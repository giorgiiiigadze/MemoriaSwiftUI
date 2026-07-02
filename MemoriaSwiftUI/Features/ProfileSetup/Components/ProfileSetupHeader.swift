import SwiftUI

/// BeReal-style header: circular glass back button, centered wordmark, glass Skip pill.
/// No progress indicator — the wizard's position isn't shown here by design.
/// Glass controls come from the shared `GlassHeaderIconButton` / `GlassHeaderPillButton`.
struct ProfileSetupHeader: View {
    var onBack: (() -> Void)?
    var onSkip: (() -> Void)?

    var body: some View {
        ZStack {
            Text("Memoria")
                .font(Typography.font(.xl, weight: .strong))
                .foregroundStyle(Colors.textPrimary)

            HStack {
                GlassHeaderIconButton(systemImage: "chevron.left", action: onBack)
                Spacer()
                if let onSkip {
                    GlassHeaderPillButton(title: "Skip", action: onSkip)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
        }
        // No explicit value: uses SwiftUI's system-default, platform-adaptive horizontal
        // padding (16pt on iPhone) instead of a hardcoded margin.
        .padding(.horizontal)
        .padding(.top, Spacing.sm)
    }
}

#Preview {
    ZStack {
        Colors.background.ignoresSafeArea()
        ProfileSetupHeader(onBack: {}, onSkip: {})
    }
}
