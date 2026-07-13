import Supabase
import SwiftUI

/// The Calendar tab: a month grid showing the user's drops as tiny thumbnails (revealed) or
/// locked tiles (sealed), with a filterable drops section below. Data comes from the Home feed's
/// `DropWithParticipants` cache — no new fetches. Month changes are pure client-side filtering.
struct CalendarView: View {
    @Environment(AppState.self) private var appState

    @State private var allDrops: [DropWithParticipants]
    @State private var isLoading: Bool
    @State private var displayedMonth: Date
    @State private var selectedDay: DateComponents?
    @State private var viewingDrop: DropWithParticipants?
    @State private var isShowingCreateDrop = false
    @State private var isShowingMonthPicker = false
    @State private var pickerDate: Date = Date()
    @State private var dragOffset: CGFloat = 0

    private let service = DropsService()

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: Spacing.xxs),
        count: 3
    )

    init() {
        let cached = HomeDropsCache.load() ?? []
        _allDrops = State(initialValue: cached)
        _isLoading = State(initialValue: cached.isEmpty)
        _displayedMonth = State(initialValue: Self.startOfMonth(Date()))
    }

    private var currentUserID: UUID? { appState.profile?.id }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(Colors.textTertiary)
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.xl) {
                            monthGrid
                                .gesture(swipeGesture)

                            dropsSection
                        }
                        .padding(.bottom, Spacing.xxxxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        pickerDate = displayedMonth
                        isShowingMonthPicker = true
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Text(Self.monthYearFormatter.string(from: displayedMonth))
                                .font(Typography.font(.lg, weight: .strong))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Colors.textPrimary)
                    }
                }
            }
            .tint(Colors.textPrimary)
        }
        .preferredColorScheme(.dark)
        .task(id: currentUserID) { await observeDrops() }
        .onChange(of: appState.lastDropRemoval) { _, removal in
            guard let removal else { return }
            allDrops.removeAll { $0.id == removal.dropID }
        }
        .sheet(isPresented: $isShowingCreateDrop) {
            CreateDropView {
                Task { await load() }
            }
        }
        .sheet(isPresented: $isShowingMonthPicker) {
            MonthPickerSheet(selection: $pickerDate) {
                displayedMonth = Self.startOfMonth(pickerDate)
                selectedDay = Calendar.current.dateComponents([.year, .month, .day], from: pickerDate)
                isShowingMonthPicker = false
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Colors.surfaceGrouped)
        }
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        let cells = gridCells(for: displayedMonth)

        return VStack(spacing: Spacing.xxs) {
            weekdayHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xxs), count: 7), spacing: Spacing.xxs) {
                ForEach(cells) { cell in
                    dayCellView(cell)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private static let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xxs), count: 7), spacing: Spacing.xxs) {
            ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(Typography.font(.xs, weight: .medium))
                    .foregroundStyle(Colors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCellView(_ cell: DayCell) -> some View {
        let isSelected = selectedDay == cell.components && cell.kind != .spill

        Button {
            handleDayTap(cell)
        } label: {
            ZStack {
                switch cell.kind {
                case .spill:
                    RoundedRectangle(cornerRadius: Radii.sm, style: .continuous)
                        .fill(Colors.surfaceDeep.opacity(0.3))
                        .overlay {
                            Text("\(cell.day)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Colors.textTertiary.opacity(0.3))
                        }

                case .empty:
                    RoundedRectangle(cornerRadius: Radii.sm, style: .continuous)
                        .fill(Color.clear)
                        .overlay {
                            Text("\(cell.day)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Colors.textTertiary)
                        }

                case .today:
                    RoundedRectangle(cornerRadius: Radii.sm, style: .continuous)
                        .fill(Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radii.sm, style: .continuous)
                                .strokeBorder(Colors.accent, lineWidth: 2)
                        }
                        .overlay {
                            dayContent(cell)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if cell.drops.count > 1 {
                                countBadge(cell.drops.count)
                            }
                        }

                case .revealed:
                    if let first = cell.drops.first,
                       let urlString = first.thumbnailURL,
                       let url = URL(string: urlString) {
                        CachedImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Colors.surfaceRaised
                        }
                        .overlay {
                            dayNumberOverlay(cell)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if cell.drops.count > 1 {
                                countBadge(cell.drops.count)
                            }
                        }
                    } else {
                        Colors.surfaceRaised
                            .overlay {
                                dayNumberOverlay(cell)
                            }
                    }

                case .sealed:
                    if let first = cell.drops.first,
                       let urlString = first.thumbnailURL,
                       let url = URL(string: urlString) {
                        CachedImage(url: url) { image in
                            image.resizable().scaledToFill()
                                .blur(radius: 8)
                                .clipped()
                        } placeholder: {
                            Colors.surfaceRaised
                        }
                        .overlay { Colors.ink.opacity(0.4) }
                        .overlay {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Colors.white.opacity(0.7))
                        }
                    } else {
                        Colors.surfaceDeep
                            .overlay {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Colors.white.opacity(0.5))
                            }
                    }
                    if cell.drops.count > 1 {
                        Color.clear
                            .overlay(alignment: .bottomTrailing) {
                                countBadge(cell.drops.count)
                            }
                    }
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Radii.sm, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radii.sm, style: .continuous)
                        .strokeBorder(Colors.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(cell.kind == .spill)
    }

    @ViewBuilder
    private func dayContent(_ cell: DayCell) -> some View {
        if cell.drops.isEmpty {
            Text("\(cell.day)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Colors.accent)
        } else {
            let first = cell.drops.first!
            let isRevealed = first.state == .open || first.state == .expired
            if isRevealed, let urlString = first.thumbnailURL, let url = URL(string: urlString) {
                CachedImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Colors.surfaceRaised
                }
                .overlay { dayNumberOverlay(cell) }
            } else if !isRevealed {
                Colors.surfaceDeep
                    .overlay {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Colors.white.opacity(0.5))
                    }
            } else {
                Text("\(cell.day)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Colors.accent)
            }
        }
    }

    private func dayNumberOverlay(_ cell: DayCell) -> some View {
        VStack {
            HStack {
                Spacer()
                Text("\(cell.day)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Colors.white)
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    .padding(2)
            }
            Spacer()
        }
    }

    private func countBadge(_ count: Int) -> some View {
        Text("+\(count - 1)")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(Colors.ink)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Colors.white, in: Capsule())
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .padding(2)
    }

    // MARK: - Drops section

    @ViewBuilder
    private var dropsSection: some View {
        let drops = sectionDrops
        let title = sectionTitle

        if !drops.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.font(.lg, weight: .strong))
                    .foregroundStyle(Colors.textPrimary)
                    .padding(.horizontal, Spacing.lg)

                LazyVGrid(columns: gridColumns, spacing: Spacing.xxs) {
                    ForEach(drops) { drop in
                        let isRevealed = drop.state == .open || drop.state == .expired
                        NavigationLink {
                            DropDetailView(dropID: drop.id, cachedDrop: drop)
                        } label: {
                            if isRevealed {
                                revealedTile(drop)
                            } else {
                                sealedTile(drop)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            emptyState
        }
    }

    private func revealedTile(_ drop: DropWithParticipants) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let urlString = drop.thumbnailURL, let url = URL(string: urlString) {
                CachedImage(url: url) { image in
                    ZStack {
                        Colors.surfaceRaised
                        image.resizable().scaledToFit()
                    }
                } placeholder: {
                    Colors.surfaceRaised
                }
            } else {
                ZStack {
                    Colors.surfaceRaised
                    Text(drop.title)
                        .font(Typography.font(.sm, weight: .medium))
                        .foregroundStyle(Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(Spacing.xs)
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(drop.creatorName ?? drop.title)
                    .font(Typography.font(.xs, weight: .semiBold))
                    .foregroundStyle(Colors.white)
                    .lineLimit(1)
                Text(Self.tileDateFormatter.string(from: drop.createdAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Colors.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(Spacing.xs)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
    }

    private func sealedTile(_ drop: DropWithParticipants) -> some View {
        SealedDropTile(
            thumbnailURL: drop.thumbnailURL,
            title: drop.title,
            countdownLabel: unlockLabel(for: drop)
        )
    }

    private var sectionTitle: String {
        if let selectedDay,
           let date = Calendar.current.date(from: selectedDay) {
            return Self.dayTitleFormatter.string(from: date)
        }

        let upcoming = comingUpDrops
        if !upcoming.isEmpty {
            return "Coming up"
        }
        return Self.monthNameFormatter.string(from: displayedMonth)
    }

    private var sectionDrops: [DropWithParticipants] {
        if let selectedDay {
            return dropsForDay(selectedDay)
        }

        let upcoming = comingUpDrops
        if !upcoming.isEmpty {
            return upcoming
        }
        return revealedDropsForMonth(displayedMonth)
    }

    /// Sealed drops the user participates in, sorted by nearest backstop.
    private var comingUpDrops: [DropWithParticipants] {
        return allDrops
            .filter { drop in
                let isSealed = drop.state == .active || drop.state == .ready
                guard isSealed else { return false }
                guard let uid = currentUserID else { return false }
                return drop.creatorId == uid || drop.participants.contains { $0.userId == uid && $0.status == .accepted }
            }
            .sorted { a, b in
                (a.openDate ?? .distantFuture) < (b.openDate ?? .distantFuture)
            }
    }

    private func revealedDropsForMonth(_ month: Date) -> [DropWithParticipants] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: month)
        return allDrops.filter { drop in
            let isRevealed = drop.state == .open || drop.state == .expired
            guard isRevealed else { return false }
            let dc = calendar.dateComponents([.year, .month], from: drop.createdAt)
            return dc.year == comps.year && dc.month == comps.month
        }
    }

    private func dropsForDay(_ day: DateComponents) -> [DropWithParticipants] {
        let calendar = Calendar.current
        return allDrops.filter { drop in
            let date = dateForDrop(drop)
            let dc = calendar.dateComponents([.year, .month, .day], from: date)
            return dc.year == day.year && dc.month == day.month && dc.day == day.day
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        let message: String = {
            if let selectedDay, let date = Calendar.current.date(from: selectedDay) {
                return "No drops on \(Self.dayTitleFormatter.string(from: date))"
            }
            return "No drops yet"
        }()

        return VStack(spacing: Spacing.xxs) {
            Text(message)
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
            Text("Start a drop and fill this day with a memory.")
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

    // MARK: - Swipe gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 60
                if value.translation.width < -threshold {
                    changeMonth(by: 1)
                } else if value.translation.width > threshold {
                    changeMonth(by: -1)
                }
                dragOffset = 0
            }
    }

    // MARK: - Helpers

    private func changeMonth(by delta: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = newMonth
            selectedDay = nil
        }
    }

    private func handleDayTap(_ cell: DayCell) {
        guard cell.kind != .spill else { return }

        if selectedDay == cell.components {
            selectedDay = nil
        } else {
            selectedDay = cell.components
        }
    }

    private func dateForDrop(_ drop: DropWithParticipants) -> Date {
        let isSealed = drop.state == .active || drop.state == .ready
        if isSealed, let openDate = drop.openDate {
            return openDate
        }
        return drop.createdAt
    }

    private func unlockLabel(for drop: DropWithParticipants) -> String {
        guard let openDate = drop.openDate else {
            return "Unlocks when everyone posts"
        }
        let seconds = Int(openDate.timeIntervalSince(Date()))
        if seconds <= 0 { return "Unlocking soon" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        if days > 0 { return "Unlocks in \(days == 1 ? "1 day" : "\(days) days")" }
        if hours > 0 { return "Unlocks in \(hours == 1 ? "1 hour" : "\(hours) hours")" }
        let minutes = seconds / 60
        return "Unlocks in \(max(1, minutes)) min"
    }

    // MARK: - Grid cell model

    private struct DayCell: Identifiable {
        let id: String
        let day: Int
        let kind: Kind
        let components: DateComponents
        let drops: [DropWithParticipants]

        enum Kind {
            case spill, empty, today, revealed, sealed
        }
    }

    private func gridCells(for month: Date) -> [DayCell] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: comps) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let mondayOffset = (firstWeekday + 5) % 7

        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        var cells: [DayCell] = []

        let dropsIndex = buildDropsIndex(for: month)

        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: month),
           let prevRange = calendar.range(of: .day, in: .month, for: prevMonth) {
            let prevComps = calendar.dateComponents([.year, .month], from: prevMonth)
            for i in 0..<mondayOffset {
                let day = prevRange.upperBound - mondayOffset + i
                cells.append(DayCell(
                    id: "prev-\(day)",
                    day: day,
                    kind: .spill,
                    components: DateComponents(year: prevComps.year, month: prevComps.month, day: day),
                    drops: []
                ))
            }
        }

        for day in range {
            let dc = DateComponents(year: comps.year, month: comps.month, day: day)
            let dayDrops = dropsIndex[day] ?? []
            let isToday = dc.year == today.year && dc.month == today.month && dc.day == today.day

            let kind: DayCell.Kind
            if isToday {
                kind = .today
            } else if dayDrops.isEmpty {
                kind = .empty
            } else {
                let hasRevealed = dayDrops.contains { $0.state == .open || $0.state == .expired }
                kind = hasRevealed ? .revealed : .sealed
            }

            cells.append(DayCell(id: "day-\(day)", day: day, kind: kind, components: dc, drops: dayDrops))
        }

        let remaining = (7 - cells.count % 7) % 7
        if remaining > 0, let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) {
            let nextComps = calendar.dateComponents([.year, .month], from: nextMonth)
            for day in 1...remaining {
                cells.append(DayCell(
                    id: "next-\(day)",
                    day: day,
                    kind: .spill,
                    components: DateComponents(year: nextComps.year, month: nextComps.month, day: day),
                    drops: []
                ))
            }
        }

        return cells
    }

    private func buildDropsIndex(for month: Date) -> [Int: [DropWithParticipants]] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: month)
        var index: [Int: [DropWithParticipants]] = [:]

        for drop in allDrops {
            let date = dateForDrop(drop)
            let dc = calendar.dateComponents([.year, .month, .day], from: date)
            guard dc.year == comps.year && dc.month == comps.month, let day = dc.day else { continue }
            index[day, default: []].append(drop)
        }

        return index
    }

    private func observeDrops() async {
        guard let currentUserID else { return }
        await RealtimeWatch.run(
            topic: "calendar-\(currentUserID.uuidString)",
            sources: [
                .init("drops"),
                .init("drop_participants", filter: .eq("user_id", value: currentUserID.uuidString)),
            ],
            onChange: { await load() }
        )
    }

    private func load() async {
        do {
            let drops = try await service.fetchDrops()
            allDrops = drops
            HomeDropsCache.store(drops)
        } catch {
            if allDrops.isEmpty && !error.isCancellation {
                // Silently keep cached data on screen.
            }
        }
        isLoading = false
    }

    // MARK: - Formatters

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    private static let dayTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f
    }()

    private static let tileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct MonthPickerSheet: View {
    @Binding var selection: Date
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            DatePicker(
                "Month",
                selection: $selection,
                displayedComponents: [.date]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()

            Button {
                onConfirm()
            } label: {
                Text("Go to month")
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.top, Spacing.lg)
    }
}

#Preview {
    CalendarView()
        .environment(AppState())
}
