import SwiftUI
import WidgetKit

struct OrbitEntry: TimelineEntry {
    let date: Date
    let snapshot: OrbitSnapshot
}

/// The widget draws whatever dial the app last wrote to the shared container. It cannot read
/// the compass itself — an extension is woken for a timeline, not run continuously — so the
/// heading here is the last one you saw, not a live one.
struct OrbitProvider: TimelineProvider {
    func placeholder(in context: Context) -> OrbitEntry {
        OrbitEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (OrbitEntry) -> Void) {
        completion(OrbitEntry(date: Date(), snapshot: OrbitShared.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrbitEntry>) -> Void) {
        let entry = OrbitEntry(date: Date(), snapshot: OrbitShared.read() ?? .placeholder)
        // The app reloads us whenever it has a materially newer dial; this is only the floor.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct OrbitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: OrbitEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Accessory families are rendered in the system's own vibrant material, so the
            // widget must not paint a ground of its own.
            LockScreenDial(snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        case .systemMedium:
            MediumWidget(snapshot: entry.snapshot)
                .containerBackground(OrbitColor.bg, for: .widget)
        default:
            SmallWidget(snapshot: entry.snapshot)
                .containerBackground(OrbitColor.bg, for: .widget)
        }
    }
}

/// 6a · Small · 2×2 · markers only.
private struct SmallWidget: View {
    var snapshot: OrbitSnapshot

    var body: some View {
        ZStack {
            StaticDialView(heading: snapshot.heading, markers: snapshot.markers,
                           style: .widgetSmall, size: 150)

            VStack(alignment: .leading, spacing: 5) {
                Text(Geo.formatHeading(snapshot.heading))
                    .tightHeading(30)
                    .foregroundStyle(OrbitColor.ink)
                Text(Geo.cardinalName(snapshot.heading))
                    .caps(8, OrbitColor.blue)
            }
            .frame(width: 86, alignment: .leading)
            .offset(x: -7, y: 3)
        }
    }
}

/// 6b · Medium · 4×2 · two people.
private struct MediumWidget: View {
    var snapshot: OrbitSnapshot

    var body: some View {
        HStack(spacing: 22) {
            ZStack {
                StaticDialView(heading: snapshot.heading, markers: snapshot.markers,
                               style: .widgetMedium, size: 150)
                VStack(spacing: 6) {
                    Text(Geo.formatHeading(snapshot.heading))
                        .tightHeading(34)
                        .foregroundStyle(OrbitColor.ink)
                    Text(Geo.cardinalName(snapshot.heading))
                        .caps(8, OrbitColor.blue)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tracking").caps(9, OrbitColor.ink)
                    Spacer()
                    Text("\(snapshot.people.count)").caps(9, OrbitColor.neutral700)
                }
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(OrbitColor.ink).frame(height: 2)
                }

                Spacer(minLength: 8)

                ForEach(Array(snapshot.people.prefix(2).enumerated()), id: \.element.id) { offset, person in
                    row(person, isFirst: offset == 0)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func row(_ person: OrbitSnapshot.Person, isFirst: Bool) -> some View {
        let delta = snapshot.delta(to: person)

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            InitialBadge(initial: person.initial, size: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(OrbitFont.semibold(13))
                    .foregroundStyle(OrbitColor.ink)
                Text(Geo.formatDistance(person.distanceM))
                    .font(OrbitFont.mono(10, weight: .regular))
                    .foregroundStyle(OrbitColor.neutral700)
            }
            Spacer(minLength: 6)
            Text(Geo.formatDelta(delta))
                .font(OrbitFont.mono(20))
                .foregroundStyle(Geo.isOnTarget(delta) ? OrbitColor.onTarget : OrbitColor.red)
        }
        .padding(.top, isFirst ? 0 : 10)
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle().fill(OrbitColor.neutral400).frame(height: 1)
            }
        }
        .padding(.bottom, isFirst ? 10 : 0)
    }
}

/// 6c · Lock screen · circular. One tinted layer, so it is the arc, the heading and the turn
/// to the nearest person — nothing else survives at this size.
private struct LockScreenDial: View {
    var snapshot: OrbitSnapshot

    var body: some View {
        let person = snapshot.people.first

        ZStack {
            StaticDialView(heading: snapshot.heading,
                           markers: Array(snapshot.markers.prefix(1)),
                           style: .lockScreen, size: 58)

            VStack(spacing: 1) {
                Text(Geo.formatHeading(snapshot.heading))
                    .font(OrbitFont.mono(13))
                if let person {
                    Text(Geo.formatDelta(snapshot.delta(to: person)))
                        .font(OrbitFont.mono(9))
                }
            }
            .foregroundStyle(.white)
        }
        .widgetAccentable()
    }
}

struct OrbitCompassWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: OrbitShared.widgetKind, provider: OrbitProvider()) { entry in
            OrbitWidgetView(entry: entry)
        }
        .configurationDisplayName("Orbit")
        .description("The dial, and how far to turn to face the people you track.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

@main
struct OrbitWidgetBundle: WidgetBundle {
    var body: some Widget {
        OrbitCompassWidget()
    }
}
