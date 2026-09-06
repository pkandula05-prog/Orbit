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
                    LaunchView { model.phase = model.hasOnboarded ? .compass : .signIn }
                        .transition(.opacity)
                case .signIn:
                    SignInView().transition(step)
                case .verify:
                    VerifyView().transition(step)
                case .permissions:
                    PermissionsView().transition(step)
                case .invite:
                    InviteView().transition(step)
                case .inviteSent:
                    InviteSentView().transition(step)
                case .compass:
                    CompassFaceView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: model.phase)

            if let request = model.incomingRequest {
                ShareRequestView(contact: request) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        model.accept(request)
                    }
                } onDecline: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        model.decline()
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .statusBarHidden(false)
        .preferredColorScheme(model.incomingRequest == nil ? .light : .dark)
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
