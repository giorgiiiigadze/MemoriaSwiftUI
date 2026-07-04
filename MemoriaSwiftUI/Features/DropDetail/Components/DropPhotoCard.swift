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
    /// Whether the viewer may pin this photo (its uploader, or the drop's creator).
    var canPin: Bool = false
    var onTogglePin: () -> Void = {}
    var onTap: () -> Void = {}

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
    }

    private var thumbnail: some View {
        ZStack {
            Colors.surfaceRaised
            CachedImage(url: photo.imageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Colors.surfaceRaised
            }
            .blur(radius: blurred ? 22 : 0)
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
