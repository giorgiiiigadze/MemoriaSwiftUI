import SwiftUI

/// A compact live countdown to a drop's open (reveal) time, ticking every second — overlaid on the
/// Drop Detail cover next to the creator info while the drop is still collecting, so the wait builds
/// anticipation for the reveal. Uses `TimelineView` so it self-updates without an owned timer; white
/// with a soft shadow to stay legible over the cover photo.
struct DropCountdownView: View {
    let openDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = openDate.timeIntervalSince(context.date)
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                Text(Self.format(remaining))
                    .monospacedDigit()
            }
            .font(Typography.font(.sm, weight: .semiBold))
            .foregroundStyle(Colors.white)
            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
        }
    }

    /// Coarsest useful precision: days show d/h/m, otherwise step down to seconds so the last hour
    /// visibly ticks.
    static func format(_ remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m \(seconds)s" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}
