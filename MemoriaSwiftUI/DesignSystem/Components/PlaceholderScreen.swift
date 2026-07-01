import SwiftUI

/// Stand-in for a not-yet-built flow so screens are reachable and testable before their
/// real implementation lands; each usage is replaced screen-by-screen in later build-order steps.
struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Text(title)
                    .font(Typography.font(.xl, weight: .semiBold))
                    .foregroundStyle(Colors.textPrimary)
                Text(subtitle)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(Typography.font(.sm, weight: .medium))
                        .foregroundStyle(Colors.accent)
                        .padding(.top, Spacing.sm)
                }
            }
        }
    }
}
