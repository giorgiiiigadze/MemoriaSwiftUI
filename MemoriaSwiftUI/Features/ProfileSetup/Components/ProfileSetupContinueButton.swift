import SwiftUI

/// White pill, black text — the BeReal-style primary action on this flow's black background.
struct ProfileSetupContinueButton: View {
    var title: String = "Continue"
    var isEnabled: Bool = true
    var isLoading: Bool = false
    // BeReal's rounder, bolder primary CTA — shared by the auth and profile-setup flows:
    // 18pt top+bottom padding, 16pt corner radius, 18pt semibold label.
    var verticalPadding: CGFloat = Spacing.lxl
    var cornerRadius: CGFloat = Radii.lg
    var titleFont: Font = Typography.font(.lg, weight: .semiBold)
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
