import SwiftUI
import Supabase
import UIKit

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
    /// Drop-search state. The toolbar button flips `isSearchActive` to attach the native search
    /// field; once attached, `isSearchPresented` is driven false→true so SwiftUI runs its real
    /// present-and-focus transition (rather than the field appearing already-presented, which can
    /// fail to focus). `isSearchPresented` going back to false detaches and clears the query.
    @State private var query = ""
    @State private var isSearchActive = false
    @State private var isSearchPresented = false
    /// Presents the Create Drop flow from the empty-state button.
    @State private var isShowingCreateDrop = false
    /// The drop whose "add yours" prompt was tapped — drives the camera cover for a feed-level upload.
    @State private var uploadTarget: DropWithParticipants?

    private let service = DropsService()
    private let notificationsService = NotificationsService()
    private let photosService = PhotosService()

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

    /// Greeting name for the first-drop card: display name, then handle, then a neutral fallback —
    /// mirroring the RN `display_name || username || 'there'`.
    private var greetingName: String {
        if let displayName = appState.profile?.displayName, !displayName.isEmpty { return displayName }
        if let username = appState.profile?.username, !username.isEmpty { return username }
        return "there"
    }

    /// The trimmed, lower-cased search query, or empty when not searching.
    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The feed filtered by the search query — matching a drop's title, its creator, or any
    /// participant's name. Returns the full feed when the query is empty.
    private var filteredDrops: [DropWithParticipants] {
        let q = trimmedQuery
        guard !q.isEmpty else { return drops }
        return drops.filter { drop in
            drop.title.lowercased().contains(q)
                || (drop.creatorName?.lowercased().contains(q) ?? false)
                || drop.participants.contains { $0.profile?.name.lowercased().contains(q) ?? false }
        }
    }

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
                // Standalone glass buttons: notifications on the left, search on the right.
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        NotificationsView(onOpenFriends: onOpenFriends)
                    } label: {
                        // Native badged bell: the dot is part of the SF Symbol, so it stays centered
                        // and never clips. Palette tints the badge red and keeps the bell primary;
                        // the plain (no-unread) bell keeps its default toolbar tint.
                        Group {
                            if unreadCount > 0 {
                                Image(systemName: "bell.badge.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Colors.error, Colors.textPrimary)
                            } else {
                                Image(systemName: "bell.fill")
                            }
                        }
                        .accessibilityLabel(unreadCount > 0
                            ? "Notifications, \(unreadCount) unread"
                            : "Notifications")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Attach the native search field (like the Friends tab), but on demand
                        // rather than always-visible. The onChange below then presents it.
                        isSearchActive = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Memoria")
                        .font(Typography.font(.xl, weight: .strong))
                        .foregroundStyle(Colors.textPrimary)
                }
            }
            // Native drop search, only attached once the toolbar button activates it — so the field
            // stays fully hidden until tapped. Detaching it on dismiss (rather than leaving it
            // parked in the nav bar) is what keeps it hidden.
            .modifier(RevealableSearch(isActive: isSearchActive, isPresented: $isSearchPresented, text: $query))
            // Present only after the field is attached, so SwiftUI sees a real false→true
            // transition and reliably slides it in focused.
            .onChange(of: isSearchActive) { _, active in
                if active { isSearchPresented = true }
            }
            // Cancel drives isPresented→false: clear the query and detach the field.
            .onChange(of: isSearchPresented) { _, presented in
                if !presented {
                    query = ""
                    isSearchActive = false
                }
            }
            .tint(Colors.textPrimary)
        }
        .preferredColorScheme(.dark)
        // Reruns on first appear and whenever `refreshToken` changes (e.g. after a drop is created).
        .task(id: refreshToken) { await load() }
        // Live-update the bell badge: re-count whenever this user's notifications change.
        .task(id: currentUserID) { await observeNotifications() }
        // Live feed: refetch whenever a drop the user can see changes, or they're invited to a new
        // one — so a drop someone else creates (and invites them to) appears without a manual refresh.
        .task(id: currentUserID) { await observeFeed() }
        .alert("Delete Failed", isPresented: $didDeleteFail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not delete the drop. Please try again.")
        }
        .sheet(isPresented: $isShowingCreateDrop) {
            CreateDropView {
                Task { await load() }
            }
        }
        // Feed-level upload: tapping "Upload" on a still-collecting card opens the shared camera and
        // adds the photo straight to that drop, reusing the same PhotosService path as the detail page.
        .fullScreenCover(item: $uploadTarget) { drop in
            CameraView { image in await performUpload(image, to: drop) }
                .ignoresSafeArea()
        }
    }

    /// Uploads a photo captured from the feed prompt to `drop`, then refreshes so the prompt clears.
    private func performUpload(_ image: UIImage, to drop: DropWithParticipants) async {
        guard let userID = currentUserID else { return }
        do {
            try await photosService.uploadPhoto(dropID: drop.id, uploaderID: userID, image: image)
            await load()
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            feedSkeleton
        } else if drops.isEmpty {
            // A brand-new user (hasn't created their first drop yet) gets the dashed onboarding tile;
            // any other empty feed shows the plain "No drops yet" message.
            if appState.profile?.hasCreatedFirstDrop == false && errorMessage == nil {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        CreateFirstDropCard(name: greetingName) { isShowingCreateDrop = true }
                        Text("Others can invite you to their drops too. Start your own to share memories with friends.")
                            .font(Typography.font(.sm))
                            .foregroundStyle(Colors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xxxxl)
                }
                .scrollIndicators(.hidden)
            } else {
                emptyState
            }
        } else {
            RefreshableGridScrollView(onRefresh: { await load() }) {
                if filteredDrops.isEmpty {
                    searchEmptyState
                } else {
                    LazyVStack(spacing: feedSpacing) {
                        ForEach(filteredDrops) { drop in
                            DropCard(
                                drop: drop,
                                currentUserID: currentUserID,
                                onDelete: { delete(drop) },
                                onTogglePin: { togglePin(drop) },
                                onUpload: { uploadTarget = drop }
                            )
                            .onAppear { DropPrefetcher.shared.prefetch(drop) }
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
            }
        }
    }

    /// Shown when a search matches no drops — mirrors the Friends tab's no-results look.
    private var searchEmptyState: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Colors.white)
                .padding(.bottom, Spacing.xxs)
            Text("No drops found")
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
            Text("Try a different name or title.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxxl)
        .padding(.bottom, Spacing.xxxl)
    }

    /// First-load placeholder: a few `DropCard`-shaped skeletons in the real feed layout, so the
    /// screen keeps its structure while drops arrive instead of a lone spinner.
    private var feedSkeleton: some View {
        ScrollView {
            LazyVStack(spacing: feedSpacing) {
                ForEach(0..<3, id: \.self) { _ in DropCardSkeleton() }
            }
            .padding(.vertical, Spacing.md)
        }
        .scrollDisabled(true)
    }

    /// Shown when the feed is empty. On error it explains the failure; otherwise a friendly
    /// first-run prompt (matching the Profile empty state) with an icon over a headline, a softer
    /// suggestion line, and a "Create a drop" button that opens the Create Drop flow.
    @ViewBuilder
    private var emptyState: some View {
        if let errorMessage {
            VStack(spacing: Spacing.sm) {
                Text("Couldn't load drops")
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.textPrimary)
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl)
        } else {
            VStack(spacing: Spacing.xxs) {
                Text("No drops yet")
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.white)
                Text("Create your first drop to start a memory.")
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                CompactPillButton(title: "Create a drop", systemImage: "camera.viewfinder") {
                    isShowingCreateDrop = true
                }
                .padding(.top, Spacing.md)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.xxxxl)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    private func load() async {
        do {
            let fetched = try await service.fetchDrops()
            drops = fetched
            HomeDropsCache.store(fetched)
            errorMessage = nil
            // Once the user has any drop, the first-drop onboarding tile has served its purpose. The
            // DB trigger already flips the column on creation; mirror it locally so the UI updates
            // this session without waiting for a profile refetch.
            if !fetched.isEmpty { appState.markFirstDropCreated() }
        } catch {
            // Only surface the error when there's nothing cached to show; otherwise keep the
            // stale-but-useful cached feed on screen and stay silent. Cancellations (fast tab
            // switches / refresh) aren't real failures, so never show them.
            if drops.isEmpty && !error.isCancellation { errorMessage = error.localizedDescription }
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

    /// Live bell badge: re-counts this user's unread notifications whenever their `notifications`
    /// rows change, without reopening the page. Torn down when the task is cancelled.
    private func observeNotifications() async {
        guard let currentUserID else { return }
        await RealtimeWatch.run(
            topic: "notif-badge-\(currentUserID.uuidString)",
            sources: [
                .init("notifications", filter: .eq("user_id", value: currentUserID.uuidString))
            ],
            onChange: { await loadUnread() }
        )
    }

    /// Live feed: refetches the drop list whenever a drop the user can see changes, or a new
    /// `drop_participants` row invites them to one. RLS already scopes the `drops` events to drops
    /// this user is allowed to see, and the invite arrives as their own participant row, so a drop
    /// someone else just created shows up here with no manual refresh.
    private func observeFeed() async {
        guard let currentUserID else { return }
        await RealtimeWatch.run(
            topic: "home-feed-\(currentUserID.uuidString)",
            sources: [
                .init("drops"),
                .init("drop_participants", filter: .eq("user_id", value: currentUserID.uuidString)),
            ],
            onChange: { await load() }
        )
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

/// Attaches `.searchable` only while `isActive`, so the field is absent from the nav bar until the
/// toolbar button turns it on. It's attached with `isPresented` still false; the caller then flips
/// `isPresented` true so SwiftUI runs its real present-and-focus transition. Cancel flips
/// `isPresented` back to false, and the caller turns `isActive` off to detach and re-hide the field.
private struct RevealableSearch: ViewModifier {
    let isActive: Bool
    @Binding var isPresented: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isActive {
            content.searchable(text: $text, isPresented: $isPresented, prompt: "Search drops…")
        } else {
            content
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
