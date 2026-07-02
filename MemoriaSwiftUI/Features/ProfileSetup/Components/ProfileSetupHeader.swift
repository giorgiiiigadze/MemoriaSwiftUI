import SwiftUI

/// BeReal-style header: circular glass back button, centered wordmark, glass Skip pill.
/// No progress indicator — the wizard's position isn't shown here by design.
struct ProfileSetupHeader: View {
    var onBack: (() -> Void)?
    var onSkip: (() -> Void)?

    var body: some View {
        ZStack {
            Text("Memoria")
                .font(Typography.font(.lg, weight: .strong))
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
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }
}

/// Circular back button, matching BeReal's top-left control. On iOS 26 it uses the system
/// `.glass` button style at `.controlSize(.large)` — Apple's native glass proportions, the
/// same sizing BeReal uses — shaped by `.buttonBorderShape(.circle)` so the glass renders
/// and animates as a circle (never hard-clipped). No fixed frame: the icon's point size plus
/// the glass style's own padding define the circle. Below iOS 26 it falls back to a
/// material-filled circle sized to roughly match.
private struct GlassHeaderIconButton: View {
    let systemImage: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
        }
        .glassChromeButton(
            .circle,
            fallbackShape: Circle(),
            fallbackInsets: EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
        )
        .opacity(action == nil ? 0 : 1)
        .disabled(action == nil)
    }
}

/// Pill Skip button, matching BeReal's top-right "Help" control — same native large-glass
/// treatment as the back button, capsule-shaped.
private struct GlassHeaderPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
        }
        .glassChromeButton(
            .capsule,
            fallbackShape: Capsule(),
            fallbackInsets: EdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22)
        )
    }
}

private extension View {
    /// Native `.glass` button style on iOS 26 at `.controlSize(.large)` (BeReal-matching
    /// glass proportions), shaped by `borderShape` so the glass itself renders and animates
    /// in that shape. Below iOS 26, falls back to a material fill + chrome border in
    /// `fallbackShape`, padded by `fallbackInsets` to approximate the same size. White
    /// foreground either way, for the dark header.
    @ViewBuilder
    func glassChromeButton(
        _ borderShape: ButtonBorderShape,
        fallbackShape: some InsettableShape,
        fallbackInsets: EdgeInsets
    ) -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass)
                .buttonBorderShape(borderShape)
                .controlSize(.large)
                .tint(Colors.white)
        } else {
            foregroundStyle(Colors.white)
                .padding(fallbackInsets)
                .background(Colors.glassChromeFallback, in: fallbackShape)
                .overlay { fallbackShape.strokeBorder(Colors.glassChromeBorder, lineWidth: 1) }
                .contentShape(fallbackShape)
        }
    }
}

#Preview {
    ZStack {
        Colors.background.ignoresSafeArea()
        ProfileSetupHeader(onBack: {}, onSkip: {})
    }
}
