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

    private let service = DropsService()

    /// Seed from the disk cache so a returning user sees their feed instantly; only fall back to
    /// the spinner when nothing is cached yet (first ever open). The fresh fetch in `load()` still
    /// runs either way.
    init() {
        let cached = HomeDropsCache.load() ?? []
        _drops = State(initialValue: cached)
        _isLoading = State(initialValue: cached.isEmpty)
    }

    private var currentUserID: UUID? { appState.session?.user.id }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Two buttons in one ToolbarItemGroup → the system renders them as a single
                // native Liquid Glass pill on iOS 26 (BeReal's top control), no custom capsule.
                ToolbarItemGroup(placement: .topBarLeading) {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        Image(systemName: "bell.fill")
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
        .task { await load() }
        .alert("Delete Failed", isPresented: $didDeleteFail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not delete the drop. Please try again.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().tint(Colors.textTertiary)
        } else if drops.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.xxxl) {
                    ForEach(drops) { drop in
                        DropCard(
                            drop: drop,
                            currentUserID: currentUserID,
                            onDelete: { delete(drop) }
                        )
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
}

#Preview {
    HomeView()
        .environment(AppState())
}
