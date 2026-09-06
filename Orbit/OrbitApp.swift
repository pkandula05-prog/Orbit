import SwiftUI

@main
struct OrbitApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .task { model.start() }
        }
    }
}

/// Artboards 02–09 are one journey, so the app animates between steps of a single view rather
/// than pushing navigation destinations — which also keeps the dial's display link alive
/// across the hand-off from onboarding.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            OrbitColor.bg.ignoresSafeArea()

            Group {
                switch model.phase {
                case .launch:
                    LaunchView { model.phase = model.hasOnboarded ? .orbit : .signIn }
                        .transition(.opacity)
                case .signIn:
                    SignInView().transition(step)
                case .verify:
                    VerifyView().transition(step)
                case .permissions:
                    PermissionsView().transition(step)
                case .invite:
                    FriendsView().transition(step)
                case .inviteSent:
                    InviteSentView().transition(step)
                case .orbit:
                    CompassFaceView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: model.phase)

        }
        .statusBarHidden(false)
    }

    /// Forward is a step to the right, back a step to the left — the same motion the sign-in
    /// counter describes.
    private var step: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}
