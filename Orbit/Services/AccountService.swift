import Foundation

/// The signed-in person.
struct Profile: Codable, Hashable, Sendable {
    var firstName = ""
    var lastName = ""
    var username = ""
    var phone = ""

    var isComplete: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && Profile.isValidUsername(username)
            && phone.filter(\.isNumber).count >= 7
    }

    /// Lowercase letters, digits and underscore, 3–20 — what the backend must also enforce.
    static func isValidUsername(_ raw: String) -> Bool {
        let value = raw.lowercased()
        guard (3...20).contains(value.count) else { return false }
        return value.allSatisfy { $0.isLowercase && $0.isASCII || $0.isNumber || $0 == "_" }
    }
}

/// Someone who could be on the dial, and where they stand with you.
struct Contact: Identifiable, Hashable, Codable, Sendable {
    /// Sharing is never implied. Being matched from your contacts, or being invited, puts
    /// nobody on the dial — only `sharing`, which both people have to agree to, does that.
    enum Relation: String, Codable, Sendable {
        case none          // matched from contacts, or found by search
        case invitedByMe   // you asked; waiting on them
        case invitedMe     // they asked; waiting on you
        case sharing       // mutual, and the only state that shows a location
    }

    /// Where this person came from, so the friends page can group them.
    enum Source: String, Codable, Sendable {
        case contacts, invite, search
    }

    var id: String
    var firstName: String
    var lastName: String
    var username: String
    var phone: String
    /// False for someone who is only in your address book — they get an SMS invite instead.
    var isOnOrbit: Bool = true
    var relation: Relation = .none
    var source: Source = .contacts

    var name: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var initial: String { String(firstName.prefix(1)).uppercased() }
    /// The dial only ever shows the first name.
    var shortName: String { firstName }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let needle = query.lowercased()
        let digits = query.filter(\.isNumber)
        return name.lowercased().contains(needle)
            || username.lowercased().contains(needle)
            || (!digits.isEmpty && phone.filter(\.isNumber).contains(digits))
    }
}

/// What the backend pushes at us while the app is open.
enum AccountEvent: Sendable {
    /// Someone you invited accepted, so you may now see each other.
    case accepted(Contact)
    /// Someone asked to share with you. Nothing is shared until you accept.
    case invited(Contact)
}

/// Everything the flow needs from a server, in one place.
///
/// There is no Orbit server in this repository, so the shipping implementation is
/// `LocalAccountStore`. The API contract each method stands for is documented in the README;
/// swapping in a real backend means one more conformance and a line in `OrbitApp`.
protocol AccountBackend: Sendable {
    /// `POST /username/check` → `{ "available": true }`.
    func isUsernameAvailable(_ username: String) async throws -> Bool
    /// `POST /auth/code` → `{ "sent": true }`.
    func sendCode(to phone: String) async throws -> String
    /// `POST /auth/verify` → session token, and creates the account with the profile.
    func verify(code: String, sentCode: String, profile: Profile) async throws
    /// `POST /contacts/match` with hashed phone numbers → the ones with accounts.
    func match(phones: [String]) async throws -> [Contact]
    /// `GET /invites` → both directions.
    func invites() async throws -> [Contact]
    /// `POST /invites` → creates a pending invite for an existing account.
    func invite(_ ids: [String]) async throws
    /// `POST /invites/sms` → sends an invite link to someone with no account yet.
    func inviteByPhone(_ phone: String) async throws
    /// `POST /invites/{id}/respond` → accepting is what starts sharing, in both directions.
    func respond(to id: String, accept: Bool) async throws
    /// Server-sent events or a socket in a real backend; a stream either way.
    func events() -> AsyncStream<AccountEvent>
}

enum AccountError: LocalizedError {
    case badPhone, badCode, usernameTaken, incompleteProfile

    var errorDescription: String? {
        switch self {
        case .badPhone: "Enter a mobile number we can text."
        case .badCode: "That code doesn't match. Try again."
        case .usernameTaken: "That username is already taken."
        case .incompleteProfile: "Fill in every field to continue."
        }
    }
}

/// Local stand-in for the service: any six digits verify, a handful of usernames are already
/// taken, invitations go out as pending, and one person invites you a few seconds in so the
/// notification badge and the accept / decline flow can be walked without a server.
struct LocalAccountStore: AccountBackend {
    /// The roster the artboards were drawn with. `relation` here is the *starting* state.
    static let seeded: [Contact] = [
        Contact(id: "ana", firstName: "Ana", lastName: "Ruiz", username: "ana", phone: "555 0121", relation: .sharing),
        Contact(id: "miles", firstName: "Miles", lastName: "Okafor", username: "milesok", phone: "555 0163", relation: .sharing),
        Contact(id: "priya", firstName: "Priya", lastName: "Shah", username: "priya_s", phone: "555 0198"),
        Contact(id: "jae", firstName: "Jae", lastName: "Lin", username: "jaelin", phone: "555 0142"),
        Contact(id: "tom", firstName: "Tom", lastName: "Weir", username: "tweir", phone: "555 0176"),
        Contact(id: "noor", firstName: "Noor", lastName: "Haddad", username: "noor", phone: "555 0110"),
        Contact(id: "tobi", firstName: "Tobi", lastName: "Adeyemi", username: "tobi", phone: "555 0155"),
        Contact(id: "wren", firstName: "Wren", lastName: "Castillo", username: "wren", phone: "555 0187",
                isOnOrbit: false),
        Contact(id: "kai", firstName: "Kai", lastName: "Mercer", username: "kai", phone: "555 0134"),
    ]

    /// What a `POST /username/check` would reject.
    static let takenUsernames: Set<String> = ["orbit", "admin", "ana", "miles", "jae", "priya", "kai", "noor"]

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        try? await Task.sleep(for: .milliseconds(350))
        return !Self.takenUsernames.contains(username.lowercased())
    }

    func sendCode(to phone: String) async throws -> String {
        guard phone.filter(\.isNumber).count >= 7 else { throw AccountError.badPhone }
        try? await Task.sleep(for: .milliseconds(600))
        // The artboards show 4172… being typed.
        return "417208"
    }

    func verify(code: String, sentCode: String, profile: Profile) async throws {
        guard profile.isComplete else { throw AccountError.incompleteProfile }
        try? await Task.sleep(for: .milliseconds(500))
        guard code.count == 6, code.allSatisfy(\.isNumber) else { throw AccountError.badCode }
        guard try await isUsernameAvailable(profile.username) else { throw AccountError.usernameTaken }
    }

    /// A real backend matches on salted hashes and never sees the raw book.
    func match(phones: [String]) async throws -> [Contact] {
        try? await Task.sleep(for: .milliseconds(300))
        guard !phones.isEmpty else { return Self.seeded }
        let digits = Set(phones.map { $0.filter(\.isNumber).suffix(7) })
        return Self.seeded.filter { digits.contains($0.phone.filter(\.isNumber).suffix(7)) }
    }

    func invites() async throws -> [Contact] {
        var jae = Self.seeded.first { $0.id == "jae" }!
        jae.relation = .invitedMe
        jae.source = .invite
        return [jae]
    }

    func invite(_ ids: [String]) async throws {
        try? await Task.sleep(for: .milliseconds(500))
    }

    func inviteByPhone(_ phone: String) async throws {
        guard phone.filter(\.isNumber).count >= 7 else { throw AccountError.badPhone }
        try? await Task.sleep(for: .milliseconds(400))
    }

    func respond(to id: String, accept: Bool) async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }

    func events() -> AsyncStream<AccountEvent> {
        AsyncStream { continuation in
            let task = Task {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                if var priya = Self.seeded.first(where: { $0.id == "priya" }) {
                    priya.relation = .invitedMe
                    priya.source = .invite
                    continuation.yield(.invited(priya))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
