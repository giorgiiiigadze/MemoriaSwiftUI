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

                            Text(displayName)
                                .font(Typography.font(.xl, weight: .strong))
                                .foregroundStyle(Colors.textPrimary)

                            statsRow
                                .padding(.top, Spacing.xs)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.lg)

                        dropsSection
                    }
                    .padding(.bottom, Spacing.xxxxl)
                }
            }
            .navigationTitle(profile.map { "@\($0.username)" } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .tint(Colors.textPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadDrops() }
        .task { await loadStats() }
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
            dropSection(title: "All drops") {
                Text("No drops yet")
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xxs)
            }
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
                    MiniDropCard(drop: drop, onTogglePin: { togglePin(drop) })
                }
                .buttonStyle(.plain)
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
