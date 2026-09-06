import CoreLocation
import Foundation

/// An orbit: a handful of people, a shared link, and an expiry. Nobody is on your dial by
/// default — membership only ever comes from joining one of these, and it always ends.
struct OrbitSession: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var hostUserID: String
    var expiresAt: Date
    var endedAt: Date?
    /// Present for the host only: the current link and its own, much shorter, expiry.
    var joinToken: String?
    var tokenExpiresAt: Date?

    /// Durations the host can pick. There is deliberately no indefinite option.
    static let durations = [1, 6, 12, 24]
    static let maxParticipants = 6

    var isActive: Bool { endedAt == nil && expiresAt > Date() }

    var isLinkLive: Bool {
        guard let tokenExpiresAt, joinToken != nil else { return false }
        return tokenExpiresAt > Date() && isActive
    }

    /// Why it is over, for the ended state — being explicit is the whole point of that screen.
    enum Ending: Sendable { case endedByHost, expired }

    var ending: Ending? {
        if endedAt != nil { return .endedByHost }
        return expiresAt <= Date() ? .expired : nil
    }
}

struct Participant: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var displayName: String
    var joinedAt: Date
    var leftAt: Date?
    var isSelf = false
    var isHost = false

    var initial: String { String(displayName.prefix(1)).uppercased() }
    var hasLeft: Bool { leftAt != nil }
}

/// The last fix for one participant, as it comes off the wire.
struct ParticipantFix: Codable, Hashable, Sendable {
    var participantID: String
    var latitude: Double
    var longitude: Double
    var accuracy: Double?
    var updatedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// How much to trust a fix, by age.
///
/// The tiers only mean something relative to how often people publish: if the background
/// interval is longer than the fresh window, everybody is permanently degraded. Tune these and
/// the publish interval together, and check it on a real phone in a real pocket.
enum Freshness: Sendable {
    case fresh      // under 90s
    case degraded   // 90s to 10 minutes
    case ghost      // over 10 minutes

    static let freshWindow: TimeInterval = 90
    static let ghostAfter: TimeInterval = 600

    init(age: TimeInterval) {
        if age < Self.freshWindow { self = .fresh }
        else if age < Self.ghostAfter { self = .degraded }
        else { self = .ghost }
    }
}

/// Distance changes what a bearing is *for*, so it changes what the dial says.
///
/// Nothing is ever cut off. A far participant is not inactive — we know exactly where they are,
/// it just is not a turn-your-head number any more.
enum Range: Sendable {
    case near   // under 1 km: precise delta, precise distance
    case far    // beyond: coarse bearing, rounded distance, hand off to Maps

    static let nearLimit: Double = 1000

    init(metres: Double) { self = metres < Self.nearLimit ? .near : .far }
}

/// One participant resolved against you: where they are on the ring, and how much of that to
/// believe.
struct ParticipantReading: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var initial: String
    var isSelf: Bool
    var hasLeft: Bool
    /// True bearing, degrees clockwise from north.
    var bearing: Double
    var distanceM: Double
    /// Degrees to turn to face them; positive is clockwise.
    var delta: Double
    var onTarget: Bool
    var freshness: Freshness
    var range: Range
    var age: TimeInterval

    /// The turn, when a turn is a useful thing to give. Beyond a kilometre it is not.
    var deltaText: String? {
        guard range == .near, freshness != .ghost else { return nil }
        return Geo.formatDelta(delta)
    }

    /// Far and stale say different things, so they read differently. Far is an eight-point
    /// bearing — still true, just coarser. Stale is a band, because precision would be a lie.
    var distanceText: String {
        switch (freshness, range) {
        case (.ghost, _): "Last seen \(Self.minutes(age))"
        case (.degraded, _): Geo.bandedDistance(distanceM)
        case (.fresh, .near): Geo.formatDistance(distanceM)
        case (.fresh, .far): "\(Geo.compassPoint(bearing)) · \(Geo.formatDistance(distanceM))"
        }
    }

    private static func minutes(_ age: TimeInterval) -> String {
        let value = max(1, Int(age / 60))
        return "\(value) min"
    }
}

/// The whole dial, in one value.
struct OrbitModel: Sendable {
    var readings: [ParticipantReading] = []

    init() {}

    init(participants: [Participant],
         fixes: [String: ParticipantFix],
         origin: CLLocationCoordinate2D,
         heading: Double,
         now: Date = Date()) {
        readings = participants.compactMap { person in
            guard !person.isSelf, let fix = fixes[person.id] else { return nil }
            let bearing = Geo.bearing(from: origin, to: fix.coordinate)
            let delta = Geo.signedDelta(from: heading, to: bearing)
            let distance = Geo.distance(from: origin, to: fix.coordinate)
            let age = now.timeIntervalSince(fix.updatedAt)

            return ParticipantReading(
                id: person.id, name: person.displayName, initial: person.initial,
                isSelf: false, hasLeft: person.hasLeft,
                bearing: bearing, distanceM: distance, delta: delta,
                onTarget: Geo.isOnTarget(delta), freshness: Freshness(age: age),
                range: Range(metres: distance), age: age
            )
        }
    }

    /// What the readout shows first: whoever you are closest to *facing*. The list reorders as
    /// you turn, which is the point — it answers "who is that way".
    var byTurn: [ParticipantReading] {
        readings.sorted { abs($0.delta) < abs($1.delta) }
    }

    /// Ghosts stay on the ring but leave the readout: a name with no usable number under it is
    /// just noise, and removing the dot entirely would read as "gone".
    var readoutRows: [ParticipantReading] {
        byTurn.filter { $0.freshness != .ghost && !$0.hasLeft }
    }

    var nearest: ParticipantReading? { readings.min { $0.distanceM < $1.distanceM } }
}
