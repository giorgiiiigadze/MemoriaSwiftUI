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
                    subtitle: "4-slide first-launch tutorial — step 4",
                    actionTitle: "Skip to Sign In",
                    action: { appState.skipOnboarding() }
                )
            case .auth:
                AuthView()
            case .profileSetup:
                PlaceholderScreen(title: "Profile Setup", subtitle: "7-step wizard — step 4")
            case .app:
                MainTabView()
            }
        }
        .environment(appState)
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
