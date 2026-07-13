import Foundation

/// One month's worth of drops, keyed by the first instant of that month so ordering is stable.
/// Shared by the Calendar tab and the Profile tab, which both bucket `CalendarDrop`s into month
/// sections and render each as a titled grid.
struct MonthSection: Identifiable {
    let id: Date
    let title: String
    let drops: [CalendarDrop]

    /// Buckets a list into month sections, preserving the input order both across and within months.
    /// Callers control chronology by the order they pass drops in (and may `.reversed()` the result):
    /// the Calendar feeds an oldest-first list and reverses; the Profile feeds a newest-first list and
    /// uses the result as-is (newest month first, newest-first within each month).
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
