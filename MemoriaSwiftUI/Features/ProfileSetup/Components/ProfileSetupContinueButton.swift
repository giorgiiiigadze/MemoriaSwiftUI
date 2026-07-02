import SwiftUI

/// White pill, black text — the BeReal-style primary action on this flow's black background.
struct ProfileSetupContinueButton: View {
    var title: String = "Continue"
    var isEnabled: Bool = true
    var isLoading: Bool = false
    // Defaults to 16pt top+bottom → ~51pt tall, matching BeReal's primary CTA (profile setup).
    // The auth flow overrides this for a slightly taller pill.
    var verticalPadding: CGFloat = Spacing.lg
    // 14pt radius / 15pt semibold label are the profile-setup defaults; the auth flow overrides
    // both to match BeReal's rounder, bolder button.
    var cornerRadius: CGFloat = 14
    var titleFont: Font = Typography.font(.body, weight: .semiBold)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(Colors.ink)
                } else {
                    Text(title)
                        .font(titleFont)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
        }
        .foregroundStyle(Colors.ink)
        .background(
            isEnabled ? Colors.white : Colors.white.opacity(0.4),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
    .background(Colors.background)
}
