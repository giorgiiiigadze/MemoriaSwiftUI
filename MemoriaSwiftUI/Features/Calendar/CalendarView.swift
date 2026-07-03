import SwiftUI

/// The Calendar tab (step 9). Drops grouped into month sections, each rendered as a grid of
/// "mini drop cards" — the drop's thumbnail as the background with the creator's name and the
/// drop's creation date overlaid.
struct CalendarView: View {
    /// How the month sections are ordered in the feed.
    private enum SortOrder: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case oldest = "Oldest"
        var id: Self { self }
    }

    @State private var allDrops: [CalendarDrop]
    @State private var isLoading: Bool
    @State private var errorMessage: String?
    @State private var sortOrder: SortOrder = .recent

    private let service = DropsService()

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

    /// Drops grouped into month sections, ordered per the header's segmented control.
    private var sections: [MonthSection] {
        let grouped = MonthSection.group(allDrops)
        return sortOrder == .recent ? Array(grouped.reversed()) : grouped
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassSegmentedControl(
                        segments: SortOrder.allCases,
                        title: { $0.rawValue },
                        selection: $sortOrder
                    )
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
                                    MiniDropCard(drop: drop)
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

/// A single memory tile: the drop's thumbnail fills the card, with a bottom scrim carrying the
/// creator's name and the drop's creation date.
private struct MiniDropCard: View {
    let drop: CalendarDrop

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            thumbnail

            // Scrim keeps the two labels legible over any thumbnail.
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(drop.creatorName)
                    .font(Typography.font(.sm, weight: .semiBold))
                    .foregroundStyle(Colors.white)
                    .lineLimit(1)
                Text(Self.dateFormatter.string(from: drop.createdAt))
                    .font(Typography.font(.xs, weight: .medium))
                    .foregroundStyle(Colors.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(Spacing.xs)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlString = drop.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    // Fit (not fill) so the whole photo is visible; the surface backing fills
                    // any letterbox gap for non-3:4 thumbnails.
                    ZStack {
                        placeholderFill
                        image.resizable().scaledToFit()
                    }
                case .empty:
                    ZStack {
                        placeholderFill
                        ProgressView().tint(Colors.textTertiary)
                    }
                case .failure:
                    placeholderContent
                @unknown default:
                    placeholderFill
                }
            }
        } else {
            placeholderContent
        }
    }

    /// Shown when a drop has no thumbnail yet — a neutral surface with the drop's title so the
    /// card still reads as that memory.
    private var placeholderContent: some View {
        ZStack {
            placeholderFill
            Text(drop.title)
                .font(Typography.font(.sm, weight: .medium))
                .foregroundStyle(Colors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(Spacing.xs)
        }
    }

    private var placeholderFill: some View {
        Colors.surfaceRaised
    }

    /// "Jun 10, 2026"
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
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

/// A rounded surface block with a highlight sweeping across it — the shimmer used by the skeleton.
private struct SkeletonBlock: View {
    var cornerRadius: CGFloat = Radii.md

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Colors.surfaceRaised)
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        colors: [.clear, Colors.white.opacity(0.10), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width)
                    // Sweep the highlight from just off the left edge to just off the right.
                    .offset(x: -width + phase * (2 * width))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

#Preview {
    CalendarView()
}
