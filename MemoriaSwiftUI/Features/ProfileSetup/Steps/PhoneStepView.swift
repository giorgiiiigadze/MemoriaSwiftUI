import SwiftUI

/// Skip lives in the header pill (like every other skippable step), driven by
/// `ProfileSetupFlowView`. Both Continue and Skip run through `store.submitPhone(rawInput:)`,
/// which performs the early `profiles` upsert (per spec); Continue additionally validates and
/// records the entered number. Errors from either path surface via `store.phoneEntryError`.
struct PhoneStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    let onContinue: () -> Void

    @State private var text = ""
    @State private var isSubmitting = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("What's your phone number?")
                .font(Typography.font(.xl, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.huge)

            Text("Optional — helps friends already in your contacts find you.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)

            TextField("", text: $text, prompt: Text("Phone number").foregroundStyle(Colors.textPlaceholder))
                .inputFieldStyle()
                .padding(.top, Spacing.lg)
                .keyboardType(.phonePad)
                .focused($isFocused)

            if let errorMessage = store.phoneEntryError {
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.error)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            ProfileSetupContinueButton(isLoading: isSubmitting, action: submit)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .onAppear {
            isFocused = true
            store.phoneEntryError = nil
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            if await store.submitPhone(rawInput: text) {
                onContinue()
            }
        }
    }
}

#Preview {
    PhoneStepView(onContinue: {})
        .environment(ProfileSetupStore(userID: UUID()))
        .background(Colors.background)
}
