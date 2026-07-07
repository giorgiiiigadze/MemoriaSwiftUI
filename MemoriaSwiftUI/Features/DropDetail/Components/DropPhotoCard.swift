import SwiftUI

/// A single photo tile on the Drop Detail page — styled like `MiniDropCard`: the photo fills a 3:4
/// tile with a bottom scrim carrying the uploader's avatar, name, and the upload date. When
/// `blurred` (someone else's photo while the drop is still collecting) the photo is blurred out —
/// no lock icon — revealing only once the drop opens. Long-press offers Pin/Unpin (uploader or the
/// drop's creator).
struct DropPhotoCard: View {
    let photo: PhotoWithUploader
    /// Blur the photo out (someone else's contribution before the drop opens).
    var blurred: Bool = false
    /// Act 1 of the reveal: frost this tile as part of the uniform "curtain" over the whole grid,
    /// regardless of whose photo it is.
    var revealCurtain: Bool = false
    /// Act 2 of the reveal: this tile starts blurred (even though the drop is open) and animates
    /// clear after its stagger delay.
    var revealing: Bool = false
    /// Stagger offset so tiles cascade rather than clearing all at once.
    var revealDelay: Double = 0
    /// Firmness of this tile's reveal tap (0...1). The parent ramps it up across the grid so the
    /// haptic cascade builds tension rather than staying flat.
    var revealIntensity: Double = 0.7
    /// Whether the viewer may pin this photo (its uploader, or the drop's creator).
    var canPin: Bool = false
    var onTogglePin: () -> Void = {}
    var onTap: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Flips true when this tile's reveal animation runs, dissolving its blur.
    @State private var revealed = false

    private let blurRadius: CGFloat = 22
    private let revealScaleFrom: CGFloat = 1.03
    private let revealDuration: Double = 1.1
    private let reduceMotionDuration: Double = 0.3

    /// Blur while locked, while the curtain is up, or while a pending reveal hasn't dissolved yet.
    private var showBlur: Bool { blurred || revealCurtain || (revealing && !revealed) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            thumbnail

            // Scrim keeps the label legible over any photo.
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    AvatarView(url: photo.uploader?.avatarURL, name: photo.uploader?.name ?? "?", size: 18)
                    Text(photo.uploader?.name ?? "Someone")
                        .font(Typography.font(.xs, weight: .semiBold))
                        .foregroundStyle(Colors.white)
                        .lineLimit(1)
                }
                Text(Self.dateFormatter.string(from: photo.uploadedAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Colors.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(Spacing.xs)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if photo.isPinned && !blurred { pinBadge }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            if canPin && !blurred {
                Button {
                    onTogglePin()
                } label: {
                    Label(photo.isPinned ? "Unpin" : "Pin",
                          systemImage: photo.isPinned ? "pin.slash" : "pin")
                }
            }
        }
        // Kick off the reveal when the tile appears already in reveal mode (drop open on entry),
        // and when it flips into reveal mode live (the drop opens while the user is watching).
        .onAppear { scheduleRevealIfNeeded() }
        .onChange(of: revealing) { _, _ in scheduleRevealIfNeeded() }
        // A sharp tap as this tile clears; ramped in firmness across the staggered grid so the
        // cascade tightens into mounting tension rather than a flat patter.
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: revealIntensity), trigger: revealed)
    }

    /// Starts this tile's un-blur (after its stagger delay), unless there's nothing to reveal.
    /// Under Reduce Motion it skips the delay and just cross-blurs quickly.
    private func scheduleRevealIfNeeded() {
        guard revealing, !blurred, !revealed else { return }
        if reduceMotion {
            withAnimation(.easeInOut(duration: reduceMotionDuration)) { revealed = true }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
                withAnimation(.easeInOut(duration: revealDuration)) { revealed = true }
            }
        }
    }

    private var thumbnail: some View {
        ZStack {
            Colors.surfaceRaised
            CachedImage(url: photo.imageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Colors.surfaceRaised
            }
            .blur(radius: showBlur ? blurRadius : 0)
            // A subtle bloom only during the reveal: the photo eases down from a hair oversized and
            // slightly dim as it sharpens, so it "breathes" open rather than snapping.
            .scaleEffect(showBlur && revealing ? revealScaleFrom : 1)
            .brightness(showBlur && revealing ? -0.05 : 0)
        }
    }

    private var pinBadge: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Colors.white)
            .padding(5)
            .background(.black.opacity(0.45), in: Circle())
            .padding(Spacing.xxs)
    }

    /// "Jun 10, 2026" — matches `MiniDropCard`.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}
