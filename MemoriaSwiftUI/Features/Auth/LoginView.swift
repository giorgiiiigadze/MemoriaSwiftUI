import SwiftUI
import Supabase

/// The login flow for users who already have an account, presented over the sign-up flow when the
/// header "Log in" pill is tapped. A two-step wizard (email → password), mirroring the sign-up
/// flow's structure and BeReal styling.
///
/// Routing after a successful sign-in is handled by `AppState`'s `authStateChanges` listener
/// (`.signedIn` → `.app` for a finished profile, or `.profileSetup` for an unfinished one). For
/// `.app`, this view stays put and lets `RootView` cross-dissolve the whole auth container into
/// the tab bar in one clean motion. Only `.profileSetup` triggers an explicit dismiss, since that
/// destination is pushed underneath this cover and has to be revealed.
struct LoginView: View {
    @Environment(AppState.self) private var appState
    let onDismiss: () -> Void

    private enum Step {
        case email, password
    }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let authStore = AuthStore()

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                AuthFlowHeader(onBack: headerBackAction, onLogin: nil)

                Group {
                    switch step {
                    case .email:
                        LoginEmailStepView(email: $email, onContinue: goToPasswordStep)
                    case .password:
                        LoginPasswordStepView(
                            password: $password,
                            isSubmitting: isSubmitting,
                            errorMessage: errorMessage,
                            onSubmit: { Task { await submit() } }
                        )
                    }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: step)
        .onChange(of: appState.phase) { _, newPhase in
            // On sign-in into the app, let `RootView`'s cross-dissolve tear down the whole auth
            // container in a single motion — popping this login push here would fire a competing
            // slide-back animation underneath the fade. Only `.profileSetup` needs the explicit
            // dismiss, since that destination is pushed underneath this cover and must be revealed.
            if newPhase == .profileSetup { onDismiss() }
        }
    }

    /// On the email step, back closes the whole login cover (returning to sign-up); on the
    /// password step it returns to the email step.
    private var headerBackAction: (() -> Void)? {
        switch step {
        case .email: return onDismiss
        case .password: return { goToEmailStep() }
        }
    }

    private func goToPasswordStep() {
        errorMessage = nil
        step = .password
    }

    private func goToEmailStep() {
        errorMessage = nil
        step = .email
    }

    private func submit() async {
        guard !password.isEmpty, !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await authStore.signIn(email: email, password: password)
        } catch {
            errorMessage = (error as? AuthError)?.message ?? error.localizedDescription
        }
    }
}

#Preview {
    LoginView(onDismiss: {})
        .environment(AppState())
}
