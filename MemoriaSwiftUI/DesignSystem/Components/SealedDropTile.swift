import SwiftUI

/// A 3:4 tile for a sealed (not-yet-revealed) drop: the cover photo heavily blurred with a lock
/// icon, or a flat dark surface when there's no cover. An optional countdown label sits below
/// the lock. Used by the Calendar screen's drops section for upcoming sealed drops.
struct SealedDropTile: View {
    let thumbnailURL: String?
    let title: String
    /// Human-readable unlock label — e.g. "Unlocks in 3 days". Nil hides the line.
    var countdownLabel: String?

    var body: some View {
        ZStack {
            if let urlString = thumbnailURL, let url = URL(string: urlString) {
                CachedImage(url: url) { image in
                    image.resizable().scaledToFill()
                        .blur(radius: 20)
                        .clipped()
                } placeholder: {
                    Colors.surfaceRaised
                }
            } else {
                Colors.surfaceRaised
            }

            Colors.ink.opacity(0.4)

            VStack(spacing: Spacing.xxs) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Colors.white.opacity(0.8))

                if let countdownLabel {
                    Text(countdownLabel)
                        .font(Typography.font(.xs, weight: .medium))
                        .foregroundStyle(Colors.white.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Spacing.xs)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
    }
}
