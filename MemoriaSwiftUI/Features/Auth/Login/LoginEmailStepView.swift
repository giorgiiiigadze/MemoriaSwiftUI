import SwiftUI

/// Step 1 of the login flow: collect the email. Same centered, no-fill BeReal style as the
/// sign-up steps. The actual sign-in happens on the password step (owned by `LoginView`).
struct LoginEmailStepView: View {
    @Binding var email: String
    let onContinue: () -> Void

    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        email.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Welcome back")
                .font(Typography.font(.xxl, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.huge)

            TextField("", text: $email, prompt: Text("Email").foregroundStyle(Colors.textPlaceholder))
                .authInputFieldStyle()
                .padding(.top, Spacing.lg)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.continue)
                .onSubmit { if isValid { onContinue() } }

            Spacer()

            ProfileSetupContinueButton(
                isEnabled: isValid,
                verticalPadding: Spacing.xl,
                cornerRadius: Radii.lg,
                titleFont: Typography.font(.lg, weight: .strong),
                action: onContinue
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .onAppear { isFocused = true }
    }
}

#Preview {
    LoginEmailStepView(email: .constant(""), onContinue: {})
        .background(Colors.background)
}
