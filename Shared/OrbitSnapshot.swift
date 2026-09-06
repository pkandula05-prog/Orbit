import Foundation
import WidgetKit

/// What the widgets get to see. A widget cannot read the compass — extensions are woken for a
/// timeline, not run continuously — so the app writes the last dial it drew into the shared
/// container and the widgets render that.
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

    /// Shown in the widget gallery and before the app has ever run.
    public static let placeholder = OrbitSnapshot(
        heading: 348,
        people: [
            Person(id: "ana", name: "Ana", initial: "A", bearing: 47, distanceM: 1200),
            Person(id: "miles", name: "Miles", initial: "M", bearing: 112, distanceM: 3800),
        ]
    )
}

/// The one place the App Group identifier is written down. It must match the App Groups
/// capability on both targets' entitlements.
public enum OrbitShared {
    public static let appGroup = "group.com.orbit.compass"
    public static let widgetKind = "OrbitCompassWidget"
    private static let key = "orbit.snapshot"

    public static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    public static func write(_ snapshot: OrbitSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    public static func read() -> OrbitSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(OrbitSnapshot.self, from: data)
    }
}
