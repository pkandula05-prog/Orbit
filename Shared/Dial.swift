import SwiftUI

/// Everything is laid out in the artboards' 300-unit square and scaled to the view.
public enum DialUnits {
    public static let view: CGFloat = 300
    public static let center = CGPoint(x: 150, y: 150)
}

/// The dial is drawn at four sizes across the app and the widgets; the parts that differ are
/// only ever radii, weights and colours, so they live here rather than in four near-copies.
public struct DialStyle: Sendable {
    public var trackRadius: CGFloat
    public var trackWidth: CGFloat
    public var trackColor: Color
    public var arcColor: Color
    public var markerRadius: CGFloat
    public var markerCenterY: CGFloat
    public var markerStroke: CGFloat
    public var markerFill: Color
    public var markerLabelSize: CGFloat
    /// Nil hides the friend initial — the lock screen marker is a solid dot with no room for it.
    public var showsMarkerLabels: Bool
    public var bodyRadius: CGFloat
    public var bodyCenterY: CGFloat
    public var bodyColor: Color
    public var minorTicks: (count: Int, dash: CGFloat, width: CGFloat, radius: CGFloat, color: Color)?
    public var majorTicks: (count: Int, dash: CGFloat, width: CGFloat, radius: CGFloat, color: Color)?

    public static let phone = DialStyle(
        trackRadius: 132, trackWidth: 8, trackColor: OrbitColor.neutral300, arcColor: OrbitColor.blue,
        markerRadius: 13, markerCenterY: 18, markerStroke: 3, markerFill: OrbitColor.bg,
        markerLabelSize: 11, showsMarkerLabels: true,
        bodyRadius: 13.5, bodyCenterY: 18.9, bodyColor: OrbitColor.red,
        minorTicks: (72, 2, 8, 148, OrbitColor.neutral400),
        majorTicks: (8, 3, 16, 144, OrbitColor.neutral600)
    )

    /// Lock screen: one tinted layer, so the track is white at two opacities.
    public static let lockScreen = DialStyle(
        trackRadius: 126, trackWidth: 18, trackColor: OrbitColor.bg.opacity(0.3), arcColor: OrbitColor.bg,
        markerRadius: 13, markerCenterY: 24, markerStroke: 0, markerFill: OrbitColor.yellow,
        markerLabelSize: 0, showsMarkerLabels: false,
        bodyRadius: 13.5, bodyCenterY: 24, bodyColor: OrbitColor.red,
        minorTicks: nil, majorTicks: nil
    )
}

/// One friend as the dial needs them — decoupled from `FriendReading` so widgets can draw a
/// dial from a stored snapshot.
public struct DialMarker: Identifiable, Hashable, Sendable {
    public var id: String
    public var initial: String
    public var bearing: Double
    public var onTarget: Bool
    public var stale: Bool

    public init(id: String, initial: String, bearing: Double, onTarget: Bool = false, stale: Bool = false) {
        self.id = id
        self.initial = initial
        self.bearing = bearing
        self.onTarget = onTarget
        self.stale = stale
    }
}

public extension DialMarker {
    init(_ reading: FriendReading) {
        self.init(id: reading.id, initial: reading.initial, bearing: reading.bearing,
                  onTarget: reading.onTarget, stale: reading.stale)
    }
}

/// North-up dial: friends sit at their true bearing, the red body shows where the device is
/// pointing, and the arc sweeps from north to that heading.
///
/// This is one `Canvas`, not a stack of shape views, so a heading change redraws in a single
/// pass with no view-tree diffing or layout — which is what lets it hold 120 fps while the
/// heading updates every frame.
public struct DialView: View {
    public var heading: Double
    public var markers: [DialMarker]
    public var style: DialStyle

    public init(heading: Double, markers: [DialMarker], style: DialStyle = .phone) {
        self.heading = heading
        self.markers = markers
        self.style = style
    }

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / DialUnits.view
            context.scaleBy(x: scale, y: scale)
            draw(in: &context)
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext) {
        let center = DialUnits.center

        if let ticks = style.minorTicks { drawTicks(ticks, in: &context) }
        if let ticks = style.majorTicks { drawTicks(ticks, in: &context) }

        let track = Path(ellipseIn: CGRect(
            x: center.x - style.trackRadius, y: center.y - style.trackRadius,
            width: style.trackRadius * 2, height: style.trackRadius * 2
        ))
        context.stroke(track, with: .color(style.trackColor), lineWidth: style.trackWidth)

        // The swept arc is the heading, read straight off the dial: north to where you point.
        var arc = Path()
        arc.addArc(center: center, radius: style.trackRadius,
                   startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + Geo.normalize(heading)),
                   clockwise: false)
        context.stroke(arc, with: .color(style.arcColor), lineWidth: style.trackWidth)

        for marker in markers { draw(marker, in: &context) }

        let body = point(atAngle: heading, radius: center.y - style.bodyCenterY)
        context.fill(
            Path(ellipseIn: CGRect(x: body.x - style.bodyRadius, y: body.y - style.bodyRadius,
                                   width: style.bodyRadius * 2, height: style.bodyRadius * 2)),
            with: .color(style.bodyColor)
        )
    }

    private func drawTicks(_ ticks: (count: Int, dash: CGFloat, width: CGFloat, radius: CGFloat, color: Color),
                           in context: inout GraphicsContext) {
        let circumference = 2 * .pi * ticks.radius
        let gap = circumference / CGFloat(ticks.count) - ticks.dash
        let path = Path(ellipseIn: CGRect(
            x: DialUnits.center.x - ticks.radius, y: DialUnits.center.y - ticks.radius,
            width: ticks.radius * 2, height: ticks.radius * 2
        ))
        // A circle path starts at three o'clock; rotating a quarter turn puts a tick on north.
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
        let opacity = marker.stale ? 0.45 : 1
        let at = point(atAngle: marker.bearing, radius: DialUnits.center.y - style.markerCenterY)
        let rect = CGRect(x: at.x - style.markerRadius, y: at.y - style.markerRadius,
                          width: style.markerRadius * 2, height: style.markerRadius * 2)

        if style.markerStroke > 0 {
            context.fill(Path(ellipseIn: rect), with: .color(style.markerFill.opacity(opacity)))
            context.stroke(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)),
                           lineWidth: style.markerStroke)
        } else {
            context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)))
        }

        guard style.showsMarkerLabels else { return }
        // Labels stay upright: the marker orbits, the letter does not turn with it.
        let text = Text(marker.initial)
            .font(OrbitFont.heading(style.markerLabelSize))
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
