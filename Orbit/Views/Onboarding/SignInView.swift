import SwiftUI

/// 03 · Who you are. Name, a unique username and the number we match you on.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Field?

    private enum Field { case first, last, username, phone }

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Sign in · 1 of 3")
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your details")
                        .tightHeading(40)
                        .foregroundStyle(OrbitColor.ink)

                    Text("The number matches you with people already sharing. The username is how they find you.")
                        .font(OrbitFont.regular(15))
                        .lineSpacing(4)
                        .foregroundStyle(OrbitColor.neutral700)
                        .padding(.top, 16)

                    HStack(spacing: 12) {
                        OrbitField(label: "First name", text: $model.profile.firstName)
                            .focused($focused, equals: .first)
                        OrbitField(label: "Last name", text: $model.profile.lastName)
                            .focused($focused, equals: .last)
                    }
                    .padding(.top, 30)

                    OrbitField(label: "Username", placeholder: "orbiter", text: $model.profile.username)
                        .focused($focused, equals: .username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.top, 18)
                        .onChange(of: model.profile.username) { _, _ in model.usernameChanged() }

                    usernameStatus
                        .padding(.top, 8)

                    OrbitField(label: "Mobile", text: $model.profile.phone, keyboard: .phonePad)
                        .focused($focused, equals: .phone)
                        .padding(.top, 18)

                    Button {
                        model.agreedToTerms.toggle()
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Rectangle()
                                .fill(model.agreedToTerms ? OrbitColor.red : .clear)
                                .frame(width: 18, height: 18)
                                .overlay { Rectangle().strokeBorder(OrbitColor.ink, lineWidth: Rule.heavy) }
                                .animation(.spring(response: 0.28, dampingFraction: 0.7),
                                           value: model.agreedToTerms)
                            Text("I agree to the terms and privacy notice")
                                .font(OrbitFont.regular(13))
                                .foregroundStyle(OrbitColor.ink)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 24)

                    if let error = model.signInError {
                        Text(error)
                            .caps(11, OrbitColor.red)
                            .padding(.top, 16)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                OrbitButton(title: "Send code", isBusy: model.isWorking, isEnabled: model.canSendCode) {
                    focused = nil
                    model.sendCode()
                }
                OrbitButton(title: "Continue with Apple", kind: .ghost, isEnabled: model.canSendCode) {
                    focused = nil
                    model.sendCode()
                }
            }
            .padding(.bottom, 46)
        }
        .screenGutters()
        .background(OrbitColor.bg)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: model.signInError)
        .animation(.easeInOut(duration: 0.2), value: model.usernameState)
    }

    /// The availability check has to be visible before the button unlocks, or a taken name
    /// just reads as a dead button.
    @ViewBuilder
    private var usernameStatus: some View {
        switch model.usernameState {
        case .empty:
            Text("Letters, numbers and underscore").caps(10, OrbitColor.neutral700)
        case .invalid:
            Text("3–20 characters · letters, numbers, underscore").caps(10, OrbitColor.red)
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.mini).tint(OrbitColor.neutral700)
                Text("Checking").caps(10, OrbitColor.neutral700)
            }
        case .available:
            Text("@\(model.profile.username) is available").caps(10, OrbitColor.onTarget)
        case .taken:
            Text("@\(model.profile.username) is taken").caps(10, OrbitColor.red)
        }
    }
}
