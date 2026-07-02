import SwiftUI

/// Step 2 (final) of the login flow: collect the password and sign in. Same centered, no-fill
/// BeReal style as the sign-up steps. The `signIn` call and its loading/error state live in
/// `LoginView`; this view surfaces what it's handed.
struct LoginPasswordStepView: View {
    @Binding var password: String
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var canContinue: Bool {
        !password.isEmpty
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Enter your password")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.huge)

            SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Colors.textPlaceholder))
                .authInputFieldStyle()
                .padding(.top, Spacing.lg)
                .textContentType(.password)
                .focused($isFocused)
                .submitLabel(.go)
                .onSubmit { if canContinue && !isSubmitting { onSubmit() } }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.error)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            ProfileSetupContinueButton(
                title: "Log in",
                isEnabled: canContinue,
                isLoading: isSubmitting,
                action: onSubmit
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .onAppear { isFocused = true }
    }
}

#Preview {
    LoginPasswordStepView(
        password: .constant(""),
        isSubmitting: false,
        errorMessage: nil,
        onSubmit: {}
    )
    .background(Colors.background)
}
