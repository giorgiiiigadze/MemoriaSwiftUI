import SwiftUI
import Supabase

/// The unauthenticated entry point. Sign-up-first: a fresh visitor lands on the sign-up flow —
/// a two-step wizard (email → password) styled like `ProfileSetupFlowView`. A successful sign-up
/// hands off to the profile-setup wizard (an immediate session) or shows the email-confirmation
/// screen (when Supabase requires confirmation first).
///
/// The header's "Log in" pill routes existing users into `LoginView`, presented as a full-screen
/// cover over this flow.
struct AuthView: View {
    @Environment(AppState.self) private var appState

    private enum SignUpStep {
        case email, password
    }

    @State private var step: SignUpStep = .email
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didRequestConfirmation = false
    @State private var isShowingLogin = false

    private let authStore = AuthStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()

                if didRequestConfirmation {
                    SignUpConfirmationView(email: email, onBackToStart: resetToStart)
                } else {
                    VStack(spacing: 0) {
                        AuthFlowHeader(
                            onBack: headerBackAction,
                            onLogin: { isShowingLogin = true }
                        )

                        Group {
                            switch step {
                            case .email:
                                SignUpEmailStepView(email: $email, onContinue: goToPasswordStep)
                            case .password:
                                SignUpPasswordStepView(
                                    password: $password,
                                    isSubmitting: isSubmitting,
                                    errorMessage: errorMessage,
                                    onSubmit: { Task { await submitSignUp() } }
                                )
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // Login is pushed with the native slide-from-right animation (and its own custom glass
            // header) rather than presented as a bottom sheet. The system nav bar is hidden so only
            // the app's `AuthFlowHeader` shows; LoginView's back button pops via `isShowingLogin`.
            .navigationDestination(isPresented: $isShowingLogin) {
                LoginView(onDismiss: { isShowingLogin = false })
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
                    .interactiveSwipeBack()
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    /// Back is only meaningful on the password step (returns to email); the email step is the
    /// flow's root, so it shows no back button.
    private var headerBackAction: (() -> Void)? {
        guard step == .password else { return nil }
        return { goToEmailStep() }
    }

    private func goToPasswordStep() {
        errorMessage = nil
        step = .password
    }

    private func goToEmailStep() {
        errorMessage = nil
        step = .email
    }

    /// Returns to a clean sign-up start (from the email-confirmation screen). Keeps the entered
    /// email so a re-attempt doesn't force retyping it, but clears the password.
    private func resetToStart() {
        didRequestConfirmation = false
        step = .email
        password = ""
        errorMessage = nil
    }

    private func submitSignUp() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let outcome = try await authStore.signUp(email: email, password: password)
            switch outcome {
            case .confirmationRequired:
                didRequestConfirmation = true
            case .signedIn(let session):
                appState.beginProfileSetup(session: session)
            }
        } catch {
            errorMessage = (error as? AuthError)?.message ?? error.localizedDescription
        }
    }
}

/// Shown after a sign-up that Supabase gates behind email confirmation — no session exists yet,
/// so the flow can't continue to profile setup until the user follows the emailed link.
private struct SignUpConfirmationView: View {
    let email: String
    let onBackToStart: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 40))
                .foregroundStyle(Colors.white)
            Text("Check your email")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
            Text("We sent a confirmation link to \(email). Follow it to finish creating your account.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button("Back", action: onBackToStart)
                .font(Typography.font(.body, weight: .medium))
                .foregroundStyle(Colors.white)
                .padding(.top, Spacing.sm)
        }
    }
}

#Preview {
    AuthView()
        .environment(AppState())
}
