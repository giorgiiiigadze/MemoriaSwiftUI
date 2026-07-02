import SwiftUI

/// Step 2 (final) of the sign-up flow: choose a password and agree to the Terms, then create the
/// account. Styled like the ProfileSetup wizard steps. The actual `signUp` network call and its
/// outcome routing live in `AuthView`; this view surfaces the loading/error it's handed.
struct SignUpPasswordStepView: View {
    @Binding var password: String
    @Binding var agreedToTerms: Bool
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        password.count >= 6 && agreedToTerms
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Create a password")
                .font(Typography.font(.xxl, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.huge)

            Text("At least 6 characters.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)

            SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Colors.textPlaceholder))
                .authInputFieldStyle()
                .padding(.top, Spacing.lg)
                .textContentType(.newPassword)
                .focused($isFocused)
                .submitLabel(.go)
                .onSubmit { if isValid { onSubmit() } }

            TermsCheckboxRow(isChecked: $agreedToTerms)

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
                verticalPadding: Spacing.xl,
                cornerRadius: Radii.lg,
                titleFont: Typography.font(.lg, weight: .strong),
                action: onSubmit
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .onAppear { isFocused = true }
    }
}

private struct TermsCheckboxRow: View {
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? Colors.white : Colors.textSecondary)
                Text("I agree to the Terms of Service")
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SignUpPasswordStepView(
        password: .constant(""),
        agreedToTerms: .constant(false),
        isSubmitting: false,
        errorMessage: nil,
        onSubmit: {}
    )
    .background(Colors.background)
}
