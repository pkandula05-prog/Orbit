import SwiftUI

/// 08 · A sharing request, over whatever is on screen. Sharing is reciprocal, so this is a
/// two-way decision and the copy says so.
struct ShareRequestView: View {
    var contact: Contact
    var onAccept: () -> Void
    var onDecline: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack(alignment: .top) {
            OrbitColor.dark
                .opacity(shown ? 1 : 0)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Orbit").caps(10, OrbitColor.ink)
                    Spacer()
                    Text("now").caps(10, OrbitColor.neutral700)
                }
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy)
                }

                Text("\(contact.shortName) wants to share direction")
                    .font(OrbitFont.semibold(16))
                    .foregroundStyle(OrbitColor.ink)
                    .padding(.top, 14)

                Text("If you accept, you each see the other's bearing and distance.")
                    .font(OrbitFont.regular(14))
                    .lineSpacing(3)
                    .foregroundStyle(OrbitColor.neutral700)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    OrbitButton(title: "Accept", action: onAccept)
                    OrbitButton(title: "Decline", kind: .secondary, action: onDecline)
                }
                .padding(.top, 16)
            }
            .padding(20)
            .background(OrbitColor.bg)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            // The card drops in from the top like the notification it is standing in for.
            .offset(y: shown ? 0 : -40)
            .opacity(shown ? 1 : 0)

            VStack(alignment: .leading, spacing: 12) {
                Text("Reciprocal by design").caps(11, OrbitColor.bg)
                Text("Sharing is always two-way. Either person can stop it, and the other is told.")
                    .font(OrbitFont.regular(14))
                    .lineSpacing(4)
                    .foregroundStyle(OrbitColor.bg.opacity(0.68))
            }
            .padding(.top, 16)
            .overlay(alignment: .top) {
                Rectangle().fill(OrbitColor.bg.opacity(0.3)).frame(height: Rule.heavy)
            }
            .screenGutters()
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 90)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { shown = true }
        }
    }
}
