import SwiftUI

/// A compact take on the auth CTA (`ProfileSetupContinueButton`): the same white pill with black
/// text, but sized to hug its label instead of filling the width, with a smaller font. For inline
/// actions (empty-state prompts, cards) where a full-width button would be too heavy.
struct CompactPillButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(Colors.ink)
                } else {
                    Label {
                        Text(title)
                    } icon: {
                        if let systemImage { Image(systemName: systemImage) }
                    }
                    .labelStyle(.titleAndIcon)
                    .font(Typography.font(.sm, weight: .semiBold))
                }
            }
            .foregroundStyle(Colors.ink)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.xl)
            .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        CompactPillButton(title: "Create a drop") {}
        CompactPillButton(title: "Add friends", systemImage: "person.badge.plus") {}
        CompactPillButton(title: "Loading", isLoading: true) {}
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Colors.background)
}
