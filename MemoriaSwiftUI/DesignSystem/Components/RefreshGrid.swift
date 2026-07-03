import SwiftUI

/// A 3×2 grid of small portrait tiles that fill in — fading and scaling up — as `progress` goes
/// 0→1, staggered left-to-right, top-to-bottom. A native port of the RN `RefreshGrid`: the pull
/// indicator whose tiles appear in sync with how far the feed is pulled down.
struct RefreshGrid: View {
    /// 0 = all tiles hidden, 1 = all tiles fully shown. Values in between reveal tiles one by one.
    var progress: CGFloat
    /// Tile width; height derives from the drops' 3:4 portrait aspect so each tile mirrors a card.
    var tileSize: CGFloat = 9
    var color: Color = Colors.white

    private let cols = 3
    private let rows = 2
    private let gap: CGFloat = 2

    private var total: Int { cols * rows }
    private var tileHeight: CGFloat { (tileSize * 4.0 / 3.0).rounded() }

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<cols, id: \.self) { col in
                        tile(index: row * cols + col)
                    }
                }
            }
        }
    }

    private func tile(index: Int) -> some View {
        // Each tile owns a 1/total-wide slice of the overall progress, so they light up in order.
        let tileProgress = min(max(progress * CGFloat(total) - CGFloat(index), 0), 1)
        let t = Self.easeInOut(tileProgress)
        return RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: tileSize, height: tileHeight)
            .opacity(t)
            .scaleEffect(0.85 + 0.15 * t)
    }

    /// Matches the RN worklet's cubic ease-in-out exactly.
    static func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

#Preview {
    VStack(spacing: 24) {
        ForEach([0.0, 0.33, 0.66, 1.0], id: \.self) { p in
            RefreshGrid(progress: p, tileSize: 14)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Colors.background)
}
