import SwiftUI

/// The Calendar tab (step 9). Drops grouped into month sections, each rendered as a grid of
/// "mini drop cards" — the drop's thumbnail as the background with the creator's name and the
/// drop's creation date overlaid.
struct CalendarView: View {
    @State private var allDrops: [CalendarDrop] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let service = DropsService()

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Spacing.xxs),
        count: 3
    )

    /// Drops grouped into month sections.
    private var sections: [MonthSection] {
        MonthSection.group(allDrops)
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
            Spacer()
            ProgressView().tint(Colors.textSecondary)
            Spacer()
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
        isLoading = true
        errorMessage = nil
        do {
            allDrops = try await service.fetchCalendarDrops()
        } catch {
            errorMessage = error.localizedDescription
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

#Preview {
    CalendarView()
}
