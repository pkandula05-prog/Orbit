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
    case compass     // 09 / 5a / 5b
}

/// 5b's readout only has room for a 2×2 grid — four is the most the dial can show clearly.
let maxTracked = 4
/// Three or more tracked friends switches the readout to the 5b layout.
let denseThreshold = 3

@MainActor
@Observable
final class AppModel {
    var phase: Phase = .launch
    /// The sharing request (08) arrives over whatever is on screen.
    var incomingRequest: Contact?

    var phone = "+1 415 555 0134"
    var agreedToTerms = true
    var code = ""
    var contacts: [Contact] = []
    var selectedInvites: Set<String> = []
    var trackedIDs: [String] = []
    var signInError: String?
    var isWorking = false

    let compass = DeviceCompass()
    private(set) var friends: [FriendLocation] = []

    private let backend: AccountBackend
    private var sentCode = ""
    private var feedTask: Task<Void, Never>?
    private var acceptTask: Task<Void, Never>?
    private var lastSnapshotWrite = Date.distantPast

    private let defaults = OrbitShared.defaults ?? .standard
    private enum Key {
        static let onboarded = "orbit.onboarded"
        static let phone = "orbit.phone"
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

    // MARK: - Lifecycle

    func start() {
        compass.start()
        if contacts.isEmpty {
            Task { contacts = await backend.contacts() }
        }
        startFeed()
        listenForAcceptances()
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
                self.publishSnapshot()
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

    private var sharingIDs: [String] {
        let sharing = contacts.filter { $0.status == .sharing }.map(\.id)
        return sharing.isEmpty ? MockFriendSource.seeds.map(\.id) : sharing
    }

    private func listenForAcceptances() {
        acceptTask?.cancel()
        acceptTask = Task { [weak self] in
            for await accepted in backend.acceptances() {
                guard let self, !Task.isCancelled else { return }
                self.mark(accepted.id, as: .sharing)
                // A friend accepting is the moment they can appear, so surface it.
                self.incomingRequest = accepted
            }
        }
    }

    // MARK: - Onboarding

    func sendCode() {
        guard agreedToTerms else {
            signInError = "Agree to the terms to continue."
            return
        }
        signInError = nil
        isWorking = true
        Task {
            do {
                sentCode = try await backend.sendCode(to: phone)
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
                try await backend.verify(code: code, sentCode: sentCode)
                defaults.set(phone, forKey: Key.phone)
                phase = .permissions
            } catch {
                signInError = error.localizedDescription
            }
            isWorking = false
        }
    }

    func requestPermissions() {
        compass.requestAuthorization()
        phase = .invite
    }

    func toggleInvite(_ id: String) {
        if selectedInvites.contains(id) { selectedInvites.remove(id) } else { selectedInvites.insert(id) }
    }

    func sendInvites() {
        let ids = Array(selectedInvites)
        isWorking = true
        Task {
            try? await backend.invite(ids)
            for id in ids { mark(id, as: .pending) }
            isWorking = false
            phase = .inviteSent
        }
    }

    /// Everyone already sharing goes onto the dial, up to what 5b can show.
    func openCompass() {
        if trackedIDs.isEmpty {
            trackedIDs = Array(sharingIDs.prefix(maxTracked))
        }
        defaults.set(true, forKey: Key.onboarded)
        persist()
        startFeed()
        phase = .compass
    }

    func accept(_ contact: Contact) {
        mark(contact.id, as: .sharing)
        if trackedIDs.count < maxTracked { trackedIDs.append(contact.id) }
        incomingRequest = nil
        persist()
        startFeed()
    }

    func decline() { incomingRequest = nil }

    // MARK: - Tracking

    func toggleTracked(_ id: String) {
        if let index = trackedIDs.firstIndex(of: id) {
            trackedIDs.remove(at: index)
        } else if trackedIDs.count < maxTracked {
            trackedIDs.append(id)
        }
        persist()
    }

    func isAtCapacity(_ id: String) -> Bool {
        !trackedIDs.contains(id) && trackedIDs.count >= maxTracked
    }

    /// Start over — the flow is worth being able to replay.
    func resetOnboarding() {
        [Key.onboarded, Key.phone, Key.tracked, Key.contacts].forEach(defaults.removeObject(forKey:))
        trackedIDs = []
        selectedInvites = []
        code = ""
        Task { contacts = await backend.contacts() }
        phase = .launch
    }

    // MARK: - Persistence

    private func mark(_ id: String, as status: Contact.Status) {
        guard let index = contacts.firstIndex(where: { $0.id == id }) else { return }
        contacts[index].status = status
        persist()
    }

    private func persist() {
        defaults.set(trackedIDs, forKey: Key.tracked)
        if let data = try? JSONEncoder().encode(contacts) {
            defaults.set(data, forKey: Key.contacts)
        }
    }

    private func restore() {
        if let saved = defaults.string(forKey: Key.phone) { phone = saved }
        trackedIDs = defaults.stringArray(forKey: Key.tracked) ?? []
        if let data = defaults.data(forKey: Key.contacts),
           let saved = try? JSONDecoder().decode([Contact].self, from: data) {
            contacts = saved
        }
    }

    var hasOnboarded: Bool { defaults.bool(forKey: Key.onboarded) }

    /// The widgets redraw from this. Writing it on every fix would wake the widget process far
    /// more often than a home screen can show, so it is throttled to once a minute.
    private func publishSnapshot() {
        guard Date().timeIntervalSince(lastSnapshotWrite) > 60 else { return }
        lastSnapshotWrite = Date()
        let people = model.tracked.prefix(2).map {
            OrbitSnapshot.Person(id: $0.id, name: $0.name, initial: $0.initial,
                                 bearing: $0.bearing, distanceM: $0.distanceM)
        }
        guard !people.isEmpty else { return }
        OrbitShared.write(OrbitSnapshot(heading: Double(compass.wholeHeading), people: Array(people)))
    }
}
