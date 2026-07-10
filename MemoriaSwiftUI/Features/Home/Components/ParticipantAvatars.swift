import SwiftUI

/// A row of overlapping circular participant avatars, capped at five with a trailing "+N" bubble
/// for the overflow — a native rebuild of the RN `ParticipantAvatars`. Each avatar loads its
/// remote photo cache-first via `AvatarView` and falls back to initials.
struct ParticipantAvatars: View {
    let participants: [DropWithParticipants.Participant]

    private let avatarSize: CGFloat = 34
    private let overlap: CGFloat = 12
    private let maxVisible = 5
    private let ringWidth: CGFloat = 1
    /// Strength of the dark scrim laid over an absent/pending member's avatar. A scrim (rather than
    /// a transparency fade) keeps the avatar opaque, so it reads as genuinely *darkened* instead of
    /// letting a bright photo behind the card show through and wash it into a pale smudge.
    private let dimScrim: CGFloat = 0.5

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

        // "X of Y uploaded" counts only active members (declined/left people aren't expected to
        // upload), so the label and the dimmed avatars tell the same story.
        let active = participants.filter { !Self.isInactive($0.status) }
        let uploadedCount = active.filter(\.hasUploaded).count

        if !visible.isEmpty {
            HStack(spacing: Spacing.xs) {
            // Negative spacing overlaps each avatar over its neighbour; the z-index steps down
            // left-to-right so earlier avatars sit on top, matching the RN stacking order.
            HStack(spacing: -overlap) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, participant in
                    let inactive = Self.isInactive(participant.status)
                    // An active member who simply hasn't dropped their photo yet is dimmed the same
                    // way, so the row reads at a glance as "who's still missing" — but keeps the
                    // default charcoal ring, since red is reserved for declined/left members.
                    let pending = !inactive && !participant.hasUploaded
                    AvatarView(
                        url: participant.profile?.avatarURL,
                        name: participant.profile?.name ?? "?",
                        size: avatarSize
                    )
                    // A member who declined their invite or left the drop reads as absent: greyed
                    // out and darkened, ringed in native red instead of the default charcoal.
                    // Members who haven't uploaded get the same grey/darken but no red ring.
                    .grayscale(inactive || pending ? 1 : 0)
                    .overlay {
                        if inactive || pending {
                            Circle().fill(Color.black.opacity(dimScrim))
                        }
                    }
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

                Spacer(minLength: Spacing.xs)

                if !active.isEmpty {
                    Text("\(uploadedCount) of \(active.count) uploaded")
                        .font(Typography.font(.xs, weight: .semiBold))
                        .foregroundStyle(Colors.white)
                        // A soft shadow keeps the white text legible over bright photos.
                        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                }
            }
        }
    }

    /// A participant who declined their invite or left / was removed — no longer an active member.
    private static func isInactive(_ status: ParticipantStatus) -> Bool {
        status == .declined || status == .removed
    }
}
