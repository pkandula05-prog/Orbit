import SwiftUI
import WidgetKit

struct OrbitEntry: TimelineEntry {
    let date: Date
    let snapshot: OrbitSnapshot
}

/// The widget draws the dial the app last wrote to the shared container. An extension is woken
/// for a timeline rather than run continuously, so it cannot read the compass live — but it is
/// not stuck on one still frame either: the app writes each friend's course and speed with
/// their fix, and the timeline carries a minute-by-minute projection of where that motion
/// takes them. Between reloads the marker keeps travelling and the delta keeps counting, and
/// the app pushes a fresh timeline whenever the real dial moves enough to notice.
struct OrbitProvider: TimelineProvider {
    /// One entry a minute for a quarter of an hour; WidgetKit budgets reloads, so the entries
    /// do the moving in between.
    private let step: TimeInterval = 60
    private let entries = 15

    func placeholder(in context: Context) -> OrbitEntry {
        OrbitEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (OrbitEntry) -> Void) {
        completion(OrbitEntry(date: Date(), snapshot: OrbitShared.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrbitEntry>) -> Void) {
        let now = Date()
        let snapshot = OrbitShared.read() ?? .placeholder
        // Everyone is carried forward along their own course, from the moment the fix was
        // taken — so an entry shown ten minutes from now is ten minutes of travel, not a repeat.
        let age = max(0, now.timeIntervalSince(snapshot.capturedAt))
        let timeline = (0..<entries).map { index in
            let ahead = Double(index) * step
            return OrbitEntry(date: now.addingTimeInterval(ahead),
                              snapshot: snapshot.projected(bySeconds: age + ahead))
        }
        completion(Timeline(entries: timeline,
                            policy: .after(now.addingTimeInterval(Double(entries) * step))))
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
            InitialBadge(initial: person.initial, size: 16, fontSize: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(OrbitFont.semibold(13))
                    .foregroundStyle(OrbitColor.ink)
                HStack(spacing: 5) {
                    Text(Geo.formatDistance(person.distanceM))
                        .font(OrbitFont.mono(10, weight: .regular))
                        .foregroundStyle(OrbitColor.neutral700)
                    MovementMark(person: person)
                }
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

/// Which way they are going, and whether that is toward you. The arrow points along their
/// course; the word says what the distance is doing.
private struct MovementMark: View {
    var person: OrbitSnapshot.Person

    var body: some View {
        if let course = person.course, person.speedMps > 0.2 {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(course))
                Text(person.closingSpeed > 0.2 ? "Closing" : "Away")
                    .caps(8, person.closingSpeed > 0.2 ? OrbitColor.onTarget : OrbitColor.neutral700)
            }
            .foregroundStyle(person.closingSpeed > 0.2 ? OrbitColor.onTarget : OrbitColor.neutral700)
        }
    }
}

struct OrbitCompassWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: OrbitShared.widgetKind, provider: OrbitProvider()) { entry in
            OrbitWidgetView(entry: entry)
        }
        .configurationDisplayName("Orbit")
        .description("The dial, how far to turn to face the people you track, and which way they are moving.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

@main
struct OrbitWidgetBundle: WidgetBundle {
    var body: some Widget {
        OrbitCompassWidget()
    }
}
