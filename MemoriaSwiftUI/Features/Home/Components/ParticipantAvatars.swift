import SwiftUI

/// A row of overlapping circular participant avatars, capped at five with a trailing "+N" bubble
/// for the overflow — a native rebuild of the RN `ParticipantAvatars`. Each avatar loads its
/// remote photo cache-first via `AvatarView` and falls back to initials.
struct ParticipantAvatars: View {
    let participants: [DropWithParticipants.Participant]

    private let avatarSize: CGFloat = 30
    private let overlap: CGFloat = 10
    private let maxVisible = 5
    private let ringWidth: CGFloat = 1
    /// How far a declined/left member's avatar is faded — clearly absent but still recognisable.
    private let inactiveOpacity: CGFloat = 0.45

    var body: some View {
        // Active members come first so declined/left people never crowd present members out of the
        // capped row (or the "+N" overflow). `enumerated` keeps the original order stable within
        // each group.
        let ordered = participants.enumerated()
            .sorted { lhs, rhs in
                let lInactive = Self.isInactive(lhs.element.status)
                let rInactive = Self.isInactive(rhs.element.status)
                if lInactive != rInactive { return !lInactive }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        let visible = Array(ordered.prefix(maxVisible))
        let extra = ordered.count - maxVisible

        if !visible.isEmpty {
            // Negative spacing overlaps each avatar over its neighbour; the z-index steps down
            // left-to-right so earlier avatars sit on top, matching the RN stacking order.
            HStack(spacing: -overlap) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, participant in
                    let inactive = Self.isInactive(participant.status)
                    AvatarView(
                        url: participant.profile?.avatarURL,
                        name: participant.profile?.name ?? "?",
                        size: avatarSize
                    )
                    // A member who declined their invite or left the drop reads as absent: greyed
                    // out and faded, ringed in native red instead of the default charcoal.
                    .grayscale(inactive ? 1 : 0)
                    .opacity(inactive ? inactiveOpacity : 1)
                    .overlay(
                        Circle().stroke(inactive ? Colors.error : Colors.charcoal, lineWidth: ringWidth)
                    )
                    .zIndex(Double(maxVisible - index))
                }

                if extra > 0 {
                    Text("+\(extra)")
                        .font(Typography.font(.xs, weight: .semiBold))
                        .foregroundStyle(Colors.textSecondary)
                        .frame(width: avatarSize, height: avatarSize)
                        .background(Circle().fill(Colors.surfaceDeep))
                        .overlay(Circle().stroke(Colors.charcoal, lineWidth: ringWidth))
                        .zIndex(0)
                }
            }
        }
    }

    /// A participant who declined their invite or left / was removed — no longer an active member.
    private static func isInactive(_ status: ParticipantStatus) -> Bool {
        status == .declined || status == .removed
    }
}
