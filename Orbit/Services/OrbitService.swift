import CoreLocation
import Foundation

/// Everything an orbit needs from a backend.
///
/// Identity is anonymous by default: `ensureIdentity` signs the device in without asking for
/// anything, because the link is the identity mechanism now. An account, if one is ever made,
/// only exists so orbits survive a reinstall.
protocol OrbitService: Sendable {
    /// Signs in anonymously if there is no session yet. Returns the user id.
    @discardableResult func ensureIdentity() async throws -> String
    func create(hours: Int, displayName: String) async throws -> OrbitSession
    func join(token: String, displayName: String) async throws -> OrbitSession
    func extend(_ orbit: OrbitSession, hours: Int) async throws -> OrbitSession
    func regenerateLink(_ orbit: OrbitSession) async throws -> OrbitSession
    func leave(_ orbit: OrbitSession) async throws
    func end(_ orbit: OrbitSession) async throws
    /// Participants, positions and the orbit's own status, as they change.
    func updates(for orbit: OrbitSession) -> AsyncStream<OrbitUpdate>
    func publish(_ fix: CLLocationCoordinate2D, accuracy: Double?, in orbit: OrbitSession) async throws
}

enum OrbitUpdate: Sendable {
    case participants([Participant])
    case fixes([ParticipantFix])
    /// A fresh copy of the orbit — the app watches this for expiry and for the host ending it.
    case session(OrbitSession)
}

enum OrbitError: LocalizedError {
    case linkInvalid, orbitFull, orbitOver, notHost, needsName

    var errorDescription: String? {
        switch self {
        case .linkInvalid: "That link has expired. Ask for a new one."
        case .orbitFull: "This orbit is full — six is the limit."
        case .orbitOver: "That orbit has ended."
        case .notHost: "Only the person who started the orbit can do that."
        case .needsName: "Enter a name so people know who you are."
        }
    }

    /// Postgres raises these by name from the join and extend functions.
    init?(postgres message: String) {
        if message.contains("link_invalid") { self = .linkInvalid }
        else if message.contains("orbit_full") { self = .orbitFull }
        else if message.contains("orbit_over") { self = .orbitOver }
        else if message.contains("not_host_or_over") { self = .notHost }
        else { return nil }
    }
}

/// Stand-in used when no Supabase project is configured, so the app runs and demos with no
/// backend at all. Three people walk around you; one of them goes quiet after a while, so the
/// staleness tiers can be seen without waiting for a friend to lose signal.
actor LocalOrbitService: OrbitService {
    private var participants: [Participant] = []
    private var origin: CLLocationCoordinate2D = .init(latitude: 37.7749, longitude: -122.4194)

    private static let cast = [
        ("Ana", 47.0, 320.0), ("Miles", 112.0, 780.0), ("Jae", 205.0, 1900.0),
    ]

    @discardableResult
    func ensureIdentity() async throws -> String { "local-user" }

    func create(hours: Int, displayName: String) async throws -> OrbitSession {
        makeSession(hours: hours, displayName: displayName, isHost: true)
    }

    func join(token: String, displayName: String) async throws -> OrbitSession {
        makeSession(hours: 6, displayName: displayName, isHost: false)
    }

    private func makeSession(hours: Int, displayName: String, isHost: Bool) -> OrbitSession {
        participants = [Participant(id: "me", displayName: displayName, joinedAt: Date(),
                                    isSelf: true, isHost: isHost)]
        participants += Self.cast.enumerated().map { index, person in
            Participant(id: "p\(index)", displayName: person.0, joinedAt: Date())
        }
        return OrbitSession(id: UUID().uuidString, hostUserID: isHost ? "local-user" : "someone",
                            expiresAt: Date().addingTimeInterval(Double(hours) * 3600),
                            joinToken: isHost ? "demo-link" : nil,
                            tokenExpiresAt: isHost ? Date().addingTimeInterval(3600) : nil)
    }

    func extend(_ orbit: OrbitSession, hours: Int) async throws -> OrbitSession {
        var updated = orbit
        updated.expiresAt = min(orbit.expiresAt.addingTimeInterval(Double(hours) * 3600),
                                Date().addingTimeInterval(24 * 3600))
        return updated
    }

    func regenerateLink(_ orbit: OrbitSession) async throws -> OrbitSession {
        var updated = orbit
        updated.joinToken = "demo-\(Int.random(in: 1000...9999))"
        updated.tokenExpiresAt = Date().addingTimeInterval(3600)
        return updated
    }

    func leave(_ orbit: OrbitSession) async throws { participants = [] }
    func end(_ orbit: OrbitSession) async throws { participants = [] }

    func updates(for orbit: OrbitSession) -> AsyncStream<OrbitUpdate> {
        AsyncStream { continuation in
            let roster = participants
            let anchor = origin
            let task = Task {
                continuation.yield(.participants(roster))
                let start = Date()
                while !Task.isCancelled {
                    let elapsed = Date().timeIntervalSince(start)
                    let fixes = Self.cast.enumerated().map { index, person in
                        let drift = sin(elapsed / 20 + Double(index)) * 6
                        let point = Geo.destination(from: anchor, bearing: person.1 + drift,
                                                    metres: person.2 + sin(elapsed / 30) * 120)
                        // Jae stops reporting after a minute, so degraded and ghost are visible.
                        let age: TimeInterval = index == 2 ? min(elapsed, 700) : 0
                        return ParticipantFix(participantID: "p\(index)",
                                              latitude: point.latitude, longitude: point.longitude,
                                              accuracy: 12,
                                              updatedAt: Date().addingTimeInterval(-age))
                    }
                    continuation.yield(.fixes(fixes))
                    try? await Task.sleep(for: .seconds(3))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func publish(_ fix: CLLocationCoordinate2D, accuracy: Double?, in orbit: OrbitSession) async throws {
        origin = fix
    }
}
