import SwiftUI

/// Everything is laid out in the artboards' 300-unit square and scaled to the view.
enum DialUnits {
    static let view: CGFloat = 300
    static let center = CGPoint(x: 150, y: 150)

    static let trackRadius: CGFloat = 132
    static let trackWidth: CGFloat = 8
    static let markerRadius: CGFloat = 13
    static let markerCenterY: CGFloat = 18
    static let bodyRadius: CGFloat = 13.5
    static let bodyCenterY: CGFloat = 18.9
    /// Two markers closer than this on the ring are unreadable, so they get nudged apart.
    static let minimumSeparation: Double = 11
}

/// One participant as the ring draws them.
struct DialMarker: Identifiable, Hashable, Sendable {
    var id: String
    var initial: String
    /// The true bearing. Never modified — the readout quotes this.
    var bearing: Double
    /// Where the dot is actually drawn, after crowding is resolved. Usually the same.
    var drawnBearing: Double
    var onTarget: Bool
    var freshness: Freshness
    var hasLeft: Bool

    init(_ reading: ParticipantReading) {
        id = reading.id
        initial = reading.initial
        bearing = reading.bearing
        drawnBearing = reading.bearing
        onTarget = reading.onTarget && reading.freshness == .fresh && reading.range == .near
        freshness = reading.freshness
        hasLeft = reading.hasLeft
    }

    /// In a crowd several people sit within a few degrees of each other and their dots merge.
    ///
    /// This spreads the drawn positions just far enough to be separate, and *only* the drawn
    /// positions: `bearing` still carries the truth, so the numbers under the dial never lie
    /// about where someone is. A nudged dot is at most a few degrees off, which at arm's length
    /// is less than the width of the dot itself.
    static func resolvingCrowding(_ markers: [DialMarker]) -> [DialMarker] {
        guard markers.count > 1 else { return markers }

        var resolved = markers.sorted { $0.bearing < $1.bearing }
        let separation = DialUnits.minimumSeparation

        // A few relaxation passes: push neighbours apart, wrapping around north, and let the
        // whole cluster settle rather than shunting everything onto the last marker.
        for _ in 0..<12 {
            var moved = false
            for index in resolved.indices {
                let next = (index + 1) % resolved.count
                let gap = Geo.signedDelta(from: resolved[index].drawnBearing,
                                          to: resolved[next].drawnBearing)
                let signedGap = resolved.count == 2 ? abs(gap) : (gap < 0 ? gap + 360 : gap)
                guard signedGap < separation else { continue }

                let push = (separation - signedGap) / 2
                resolved[index].drawnBearing = Geo.normalize(resolved[index].drawnBearing - push)
                resolved[next].drawnBearing = Geo.normalize(resolved[next].drawnBearing + push)
                moved = true
            }
            if !moved { break }
        }
        return resolved
    }
}

/// North-up dial: participants sit at their true bearing, the red body shows where the phone is
/// pointing, and the arc sweeps from north to that heading.
///
/// This is one `Canvas`, not a stack of shape views, so a heading change redraws in a single
/// pass with no view-tree diffing and no layout — which is what lets it hold 120 fps while the
/// heading updates every frame.
struct DialView: View {
    var heading: Double
    var markers: [DialMarker]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / DialUnits.view
            context.scaleBy(x: scale, y: scale)
            draw(in: &context)
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext) {
        let center = DialUnits.center

        drawTicks((72, 2, 8, 148, OrbitColor.neutral400), in: &context)
        drawTicks((8, 3, 16, 144, OrbitColor.neutral600), in: &context)

        let track = Path(ellipseIn: CGRect(
            x: center.x - DialUnits.trackRadius, y: center.y - DialUnits.trackRadius,
            width: DialUnits.trackRadius * 2, height: DialUnits.trackRadius * 2
        ))
        context.stroke(track, with: .color(OrbitColor.neutral300), lineWidth: DialUnits.trackWidth)

        var arc = Path()
        arc.addArc(center: center, radius: DialUnits.trackRadius,
                   startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + Geo.normalize(heading)), clockwise: false)
        context.stroke(arc, with: .color(OrbitColor.blue), lineWidth: DialUnits.trackWidth)

        for marker in markers { draw(marker, in: &context) }

        let body = point(atAngle: heading, radius: center.y - DialUnits.bodyCenterY)
        context.fill(
            Path(ellipseIn: CGRect(x: body.x - DialUnits.bodyRadius, y: body.y - DialUnits.bodyRadius,
                                   width: DialUnits.bodyRadius * 2, height: DialUnits.bodyRadius * 2)),
            with: .color(OrbitColor.red)
        )
    }

    private func drawTicks(_ ticks: (count: Int, dash: CGFloat, width: CGFloat, radius: CGFloat, color: Color),
                           in context: inout GraphicsContext) {
        let gap = 2 * .pi * ticks.radius / CGFloat(ticks.count) - ticks.dash
        let path = Path(ellipseIn: CGRect(
            x: DialUnits.center.x - ticks.radius, y: DialUnits.center.y - ticks.radius,
            width: ticks.radius * 2, height: ticks.radius * 2
        ))
        // A circle path starts at three o'clock; a quarter turn puts a tick on north.
        var rotated = context
        rotated.translateBy(x: DialUnits.center.x, y: DialUnits.center.y)
        rotated.rotate(by: .degrees(-90))
        rotated.translateBy(x: -DialUnits.center.x, y: -DialUnits.center.y)
        rotated.stroke(path, with: .color(ticks.color),
                       style: StrokeStyle(lineWidth: ticks.width, dash: [ticks.dash, gap],
                                          dashPhase: ticks.dash / 2))
    }

    private func draw(_ marker: DialMarker, in context: inout GraphicsContext) {
        let tint = marker.onTarget ? OrbitColor.onTarget : OrbitColor.yellow
        // Three states, three weights. A ghost is drawn hollow and faint but is never removed:
        // taking the dot away reads as "they left", and sends people the wrong way.
        let opacity: Double = switch marker.freshness {
        case .fresh: marker.hasLeft ? 0.3 : 1
        case .degraded: 0.55
        case .ghost: 0.3
        }

        let at = point(atAngle: marker.drawnBearing, radius: DialUnits.center.y - DialUnits.markerCenterY)
        let rect = CGRect(x: at.x - DialUnits.markerRadius, y: at.y - DialUnits.markerRadius,
                          width: DialUnits.markerRadius * 2, height: DialUnits.markerRadius * 2)

        context.fill(Path(ellipseIn: rect), with: .color(OrbitColor.bg.opacity(opacity)))
        context.stroke(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)),
                       style: StrokeStyle(lineWidth: 3,
                                          dash: marker.freshness == .ghost ? [3, 3] : []))

        // Labels stay upright: the marker orbits, the letter does not turn with it.
        let text = Text(marker.initial)
            .font(OrbitFont.heading(11))
            .foregroundStyle(tint.opacity(opacity))
        context.draw(context.resolve(text), at: at, anchor: .center)
    }

    /// Degrees are clockwise from north, so the dial's own frame, not the screen's.
    private func point(atAngle degrees: Double, radius: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: DialUnits.center.x + radius * sin(radians),
                       y: DialUnits.center.y - radius * cos(radians))
    }
}
