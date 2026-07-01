import SwiftUI

/// A glass-chrome container. `.panel` is for general floating surfaces on dark
/// backgrounds (invite cards, headers); `.floatingChrome` is for controls that sit
/// directly over photo content (Drop Detail / Story header buttons).
struct GlassCard<Content: View>: View {
    enum Style {
        case panel
        case floatingChrome
    }

    var style: Style = .panel
    var cornerRadius: CGFloat = Radii.lg
    let content: Content

    init(style: Style = .panel, cornerRadius: CGFloat = Radii.lg, @ViewBuilder content: () -> Content) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                if #available(iOS 26, *) {
                    glassBackground
                } else {
                    fallbackBackground
                }
            }
    }

    @available(iOS 26, *)
    private var glassBackground: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let glass = style == .panel
            ? Glass.regular.tint(Colors.glassPanelTint).interactive()
            : Glass.regular.interactive()
        return shape
            .fill(.clear)
            .glassEffect(glass, in: shape)
    }

    private var fallbackBackground: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return shape
            .fill(style == .panel ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Colors.glassChromeFallback))
            .overlay {
                if style == .floatingChrome {
                    shape.strokeBorder(Colors.glassChromeBorder, lineWidth: 1)
                }
            }
    }
}

#Preview {
    ZStack {
        Colors.background.ignoresSafeArea()
        VStack(spacing: Spacing.lg) {
            GlassCard {
                Text("Invite your friends")
                    .font(Typography.font(.body, weight: .medium))
                    .foregroundStyle(Colors.textPrimary)
                    .padding(Spacing.md)
            }
            GlassCard(style: .floatingChrome) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Colors.white)
                    .padding(Spacing.sm)
            }
        }
        .padding()
    }
}
