import SwiftUI
import Supabase

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()

    var body: some View {
        Group {
            switch appState.phase {
            case .splash:
                SplashView()
            case .onboarding:
                PlaceholderScreen(
                    title: "Onboarding",
                    subtitle: "4-slide first-launch tutorial — not yet built",
                    actionTitle: "Skip to Sign In",
                    action: { appState.skipOnboarding() }
                )
            case .auth, .profileSetup:
                // Sharing one NavigationStack (instead of swapping `.auth`/`.profileSetup` as
                // separate top-level cases) gets the wizard a genuine native push transition —
                // real spring physics and the interactive edge-swipe-back gesture — instead of
                // a hand-rolled `.transition`/`.animation` approximation.
                AuthFlowContainer()
            case .app:
                MainTabView()
            }
        }
        .environment(appState)
        .animation(.easeInOut(duration: 0.3), value: appState.phase)
        .task {
            appState.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await SupabaseClient.shared.auth.startAutoRefresh() }
            case .background:
                Task { await SupabaseClient.shared.auth.stopAutoRefresh() }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}

/// Hosts `AuthView` as the NavigationStack root and pushes `ProfileSetupFlowView` natively
/// when a sign-up hands off to `.profileSetup` — real push transition, spring physics, and
/// the interactive edge-swipe-back gesture, all for free from `UINavigationController`.
///
/// `isShowingProfileSetup` is a plain, independently-mutable `@State` (not a binding derived
/// from `appState.phase`) specifically so a swipe-back gesture can drive it to `false` on its
/// own — `appState.phase` intentionally stays `.profileSetup` in that case (there's no
/// meaningful "cancel sign-up" action), and a cold relaunch will self-correct via
/// `AppState.hydrate`'s existing incomplete-profile handling.
private struct AuthFlowContainer: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingProfileSetup = false

    var body: some View {
        NavigationStack {
            AuthView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $isShowingProfileSetup) {
                    if let userID = appState.session?.user.id {
                        ProfileSetupFlowView(userID: userID, onComplete: appState.completeProfileSetup)
                            .toolbar(.hidden, for: .navigationBar)
                    } else {
                        // Defensive only — AppState never sets `.profileSetup` without a session.
                        PlaceholderScreen(title: "Profile Setup", subtitle: "Unreachable — no session")
                    }
                }
        }
        .onChange(of: appState.phase, initial: true) { _, newPhase in
            isShowingProfileSetup = newPhase == .profileSetup
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()
            ProgressView()
                .tint(Colors.accent)
        }
    }
}

#Preview {
    RootView()
}
