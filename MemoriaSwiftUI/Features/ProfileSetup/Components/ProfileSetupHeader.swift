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
/// real interactive Liquid Glass press physics (scale, highlight, lensing) rather than a
/// static glass background painted behind a `.plain` button. Below iOS 26 it falls back to
/// a material-filled circle with the same chrome border as `GlassCard`'s fallback.
private struct GlassHeaderIconButton: View {
    let systemImage: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemImage)
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
                .frame(width: 40, height: 40)
        }
        .glassChromeButton(shape: Circle())
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
                .foregroundStyle(Colors.white)
                .padding(.horizontal, Spacing.md)
                .frame(height: 40)
        }
        .glassChromeButton(shape: Capsule())
    }
}

private extension View {
    /// Applies the native `.glass` button style on iOS 26 (real interactive Liquid Glass),
    /// clipped to `shape`; falls back to a material fill + chrome border on older OSes.
    @ViewBuilder
    func glassChromeButton(shape: some Shape & InsettableShape) -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass)
                .clipShape(shape)
        } else {
            buttonStyle(.plain)
                .background(Colors.glassChromeFallback, in: shape)
                .overlay { shape.strokeBorder(Colors.glassChromeBorder, lineWidth: 1) }
        }
    }
}

#Preview {
    ZStack {
        Colors.background.ignoresSafeArea()
        ProfileSetupHeader(onBack: {}, onSkip: {})
    }
}
