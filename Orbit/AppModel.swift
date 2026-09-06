import CoreLocation
import Observation
import SwiftUI

/// Where the flow is. Artboards 02–09 are steps of one journey, not separate destinations, so
/// the app holds the step rather than pushing routes.
enum Phase: Equatable {
    case launch      // 02
    case signIn      // 03
    case verify      // 04
    case permissions // 05
    case invite      // 06
    case inviteSent  // 07
    case orbit       // 09 / 5a / 5b
}

/// 5b's readout only has room for a 2×2 grid — four is the most the dial can show clearly.
let maxTracked = 4
/// Three or more tracked friends switches the readout to the 5b layout.
let denseThreshold = 3

@MainActor
@Observable
final class AppModel {
    enum UsernameState: Equatable {
        case empty, invalid, checking, available, taken
    }

    var phase: Phase = .launch

    var profile = Profile(phone: "+1 415 555 0134")
    var agreedToTerms = true
    var usernameState: UsernameState = .empty
    var code = ""
    var signInError: String?
    var isWorking = false

    var contacts: [Contact] = []
    var selectedInvites: Set<String> = []
    var trackedIDs: [String] = []
    /// Whether the address book has been matched — the friends page asks, nothing else does.
    var hasMatchedContacts = false
    var contactsDenied = false

    /// Sheets over the dial: the invite inbox and the friends page.
    var showingInvites = false
    var showingFriends = false

    let compass = DeviceCompass()
    /// The Lock Screen / Dynamic Island dial. This is the only surface outside the app that
    /// can follow you in real time.
    let live = LiveDial()
    private(set) var friends: [FriendLocation] = []

    private let backend: AccountBackend
    private var sentCode = ""
    private var feedTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var usernameTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private enum Key {
        static let onboarded = "orbit.onboarded"
        static let profile = "orbit.profile"
        static let tracked = "orbit.tracked"
        static let contacts = "orbit.contacts"
    }

    init(backend: AccountBackend = LocalAccountStore()) {
        self.backend = backend
        restore()
    }

    // MARK: - Model

    /// Rebuilt on the whole-degree heading rather than the drawn angle: the numbers only ever
    /// show whole degrees, so there is nothing to gain from recomputing them 120 times a
    /// second, and plenty to lose.
    var model: CompassModel {
        CompassModel(friends: friends,
                     origin: compass.coordinate ?? MockFriendSource.demoOrigin,
                     heading: Double(compass.wholeHeading),
                     trackedIDs: trackedIDs)
    }

    var dense: Bool { trackedIDs.count >= denseThreshold }

    var headerRight: String {
        guard let altitude = compass.altitude else { return "\(trackedIDs.count) tracked" }
        return "Alt \(Int(altitude.rounded())) m"
    }

    /// People who asked to share with you and are still waiting on an answer. Nothing of yours
    /// is shared with them until you accept.
    var incomingInvites: [Contact] { contacts.filter { $0.relation == .invitedMe } }

    /// Only people you and they have both agreed to share with are on the dial.
    private var sharingIDs: [String] { contacts.filter { $0.relation == .sharing }.map(\.id) }

    // MARK: - Lifecycle

    func start() {
        compass.start()
        // Every whole degree, not every frame: enough to look continuous, cheap enough to push.
        compass.onHeadingChange = { [weak self] _ in self?.pushLive() }
        if contacts.isEmpty { loadDirectory() }
        startFeed()
        listenForEvents()
    }

    /// Without contacts access there is still the invite inbox and search, so the page is never
    /// empty and the permission stays optional.
    private func loadDirectory() {
        Task {
            let invites = (try? await backend.invites()) ?? []
            merge(invites)
        }
    }

    func matchContacts() {
        Task {
            guard let phones = await ContactsAccess.requestAndFetch() else {
                contactsDenied = true
                return
            }
            hasMatchedContacts = true
            contactsDenied = false
            merge((try? await backend.match(phones: phones)) ?? [])
        }
    }

    /// Adds people we did not already know about, and never downgrades a relation we hold.
    private func merge(_ incoming: [Contact]) {
        for contact in incoming {
            if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
                if contacts[index].relation == .none { contacts[index].relation = contact.relation }
                contacts[index].isOnOrbit = contact.isOnOrbit
            } else {
                contacts.append(contact)
            }
        }
        persist()
    }

    private func startFeed() {
        feedTask?.cancel()
        let source = Self.makeSource(origin: { [fix = compass.lastFix] in
            fix.coordinate ?? MockFriendSource.demoOrigin
        }, visible: sharingIDs)

        feedTask = Task { [weak self] in
            for await batch in source.stream() {
                guard let self, !Task.isCancelled else { return }
                self.friends = batch
                self.pushLive()
            }
        }
    }

    /// A real feed reports real coordinates and ignores `origin`; only the mock uses it.
    private static func makeSource(origin: @escaping @Sendable () -> CLLocationCoordinate2D,
                                   visible: [String]) -> FriendSource {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "OrbitFeedURL") as? String,
           !raw.isEmpty, let url = URL(string: raw) {
            let token = Bundle.main.object(forInfoDictionaryKey: "OrbitFeedToken") as? String
            return RESTFriendSource(endpoint: url, token: token?.isEmpty == false ? token : nil)
        }
        return MockFriendSource(origin: origin, visible: visible)
    }

    private func listenForEvents() {
        eventTask?.cancel()
        eventTask = Task { [weak self, backend] in
            for await event in backend.events() {
                guard let self, !Task.isCancelled else { return }
                switch event {
                case .invited(let contact): self.merge([contact])
                case .accepted(let contact):
                    self.set(contact.id, to: .sharing)
                    self.startFeed()
                }
            }
        }
    }

    // MARK: - Sign in

    /// Debounced so a check goes out per pause in typing, not per keystroke.
    func usernameChanged() {
        usernameTask?.cancel()
        let username = profile.username.lowercased()
        profile.username = username

        guard !username.isEmpty else { usernameState = .empty; return }
        guard Profile.isValidUsername(username) else { usernameState = .invalid; return }

        usernameState = .checking
        usernameTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let available = (try? await backend.isUsernameAvailable(username)) ?? false
            guard !Task.isCancelled, profile.username.lowercased() == username else { return }
            usernameState = available ? .available : .taken
        }
    }

    var canSendCode: Bool {
        profile.isComplete && agreedToTerms && usernameState == .available
    }

    func sendCode() {
        guard agreedToTerms else {
            signInError = "Agree to the terms and privacy notice to continue."
            return
        }
        guard usernameState != .taken else {
            signInError = AccountError.usernameTaken.errorDescription
            return
        }
        guard profile.isComplete else {
            signInError = AccountError.incompleteProfile.errorDescription
            return
        }
        signInError = nil
        isWorking = true
        Task {
            do {
                sentCode = try await backend.sendCode(to: profile.phone)
                code = ""
                phase = .verify
            } catch {
                signInError = error.localizedDescription
            }
            isWorking = false
        }
    }

    func verifyCode() {
        signInError = nil
        isWorking = true
        Task {
            do {
                try await backend.verify(code: code, sentCode: sentCode, profile: profile)
                persist()
                phase = .permissions
            } catch {
                signInError = error.localizedDescription
            }
            isWorking = false
        }
    }

    /// The only place the app asks for location and compass access.
    func requestPermissions() {
        compass.requestAuthorization()
        phase = .invite
    }

    // MARK: - Invites

    func toggleInvite(_ id: String) {
        if selectedInvites.contains(id) { selectedInvites.remove(id) } else { selectedInvites.insert(id) }
    }

    /// Inviting shares nothing. It asks — and only their acceptance starts a two-way share.
    func sendInvites() {
        let ids = Array(selectedInvites)
        guard !ids.isEmpty else { return }
        isWorking = true
        Task {
            try? await backend.invite(ids)
            for id in ids { set(id, to: .invitedByMe) }
            selectedInvites = []
            isWorking = false
            if phase == .invite { phase = .inviteSent }
        }
    }

    /// Someone with no account yet: they get an SMS with a link, and appear once they join.
    func inviteByPhone(_ phone: String) {
        isWorking = true
        Task {
            do {
                try await backend.inviteByPhone(phone)
                signInError = nil
            } catch {
                signInError = error.localizedDescription
            }
            isWorking = false
        }
    }

    /// Accepting is the explicit, two-way act that starts sharing; declining shares nothing.
    func respond(to contact: Contact, accept: Bool) {
        Task { try? await backend.respond(to: contact.id, accept: accept) }
        if accept {
            set(contact.id, to: .sharing)
            if trackedIDs.count < maxTracked { trackedIDs.append(contact.id) }
            startFeed()
        } else {
            contacts.removeAll { $0.id == contact.id }
        }
        persist()
    }

    func openOrbit() {
        if trackedIDs.isEmpty { trackedIDs = Array(sharingIDs.prefix(maxTracked)) }
        defaults.set(true, forKey: Key.onboarded)
        persist()
        startFeed()
        phase = .orbit
        pushLive()
    }

    // MARK: - Tracking

    func toggleTracked(_ id: String) {
        if let index = trackedIDs.firstIndex(of: id) {
            trackedIDs.remove(at: index)
        } else if trackedIDs.count < maxTracked {
            trackedIDs.append(id)
        }
        persist()
        if trackedIDs.isEmpty { live.stop() } else { pushLive() }
    }

    func isAtCapacity(_ id: String) -> Bool {
        !trackedIDs.contains(id) && trackedIDs.count >= maxTracked
    }

    /// Start over — the flow is worth being able to replay.
    func resetOnboarding() {
        [Key.onboarded, Key.profile, Key.tracked, Key.contacts].forEach(defaults.removeObject(forKey:))
        trackedIDs = []
        selectedInvites = []
        contacts = []
        code = ""
        profile = Profile(phone: "+1 415 555 0134")
        usernameState = .empty
        hasMatchedContacts = false
        loadDirectory()
        phase = .launch
    }

    // MARK: - Persistence

    private func set(_ id: String, to relation: Contact.Relation) {
        guard let index = contacts.firstIndex(where: { $0.id == id }) else { return }
        contacts[index].relation = relation
        persist()
    }

    private func persist() {
        defaults.set(trackedIDs, forKey: Key.tracked)
        if let data = try? JSONEncoder().encode(contacts) { defaults.set(data, forKey: Key.contacts) }
        if let data = try? JSONEncoder().encode(profile) { defaults.set(data, forKey: Key.profile) }
    }

    private func restore() {
        if let data = defaults.data(forKey: Key.profile),
           let saved = try? JSONDecoder().decode(Profile.self, from: data) {
            profile = saved
            usernameState = saved.username.isEmpty ? .empty : .available
        }
        trackedIDs = defaults.stringArray(forKey: Key.tracked) ?? []
        if let data = defaults.data(forKey: Key.contacts),
           let saved = try? JSONDecoder().decode([Contact].self, from: data) {
            contacts = saved
        }
    }

    var hasOnboarded: Bool { defaults.bool(forKey: Key.onboarded) }

    /// The widgets redraw from this. Written whenever the dial has materially changed — a new
    /// bearing, a new distance, someone added or dropped — rather than on a fixed clock, so a
    /// widget is never more than one fix behind while the app is open.
    /// The dial as the Live Activity wants it.
    private func currentSnapshot() -> OrbitSnapshot? {
        let people = model.tracked.prefix(2).map { friend in
            OrbitSnapshot.Person(id: friend.id, name: friend.name, initial: friend.initial,
                                 bearing: friend.bearing, distanceM: friend.distanceM)
        }
        guard !people.isEmpty else { return nil }
        return OrbitSnapshot(heading: Double(compass.wholeHeading), people: Array(people))
    }

    /// Real time, as far as iOS allows: the activity is pushed on every whole degree and every
    /// fix. This is the only surface outside the app that can keep up — a home screen widget
    /// cannot read the compass and is reloaded on a daily budget, which is why there are none.
    private func pushLive() {
        guard phase == .orbit, let snapshot = currentSnapshot() else { return }
        if live.isRunning {
            live.update(with: snapshot)
        } else {
            live.start(with: snapshot)
            compass.requestBackgroundUpdates()
        }
    }
}
