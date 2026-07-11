import SwiftUI

/// Avatar diameter shared by `FriendRow` and its skeleton, so both line up exactly.
private let friendRowAvatarSize: CGFloat = 48

/// A person row in the Friends tab: avatar + name over a handle (or "friends for …" when `since`
/// is set), with an optional trailing control (Add / Accept / status chip). Mirrors the RN `UserRow`.
struct FriendRow<Trailing: View>: View {
    let profile: DropWithParticipants.ProfileRef
    /// When set, the subtitle reads "friends for <duration>" instead of the @handle.
    var since: Date? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(
        profile: DropWithParticipants.ProfileRef,
        since: Date? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.profile = profile
        self.since = since
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            AvatarView(url: profile.avatarURL, name: profile.name, size: friendRowAvatarSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Colors.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typography.font(.xs))
                    .foregroundStyle(Colors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.vertical, Spacing.sm)
    }

    private var subtitle: String {
        if let since { return "friends for \(FriendDuration.string(since))" }
        return "@\(profile.username)"
    }
}

/// Human-readable "how long we've been friends", mirroring the RN `friendDuration`.
enum FriendDuration {
    static func string(_ since: Date) -> String {
        let days = max(0, Calendar.current.dateComponents([.day], from: since, to: Date()).day ?? 0)
        switch days {
        case 0: return "today"
        case 1: return "1 day"
        case 2..<7: return "\(days) days"
        case 7..<30:
            let weeks = days / 7
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        case 30..<365:
            let months = days / 30
            return months == 1 ? "1 month" : "\(months) months"
        default:
            let years = days / 365
            return years == 1 ? "1 year" : "\(years) years"
        }
    }
}

/// Shimmering placeholder matching `FriendRow`'s layout, shown while search results load.
struct FriendRowSkeleton: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            SkeletonBlock(cornerRadius: friendRowAvatarSize / 2)
                .frame(width: friendRowAvatarSize, height: friendRowAvatarSize)

            VStack(alignment: .leading, spacing: 5) {
                SkeletonBlock(cornerRadius: Radii.xs)
                    .frame(width: 130, height: 13)
                SkeletonBlock(cornerRadius: Radii.xs)
                    .frame(width: 80, height: 11)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // The real chip in placeholder mode, so the button lines up exactly with loaded rows.
            FriendChip(label: "Add", isPlaceholder: true)
        }
        .padding(.vertical, Spacing.sm)
    }
}
