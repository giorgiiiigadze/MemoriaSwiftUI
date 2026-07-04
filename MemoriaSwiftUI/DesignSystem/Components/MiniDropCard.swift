import SwiftUI

/// A single memory tile: the drop's thumbnail fills the card, with a bottom scrim carrying the
/// creator's name and the drop's creation date. Shared across the Calendar month grid and the
/// Profile drops grid — both render `CalendarDrop`s as a compact 3:4 tile.
struct MiniDropCard: View {
    let drop: CalendarDrop
    /// Provided only when the drop is pinnable (the viewer owns it); when nil the context menu
    /// omits the Pin item. Toggles `drop.isPinned` — the parent persists and updates its list.
    var onTogglePin: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            thumbnail

            // Scrim keeps the two labels legible over any thumbnail.
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Tight two-line label block: sizes stepped down and spacing pulled in so it reads as
            // a compact caption on these small tiles. The date drops below the smallest Typography
            // token (12), so it uses a literal 11.
            VStack(alignment: .leading, spacing: 2) {
                Text(drop.creatorName)
                    .font(Typography.font(.xs, weight: .semiBold))
                    .foregroundStyle(Colors.white)
                    .lineLimit(1)
                Text(Self.dateFormatter.string(from: drop.createdAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Colors.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(Spacing.xs)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if drop.pinned { pinBadge }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
        .contextMenu {
            if let onTogglePin {
                Button {
                    onTogglePin()
                } label: {
                    Label(drop.pinned ? "Unpin" : "Pin",
                          systemImage: drop.pinned ? "pin.slash" : "pin")
                }
            }
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var pinBadge: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Colors.white)
            .padding(5)
            .background(.black.opacity(0.45), in: Circle())
            .padding(Spacing.xxs)
    }

    private var shareText: String {
        "Check out \"\(drop.title)\" on Memoria\nhttps://memoria.app/drop/\(drop.id.uuidString.lowercased())"
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
