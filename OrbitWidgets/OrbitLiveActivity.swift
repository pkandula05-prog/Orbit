import ActivityKit
import SwiftUI
import WidgetKit

/// The dial on the Lock Screen and in the Dynamic Island, updated by the app in real time.
struct OrbitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrbitActivityAttributes.self) { context in
            LockScreenLive(state: context.state)
                .padding(16)
                .activityBackgroundTint(OrbitColor.ink.opacity(0.85))
                .activitySystemActionForegroundColor(OrbitColor.bg)
        } dynamicIsland: { context in
            // ActivityKit requires a Dynamic Island presentation; there is no way to decline
            // one. So it is kept to the minimum the API accepts — the heading, nothing more —
            // rather than a second copy of the dial competing with the Lock Screen.
            let snapshot = context.state.snapshot

            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(Geo.formatHeading(snapshot.heading))
                        .font(OrbitFont.mono(22))
                        .foregroundStyle(.white)
                }
            } compactLeading: {
                Text(Geo.formatHeading(snapshot.heading))
                    .font(OrbitFont.mono(12))
                    .foregroundStyle(OrbitColor.red)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Text(Geo.formatHeading(snapshot.heading))
                    .font(OrbitFont.mono(11))
                    .foregroundStyle(OrbitColor.red)
            }
        }
    }
}

/// The extension exists only to host the Live Activity now. The home screen widgets were
/// removed: a widget extension cannot read the compass and is reloaded on a daily budget, so
/// a live dial was never possible there — this is the surface the app can actually push to.
@main
struct OrbitWidgetBundle: WidgetBundle {
    var body: some Widget {
        OrbitLiveActivity()
    }
}

private struct LockScreenLive: View {
    var state: OrbitActivityAttributes.ContentState

    var body: some View {
        let snapshot = state.snapshot

        HStack(spacing: 18) {
            StaticDialView(heading: snapshot.heading, markers: snapshot.markers,
                           style: .lockScreen, size: 76)

            VStack(alignment: .leading, spacing: 0) {
                Text(Geo.formatHeading(snapshot.heading))
                    .font(OrbitFont.mono(30))
                    .foregroundStyle(.white)
                Text(Geo.cardinalName(snapshot.heading))
                    .caps(9, .white.opacity(0.6))
                    .padding(.top, 4)

                ForEach(snapshot.people) { person in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(person.name).caps(9, .white.opacity(0.7))
                        Spacer(minLength: 8)
                        Text(Geo.formatDistance(person.distanceM))
                            .font(OrbitFont.mono(10, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(Geo.formatDelta(snapshot.delta(to: person)))
                            .font(OrbitFont.mono(15))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}
