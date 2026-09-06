import Combine
import SwiftUI

/// 04 · Enter the code. Six underlines, filled left to right; the next one to be typed carries
/// the red rule.
struct VerifyView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool
    @State private var secondsLeft = 24

    private let length = 6
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Sign in · 2 of 3", trailing: "Back") {
                model.phase = .signIn
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 0) {
                Text("Enter the code")
                    .tightHeading(40)
                    .foregroundStyle(OrbitColor.ink)

                Text("Sent to \(model.phone)")
                    .font(OrbitFont.regular(15))
                    .foregroundStyle(OrbitColor.neutral700)
                    .padding(.top, 16)

                digits
                    .padding(.top, 34)
                    .contentShape(Rectangle())
                    .onTapGesture { focused = true }

                Text(secondsLeft > 0 ? String(format: "Resend in 0:%02d", secondsLeft) : "Resend code")
                    .caps(11, secondsLeft > 0 ? OrbitColor.neutral700 : OrbitColor.red)
                    .padding(.top, 22)
                    .onTapGesture {
                        guard secondsLeft == 0 else { return }
                        secondsLeft = 24
                        model.sendCode()
                    }

                if let error = model.signInError {
                    Text(error)
                        .caps(11, OrbitColor.red)
                        .padding(.top, 18)
                        .transition(.opacity)
                }
            }
            .padding(.top, 62)

            Spacer(minLength: 24)

            OrbitButton(title: "Verify",
                        isBusy: model.isWorking,
                        isEnabled: model.code.count == length) {
                focused = false
                model.verifyCode()
            }
            .padding(.bottom, 46)
        }
        .screenGutters()
        .background(OrbitColor.bg)
        .background {
            // The real field is invisible; the underlines are the interface.
            TextField("", text: $model.code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0)
                .frame(width: 1, height: 1)
                .onChange(of: model.code) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(length))
                    if digits != new { model.code = digits }
                }
        }
        .onAppear { focused = true }
        .onReceive(timer) { _ in if secondsLeft > 0 { secondsLeft -= 1 } }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: model.signInError)
    }

    private var digits: some View {
        HStack(spacing: 10) {
            ForEach(0..<length, id: \.self) { index in
                let characters = Array(model.code)
                let filled = index < characters.count
                let active = index == characters.count

                VStack(spacing: 10) {
                    Text(filled ? String(characters[index]) : "—")
                        .font(OrbitFont.mono(30))
                        .foregroundStyle(filled ? OrbitColor.ink
                                        : active ? OrbitColor.red : OrbitColor.neutral400)
                        .contentTransition(.numericText())
                    Rectangle()
                        .fill(filled ? OrbitColor.ink : active ? OrbitColor.red : OrbitColor.neutral400)
                        .frame(height: Rule.heavy)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: model.code)
    }
}
