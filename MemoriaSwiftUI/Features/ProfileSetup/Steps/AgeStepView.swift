import SwiftUI

struct AgeStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    let onContinue: () -> Void

    @State private var text = ""
    @State private var errorMessage: String?

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("How old are you?")
                .font(Typography.font(.xl, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.huge)

            Text("Optional — you can skip this.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)

            TextField("", text: $text, prompt: Text("Age").foregroundStyle(Colors.textPlaceholder))
                .inputFieldStyle()
                .tint(Colors.white)
                .padding(.top, Spacing.lg)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    text = String(newValue.filter(\.isNumber).prefix(3))
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.error)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            ProfileSetupContinueButton(action: submit)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .onAppear {
            if let age = store.age {
                text = String(age)
            }
            isFocused = true
        }
    }

    private func submit() {
        guard !text.isEmpty else {
            store.age = nil
            onContinue()
            return
        }
        guard let value = Int(text), (1...120).contains(value) else {
            errorMessage = "Enter an age between 1 and 120, or leave it blank."
            return
        }
        errorMessage = nil
        store.age = value
        onContinue()
    }
}

#Preview {
    AgeStepView(onContinue: {})
        .environment(ProfileSetupStore(userID: UUID()))
        .background(Colors.background)
}
