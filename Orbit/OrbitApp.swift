import SwiftUI

@main
struct OrbitApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .task { model.start() }
                // Viewing is foreground-only; publishing is not. The fix rate follows which
                // side of that line the app is on.
                .onChange(of: scenePhase) { _, phase in
                    model.compass.setForeground(phase == .active)
                }
                .onOpenURL { model.handle($0) }
        }
    }
}

/// There is no account wall: permissions, then a dial. Everything else is an orbit's lifecycle.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            OrbitColor.bg.ignoresSafeArea()

            Group {
                switch model.phase {
                case .launch:
                    LaunchView { model.phase = .permissions }
                        .transition(.opacity)
                case .permissions:
                    PermissionsView().transition(step)
                case .idle:
                    IdleView().transition(step)
                case .orbit:
                    OrbitFaceView().transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .ended(let ending):
                    EndedOrbitView(ending: ending).transition(.opacity)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: model.phase)

            // A link tapped before we knew what to call you.
            if let token = model.pendingToken {
                JoinNameView(token: token)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.9), value: model.pendingToken)
    }

    private var step: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity))
    }
}
