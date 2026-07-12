import SwiftUI

/// The unauthenticated landing screen: a big two-tone headline, a "tap anywhere" hint, and the
/// legal footer. Tapping anywhere hands off into the sign-up flow. Shown only as the true
/// unauthenticated root (not when Auth is presented as the add-account cover).
struct WelcomeView: View {
    /// Invoked when the user taps anywhere to begin.
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()

            // Two-tone headline, left-aligned and centered vertically.
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome to Memoria —")
                    .foregroundStyle(Colors.textPrimary)
                Text("your shared photo drops.")
                    .foregroundStyle(Colors.textMuted)
            }
            .font(Typography.font(.xxxl, weight: .strong))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.xl)

            // Bottom cluster: the tap hint above the legal line.
            VStack(spacing: Spacing.lg) {
                Text("Tap anywhere to get started")
                    .font(Typography.font(.sm, weight: .semiBold))
                    .foregroundStyle(Colors.textTertiary)

                Text("By continuing you acknowledge that you have read and agree to Memoria's [Terms of Use](https://memoria.app/terms) and [Privacy Policy](https://memoria.app/privacy).")
                    .font(Typography.font(.xs))
                    .foregroundStyle(Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .tint(Colors.accent)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        // Tap anywhere (except the legal links, which take their own taps) to begin.
        .contentShape(Rectangle())
        .onTapGesture(perform: onStart)
    }
}

#Preview {
    WelcomeView(onStart: {})
        .preferredColorScheme(.dark)
}
