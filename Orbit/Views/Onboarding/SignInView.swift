import SwiftUI

/// 03 · Your number.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Sign in · 1 of 3")
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 0) {
                Text("Your number")
                    .tightHeading(40)
                    .foregroundStyle(OrbitColor.ink)

                Text("We use it to match you with people already sharing their location.")
                    .font(OrbitFont.regular(15))
                    .lineSpacing(4)
                    .foregroundStyle(OrbitColor.neutral700)
                    .padding(.top, 16)

                OrbitField(label: "Mobile", text: $model.phone, keyboard: .phonePad)
                    .padding(.top, 34)
                    .focused($focused)

                Button {
                    model.agreedToTerms.toggle()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Rectangle()
                            .fill(model.agreedToTerms ? OrbitColor.red : .clear)
                            .frame(width: 18, height: 18)
                            .overlay { Rectangle().strokeBorder(OrbitColor.ink, lineWidth: Rule.heavy) }
                            // The tick is the only fill in the block, so it is worth a beat.
                            .animation(.spring(response: 0.28, dampingFraction: 0.7),
                                       value: model.agreedToTerms)
                        Text("I agree to the terms and privacy notice")
                            .font(OrbitFont.regular(13))
                            .foregroundStyle(OrbitColor.ink)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 26)

                if let error = model.signInError {
                    Text(error)
                        .caps(11, OrbitColor.red)
                        .padding(.top, 18)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, 62)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                OrbitButton(title: "Send code", isBusy: model.isWorking) {
                    focused = false
                    model.sendCode()
                }
                OrbitButton(title: "Continue with Apple", kind: .ghost) {
                    focused = false
                    model.sendCode()
                }
            }
            .padding(.bottom, 46)
        }
        .screenGutters()
        .background(OrbitColor.bg)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: model.signInError)
    }
}
