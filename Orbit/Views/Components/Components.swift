import SwiftUI

enum OrbitButtonKind {
    case primary, secondary, ghost
}

struct OrbitButton: View {
    var title: String
    var kind: OrbitButtonKind = .primary
    var isBusy = false
    var isEnabled = true
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(OrbitFont.semibold(16))
                    .opacity(isBusy ? 0 : 1)
                if isBusy {
                    ProgressView().tint(foreground)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(foreground)
            .background(background)
            .overlay {
                if kind == .ghost {
                    Rectangle().strokeBorder(OrbitColor.ink, lineWidth: Rule.heavy)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isBusy)
        .opacity(isEnabled ? 1 : 0.4)
        // A press is the only place the design moves: a short, deep scale that settles
        // without bouncing, so a tap feels answered rather than animated.
        .scaleEffect(pressed ? 0.975 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: pressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            pressed = pressing
        } perform: {}
    }

    private var background: Color {
        switch kind {
        case .primary: OrbitColor.red
        case .secondary: OrbitColor.ink
        case .ghost: .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary, .secondary: OrbitColor.bg
        case .ghost: OrbitColor.ink
        }
    }
}

/// `Sign in · 1 of 3` and its rule, with an optional action on the right.
struct StepHeader: View {
    var title: String
    var trailing: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).caps(11, OrbitColor.ink)
            Spacer(minLength: 12)
            if let trailing {
                Button { trailingAction?() } label: {
                    Text(trailing).caps(11, OrbitColor.neutral700)
                }
                .buttonStyle(.plain)
                .disabled(trailingAction == nil)
            }
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy)
        }
    }
}

struct OrbitField: View {
    var label: String
    var placeholder: String = ""
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !label.isEmpty {
                Text(label).caps(10, OrbitColor.neutral700)
            }
            TextField(placeholder, text: $text)
                .font(OrbitFont.regular(17))
                .foregroundStyle(OrbitColor.ink)
                .keyboardType(keyboard)
                .textContentType(keyboard == .phonePad ? .telephoneNumber : nil)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(.white)
                .overlay { Rectangle().strokeBorder(OrbitColor.ink, lineWidth: Rule.heavy) }
        }
    }
}

struct OrbitTag: View {
    var title: String

    var body: some View {
        Text(title)
            .caps(10, OrbitColor.neutral700)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay { Rectangle().strokeBorder(OrbitColor.neutral500, lineWidth: 1.5) }
    }
}

/// A row in the invite and pending lists: heavy rule above the first, light above the rest.
struct ListRow<Trailing: View>: View {
    var isFirst: Bool
    var minHeight: CGFloat = 56
    @ViewBuilder var content: () -> Trailing

    var body: some View {
        content()
            .frame(minHeight: minHeight)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(isFirst ? OrbitColor.ink : OrbitColor.neutral400)
                    .frame(height: isFirst ? Rule.heavy : Rule.light)
            }
    }
}

extension View {
    /// Every onboarding screen is the same block: 32pt gutters on the artboards' 393pt width.
    func screenGutters() -> some View { padding(.horizontal, 32) }
}
