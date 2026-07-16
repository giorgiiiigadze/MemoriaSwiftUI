import Supabase
import SwiftUI

/// The Profile tab (step 10). TikTok-style: a large circular avatar with the user's name beneath,
/// a native header whose gear button pushes `SettingsView`. Below the identity block, an "All drops"
/// section renders the user's own drops as a grid of `MiniDropCard`s — the same section-header +
/// 3-up grid the Calendar tab uses.
struct ProfileView: View {
    @Environment(AppState.self) private var appState

    @State private var drops: [CalendarDrop]
    @State private var isLoadingDrops: Bool
    @State private var friendsCount: Int
    @State private var invitedCount: Int
    /// Drop whose detail page to push — driven by the card's "View drop" context-menu item.
    @State private var viewingDrop: CalendarDrop?
    /// Presents the Create Drop flow from the empty-state button.
    @State private var isShowingCreateDrop = false
    /// Presents the account switcher from the tappable username in the header.
    @State private var isShowingAccountSwitcher = false

    private let service = DropsService()
    private let friendsService = FriendsService()

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Spacing.xxs),
        count: 3
    )

    /// Seed from the disk cache so the grid renders instantly on open; only show the skeleton when
    /// nothing is cached yet (first ever open). The fresh fetch in `loadDrops()` still runs either way.
    init() {
        let cached = ProfileDropsCache.load() ?? []
        _drops = State(initialValue: cached)
        _isLoadingDrops = State(initialValue: cached.isEmpty)

        let stats = ProfileStatsCache.load()
        _friendsCount = State(initialValue: stats?.friends ?? 0)
        _invitedCount = State(initialValue: stats?.invited ?? 0)
    }

    private var profile: Profile? { appState.profile }

    /// Shown under the avatar. Falls back to the handle, then empty, so it never shows a raw nil.
    private var displayName: String {
        profile?.displayName ?? profile?.username ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        VStack(spacing: Spacing.xxs) {
                            // Tapping the avatar or the name opens the edit screen — the always-on
                            // pencil is gone.
                            NavigationLink {
                                ProfileDetailsView()
                            } label: {
                                AvatarView(url: profile?.avatarURL, name: displayName, size: 112)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, Spacing.xl)
                            .padding(.bottom, Spacing.xs)

                            NavigationLink {
                                ProfileDetailsView()
                            } label: {
                                Text(displayName)
                                    .font(Typography.font(.xl, weight: .strong))
                                    .foregroundStyle(Colors.textPrimary)
                            }
                            .buttonStyle(.plain)

                            // Quiet prose replacing the old stat columns — not tappable.
                            Text(memoriesLine)
                                .font(Typography.font(.sm))
                                .foregroundStyle(Colors.textSecondary)

                            if let originLine {
                                Text(originLine)
                                    .font(Typography.font(.xs))
                                    .foregroundStyle(Colors.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.lg)

                        dropsSection
                    }
                    .padding(.bottom, Spacing.xxxxl)
                }
                .navigationDestination(item: $viewingDrop) { drop in
                    DropDetailView(dropID: drop.id)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Tappable username → account switcher (Instagram-style). The chevron signals it
                // opens something. Sits in the leading slot so iOS 26 renders it as a Liquid Glass
                // pill (like the trailing gear), rather than as plain centered title text.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingAccountSwitcher = true
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Text(profile.map { "@\($0.username)" } ?? "")
                                .font(Typography.font(.body, weight: .semiBold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Colors.textPrimary)
                        .padding(.horizontal, Spacing.xs)
                    }
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .padding(.horizontal, Spacing.xxs)
                    }
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(Colors.textPrimary)
                }
            }
        }
        .sheet(isPresented: $isShowingAccountSwitcher) {
            AccountSwitcherSheet()
        }
        .sheet(isPresented: $isShowingCreateDrop) {
            CreateDropView {
                Task { await loadDrops(); await loadStats() }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadDrops() }
        .task { await loadStats() }
        .task(id: profile?.id) { await observeDrops() }
        // A drop deleted/left from its detail screen — drop it from the grid at once, so returning
        // here after deleting one of your own drops doesn't show a stale card.
        .onChange(of: appState.lastDropRemoval) { _, removal in
            guard let removal else { return }
            drops.removeAll { $0.id == removal.dropID }
            ProfileDropsCache.store(drops)
        }
    }

    /// Quiet one-liner under the name — e.g. "12 memories with 5 friends" — replacing the old stat
    /// columns. Singular-aware so "1 memory with 1 friend" reads naturally.
    private var memoriesLine: String {
        let memories = "\(drops.count) \(drops.count == 1 ? "memory" : "memories")"
        let friends = "\(friendsCount) \(friendsCount == 1 ? "friend" : "friends")"
        return "\(memories) with \(friends)"
    }

    /// "Capturing since July 2026", from the profile's creation date; nil until the profile loads.
    private var originLine: String? {
        guard let createdAt = profile?.createdAt else { return nil }
        return "Capturing since \(Self.monthYearFormatter.string(from: createdAt))"
    }

    /// The user's drops bucketed by month, newest month first. `fetchUserDrops` returns newest-first,
    /// so `MonthSection.group` (which preserves order) already yields the right order — no reverse.
    private var sections: [MonthSection] { MonthSection.group(drops) }

    /// "July 2026" — for the "Capturing since" origin line.
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// The drops list, grouped into month sections (Calendar-tab style) — a month header above a grid
    /// of `MiniDropCard`s. The pin badge still shows per-tile; there's no separate "Pinned" section.
    @ViewBuilder
    private var dropsSection: some View {
        if isLoadingDrops {
            skeletonGrid
        } else if drops.isEmpty {
            emptyState(icon: "camera.viewfinder", title: "No drops yet",
                       subtitle: "Create your first drop to start a memory.",
                       actionTitle: "Create a drop") { isShowingCreateDrop = true }
        } else {
            LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(section.title)
                            .font(Typography.font(.lg, weight: .strong))
                            .foregroundStyle(Colors.textPrimary)
                            .padding(.horizontal, Spacing.lg)

                        grid(section.drops)
                    }
                }
            }
        }
    }

    /// Friendly empty state matching the Friends search's "No users found": an icon over a white
    /// headline and a softer white suggestion line, centered and pushed down from the top.
    private func emptyState(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(title)
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
            Text(subtitle)
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.white.opacity(0.7))
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                CompactPillButton(title: actionTitle, systemImage: icon, action: action)
                    .padding(.top, Spacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxxl)
        .padding(.bottom, Spacing.xxxl)
    }

    private func grid(_ items: [CalendarDrop]) -> some View {
        LazyVGrid(columns: columns, spacing: Spacing.xxs) {
            ForEach(items) { drop in
                NavigationLink {
                    DropDetailView(dropID: drop.id)
                } label: {
                    MiniDropCard(
                        drop: drop,
                        showCreator: false,
                        onTogglePin: { togglePin(drop) },
                        onView: { viewingDrop = drop }
                    )
                }
                .buttonStyle(.plain)
                .onAppear { DropPrefetcher.shared.prefetch(dropID: drop.id) }
            }
        }
    }

    /// Shimmering placeholders in the exact grid the real cards use, so the swap to loaded content
    /// doesn't shift anything.
    private var skeletonGrid: some View {
        LazyVGrid(columns: columns, spacing: Spacing.xxs) {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonBlock(cornerRadius: Radii.md)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
            }
        }
    }

    private func loadDrops() async {
        guard let id = profile?.id else {
            isLoadingDrops = false
            return
        }
        defer { isLoadingDrops = false }
        if let fetched = try? await service.fetchUserDrops(creatorId: id) {
            drops = fetched
            ProfileDropsCache.store(drops)
        }
    }

    private func observeDrops() async {
        guard let id = profile?.id else { return }
        await RealtimeWatch.run(
            topic: "profile-drops-\(id.uuidString)",
            sources: [
                .init("drops", filter: .eq("creator_id", value: id.uuidString)),
            ],
            onEvent: handleRealtimeEvent,
            onChange: { await loadDrops() }
        )
    }

    private func handleRealtimeEvent(_ event: RealtimeWatch.Event) async {
        guard event.table == "drops", let id = event.deletedRecordID else { return }
        appState.markDropRemoved(id)
    }

    private func togglePin(_ drop: CalendarDrop) {
        guard let index = drops.firstIndex(where: { $0.id == drop.id }) else { return }
        let newValue = !drops[index].pinned
        drops[index].isPinned = newValue
        ProfileDropsCache.store(drops)
        Task { try? await service.setPinned(dropID: drop.id, pinned: newValue) }
    }

    private func loadStats() async {
        guard let id = profile?.id else { return }
        if let count = try? await friendsService.friendCount(userID: id) { friendsCount = count }
        if let count = try? await service.invitedDropCount(userID: id) { invitedCount = count }
        ProfileStatsCache.store(friends: friendsCount, invited: invitedCount)
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
