import SwiftUI

struct NameStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    let onContinue: () -> Void

    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        !store.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        @Bindable var store = store

        VStack(spacing: Spacing.lg) {
            Text("What should friends call you?")
                .font(Typography.font(.xl, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.huge)

            TextField("", text: $store.name, prompt: Text("Your name").foregroundStyle(Colors.textPlaceholder))
                .inputFieldStyle()
                .padding(.top, Spacing.lg)
                .textInputAutocapitalization(.words)
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
    NameStepView(onContinue: {})
        .environment(ProfileSetupStore(userID: UUID()))
        .background(Colors.background)
}
