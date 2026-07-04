import SwiftUI
import Supabase

/// The Home tab (step 5 — drop feed): a vertically scrolling list of every drop rendered as a
/// native `DropCard`. Native navigation header with the leading Liquid Glass bell/share pill and
/// the centered "Memoria" wordmark.
struct HomeView: View {
    @Environment(AppState.self) private var appState

    @State private var drops: [DropWithParticipants]
    @State private var isLoading: Bool
    @State private var errorMessage: String?
    @State private var didDeleteFail = false
    /// Unread notification count for the bell badge.
    @State private var unreadCount: Int

    private let service = DropsService()
    private let notificationsService = NotificationsService()

    /// Vertical gap between drop cards in the feed.
    private let feedSpacing: CGFloat = 35

    /// Bumped by the parent (e.g. after creating a drop) to force the feed to refetch. Feeds the
    /// `.task(id:)` below, which reruns whenever it changes.
    var refreshToken: Int = 0
    /// Switches to the Friends tab — passed down to the Notifications page for friend taps.
    var onOpenFriends: () -> Void = {}

    /// Seed from the disk cache so a returning user sees their feed instantly; only fall back to
    /// the spinner when nothing is cached yet (first ever open). The fresh fetch in `load()` still
    /// runs either way.
    init(refreshToken: Int = 0, onOpenFriends: @escaping () -> Void = {}) {
        self.refreshToken = refreshToken
        self.onOpenFriends = onOpenFriends
        let cached = HomeDropsCache.load() ?? []
        _drops = State(initialValue: cached)
        _isLoading = State(initialValue: cached.isEmpty)
        // Seed the bell badge from the cached notifications so it's correct on the first frame.
        let cachedNotifs = NotificationsCache.load() ?? []
        _unreadCount = State(initialValue: cachedNotifs.filter { !$0.read }.count)
    }

    private var currentUserID: UUID? { appState.session?.user.id }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()
                content
            }
            // Refresh the badge whenever Home reappears (e.g. after viewing & reading notifications).
            .onAppear { Task { await loadUnread() } }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Two buttons in one ToolbarItemGroup → the system renders them as a single
                // native Liquid Glass pill on iOS 26 (BeReal's top control), no custom capsule.
                ToolbarItemGroup(placement: .topBarLeading) {
                    NavigationLink {
                        NotificationsView(onOpenFriends: onOpenFriends)
                    } label: {
                        // Bell + badge in a padded ZStack so the badge sits at the corner *inside*
                        // the label's bounds — a negative overlay offset gets clipped by the toolbar.
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .padding(.top, Spacing.xs)
                                .padding(.trailing, Spacing.xs)
                            if unreadCount > 0 { unreadBadge }
                        }
                        .accessibilityLabel(unreadCount > 0
                            ? "Notifications, \(unreadCount) unread"
                            : "Notifications")
                    }
                    Button {
                        // TODO: share / invite
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Memoria")
                        .font(Typography.font(.xl, weight: .strong))
                        .foregroundStyle(Colors.textPrimary)
                }
            }
            .tint(Colors.textPrimary)
        }
        .preferredColorScheme(.dark)
        // Reruns on first appear and whenever `refreshToken` changes (e.g. after a drop is created).
        .task(id: refreshToken) { await load() }
        // Live-update the bell badge: re-count whenever this user's notifications change.
        .task(id: currentUserID) { await observeNotifications() }
        .alert("Delete Failed", isPresented: $didDeleteFail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not delete the drop. Please try again.")
        }
    }

    /// Red count pill on the bell — capped at "99+", ringed in the background colour so it reads
    /// cleanly over the toolbar.
    private var unreadBadge: some View {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Colors.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Colors.error, in: Capsule())
            .overlay(Capsule().stroke(Colors.background, lineWidth: 2))
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().tint(Colors.textTertiary)
        } else if drops.isEmpty {
            emptyState
        } else {
            RefreshableGridScrollView(onRefresh: { await load() }) {
                LazyVStack(spacing: feedSpacing) {
                    ForEach(drops) { drop in
                        DropCard(
                            drop: drop,
                            currentUserID: currentUserID,
                            onDelete: { delete(drop) },
                            onTogglePin: { togglePin(drop) }
                        )
                        .onAppear { DropPrefetcher.shared.prefetch(drop) }
                    }
                }
                .padding(.vertical, Spacing.md)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            if let errorMessage {
                Text("Couldn't load drops")
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.textPrimary)
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No drops yet")
                    .font(Typography.font(.md, weight: .medium))
                    .foregroundStyle(Colors.textSecondary)
            }
        }
        .padding(Spacing.xl)
    }

    private func load() async {
        do {
            let fetched = try await service.fetchDrops()
            drops = fetched
            HomeDropsCache.store(fetched)
            errorMessage = nil
        } catch {
            // Only surface the error when there's nothing cached to show; otherwise keep the
            // stale-but-useful cached feed on screen and stay silent.
            if drops.isEmpty { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    /// Refreshes the bell's unread count. Silent on failure — the badge just keeps its last value.
    private func loadUnread() async {
        guard let currentUserID else { return }
        if let count = try? await notificationsService.unreadCount(userId: currentUserID) {
            unreadCount = count
        }
    }

    /// Subscribes to Postgres changes on this user's `notifications` rows and re-counts the badge on
    /// every insert/update/delete, so it updates live without reopening the page. The channel is
    /// torn down when the task is cancelled (view goes away or the user changes).
    private func observeNotifications() async {
        guard let currentUserID else { return }
        let channel = SupabaseClient.shared.channel("notif-badge-\(currentUserID.uuidString)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "notifications",
            filter: .eq("user_id", value: currentUserID.uuidString)
        )
        await channel.subscribe()
        defer { Task { await channel.unsubscribe() } }
        // Reconcile once on connect, then on every change event.
        await loadUnread()
        for await _ in changes {
            await loadUnread()
        }
    }

    /// Optimistically drops the row, then deletes on the server — restoring the feed (and the
    /// cache) and surfacing an alert if the network delete fails.
    private func delete(_ drop: DropWithParticipants) {
        let previous = drops
        drops.removeAll { $0.id == drop.id }
        HomeDropsCache.store(drops)

        Task {
            do {
                try await service.deleteDrop(id: drop.id)
            } catch {
                drops = previous
                HomeDropsCache.store(previous)
                didDeleteFail = true
            }
        }
    }

    /// Flip a drop's pinned state (creator-only), optimistically updating the feed + cache.
    private func togglePin(_ drop: DropWithParticipants) {
        guard let index = drops.firstIndex(where: { $0.id == drop.id }) else { return }
        let newValue = !drops[index].pinned
        drops[index].isPinned = newValue
        HomeDropsCache.store(drops)
        Task { try? await service.setPinned(dropID: drop.id, pinned: newValue) }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
