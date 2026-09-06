import SwiftUI

/// 05 · Two permissions. Asked for together, in plain terms, before the system prompt appears.
struct PermissionsView: View {
    @Environment(AppModel.self) private var model

    private struct Permission {
        let index: String, title: String, detail: String
    }

    private let permissions = [
        Permission(index: "01", title: "Location",
                   detail: "To place your friends on the dial. Shared only with people you pick."),
        Permission(index: "02", title: "Motion & compass",
                   detail: "To read which way you are facing. Never leaves the device."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Sign in · 3 of 3")
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 0) {
                Text("Two permissions")
                    .tightHeading(40)
                    .foregroundStyle(OrbitColor.ink)

                ForEach(Array(permissions.enumerated()), id: \.offset) { offset, permission in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(permission.index)
                            .font(OrbitFont.mono(13))
                            .foregroundStyle(OrbitColor.red)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(permission.title)
                                .font(OrbitFont.semibold(17))
                                .foregroundStyle(OrbitColor.ink)
                            Text(permission.detail)
                                .font(OrbitFont.regular(14))
                                .lineSpacing(3)
                                .foregroundStyle(OrbitColor.neutral700)
                        }
                    }
                    .padding(.top, 16)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(offset == 0 ? OrbitColor.ink : OrbitColor.neutral400)
                            .frame(height: offset == 0 ? Rule.heavy : Rule.light)
                    }
                    .padding(.top, offset == 0 ? 32 : 20)
                }

                Text("You can turn either off at any time")
                    .caps(11, OrbitColor.neutral700)
                    .padding(.top, 26)
            }
            .padding(.top, 62)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                OrbitButton(title: "Allow both") { model.requestPermissions() }
                OrbitButton(title: "Not now", kind: .ghost) { model.phase = .invite }
            }
            .padding(.bottom, 46)
        }
        .screenGutters()
        .background(OrbitColor.bg)
    }
}
