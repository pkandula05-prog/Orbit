import SwiftUI

/// The same dial, composed from shapes instead of a `Canvas`.
///
/// WidgetKit archives a widget's view tree and replays it out of process, where `Canvas`
/// cannot be relied on to draw. Widgets show one still frame anyway, so they have nothing to
/// gain from the canvas — this version is built from shapes that archive cleanly, and the
/// canvas stays in the app where the per-frame redraw actually matters. Both read the same
/// `DialStyle`, so the two cannot drift apart on geometry.
struct StaticDialView: View {
    var heading: Double
    var markers: [DialMarker]
    var style: DialStyle
    var size: CGFloat

    private var scale: CGFloat { size / DialUnits.view }

    var body: some View {
        ZStack {
            if let ticks = style.minorTicks { tickRing(ticks) }
            if let ticks = style.majorTicks { tickRing(ticks) }

            Circle()
                .stroke(style.trackColor, lineWidth: style.trackWidth)
                .frame(width: style.trackRadius * 2, height: style.trackRadius * 2)

            Circle()
                .trim(from: 0, to: Geo.normalize(heading) / 360)
                .stroke(style.arcColor, lineWidth: style.trackWidth)
                .frame(width: style.trackRadius * 2, height: style.trackRadius * 2)
                .rotationEffect(.degrees(-90))

            ForEach(markers) { marker in
                markerView(marker)
            }

            Circle()
                .fill(style.bodyColor)
                .frame(width: style.bodyRadius * 2, height: style.bodyRadius * 2)
                .offset(y: -(DialUnits.center.y - style.bodyCenterY))
                .rotationEffect(.degrees(heading))
        }
        .frame(width: DialUnits.view, height: DialUnits.view)
        .scaleEffect(scale)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func tickRing(_ ticks: (count: Int, dash: CGFloat, width: CGFloat, radius: CGFloat, color: Color)) -> some View {
        let gap = 2 * .pi * ticks.radius / CGFloat(ticks.count) - ticks.dash
        return Circle()
            .stroke(ticks.color, style: StrokeStyle(lineWidth: ticks.width,
                                                    dash: [ticks.dash, gap],
                                                    dashPhase: ticks.dash / 2))
            .frame(width: ticks.radius * 2, height: ticks.radius * 2)
            .rotationEffect(.degrees(-90))
    }

    private func markerView(_ marker: DialMarker) -> some View {
        let tint = marker.onTarget ? OrbitColor.onTarget : OrbitColor.yellow

        return ZStack {
            if style.markerStroke > 0 {
                Circle().fill(style.markerFill)
                Circle().strokeBorder(tint, lineWidth: style.markerStroke)
            } else {
                Circle().fill(tint)
            }

            if style.showsMarkerLabels {
                Text(marker.initial)
                    .font(OrbitFont.heading(style.markerLabelSize))
                    .foregroundStyle(tint)
                    // The marker orbits; the letter stays upright.
                    .rotationEffect(.degrees(-marker.bearing))
            }
        }
        .opacity(marker.stale ? 0.45 : 1)
        .frame(width: style.markerRadius * 2, height: style.markerRadius * 2)
        .offset(y: -(DialUnits.center.y - style.markerCenterY))
        .rotationEffect(.degrees(marker.bearing))
    }
}
