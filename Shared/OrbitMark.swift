import SwiftUI

/// The Orbit mark: the dial reduced to one swept arc, the red heading body and a yellow
/// marker. Drawn in the icon's 172-unit square and scaled, so the launch screen and the app
/// icon are the same geometry rather than two drawings that have to be kept in step.
struct OrbitMark: View {
    var size: CGFloat
    var ground: Color = OrbitColor.bg
    var track: Color = OrbitColor.neutral300

    /// Everything below is in the 172-unit square the icon was drawn in.
    private static let box: CGFloat = 172
    private static let radius: CGFloat = 78
    private static let stroke: CGFloat = 16
    private static let dotRadius: CGFloat = 15
    private static let arc: ClosedRange<Double> = 265...355
    private static let bodyBearing: Double = 40
    private static let markerBearing: Double = 250

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / Self.box
            context.scaleBy(x: scale, y: scale)
            Self.draw(in: &context, ground: ground, track: track)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static func draw(in context: inout GraphicsContext, ground: Color, track: Color) {
        let center = CGPoint(x: box / 2, y: box / 2)
        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                            width: radius * 2, height: radius * 2))
        context.stroke(circle, with: .color(track), lineWidth: stroke)

        var swept = Path()
        swept.addArc(center: center, radius: radius,
                     startAngle: .degrees(arc.lowerBound - 90),
                     endAngle: .degrees(arc.upperBound - 90), clockwise: false)
        context.stroke(swept, with: .color(OrbitColor.blue), lineWidth: stroke)

        let body = point(bodyBearing, center: center)
        context.fill(dot(at: body), with: .color(OrbitColor.red))

        let marker = point(markerBearing, center: center)
        context.fill(dot(at: marker), with: .color(ground))
        context.stroke(dot(at: marker), with: .color(OrbitColor.yellow), lineWidth: 5)
    }

    private static func dot(at point: CGPoint) -> Path {
        Path(ellipseIn: CGRect(x: point.x - dotRadius, y: point.y - dotRadius,
                               width: dotRadius * 2, height: dotRadius * 2))
    }

    private static func point(_ bearing: Double, center: CGPoint) -> CGPoint {
        let radians = bearing * .pi / 180
        return CGPoint(x: center.x + radius * sin(radians), y: center.y - radius * cos(radians))
    }
}
