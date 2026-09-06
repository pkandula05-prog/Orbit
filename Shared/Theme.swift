import SwiftUI

/// Palette from the *Compass Face* design study.
///
/// The `modernist` design system's `styles.css` was not reachable when this was built, so the
/// neutral ramp is matched by eye between the background and ink values it sits between.
/// Swap in the real values if you have them.
public enum OrbitColor {
    public static let bg = Color(hex: 0xF3F2F2)
    public static let ink = Color(hex: 0x201E1D)
    public static let red = Color(hex: 0xEC3013)
    public static let blue = Color(hex: 0x1B3FA8)
    public static let yellow = Color(hex: 0xFBC417)
    public static let onTarget = Color(hex: 0x34C759)
    /// The dark ground used by the icon wall and the sharing request.
    public static let dark = Color(hex: 0x2A2725)

    public static let neutral300 = Color(hex: 0xD9D7D5)
    public static let neutral400 = Color(hex: 0xC4C1BE)
    public static let neutral500 = Color(hex: 0xA8A4A0)
    public static let neutral600 = Color(hex: 0x7D7975)
    public static let neutral700 = Color(hex: 0x5C5854)
}

public extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

public enum OrbitFont {
    public static func heading(_ size: CGFloat) -> Font { .custom("Archivo-Bold", fixedSize: size) }
    public static func semibold(_ size: CGFloat) -> Font { .custom("Archivo-SemiBold", fixedSize: size) }
    public static func regular(_ size: CGFloat) -> Font { .custom("Archivo-Regular", fixedSize: size) }
    /// Every numeral in the design is monospaced, so digits do not jitter as they count.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// The caps micro-label carrying nearly all secondary text in the design.
public struct CapsLabel: ViewModifier {
    let size: CGFloat
    let color: Color

    public func body(content: Content) -> some View {
        content
            .font(OrbitFont.semibold(size))
            .tracking(size * 0.18)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

public extension View {
    func caps(_ size: CGFloat = 11, _ color: Color = OrbitColor.ink) -> some View {
        modifier(CapsLabel(size: size, color: color))
    }

    /// Archivo's own line box is taller than the artboards' `line-height: .84`; a fixed,
    /// tighter box would clip the ascenders, so the box stays generous and the stacking is
    /// pulled back in with negative padding instead.
    func tightHeading(_ size: CGFloat) -> some View {
        self.font(OrbitFont.heading(size))
            .tracking(size * -0.035)
            .padding(.vertical, -size * 0.08)
    }
}

/// The design has no rounded corners and no shadows: every surface is a square-edged block,
/// separated by a 2pt ink rule or a 1pt neutral one.
enum Rule {
    static let heavy: CGFloat = 2
    static let light: CGFloat = 1
}

/// The square avatar used in every list and on the tracking row.
struct InitialBadge: View {
    var initial: String
    var size: CGFloat
    var filled = true
    var fill: Color = OrbitColor.red

    var body: some View {
        Text(initial)
            .font(OrbitFont.heading(size * 0.37))
            .foregroundStyle(filled ? OrbitColor.bg : OrbitColor.neutral700)
            .frame(width: size, height: size)
            .background(filled ? fill : .clear)
            .overlay {
                if !filled {
                    Rectangle().strokeBorder(OrbitColor.neutral500, lineWidth: Rule.heavy)
                }
            }
    }
}

