import SwiftUI

struct AgeStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    let onContinue: () -> Void

    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("How old are you?")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
                .padding(.top, Spacing.xxl)

            Text("Optional — you can skip this.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)

            TextField("", text: $text, prompt: Text("Age").foregroundStyle(Colors.textPlaceholder))
                .inputFieldStyle()
                .keyboardType(.numberPad)
                .onChange(of: text) { _, newValue in
                    text = String(newValue.filter(\.isNumber).prefix(3))
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.error)
            }

            Spacer()

            ProfileSetupContinueButton(action: submit)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
        .onAppear {
            if let age = store.age {
                text = String(age)
            }
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
