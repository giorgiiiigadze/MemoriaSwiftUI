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

/// Circular back button. On iOS 26 it uses the system `.glass` button style so it gets the
/// real interactive Liquid Glass press physics (scale, highlight, lensing); the round shape
/// comes from `.buttonBorderShape(.circle)` so the glass renders/animates as a circle rather
/// than being hard-clipped. Below iOS 26 it falls back to a material-filled circle.
private struct GlassHeaderIconButton: View {
    let systemImage: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemImage)
                .font(Typography.font(.md, weight: .semiBold))
                .frame(width: 40, height: 40)
        }
        .glassChromeButton(.circle, fallbackShape: Circle())
        .opacity(action == nil ? 0 : 1)
        .disabled(action == nil)
    }
}

/// Pill Skip button — same native-glass treatment as the back button.
private struct GlassHeaderPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.font(.sm, weight: .semiBold))
                .padding(.horizontal, Spacing.md)
                .frame(height: 40)
        }
        .glassChromeButton(.capsule, fallbackShape: Capsule())
    }
}

private extension View {
    /// Native `.glass` button style on iOS 26, shaped by `borderShape` so the glass itself
    /// renders and animates in that shape. Below iOS 26, falls back to a material fill +
    /// chrome border in `fallbackShape`. White foreground either way, for the dark header.
    @ViewBuilder
    func glassChromeButton(
        _ borderShape: ButtonBorderShape,
        fallbackShape: some InsettableShape
    ) -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass)
                .buttonBorderShape(borderShape)
                .tint(Colors.white)
        } else {
            foregroundStyle(Colors.white)
                .buttonStyle(.plain)
                .background(Colors.glassChromeFallback, in: fallbackShape)
                .overlay { fallbackShape.strokeBorder(Colors.glassChromeBorder, lineWidth: 1) }
        }
    }
}

#Preview {
    ZStack {
        Colors.background.ignoresSafeArea()
        ProfileSetupHeader(onBack: {}, onSkip: {})
    }
}
