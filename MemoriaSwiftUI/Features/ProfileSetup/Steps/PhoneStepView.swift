import SwiftUI

/// Both Continue and Skip trigger the early `profiles` upsert (per spec), so this step
/// renders its own Skip button with the same inline loading/error handling as Continue,
/// instead of using `ProfileSetupHeader`'s generic (no-side-effect) Skip.
struct PhoneStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    let onContinue: () -> Void

    @State private var text = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("What's your phone number?")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
                .padding(.top, Spacing.xxl)

            Text("Optional — helps friends already in your contacts find you.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)

            TextField("", text: $text, prompt: Text("Phone number").foregroundStyle(Colors.textPlaceholder))
                .inputFieldStyle()
                .keyboardType(.phonePad)

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.error)
            }

            Spacer()

            VStack(spacing: Spacing.sm) {
                ProfileSetupContinueButton(isLoading: isSubmitting, action: { submit(withPhone: true) })

                Button {
                    submit(withPhone: false)
                } label: {
                    Text("Skip")
                        .font(Typography.font(.sm, weight: .medium))
                        .foregroundStyle(Colors.textTertiary)
                }
                .disabled(isSubmitting)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    private func submit(withPhone: Bool) {
        errorMessage = nil

        if withPhone {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                guard let normalized = ContactsMatchingService.normalize(trimmed) else {
                    errorMessage = "That doesn't look like a valid phone number."
                    return
                }
                store.phone = normalized
            }
        }

        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await store.upsertEarly()
                onContinue()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    PhoneStepView(onContinue: {})
        .environment(ProfileSetupStore(userID: UUID()))
        .background(Colors.background)
}
