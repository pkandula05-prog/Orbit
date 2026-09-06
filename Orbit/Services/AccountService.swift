import Foundation
import Observation

/// Someone who could be on the dial, and where they are in the sharing handshake.
struct Contact: Identifiable, Hashable, Codable, Sendable {
    enum Status: String, Codable, Sendable {
        /// Already on Orbit and sharing back — they can be tracked today.
        case sharing
        /// Invited, waiting on them.
        case pending
        /// In your contacts, not invited.
        case none
    }

    var id: String
    var name: String
    var phone: String
    var status: Status = .none

    var initial: String { String(name.prefix(1)).uppercased() }
    /// The dial only ever shows the first name; the list shows the full one.
    var shortName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

/// Everything the onboarding flow needs from a backend, in one place.
///
/// There is no Orbit server in this repository, so the shipping implementation is
/// `LocalAccountStore` — a believable stand-in that persists to the App Group. Swapping in a
/// real backend means writing one more conformance and choosing it in `OrbitApp`; no screen
/// changes.
protocol AccountBackend: Sendable {
    func sendCode(to phone: String) async throws -> String
    func verify(code: String, sentCode: String) async throws
    func invite(_ ids: [String]) async throws
    func contacts() async -> [Contact]
    /// Fires when someone accepts and their marker can appear on the dial.
    func acceptances() -> AsyncStream<Contact>
}

enum AccountError: LocalizedError {
    case badPhone, badCode

    var errorDescription: String? {
        switch self {
        case .badPhone: "Enter a mobile number we can text."
        case .badCode: "That code doesn't match. Try again."
        }
    }
}

/// Local stand-in for the service: any six digits verify, invitations go out as `pending`,
/// and the roster from the artboards is already sharing. One invitee accepts a few seconds
/// later, so the "waiting on them" state resolves in front of you rather than sitting there.
struct LocalAccountStore: AccountBackend {
    /// The roster the artboards were drawn with.
    static let seeded: [Contact] = [
        Contact(id: "ana", name: "Ana Ruiz", phone: "555 0121", status: .sharing),
        Contact(id: "miles", name: "Miles Okafor", phone: "555 0163", status: .sharing),
        Contact(id: "priya", name: "Priya Shah", phone: "555 0198"),
        Contact(id: "jae", name: "Jae Lin", phone: "555 0142"),
        Contact(id: "tom", name: "Tom Weir", phone: "555 0176"),
        Contact(id: "noor", name: "Noor Haddad", phone: "555 0110"),
        Contact(id: "tobi", name: "Tobi Adeyemi", phone: "555 0155"),
        Contact(id: "wren", name: "Wren Castillo", phone: "555 0187"),
        Contact(id: "kai", name: "Kai Mercer", phone: "555 0134"),
    ]

    func sendCode(to phone: String) async throws -> String {
        let digits = phone.filter(\.isNumber)
        guard digits.count >= 7 else { throw AccountError.badPhone }
        try? await Task.sleep(for: .milliseconds(600))
        // The artboards show 4172… as the code being typed.
        return "417208"
    }

    func verify(code: String, sentCode: String) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        guard code.count == 6, code.allSatisfy(\.isNumber) else { throw AccountError.badCode }
    }

    func invite(_ ids: [String]) async throws {
        try? await Task.sleep(for: .milliseconds(500))
    }

    func contacts() async -> [Contact] { Self.seeded }

    func acceptances() -> AsyncStream<Contact> {
        AsyncStream { continuation in
            let task = Task {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                // Sharing is reciprocal, so an acceptance is what puts someone on the dial.
                if var priya = Self.seeded.first(where: { $0.id == "priya" }) {
                    priya.status = .sharing
                    continuation.yield(priya)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
