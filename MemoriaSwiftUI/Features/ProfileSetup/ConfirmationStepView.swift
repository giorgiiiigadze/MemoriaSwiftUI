import SwiftUI

struct ConfirmationStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    let onComplete: (Profile) -> Void

    @State private var errorMessage: String?
    @State private var isFinalizing = true

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Colors.success)

            Text("Profile created ✓")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                Button("Try Again") {
                    Task { await finalize() }
                }
                .font(Typography.font(.sm, weight: .medium))
                .foregroundStyle(Colors.accent)
            } else if isFinalizing {
                ProgressView()
            } else {
                // `performUpsert` silently appends a random suffix on a same-username race,
                // so this is the user's only confirmation of what actually got saved.
                Text("@\(store.username)")
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Colors.background.ignoresSafeArea())
        .task {
            await finalize()
        }
    }

    private func finalize() async {
        errorMessage = nil
        isFinalizing = true
        do {
            let profile = try await store.finalize()
            isFinalizing = false
            try? await Task.sleep(for: .milliseconds(1400))
            onComplete(profile)
        } catch {
            isFinalizing = false
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ConfirmationStepView(onComplete: { _ in })
        .environment(ProfileSetupStore(userID: UUID()))
}
