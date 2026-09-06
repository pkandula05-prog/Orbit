import CoreLocation
import Foundation

/// A friend's last known fix, as it arrives from whatever feed is behind `FriendSource`.
public struct FriendLocation: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var initial: String
    public var latitude: Double
    public var longitude: Double
    public var updatedAt: Date

    public init(id: String, name: String, initial: String, latitude: Double, longitude: Double, updatedAt: Date) {
        self.id = id
        self.name = name
        self.initial = initial
        self.latitude = latitude
        self.longitude = longitude
        self.updatedAt = updatedAt
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Fixes older than this dim their marker on the ring.
public let staleAfter: TimeInterval = 5 * 60

/// One friend resolved against the device: where they are on the dial and how far to turn.
public struct FriendReading: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var initial: String
    /// True bearing from the device to the friend, degrees clockwise from north.
    public var bearing: Double
    public var distanceM: Double
    /// Degrees to turn to face them: positive is clockwise.
    public var delta: Double
    public var onTarget: Bool
    public var stale: Bool
    public var tracked: Bool

    public init(id: String, name: String, initial: String, bearing: Double, distanceM: Double,
                delta: Double, onTarget: Bool, stale: Bool, tracked: Bool) {
        self.id = id
        self.name = name
        self.initial = initial
        self.bearing = bearing
        self.distanceM = distanceM
        self.delta = delta
        self.onTarget = onTarget
        self.stale = stale
        self.tracked = tracked
    }
}

public struct CompassModel: Sendable {
    public var readings: [FriendReading] = []
    public var tracked: [FriendReading] = []
    public var nearest: FriendReading?
    public var farthest: FriendReading?

    public init() {}

    /// Bearings and distances are resolved against `origin`; `heading` only feeds the turn
    /// deltas, so the geometry can be rebuilt cheaply as the device turns.
    public init(friends: [FriendLocation],
                origin: CLLocationCoordinate2D,
                heading: Double,
                trackedIDs: [String],
                now: Date = Date()) {
        readings = friends.map { friend in
            let bearing = Geo.bearing(from: origin, to: friend.coordinate)
            let delta = Geo.signedDelta(from: heading, to: bearing)

            return FriendReading(
                id: friend.id,
                name: friend.name,
                initial: friend.initial,
                bearing: bearing,
                distanceM: Geo.distance(from: origin, to: friend.coordinate),
                delta: delta,
                onTarget: Geo.isOnTarget(delta),
                stale: now.timeIntervalSince(friend.updatedAt) > staleAfter,
                tracked: trackedIDs.contains(friend.id)
            )
        }
        // Keep the ring in the order the user added people, not the feed's order.
        .sorted { a, b in
            let ia = trackedIDs.firstIndex(of: a.id) ?? Int.max
            let ib = trackedIDs.firstIndex(of: b.id) ?? Int.max
            return ia == ib ? a.name < b.name : ia < ib
        }

        tracked = readings.filter(\.tracked)
        let byDistance = tracked.sorted { $0.distanceM < $1.distanceM }
        nearest = byDistance.first
        farthest = byDistance.count > 1 ? byDistance.last : nil
    }
}
