import ActivityKit
import Foundation

/// A Live Activity is the only thing on iOS that updates in something close to real time
/// outside the app. A home screen widget cannot: WidgetKit wakes an extension for a timeline
/// on a daily budget and never runs it continuously, so it can never follow a compass. An
/// activity, by contrast, is pushed a new state by the app itself, as often as the app has one.
struct OrbitActivityAttributes: ActivityAttributes {
    /// Everything that changes as you walk. Pushed by the app, several times a second while
    /// it is in front, and on every location update behind it.
    struct ContentState: Codable, Hashable {
        var heading: Double
        var people: [OrbitSnapshot.Person]

        var snapshot: OrbitSnapshot {
            OrbitSnapshot(heading: heading, people: people)
        }
    }

    /// Fixed for the life of the activity.
    var startedAt: Date
}
