import SwiftUI

/// The small pill button/label used across the Friends tab's rows — "Add", "Accept", "Decline",
/// "Friends", "Pending". A tappable button when `action` is set, otherwise a static status label.
/// Mirrors the RN `Chip` variants.
struct FriendChip: View {
    enum Variant {
        case white   // primary call-to-action ("Add")
        case green   // positive action ("Accept")
        case muted   // secondary action ("Decline")
        case card    // static status ("Friends" / "Pending")
    }

    let label: String
    var variant: Variant = .white
    var action: (() -> Void)? = nil
    var disabled: Bool = false
    /// When true the chip renders shimmer-filled (a loading placeholder) at the exact size a real
    /// chip with this label would be — so skeleton rows and loaded rows line up perfectly.
    var isPlaceholder: Bool = false

    var body: some View {
        if let action, !isPlaceholder {
            Button(action: action) { pill }
                .buttonStyle(.plain)
                .disabled(disabled)
        } else {
            pill
        }
    }

    private var pill: some View {
        Text(label)
            .font(Typography.font(.xs, weight: .semiBold))
            .foregroundStyle(isPlaceholder ? .clear : foreground)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background {
                if isPlaceholder {
                    SkeletonBlock(cornerRadius: Radii.full)
                } else {
                    Capsule().fill(background)
                }
            }
            .opacity(disabled ? 0.5 : 1)
    }

    private var background: Color {
        switch variant {
        case .white: Colors.white
        case .green: Colors.success
        case .muted: Colors.surfaceRaised
        case .card: Colors.surfaceCard
        }
    }

    private var foreground: Color {
        switch variant {
        case .white: Colors.ink
        case .green: Colors.white
        case .muted: Colors.textSecondary
        case .card: Colors.white
        }
    }
}

#Preview {
    HStack(spacing: Spacing.sm) {
        FriendChip(label: "Add", variant: .white, action: {})
        FriendChip(label: "Accept", variant: .green, action: {})
        FriendChip(label: "Decline", variant: .muted, action: {})
        FriendChip(label: "Friends", variant: .card)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Colors.background)
}
