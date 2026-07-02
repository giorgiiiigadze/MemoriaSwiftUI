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

private struct GlassHeaderIconButton: View {
    let systemImage: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            GlassCard(style: .floatingChrome, cornerRadius: 20) {
                Image(systemName: systemImage)
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.white)
                    .frame(width: 40, height: 40)
            }
        }
        .buttonStyle(.plain)
        .opacity(action == nil ? 0 : 1)
        .disabled(action == nil)
    }
}

private struct GlassHeaderPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(style: .floatingChrome, cornerRadius: Radii.full) {
                Text(title)
                    .font(Typography.font(.sm, weight: .semiBold))
                    .foregroundStyle(Colors.white)
                    .padding(.horizontal, Spacing.md)
                    .frame(height: 40)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Colors.background.ignoresSafeArea()
        ProfileSetupHeader(onBack: {}, onSkip: {})
    }
}
