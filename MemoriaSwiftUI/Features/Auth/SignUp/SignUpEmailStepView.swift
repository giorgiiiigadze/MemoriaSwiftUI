import SwiftUI

/// Step 1 of the sign-up flow: collect the email. Styled to match the ProfileSetup wizard steps
/// (left-aligned title, `inputFieldStyle` field, bottom `ProfileSetupContinueButton`).
struct SignUpEmailStepView: View {
    @Binding var email: String
    let onContinue: () -> Void

    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        email.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("What's your email?")
                .font(Typography.font(.xl, weight: .semiBold))
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

            ProfileSetupContinueButton(isEnabled: isValid, action: onContinue)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .onAppear { isFocused = true }
    }
}

#Preview {
    SignUpEmailStepView(email: .constant(""), onContinue: {})
        .background(Colors.background)
}
