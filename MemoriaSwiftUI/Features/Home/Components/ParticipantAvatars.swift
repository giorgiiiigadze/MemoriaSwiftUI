import SwiftUI

/// A row of overlapping circular participant avatars, capped at five with a trailing "+N" bubble
/// for the overflow — a native rebuild of the RN `ParticipantAvatars`. Each avatar loads its
/// remote photo cache-first via `AvatarView` and falls back to initials.
struct ParticipantAvatars: View {
    let participants: [DropWithParticipants.Participant]

    private let avatarSize: CGFloat = 30
    private let overlap: CGFloat = 10
    private let maxVisible = 5

    var body: some View {
        let visible = Array(participants.prefix(maxVisible))
        let extra = participants.count - maxVisible

        if !visible.isEmpty {
            // Negative spacing overlaps each avatar over its neighbour; the z-index steps down
            // left-to-right so earlier avatars sit on top, matching the RN stacking order.
            HStack(spacing: -overlap) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, participant in
                    AvatarView(
                        url: participant.profile?.avatarURL,
                        name: participant.profile?.name ?? "?",
                        size: avatarSize
                    )
                    .overlay(Circle().stroke(Colors.charcoal, lineWidth: 1))
                    .zIndex(Double(maxVisible - index))
                }

                if extra > 0 {
                    Text("+\(extra)")
                        .font(Typography.font(.xs, weight: .semiBold))
                        .foregroundStyle(Colors.textSecondary)
                        .frame(width: avatarSize, height: avatarSize)
                        .background(Circle().fill(Colors.surfaceDeep))
                        .overlay(Circle().stroke(Colors.charcoal, lineWidth: 1))
                        .zIndex(0)
                }
            }
        }
    }
}
