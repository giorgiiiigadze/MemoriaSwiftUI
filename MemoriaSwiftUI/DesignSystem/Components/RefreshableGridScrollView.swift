import SwiftUI

/// A vertically scrolling container with a custom pull-to-refresh whose indicator is the
/// `RefreshGrid`: its tiles fill in as the user drags down, in sync with the pull distance, and
/// loop while the refresh runs. On iOS 18+ the pull distance is read via `onScrollGeometryChange`;
/// on iOS 17 it falls back to the system `.refreshable` spinner.
struct RefreshableGridScrollView<Content: View>: View {
    /// Pull distance (pt) past which releasing triggers a refresh. Mirrors the RN `PULL_THRESHOLD`.
    var triggerDistance: CGFloat = 100
    /// Height held open at the top while the refresh runs, so the grid stays visible after release.
    var indicatorHeight: CGFloat = 64
    let onRefresh: () async -> Void
    @ViewBuilder var content: () -> Content

    /// How far the content is currently pulled down (0 when at rest or scrolled up).
    @State private var pull: CGFloat = 0
    /// Set once a pull crosses `triggerDistance`, so releasing (pull springing back) fires a refresh.
    @State private var primed = false
    @State private var isRefreshing = false

    private var pullProgress: CGFloat { min(max(pull / triggerDistance, 0), 1) }
    // Once past the threshold (`primed`) the grid stays fully shown through the release and refresh
    // — so it doesn't fade back out during the spring-back and then pop to full when the refresh
    // fires. Below the threshold it just tracks the pull.
    private var displayProgress: CGFloat { (isRefreshing || primed) ? 1 : pullProgress }

    var body: some View {
        if #available(iOS 18.0, *) {
            customPull
        } else {
            // iOS 17: no reliable overscroll read, so use the stock refresh control.
            ScrollView { content() }
                .refreshable { await onRefresh() }
        }
    }

    @available(iOS 18.0, *)
    private var customPull: some View {
        ScrollView {
            content()
                // Hold the indicator's space open while refreshing so it stays on screen.
                .padding(.top, isRefreshing ? indicatorHeight : 0)
        }
        // Bounce even when the feed is short, so the pull gesture always works.
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        // Report how far the content is overscrolled below the top (0 at rest / scrolled up).
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            max(0, -(geo.contentOffset.y + geo.contentInsets.top))
        } action: { _, newValue in
            handle(pull: newValue)
        }
        .overlay(alignment: .top) {
            // Fixed-position indicator, like the RN `RefreshGrid` overlay: the grid stays put and
            // only its tiles fade/scale in with `displayProgress`. It never grows or drifts as you
            // pull — the content scrolls down and reveals the stationary grid.
            RefreshGrid(progress: displayProgress)
                .frame(height: indicatorHeight)
                .allowsHitTesting(false)
        }
    }

    private func handle(pull value: CGFloat) {
        guard !isRefreshing else { return }
        let clamped = max(0, value)

        if clamped >= triggerDistance {
            primed = true
        }
        // Once primed, the first frame where the pull starts shrinking is the release. Fire the
        // refresh *now*, near the peak, so the content settles up to the held-open height in one
        // smooth motion — instead of springing back down first and then getting yanked open, which
        // reverses direction and reads as a bounce.
        if primed, clamped < pull {
            startRefresh()
        }
        pull = clamped
        if clamped == 0 { primed = false }
    }

    private func startRefresh() {
        // `primed` stays true here so `displayProgress` holds at 1 (no dip/flash). It's cleared
        // only when the refresh finishes below, which is exactly when we want the grid to fade out.
        // `.smooth` (no overshoot) so the content settles into the held-open position without bounce.
        withAnimation(.smooth(duration: 0.3)) { isRefreshing = true }

        Task {
            let start = Date()
            await onRefresh()
            // Keep the indicator up long enough to read as a refresh, even on a fast network.
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < 0.7 { try? await Task.sleep(for: .seconds(0.7 - elapsed)) }

            // Drop both flags together so the grid fades out once (1 → 0) as the held-open space
            // closes — `.smooth` keeps that settle bounce-free too.
            withAnimation(.smooth(duration: 0.3)) {
                isRefreshing = false
                primed = false
            }
            pull = 0
        }
    }
}
