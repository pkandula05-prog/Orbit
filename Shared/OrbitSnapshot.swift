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
        /// Which way they are moving, degrees clockwise from north. Nil when they are still.
        public var course: Double?
        public var speedMps: Double

        public init(id: String, name: String, initial: String, bearing: Double, distanceM: Double,
                    course: Double? = nil, speedMps: Double = 0) {
            self.id = id
            self.name = name
            self.initial = initial
            self.bearing = bearing
            self.distanceM = distanceM
            self.course = course
            self.speedMps = speedMps
        }

        /// Are they closing on you, or opening away? The sign of the component of their travel
        /// along the line between you.
        public var closingSpeed: Double {
            guard let course, speedMps > 0.2 else { return 0 }
            // Their course relative to the direction back toward you.
            return speedMps * cos((course - (bearing + 180)) * .pi / 180)
        }

        /// Where they will be `seconds` from now if they keep going as they are. A widget is
        /// only reloaded every few minutes, so its later timeline entries are projected rather
        /// than repeats of one stale fix.
        public func projected(bySeconds seconds: Double) -> Person {
            guard let course, speedMps > 0.2, seconds > 0 else { return self }
            // Work in a local plane: at these distances the curvature does not matter.
            let travelled = speedMps * seconds
            let x = distanceM * sin(bearing * .pi / 180) + travelled * sin(course * .pi / 180)
            let y = distanceM * cos(bearing * .pi / 180) + travelled * cos(course * .pi / 180)

            var moved = self
            moved.bearing = Geo.normalize(atan2(x, y) * 180 / .pi)
            moved.distanceM = sqrt(x * x + y * y)
            return moved
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

    /// A change nobody could see on a home screen is not worth a widget reload.
    public func differsMeaningfully(from other: OrbitSnapshot?) -> Bool {
        guard let other else { return true }
        guard other.people.map(\.id) == people.map(\.id) else { return true }
        if abs(Geo.signedDelta(from: other.heading, to: heading)) >= 2 { return true }
        return zip(people, other.people).contains { new, old in
            abs(Geo.signedDelta(from: old.bearing, to: new.bearing)) >= 2
                || abs(new.distanceM - old.distanceM) >= 25
        }
    }

    /// The same dial, rolled forward — every person carried along their own course.
    public func projected(bySeconds seconds: Double) -> OrbitSnapshot {
        OrbitSnapshot(heading: heading,
                      people: people.map { $0.projected(bySeconds: seconds) },
                      capturedAt: capturedAt.addingTimeInterval(seconds))
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
            Person(id: "ana", name: "Ana", initial: "A", bearing: 47, distanceM: 1200,
                   course: 214, speedMps: 1.4),
            Person(id: "miles", name: "Miles", initial: "M", bearing: 112, distanceM: 3800,
                   course: 30, speedMps: 0.6),
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
