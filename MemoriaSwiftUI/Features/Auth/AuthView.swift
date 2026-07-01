import SwiftUI
import Supabase

struct AuthView: View {
    private enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    private enum Field {
        case email, password
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var agreedToTerms = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didRequestConfirmation = false
    @FocusState private var focusedField: Field?

    private let authStore = AuthStore()

    private var isEmailValid: Bool {
        email.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }

    private var canSubmit: Bool {
        guard isEmailValid, !password.isEmpty, !isSubmitting else { return false }
        guard mode == .signUp else { return true }
        return password.count >= 6 && agreedToTerms
    }

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()

            if didRequestConfirmation {
                confirmationView
            } else {
                form
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text("Memoria")
                    .font(Typography.font(.xxl, weight: .bold))
                    .foregroundStyle(Colors.textPrimary)
                    .padding(.top, Spacing.huge)

                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) {
                    errorMessage = nil
                }

                VStack(spacing: Spacing.md) {
                    AuthTextField(placeholder: "Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                    AuthSecureField(placeholder: "Password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await submit() } }
                }

                if mode == .signUp {
                    TermsCheckboxRow(isChecked: $agreedToTerms)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.font(.sm))
                        .foregroundStyle(Colors.error)
                        .multilineTextAlignment(.center)
                }

                submitButton
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView().tint(Colors.ink)
                } else {
                    Text(mode == .signIn ? "Sign In" : "Sign Up")
                        .font(Typography.font(.body, weight: .semiBold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        }
        .foregroundStyle(Colors.ink)
        .background(
            canSubmit ? Colors.accent : Colors.accent.opacity(0.4),
            in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
        )
        .disabled(!canSubmit)
    }

    private var confirmationView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 40))
                .foregroundStyle(Colors.accent)
            Text("Check your email")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
            Text("We sent a confirmation link to \(email). Follow it to finish creating your account.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button("Back to Sign In") {
                didRequestConfirmation = false
                mode = .signIn
                password = ""
                agreedToTerms = false
            }
            .font(Typography.font(.body, weight: .medium))
            .foregroundStyle(Colors.accent)
            .padding(.top, Spacing.sm)
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        errorMessage = nil
        focusedField = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            switch mode {
            case .signIn:
                try await authStore.signIn(email: email, password: password)
            case .signUp:
                let outcome = try await authStore.signUp(email: email, password: password)
                if outcome == .confirmationRequired {
                    didRequestConfirmation = true
                }
            }
        } catch {
            errorMessage = (error as? AuthError)?.message ?? error.localizedDescription
        }
    }
}

private struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Colors.textPlaceholder))
            .foregroundStyle(Colors.textPrimary)
            .padding(Spacing.md)
            .background(Colors.surfaceInput, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
    }
}

private struct AuthSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(Colors.textPlaceholder))
            .foregroundStyle(Colors.textPrimary)
            .padding(Spacing.md)
            .background(Colors.surfaceInput, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
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
                    .foregroundStyle(isChecked ? Colors.accent : Colors.textSecondary)
                Text("I agree to the Terms of Service")
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AuthView()
}
