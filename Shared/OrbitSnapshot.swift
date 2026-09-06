import Foundation

/// The dial, as a value. Shared between the app and the Live Activity that mirrors it.
public struct OrbitSnapshot: Codable, Hashable, Sendable {
    public struct Person: Codable, Hashable, Identifiable, Sendable {
        public var id: String
        public var name: String
        public var initial: String
        public var bearing: Double
        public var distanceM: Double

        public init(id: String, name: String, initial: String, bearing: Double, distanceM: Double) {
            self.id = id
            self.name = name
            self.initial = initial
            self.bearing = bearing
            self.distanceM = distanceM
        }
    }

    public var heading: Double
    public var people: [Person]
    public var capturedAt: Date

    public init(heading: Double, people: [Person], capturedAt: Date = Date()) {
        self.heading = heading
        self.people = people
        self.capturedAt = capturedAt
    }

    public func delta(to person: Person) -> Double {
        Geo.signedDelta(from: heading, to: person.bearing)
    }

    public var markers: [DialMarker] {
        people.map {
            DialMarker(id: $0.id, initial: $0.initial, bearing: $0.bearing,
                       onTarget: Geo.isOnTarget(delta(to: $0)))
        }
    }

    /// Shown while the Live Activity is starting.
    public static let placeholder = OrbitSnapshot(
        heading: 348,
        people: [
            Person(id: "ana", name: "Ana", initial: "A", bearing: 47, distanceM: 1200),
            Person(id: "miles", name: "Miles", initial: "M", bearing: 112, distanceM: 3800),
        ]
    )
}
