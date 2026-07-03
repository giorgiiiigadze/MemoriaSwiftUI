import SwiftUI

/// Step 2 (final) of the sign-up flow: choose a password, then create the account. Styled like the
/// ProfileSetup wizard steps. The actual `signUp` network call and its outcome routing live in
/// `AuthView`; this view surfaces the loading/error it's handed.
struct SignUpPasswordStepView: View {
    @Binding var password: String
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        password.count >= 6
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Create a password")
                .font(Typography.font(.xl, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.huge)

            Text("At least 6 characters.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)

            SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Colors.textPlaceholder))
                .inputFieldStyle()
                .padding(.top, Spacing.lg)
                .textContentType(.newPassword)
                .focused($isFocused)
                .submitLabel(.go)
                .onSubmit { if isValid { onSubmit() } }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.error)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            ProfileSetupContinueButton(
                title: "Create account",
                isEnabled: isValid,
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
    SignUpPasswordStepView(
        password: .constant(""),
        isSubmitting: false,
        errorMessage: nil,
        onSubmit: {}
    )
    .background(Colors.background)
}
