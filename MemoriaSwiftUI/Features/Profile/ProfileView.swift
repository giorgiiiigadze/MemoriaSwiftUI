import SwiftUI

/// The Profile tab (step 10). TikTok-style: a large circular avatar with the user's name beneath,
/// a native header whose gear button pushes `SettingsView`. Below the identity block, an "All drops"
/// section renders the user's own drops as a grid of `MiniDropCard`s — the same section-header +
/// 3-up grid the Calendar tab uses.
struct ProfileView: View {
    @Environment(AppState.self) private var appState

    @State private var drops: [CalendarDrop]
    @State private var isLoadingDrops: Bool

    private let service = DropsService()

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
    }

    /// The "All drops" header (Calendar section style) above the user's drops grid.
    private var dropsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("All drops")
                .font(Typography.font(.lg, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .padding(.horizontal, Spacing.lg)

            dropsContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var dropsContent: some View {
        if isLoadingDrops {
            // Shimmering placeholders in the exact grid the real cards use, so the swap to loaded
            // content doesn't shift anything.
            LazyVGrid(columns: columns, spacing: Spacing.xxs) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonBlock(cornerRadius: Radii.md)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                }
            }
        } else if drops.isEmpty {
            Text("No drops yet")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xxs)
        } else {
            LazyVGrid(columns: columns, spacing: Spacing.xxs) {
                ForEach(drops) { drop in
                    MiniDropCard(drop: drop)
                }
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
            ProfileDropsCache.store(fetched)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
