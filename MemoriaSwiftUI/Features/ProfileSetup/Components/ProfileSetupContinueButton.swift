import SwiftUI

/// Inverted from `AuthView`'s accent-on-dark submit button — charcoal-on-light, matching
/// this flow's one-light-themed-flow-in-a-dark-app design.
struct ProfileSetupContinueButton: View {
    var title: String = "Continue"
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(Colors.lightBackground)
                } else {
                    Text(title)
                        .font(Typography.font(.body, weight: .semiBold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        }
        .foregroundStyle(Colors.lightBackground)
        .background(
            isEnabled ? Colors.charcoal : Colors.charcoal.opacity(0.4),
            in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
        )
        .disabled(!isEnabled || isLoading)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        ProfileSetupContinueButton(action: {})
        ProfileSetupContinueButton(isEnabled: false, action: {})
        ProfileSetupContinueButton(isLoading: true, action: {})
    }
    .padding()
    .background(Colors.lightBackground)
}
