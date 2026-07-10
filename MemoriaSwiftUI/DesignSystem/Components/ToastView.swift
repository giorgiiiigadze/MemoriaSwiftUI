import SwiftUI

/// The toast pill itself: a Liquid Glass capsule (shared `GlassCard` `.floatingChrome` style, so it
/// gets the real `glassEffect` on iOS 26 and the material fallback below it) holding an optional
/// icon and a line of text.
struct ToastView: View {
    let state: ToastState

    var body: some View {
        GlassCard(style: .floatingChrome, cornerRadius: Radii.full) {
            HStack(spacing: Spacing.xs) {
                if let systemImage = state.systemImage {
                    Image(systemName: systemImage)
                        .font(Typography.font(.body, weight: .semiBold))
                        .foregroundStyle(Colors.textPrimary)
                }
                Text(state.text)
                    .font(Typography.font(.body, weight: .semiBold))
                    .foregroundStyle(Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .shadow(color: Colors.ink.opacity(0.35), radius: 12, y: 4)
    }
}
