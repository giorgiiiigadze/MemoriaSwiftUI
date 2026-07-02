import SwiftUI

struct ProfileSetupHeader: View {
    let step: ProfileSetupStep
    var onBack: (() -> Void)?
    var onSkip: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(Typography.font(.md, weight: .medium))
                    .foregroundStyle(Colors.charcoal)
                    .frame(width: 32, height: 32)
            }
            .opacity(onBack == nil ? 0 : 1)
            .disabled(onBack == nil)

            HStack(spacing: Spacing.xxs) {
                ForEach(ProfileSetupStep.allCases, id: \.self) { candidate in
                    Capsule()
                        .fill(candidate.rawValue <= step.rawValue ? Colors.accent : Colors.charcoal.opacity(0.15))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }

            Group {
                if let onSkip {
                    Button("Skip", action: onSkip)
                        .font(Typography.font(.sm, weight: .medium))
                        .foregroundStyle(Colors.textTertiary)
                } else {
                    Color.clear
                }
            }
            .frame(width: 36)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }
}

#Preview {
    ProfileSetupHeader(step: .username, onBack: {}, onSkip: {})
        .background(Colors.lightBackground)
}
