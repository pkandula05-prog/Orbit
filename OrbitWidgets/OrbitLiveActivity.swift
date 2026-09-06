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
            let snapshot = context.state.snapshot
            let first = snapshot.people.first

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StaticDialView(heading: snapshot.heading, markers: snapshot.markers,
                                   style: .lockScreen, size: 62)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(Geo.formatHeading(snapshot.heading))
                            .font(OrbitFont.mono(24))
                            .foregroundStyle(.white)
                        if let first {
                            Text("\(first.name) \(Geo.formatDistance(first.distanceM))")
                                .caps(9, .white.opacity(0.7))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 18) {
                        ForEach(snapshot.people) { person in
                            HStack(spacing: 6) {
                                Text(person.name).caps(9, .white.opacity(0.7))
                                Text(Geo.formatDelta(snapshot.delta(to: person)))
                                    .font(OrbitFont.mono(15))
                                    .foregroundStyle(.white)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            } compactLeading: {
                Text(Geo.formatHeading(snapshot.heading))
                    .font(OrbitFont.mono(12))
                    .foregroundStyle(OrbitColor.red)
            } compactTrailing: {
                if let first {
                    Text(Geo.formatDelta(snapshot.delta(to: first)))
                        .font(OrbitFont.mono(12))
                        .foregroundStyle(.white)
                }
            } minimal: {
                Text(Geo.formatHeading(snapshot.heading))
                    .font(OrbitFont.mono(11))
                    .foregroundStyle(OrbitColor.red)
            }
        }
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
