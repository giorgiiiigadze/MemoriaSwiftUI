import SwiftUI

/// Circular glass header control, matching BeReal's top-left back button. On iOS 26 it uses the
/// system `.glass` button style at `.controlSize(.large)` — Apple's native glass proportions, the
/// same sizing BeReal uses — shaped by `.buttonBorderShape(.circle)` so the glass renders and
/// animates as a circle (never hard-clipped). No fixed frame: the icon's point size plus the glass
/// style's own padding define the circle. Below iOS 26 it falls back to a material-filled circle
/// sized to roughly match. Passing a `nil` action renders an invisible, disabled placeholder that
/// still reserves the layout slot.
struct GlassHeaderIconButton: View {
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

/// Pill glass header control, matching BeReal's top-right "Help" control — same native large-glass
/// treatment as `GlassHeaderIconButton`, capsule-shaped. Used for the ProfileSetup "Skip" and the
/// auth flow's "Log in".
struct GlassHeaderPillButton: View {
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

extension View {
    /// Native `.glass` button style on iOS 26 at `.controlSize(.large)` (BeReal-matching glass
    /// proportions), shaped by `borderShape` so the glass itself renders and animates in that
    /// shape. Below iOS 26, falls back to a material fill + chrome border in `fallbackShape`,
    /// padded by `fallbackInsets` to approximate the same size. White foreground either way, for
    /// the dark header.
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
        HStack {
            GlassHeaderIconButton(systemImage: "chevron.left", action: {})
            Spacer()
            GlassHeaderPillButton(title: "Log in", action: {})
        }
        .padding()
    }
}
