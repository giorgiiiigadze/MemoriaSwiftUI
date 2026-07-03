import Foundation

/// The relative time label under a drop's identity — "opens in 2 hours", "opened for 3 days".
/// A faithful port of the RN app's `dropTimeLabel` / `duration` helpers so the wording matches
/// exactly across the two clients.
enum DropTime {
    /// `nil` when the drop has no open date yet (the card then shows no second line).
    static func label(state: DropState, date: Date?) -> String? {
        guard let date else { return nil }
        let now = Date()

        switch state {
        case .open, .expired:
            let seconds = Int(now.timeIntervalSince(date))
            return seconds < 60 ? "just opened" : "opened for \(duration(seconds))"
        case .active, .ready:
            let seconds = Int(date.timeIntervalSince(now))
            if seconds <= 0 { return "opens today" }
            return "opens in \(duration(seconds))"
        }
    }

    /// Coarse, single-unit humanized duration ("a minute", "3 hours", "1 week").
    private static func duration(_ seconds: Int) -> String {
        switch seconds {
        case ..<3_600:
            let m = seconds / 60
            return m <= 1 ? "a minute" : "\(m) minutes"
        case ..<86_400:
            let h = seconds / 3_600
            return h == 1 ? "1 hour" : "\(h) hours"
        case ..<604_800:
            let d = seconds / 86_400
            return d == 1 ? "1 day" : "\(d) days"
        case ..<2_592_000:
            let w = seconds / 604_800
            return w == 1 ? "1 week" : "\(w) weeks"
        case ..<31_536_000:
            let mo = seconds / 2_592_000
            return mo == 1 ? "1 month" : "\(mo) months"
        default:
            let y = seconds / 31_536_000
            return y == 1 ? "1 year" : "\(y) years"
        }
    }
}
