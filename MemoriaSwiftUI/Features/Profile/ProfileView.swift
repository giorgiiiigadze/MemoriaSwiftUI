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
                        VStack(spacing: Spacing.md) {
                            AvatarView(url: profile?.avatarURL, name: displayName, size: 112)
                                .padding(.top, Spacing.xl)

                            HStack(spacing: Spacing.xs) {
                                Text(displayName)
                                    .font(Typography.font(.xl, weight: .strong))
                                    .foregroundStyle(Colors.textPrimary)

                                // White pencil button → the profile edit screen.
                                NavigationLink {
                                    ProfileDetailsView()
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Colors.white)
                                        .frame(width: 28, height: 28)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            statsRow
                                .padding(.top, Spacing.xs)
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
        // A drop deleted/left from its detail screen — drop it from the grid at once, so returning
        // here after deleting one of your own drops doesn't show a stale card.
        .onChange(of: appState.lastDropRemoval) { _, removal in
            guard let removal else { return }
            drops.removeAll { $0.id == removal.dropID }
            ProfileDropsCache.store(drops)
        }
    }

    /// TikTok-style stat row: three number-over-label columns, evenly spaced, centered under the name.
    private var statsRow: some View {
        HStack(spacing: 0) {
            ProfileStat(value: drops.count, label: "Drops")
            ProfileStat(value: friendsCount, label: "Friends")
            ProfileStat(value: invitedCount, label: "Invited")
        }
        .frame(maxWidth: 300)
    }

    private var pinnedDrops: [CalendarDrop] { drops.filter(\.pinned) }
    private var unpinnedDrops: [CalendarDrop] { drops.filter { !$0.pinned } }

    /// A "Pinned" section (when any are pinned) above the "All drops" grid.
    @ViewBuilder
    private var dropsSection: some View {
        if isLoadingDrops {
            dropSection(title: "All drops") { skeletonGrid }
        } else if drops.isEmpty {
            emptyState(icon: "camera.viewfinder", title: "No drops yet",
                       subtitle: "Create your first drop to start a memory.",
                       actionTitle: "Create a drop") { isShowingCreateDrop = true }
        } else {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if !pinnedDrops.isEmpty {
                    dropSection(title: "Pinned") { grid(pinnedDrops) }
                }
                if !unpinnedDrops.isEmpty {
                    dropSection(title: "All drops") { grid(unpinnedDrops) }
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

    /// A titled section (Calendar section-header style) wrapping some drops content.
    private func dropSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.font(.lg, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .padding(.horizontal, Spacing.lg)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// One TikTok-style stat: a bold count over a small muted label, filling its share of the row.
private struct ProfileStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(Typography.font(.lg, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
            Text(label)
                .font(Typography.font(.xs))
                .foregroundStyle(Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
