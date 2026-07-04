import SwiftUI

/// The Calendar tab (step 9). Drops grouped into month sections, each rendered as a grid of
/// "mini drop cards" — the drop's thumbnail as the background with the creator's name and the
/// drop's creation date overlaid.
struct CalendarView: View {
    @Environment(AppState.self) private var appState

    @State private var allDrops: [CalendarDrop]
    @State private var isLoading: Bool
    @State private var errorMessage: String?

    private let service = DropsService()

    private var currentUserID: UUID? { appState.profile?.id }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Spacing.xxs),
        count: 3
    )

    /// Seed from the disk cache so a returning user sees their months + cards instantly; only fall
    /// back to the skeleton when there's nothing cached yet (first ever open). The fresh fetch in
    /// `load()` still runs either way.
    init() {
        let cached = CalendarDropsCache.load() ?? []
        _allDrops = State(initialValue: cached)
        _isLoading = State(initialValue: cached.isEmpty)
    }

    /// Drops grouped into month sections, most recent month first.
    private var sections: [MonthSection] {
        Array(MonthSection.group(allDrops).reversed())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Calendar")
                        .font(Typography.font(.xl, weight: .strong))
                        .foregroundStyle(Colors.textPrimary)
                }
            }
            .tint(Colors.textPrimary)
        }
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            CalendarSkeleton(columns: columns)
        } else if let errorMessage {
            Spacer()
            VStack(spacing: Spacing.sm) {
                Text("Couldn't load memories")
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.textPrimary)
                Text(errorMessage)
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl)
            Spacer()
        } else if sections.isEmpty {
            Spacer()
            Text("No memories yet")
                .font(Typography.font(.md, weight: .medium))
                .foregroundStyle(Colors.textSecondary)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(section.title)
                                .font(Typography.font(.lg, weight: .strong))
                                .foregroundStyle(Colors.textPrimary)
                                .padding(.horizontal, Spacing.lg)

                            LazyVGrid(columns: columns, spacing: Spacing.xxs) {
                                ForEach(section.drops) { drop in
                                    MiniDropCard(
                                        drop: drop,
                                        onTogglePin: drop.creatorId == currentUserID ? { togglePin(drop) } : nil
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xxxxl)
            }
        }
    }

    /// Flip a drop's pinned state (creator-only). Updates in place — the badge reflects it; the
    /// month grouping stays chronological.
    private func togglePin(_ drop: CalendarDrop) {
        guard let index = allDrops.firstIndex(where: { $0.id == drop.id }) else { return }
        let newValue = !allDrops[index].pinned
        allDrops[index].isPinned = newValue
        CalendarDropsCache.store(allDrops)
        Task { try? await service.setPinned(dropID: drop.id, pinned: newValue) }
    }

    private func load() async {
        do {
            let drops = try await service.fetchCalendarDrops()
            allDrops = drops
            CalendarDropsCache.store(drops)
            errorMessage = nil
        } catch {
            // Only surface the error when there's nothing cached to show; otherwise keep the
            // stale-but-useful cached content on screen and stay silent.
            if allDrops.isEmpty { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }
}

/// One month's worth of drops, keyed by the first instant of that month so ordering is stable.
private struct MonthSection: Identifiable {
    let id: Date
    let title: String
    let drops: [CalendarDrop]

    /// Buckets an already-sorted (oldest-first) list into month sections, preserving order.
    static func group(_ drops: [CalendarDrop]) -> [MonthSection] {
        let calendar = Calendar.current
        var order: [Date] = []
        var buckets: [Date: [CalendarDrop]] = [:]

        for drop in drops {
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: drop.createdAt)
            ) ?? drop.createdAt
            if buckets[monthStart] == nil { order.append(monthStart) }
            buckets[monthStart, default: []].append(drop)
        }

        return order.map { start in
            MonthSection(id: start, title: Self.formatter.string(from: start), drops: buckets[start] ?? [])
        }
    }

    /// "May, 2026"
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM, yyyy"
        return f
    }()
}

/// First-open placeholder: a couple of month sections' worth of shimmering blocks in the exact
/// grid the real content uses, so the transition to loaded data doesn't shift anything.
private struct CalendarSkeleton: View {
    let columns: [GridItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                ForEach(0..<3, id: \.self) { section in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        // Month title placeholder.
                        SkeletonBlock(cornerRadius: Radii.sm)
                            .frame(width: 130, height: 20)
                            .padding(.horizontal, Spacing.lg)

                        LazyVGrid(columns: columns, spacing: Spacing.xxs) {
                            ForEach(0..<(section == 0 ? 6 : 3), id: \.self) { _ in
                                SkeletonBlock(cornerRadius: Radii.md)
                                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xxxxl)
        }
        .scrollDisabled(true)
        .allowsHitTesting(false)
    }
}

#Preview {
    CalendarView()
        .environment(AppState())
}
