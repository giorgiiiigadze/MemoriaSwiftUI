import SwiftUI

/// White pill, black text — the BeReal-style primary action on this flow's black background.
struct ProfileSetupContinueButton: View {
    var title: String = "Continue"
    var isEnabled: Bool = true
    var isLoading: Bool = false
    // Defaults to 16pt top+bottom → ~51pt tall, matching BeReal's primary CTA (profile setup).
    // The auth flow overrides this for a slightly taller pill.
    var verticalPadding: CGFloat = Spacing.lg
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(Colors.ink)
                } else {
                    Text(title)
                        .font(Typography.font(.body, weight: .semiBold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
        }
        .foregroundStyle(Colors.ink)
        .background(
            // 14pt — BeReal's rounded-rectangle CTA radius (between Radii.md/lg).
            isEnabled ? Colors.white : Colors.white.opacity(0.4),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
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
