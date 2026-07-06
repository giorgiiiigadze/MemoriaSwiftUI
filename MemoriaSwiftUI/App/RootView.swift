import SwiftUI
import Supabase

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()

    /// Keeps the splash up for a minimum of 0.8s so it never flashes by on fast boot paths
    /// (e.g. no stored session, where hydration resolves within a frame). Runs concurrently
    /// with boot hydration, so the network round-trip counts toward the minimum rather than
    /// stacking on top of it.
    @State private var minimumSplashElapsed = false

    private var isShowingSplash: Bool {
        appState.phase == .splash || !minimumSplashElapsed
    }

    var body: some View {
        // A `ZStack` (not a `Group`) so the outgoing and incoming screens overlap during a phase
        // change and genuinely cross-dissolve — each branch carries `.transition(.opacity)`, driven
        // by the `.animation(value:)` modifiers below. This is what gives logout (`.app` → `.auth`)
        // its smooth fade out of the account.
        ZStack {
            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                switch appState.phase {
                case .splash:
                    SplashView()
                        .transition(.opacity)
                case .onboarding:
                    PlaceholderScreen(
                        title: "Onboarding",
                        subtitle: "4-slide first-launch tutorial — not yet built",
                        actionTitle: "Skip to Sign In",
                        action: { appState.skipOnboarding() }
                    )
                    .transition(.opacity)
                case .auth, .profileSetup:
                    // Sharing one NavigationStack (instead of swapping `.auth`/`.profileSetup` as
                    // separate top-level cases) gets the wizard a genuine native push transition —
                    // real spring physics and the interactive edge-swipe-back gesture — instead of
                    // a hand-rolled `.transition`/`.animation` approximation.
                    AuthFlowContainer()
                        .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                case .app:
                    MainTabView()
                        // 0.6s (vs the ambient 0.3s) makes the account↔auth cross-dissolve — most
                        // visibly the fade out of the account on logout — slower and smoother. The
                        // per-transition animation overrides the ambient one just for this swap.
                        .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                }
            }
        }
        .environment(appState)
        // Add-account flow: presents the login screen over the app without signing out the current
        // account. A successful sign-in flips `phase` to `.app`, and `hydrate` clears
        // `isAddingAccount`, auto-dismissing this cover as the switch completes.
        .fullScreenCover(isPresented: Binding(
            get: { appState.isAddingAccount },
            set: { if !$0 { appState.cancelAddAccount() } }
        )) {
            Group {
                switch appState.addAccountMode {
                case .signIn:
                    LoginView(onDismiss: { appState.cancelAddAccount() })
                case .signUp:
                    // Create a brand-new account: the full sign-up flow, with a back control on its
                    // root step to close the cover and return to the current account.
                    AuthView(onCancel: { appState.cancelAddAccount() })
                }
            }
            .environment(appState)
        }
        .alert(
            "Switch Failed",
            isPresented: Binding(
                get: { appState.switchErrorMessage != nil },
                set: { if !$0 { appState.switchErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.switchErrorMessage ?? "")
        }
        .animation(.easeInOut(duration: 0.3), value: isShowingSplash)
        .animation(.easeInOut(duration: 0.3), value: appState.phase)
        .task {
            appState.start()
        }
        .task {
            try? await Task.sleep(for: .seconds(0.8))
            minimumSplashElapsed = true
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
            Colors.white.ignoresSafeArea()

            Text("Memoria")
                .font(Typography.font(.xxxl, weight: .strong))
                .foregroundStyle(Colors.ink)
        }
    }
}

#Preview {
    RootView()
}
