import ActivityKit
import Foundation
import Observation

/// Runs the Live Activity that mirrors the dial onto the Lock Screen and Dynamic Island.
///
/// This is the real-time path. The app pushes a new state on every heading or position change
/// it sees — which, while the app is in front, is several times a second — so the activity
/// tracks you the way the dial does rather than the way a home screen widget can.
@MainActor
@Observable
final class LiveDial {
    private(set) var isRunning = false
    private var activity: Activity<OrbitActivityAttributes>?
    private var lastPush = Date.distantPast

    /// ActivityKit coalesces updates; pushing faster than this buys nothing but battery.
    private let minimumInterval: TimeInterval = 0.5

    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(with snapshot: OrbitSnapshot) {
        guard isAvailable, activity == nil, !snapshot.people.isEmpty else { return }
        let state = OrbitActivityAttributes.ContentState(heading: snapshot.heading,
                                                         people: snapshot.people)
        activity = try? Activity.request(
            attributes: OrbitActivityAttributes(startedAt: Date()),
            content: ActivityContent(state: state, staleDate: nil)
        )
        isRunning = activity != nil
    }

    func update(with snapshot: OrbitSnapshot) {
        guard let activity else { return }
        guard Date().timeIntervalSince(lastPush) >= minimumInterval else { return }
        lastPush = Date()

        let state = OrbitActivityAttributes.ContentState(heading: snapshot.heading,
                                                         people: snapshot.people)
        Task {
            // No stale date: the app is the only writer, and it is always the current dial.
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func stop() {
        guard let activity else { return }
        self.activity = nil
        isRunning = false
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
