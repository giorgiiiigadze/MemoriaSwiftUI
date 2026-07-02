import SwiftUI

struct NameStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    let onContinue: () -> Void

    private var isValid: Bool {
        !store.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("What should friends call you?")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.charcoal)
                .padding(.top, Spacing.xxl)

            TextField("", text: $store.name, prompt: Text("Your name").foregroundStyle(Colors.textPlaceholder))
                .inputFieldStyle()
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .onSubmit { if isValid { onContinue() } }

            Spacer()

            ProfileSetupContinueButton(isEnabled: isValid, action: onContinue)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
    }
}

#Preview {
    NameStepView(onContinue: {})
        .environment(ProfileSetupStore(userID: UUID()))
        .background(Colors.lightBackground)
}
