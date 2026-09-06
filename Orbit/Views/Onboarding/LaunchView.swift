import SwiftUI

/// 02 · Launch. Holds while the compass settles, then hands over to sign-in or the dial.
struct LaunchView: View {
    var onFinish: () -> Void

    @State private var progress: CGFloat = 0
    @State private var markIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            OrbitMark(size: 172)
                .scaleEffect(markIn ? 1 : 0.94)
                .opacity(markIn ? 1 : 0)

            Spacer().frame(height: 46)

            Text("Orbit")
                .tightHeading(52)
                .foregroundStyle(OrbitColor.ink)
                .opacity(markIn ? 1 : 0)
                .offset(y: markIn ? 0 : 8)

            Text("Point at the people you know")
                .caps(11, OrbitColor.neutral700)
                .padding(.top, 16)
                .opacity(markIn ? 1 : 0)
                .offset(y: markIn ? 0 : 8)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 12) {
                Text("Loading · calibrating compass").caps(11, OrbitColor.neutral700)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(OrbitColor.neutral300)
                        Rectangle().fill(OrbitColor.red).frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 4)
            }
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy)
            }
            .padding(.bottom, 46)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .screenGutters()
        .background(OrbitColor.bg)
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { markIn = true }
            // Eased rather than linear: the bar slows as it fills, so the hand-off lands on a
            // settled bar instead of cutting a moving one.
            withAnimation(.easeOut(duration: 1.6)) { progress = 1 }
            try? await Task.sleep(for: .milliseconds(1750))
            onFinish()
        }
    }
}
