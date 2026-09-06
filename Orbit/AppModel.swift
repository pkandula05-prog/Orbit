import CoreLocation
import Observation
import SwiftUI

/// Where the app is. There is no account wall: permissions, then a dial — empty until you start
/// or join an orbit.
enum Phase: Equatable {
    case launch
    case permissions
    /// No orbit. One action: start one.
    case idle
    /// In an orbit, watching the dial.
    case orbit
    /// It is over, and says so. An empty dial would read as "still going, nobody here".
    case ended(OrbitSession.Ending)
}

@MainActor
@Observable
final class AppModel {
    var phase: Phase = .launch

    private(set) var session: OrbitSession?
    private(set) var participants: [Participant] = []
    private(set) var fixes: [String: ParticipantFix] = [:]

    /// Asked for at the moment of creating or joining, never before.
    var displayName = ""
    /// A link tapped before we had a name; held until the name sheet is answered.
    var pendingToken: String?
    var error: String?
    var isWorking = false

    /// Which four rows the readout is showing, when there are more than four.
    var readoutPage = 0
    var showingParticipants = false
    /// Announcements: joins and departures, by name.
    var notice: String?

    let compass = DeviceCompass()
    private let service: OrbitService
    private var updateTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var knownParticipantIDs: Set<String> = []
    private var lastPublished = Date.distantPast

    private let defaults = UserDefaults.standard
    private enum Key {
        static let name = "orbit.displayName"
        /// Only the last positions seen, so a cold open has something to draw.
        static let lastFixes = "orbit.lastFixes"
    }

    init(service: OrbitService? = nil) {
        self.service = service ?? SupabaseService.shared.map(SupabaseOrbitService.init) ?? LocalOrbitService()
        displayName = defaults.string(forKey: Key.name) ?? ""
        restoreLastFixes()
    }

    // MARK: - Model

    /// Rebuilt on the whole-degree heading rather than the drawn angle: the numbers only ever
    /// show whole degrees, so there is nothing to gain from recomputing them 120 times a second.
    var model: OrbitModel {
        guard let origin = compass.coordinate else { return OrbitModel() }
        return OrbitModel(participants: participants, fixes: fixes, origin: origin,
                          heading: Double(compass.wholeHeading))
    }

    /// Nudged apart where people are crowded, so six dots in one direction stay countable.
    var markers: [DialMarker] {
        DialMarker.resolvingCrowding(model.readings.map(DialMarker.init))
    }

    /// Four at a time, ordered by how far you would have to turn. Tapping pages through.
    var visibleRows: [ParticipantReading] {
        let rows = model.readoutRows
        guard rows.count > 4 else { return rows }
        let start = (readoutPage * 4) % rows.count
        return Array((rows + rows)[start..<(start + 4)])
    }

    var canPageReadout: Bool { model.readoutRows.count > 4 }

    var activeCount: Int { participants.filter { !$0.hasLeft }.count }
    var isHost: Bool { participants.first { $0.isSelf }?.isHost ?? false }
    var isFull: Bool { activeCount >= OrbitSession.maxParticipants }

    var timeRemaining: String {
        guard let session else { return "" }
        let seconds = max(0, session.expiresAt.timeIntervalSinceNow)
        if seconds >= 3600 { return "\(Int(seconds / 3600))h \(Int(seconds.truncatingRemainder(dividingBy: 3600) / 60))m left" }
        return "\(Int(seconds / 60))m left"
    }

    // MARK: - Lifecycle

    func start() {
        compass.start()
        compass.onLocationChange = { [weak self] coordinate, _, accuracy in
            self?.publish(coordinate, accuracy: accuracy)
        }
        Task { try? await service.ensureIdentity() }
    }

    /// A link tapped from anywhere: `orbit://join/<token>` or an https link ending in the token.
    func handle(_ url: URL) {
        let token = url.lastPathComponent
        guard !token.isEmpty, token != "/" else { return }
        guard !displayName.isEmpty else {
            pendingToken = token
            return
        }
        join(token: token)
    }

    func create(hours: Int) {
        guard !displayName.isEmpty else { error = OrbitError.needsName.errorDescription; return }
        run {
            let session = try await self.service.create(hours: hours, displayName: self.displayName)
            self.enter(session)
        }
    }

    func join(token: String) {
        guard !displayName.isEmpty else { pendingToken = token; return }
        run {
            let session = try await self.service.join(token: token, displayName: self.displayName)
            self.enter(session)
        }
    }

    func extend(hours: Int) {
        guard let session else { return }
        run { self.session = try await self.service.extend(session, hours: hours) }
    }

    func regenerateLink() {
        guard let session else { return }
        run { self.session = try await self.service.regenerateLink(session) }
    }

    /// One tap, and it does not end the orbit for anyone else.
    func leave() {
        guard let session else { return }
        Task { try? await self.service.leave(session) }
        finish(.endedByHost)
    }

    /// The host ending it ends it for everyone — the orbit belongs to whoever started it.
    func endForEveryone() {
        guard let session else { return }
        Task { try? await self.service.end(session) }
        finish(.endedByHost)
    }

    func dismissEnded() {
        phase = .idle
        session = nil
        participants = []
        fixes = [:]
    }

    private func enter(_ session: OrbitSession) {
        self.session = session
        knownParticipantIDs = []
        defaults.set(displayName, forKey: Key.name)
        pendingToken = nil
        phase = .orbit
        listen(to: session)
        watchExpiry()
    }

    private func finish(_ ending: OrbitSession.Ending) {
        updateTask?.cancel()
        expiryTask?.cancel()
        // Publishing stops the moment the orbit does — no orbit, no location updates at all.
        compass.setPublishing(false)
        phase = .ended(ending)
    }

    private func listen(to session: OrbitSession) {
        updateTask?.cancel()
        // Background updates are asked for here, in the context of joining, and nowhere else.
        compass.setPublishing(true)

        updateTask = Task { [weak self] in
            for await update in service.updates(for: session) {
                guard let self, !Task.isCancelled else { return }
                switch update {
                case .participants(let roster): self.apply(roster)
                case .fixes(let list):
                    for fix in list { self.fixes[fix.participantID] = fix }
                    self.saveLastFixes()
                case .session(let fresh):
                    self.session = fresh
                    if let ending = fresh.ending { self.finish(ending) }
                }
            }
        }
    }

    /// Joins and departures are announced by name. A stranger on the link should be
    /// conspicuous, and a silent exit sends people walking toward somebody who has gone.
    private func apply(_ roster: [Participant]) {
        let live = Set(roster.filter { !$0.hasLeft && !$0.isSelf }.map(\.id))

        if !knownParticipantIDs.isEmpty {
            let arrived = live.subtracting(knownParticipantIDs)
            let gone = knownParticipantIDs.subtracting(live)
            if let id = arrived.first, let who = roster.first(where: { $0.id == id }) {
                announce("\(who.displayName) joined")
            } else if let id = gone.first, let who = roster.first(where: { $0.id == id }) {
                announce("\(who.displayName) left")
            }
        }

        knownParticipantIDs = live
        participants = roster
    }

    private func announce(_ text: String) {
        notice = text
        Task {
            try? await Task.sleep(for: .seconds(4))
            if notice == text { notice = nil }
        }
    }

    /// Expiry is the server's to enforce; this only keeps the countdown honest on screen and
    /// closes the dial the moment the clock runs out.
    private func watchExpiry() {
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self, let session = self.session else { return }
                if let ending = session.ending { self.finish(ending); return }
            }
        }
    }

    // MARK: - Publishing

    /// Your position goes up only while you are in a live orbit, and no faster than the tier
    /// boundaries need: often enough that nobody drifts into "degraded" while walking, slow
    /// enough to be kind to the battery.
    private func publish(_ coordinate: CLLocationCoordinate2D, accuracy: Double?) {
        guard let session, session.isActive else { return }
        let interval: TimeInterval = compass.isForeground ? 5 : 45
        guard Date().timeIntervalSince(lastPublished) >= interval else { return }
        lastPublished = Date()
        Task { try? await service.publish(coordinate, accuracy: accuracy, in: session) }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        error = nil
        Task {
            do { try await work() } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isWorking = false
        }
    }

    // MARK: - Cold open

    /// Opening the app shows a blank ring for a moment while positions arrive. Drawing the last
    /// ones we saw, greyed and marked stale, beats an empty dial: stale-but-labelled is
    /// information, empty is not.
    private func saveLastFixes() {
        guard let data = try? JSONEncoder().encode(Array(fixes.values)) else { return }
        defaults.set(data, forKey: Key.lastFixes)
    }

    private func restoreLastFixes() {
        guard let data = defaults.data(forKey: Key.lastFixes),
              let saved = try? JSONDecoder().decode([ParticipantFix].self, from: data) else { return }
        fixes = Dictionary(uniqueKeysWithValues: saved.map { ($0.participantID, $0) })
    }
}
