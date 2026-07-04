import SwiftUI

/// A rounded surface block with a highlight sweeping across it — the shimmer used by loading
/// skeletons (the Calendar grid, the Notifications list, the Friends rows, etc.).
///
/// The sweep is derived from a shared wall-clock via `TimelineView`, so every `SkeletonBlock`
/// on screen is always in phase regardless of when it appeared — no per-block animation drift.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = Radii.md

    /// Seconds for one full left-to-right sweep.
    private let period: TimeInterval = 1.2

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Colors.surfaceRaised)
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width
                    TimelineView(.animation) { context in
                        // 0→1 ramp off the global clock — identical for every block this frame.
                        let phase = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: period) / period
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
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
