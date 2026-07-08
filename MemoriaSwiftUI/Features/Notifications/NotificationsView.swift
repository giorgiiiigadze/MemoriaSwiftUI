import SwiftUI
import Supabase

/// Pushed natively from the Home header's bell button (native slide-from-right + back button).
/// Lists the current user's notifications, split into Today / Earlier sections, each row showing
/// the actor's avatar (a stacked dual avatar for drop invites from someone else), the activity
/// line, a relative timestamp, and the drop's thumbnail. Pull-to-refresh reloads; tapping a row
/// marks it read. Mirrors the RN `NotificationsScreen`.
struct NotificationsView: View {
    /// Switches the app to the Friends tab — used when a friend notification is tapped, since that
    /// lives in a different tab (not this Home navigation stack). Supplied by `MainTabView`.
    var onOpenFriends: () -> Void = {}

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var notifications: [NotificationWithMeta]
    @State private var isLoaded: Bool
    /// Drop to open when a drop-related notification is tapped.
    @State private var navigatedDropID: UUID?
    /// Pushes the dedicated Friend requests list from the summary row.
    @State private var showingFriendRequests = false

    private let service = NotificationsService()

    /// Seed from the disk cache so rows render instantly on open; only show the skeleton when
    /// nothing is cached yet (first ever open). The fresh fetch in `load()` still runs either way.
    init(onOpenFriends: @escaping () -> Void = {}) {
        self.onOpenFriends = onOpenFriends
        let cached = NotificationsCache.load() ?? []
        _notifications = State(initialValue: cached)
        _isLoaded = State(initialValue: !cached.isEmpty)
    }

    private var currentUserID: UUID? { appState.session?.user.id }

    /// Friend requests are lifted out of the main list into their own summary row + sub-screen.
    private var friendRequests: [NotificationWithMeta] {
        notifications.filter { $0.type == .friendRequest }
    }
    /// The most recent request drives the summary row's avatar + subtitle (newest-first order).
    private var latestFriendRequest: NotificationWithMeta? { friendRequests.first }
    private var hasUnreadFriendRequests: Bool { friendRequests.contains { !$0.read } }

    /// Today first, then the past week, then everything older — only non-empty sections are kept.
    /// A single pass keeps the incoming newest-first order within each bucket. Friend requests are
    /// excluded here; they live in the pinned summary row above these sections.
    private var sections: [(title: String, items: [NotificationWithMeta])] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        var today: [NotificationWithMeta] = []
        var lastWeek: [NotificationWithMeta] = []
        var earlier: [NotificationWithMeta] = []
        for notification in notifications where notification.type != .friendRequest {
            if notification.isToday {
                today.append(notification)
            } else if notification.createdAt >= weekAgo {
                lastWeek.append(notification)
            } else {
                earlier.append(notification)
            }
        }
        var result: [(String, [NotificationWithMeta])] = []
        if !today.isEmpty { result.append(("Today", today)) }
        if !lastWeek.isEmpty { result.append(("Last 7 Days", lastWeek)) }
        if !earlier.isEmpty { result.append(("Earlier", earlier)) }
        return result
    }

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()

            if !isLoaded {
                NotificationsSkeleton()
            } else if notifications.isEmpty {
                emptyState
            } else {
                List {
                    if !friendRequests.isEmpty {
                        Section {
                            friendRequestsSummaryRow
                                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md,
                                                          bottom: Spacing.xs, trailing: Spacing.md))
                                .listRowBackground(Colors.background)
                                .listRowSeparator(.hidden)
                                .contentShape(.rect)
                                .onTapGesture { showingFriendRequests = true }
                        }
                    }
                    ForEach(sections, id: \.title) { section in
                        Section {
                            ForEach(section.items) { notification in
                                NotificationRow(
                                    notification: notification,
                                    currentUserID: currentUserID,
                                    myProfile: appState.profile
                                )
                                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md,
                                                          bottom: Spacing.xs, trailing: Spacing.md))
                                .listRowBackground(notification.read ? Colors.background : Colors.surface)
                                .listRowSeparator(.hidden)
                                .contentShape(.rect)
                                .onTapGesture { tap(notification) }
                            }
                        } header: {
                            Text(section.title)
                                .font(Typography.font(.sm, weight: .semiBold))
                                .foregroundStyle(Colors.textPrimary)
                        }
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(Spacing.xs)
                .scrollContentBackground(.hidden)
                .background(Colors.background)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarWhenPushed()
        .navigationDestination(item: $navigatedDropID) { dropID in
            DropDetailView(dropID: dropID)
        }
        .navigationDestination(isPresented: $showingFriendRequests) {
            FriendRequestsList(
                requests: friendRequests,
                currentUserID: currentUserID,
                myProfile: appState.profile,
                onTap: tap
            )
        }
        .task { await load() }
    }

    /// Friendly empty state matching the Friends tab's "No users found": an icon over a white
    /// headline and a softer suggestion line, centered and pushed down from the top.
    private var emptyState: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Colors.white)
                .padding(.bottom, Spacing.xxs)
            Text("No notifications")
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
            Text("You're all caught up. New activity will show up here.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxxl)
        .padding(.bottom, Spacing.xxxl)
    }

    /// The pinned row at the top of the list: the latest requester's avatar, a "Friend requests"
    /// title over the most recent request, an unread dot, and a chevron into the dedicated screen.
    private var friendRequestsSummaryRow: some View {
        HStack(spacing: Spacing.md) {
            AvatarView(
                url: latestFriendRequest?.actor?.avatarURL,
                name: latestFriendRequest?.actor?.name ?? "?",
                size: 58
            )
            VStack(alignment: .leading, spacing: 0) {
                Text("Friend requests")
                    .font(Typography.font(.body, weight: .semiBold))
                    .foregroundStyle(Colors.white)
                if let latest = latestFriendRequest {
                    Text(latest.text)
                        .font(Typography.font(.body))
                        .foregroundStyle(Colors.white)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasUnreadFriendRequests {
                Circle()
                    .fill(Colors.error)
                    .frame(width: 8, height: 8)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Colors.textTertiary)
        }
    }

    private func load() async {
        guard let currentUserID else { return }
        defer { isLoaded = true }
        do {
            let fetched = try await service.fetchNotifications(userId: currentUserID)
            notifications = fetched
            NotificationsCache.store(fetched)
        } catch {
            // Keep whatever is already on screen; an empty first load just shows the empty state.
        }
    }

    /// Handle a tap: optimistically mark it read (then persist), and act on it — a drop-related
    /// notification opens that drop's detail page. Friend notifications carry no `dropId`, so they
    /// just mark read for now. Mirrors the RN `markOneRead` + tap.
    private func tap(_ notification: NotificationWithMeta) {
        if !notification.read {
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].read = true
            }
            Task { try? await service.markRead(id: notification.id) }
        }
        if let dropID = notification.dropId {
            navigatedDropID = dropID
        } else if notification.type == .friendRequest || notification.type == .friendAccepted {
            // Friend activity lives in the Friends tab — jump there and pop this page so returning
            // to Home lands on the feed, not a stale Notifications screen.
            onOpenFriends()
            dismiss()
        }
    }
}

/// The dedicated Friend requests screen, pushed from the summary row: the same notification rows
/// as the main list, filtered to friend requests. Tapping one runs the parent's `tap` handler
/// (marks read, then jumps to the Friends tab).
private struct FriendRequestsList: View {
    let requests: [NotificationWithMeta]
    let currentUserID: UUID?
    let myProfile: Profile?
    var onTap: (NotificationWithMeta) -> Void

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()
            List {
                ForEach(requests) { notification in
                    NotificationRow(
                        notification: notification,
                        currentUserID: currentUserID,
                        myProfile: myProfile
                    )
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md,
                                              bottom: Spacing.xs, trailing: Spacing.md))
                    .listRowBackground(notification.read ? Colors.background : Colors.surface)
                    .listRowSeparator(.hidden)
                    .contentShape(.rect)
                    .onTapGesture { onTap(notification) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Colors.background)
        }
        .navigationTitle("Friend requests")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarWhenPushed()
    }
}

/// A single notification line: avatar (stacked dual avatar for a drop from someone else) + activity
/// text + relative time, with the drop's thumbnail trailing when present, and an unread dot badge.
private struct NotificationRow: View {
    let notification: NotificationWithMeta
    let currentUserID: UUID?
    let myProfile: Profile?

    private let avatarSize: CGFloat = 58
    private let dualSize: CGFloat = 43
    private let thumbnailSize: CGFloat = 44

    /// A drop notification whose creator is someone other than the current user gets the stacked
    /// dual avatar (drop creator over me); everything else shows the single actor avatar.
    private var showsDualAvatar: Bool {
        notification.drop != nil
            && notification.drop?.creator?.id != nil
            && notification.drop?.creator?.id != currentUserID
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            avatar
                .frame(width: avatarSize, height: avatarSize)
                .overlay(alignment: .bottomTrailing) {
                    if !notification.read { unreadBadge }
                }

            // Mirrors the DropCard header's text block (medium primary in white above a `.sm`
            // regular tertiary secondary, no gap), but with a larger `.md` primary.
            VStack(alignment: .leading, spacing: 0) {
                Text(notification.text)
                    .font(Typography.font(.body, weight: .medium))
                    .foregroundStyle(Colors.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(notification.timeAgo)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let thumbnail = notification.drop?.thumbnailURL {
                RemoteThumbnail(url: thumbnail, size: thumbnailSize)
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if showsDualAvatar {
            ZStack {
                AvatarView(
                    url: notification.drop?.creator?.avatarURL,
                    name: notification.drop?.creator?.name ?? "Drop",
                    size: dualSize
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                AvatarView(url: myProfile?.avatarURL, name: myName, size: dualSize)
                    .overlay(Circle().stroke(Colors.background, lineWidth: 2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        } else {
            AvatarView(
                url: notification.actor?.avatarURL,
                name: notification.actor?.name ?? "?",
                size: avatarSize
            )
        }
    }

    private var myName: String {
        if let displayName = myProfile?.displayName, !displayName.isEmpty { return displayName }
        return myProfile?.username ?? "?"
    }

    private var unreadBadge: some View {
        Circle()
            .fill(Colors.blueNotif)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Colors.background, lineWidth: 1.5))
            .offset(x: 1)
    }
}

/// A small rounded remote image (the drop's thumbnail) that reuses the app's on-disk avatar cache
/// for an instant, cache-first render — falling back to a neutral placeholder while it loads.
private struct RemoteThumbnail: View {
    let url: String
    let size: CGFloat

    @State private var image: UIImage?

    init(url: String, size: CGFloat) {
        self.url = url
        self.size = size
        // Instant path: if the bytes are already on disk, seed the state before the first frame so
        // the thumbnail paints immediately with no placeholder flash.
        if let resolved = URL(string: url),
           let cached = AvatarImageCache.data(for: resolved),
           let img = UIImage(data: cached) {
            _image = State(initialValue: img)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Colors.surface)
            .frame(width: size, height: size)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let resolved = URL(string: url) else { return }
        if let cached = AvatarImageCache.data(for: resolved), let img = UIImage(data: cached) {
            image = img
        }
        if let (data, _) = try? await URLSession.shared.data(from: resolved) {
            AvatarImageCache.store(data, for: resolved)
            if let img = UIImage(data: data) { image = img }
        }
    }
}

/// A shimmering placeholder shown during the first load, mirroring the row layout (avatar, two
/// text lines, thumbnail) under a section header so the screen has shape before the data arrives.
private struct NotificationsSkeleton: View {
    private let avatarSize: CGFloat = 58
    private let thumbnailSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section-header placeholder ("Today").
            SkeletonBlock(cornerRadius: Radii.sm)
                .frame(width: 60, height: 14)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.sm)

            ForEach(0..<7, id: \.self) { _ in
                row
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private var row: some View {
        HStack(spacing: Spacing.md) {
            SkeletonBlock(cornerRadius: avatarSize / 2)
                .frame(width: avatarSize, height: avatarSize)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                SkeletonBlock(cornerRadius: Radii.sm)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                SkeletonBlock(cornerRadius: Radii.sm)
                    .frame(width: 80, height: 12)
            }

            SkeletonBlock(cornerRadius: Radii.sm)
                .frame(width: thumbnailSize, height: thumbnailSize)
        }
        .padding(.vertical, Spacing.sm)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}
