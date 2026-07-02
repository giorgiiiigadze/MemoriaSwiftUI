import SwiftUI

/// White pill, black text — the BeReal-style primary action on this flow's black background.
struct ProfileSetupContinueButton: View {
    var title: String = "Continue"
    var isEnabled: Bool = true
    var isLoading: Bool = false
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
            .padding(.vertical, Spacing.sm)
        }
        .foregroundStyle(Colors.ink)
        .background(
            isEnabled ? Colors.white : Colors.white.opacity(0.4),
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
    .background(Colors.background)
}
