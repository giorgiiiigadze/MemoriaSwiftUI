import SwiftUI

/// A single drop photo, full-screen — its own page, pushed natively (right-slide transition + the
/// system back button in a transparent nav bar). The photo is shown in a `DropCard`-style 3:4
/// rounded container over a blurred, dimmed version of the same photo. One photo per page —
/// tapping a different photo opens its own page.
struct PhotoViewerView: View {
    let photos: [PhotoWithUploader]
    let startIndex: Int
    /// Shared with `DropDetailView`'s grid so this page zooms out of / back into its source tile.
    let zoomNamespace: Namespace.ID

    @State private var isShowingReportNotice = false
    @Environment(\.dismiss) private var dismiss

    /// The photo being viewed — drives the card, the header's uploader + date, and the backdrop.
    private var currentPhoto: PhotoWithUploader { photos[startIndex] }

    /// Relative "1 minute ago" / "3 hours ago" / "1 week ago" style for the upload time.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .top) {
            background

            VStack(spacing: Spacing.md) {
                photoCard(currentPhoto)
                placeholder
            }
            .padding(.top, Spacing.md)
        }
        // Native header: transparent bar, tinted for the dark viewer. The default back chevron is
        // replaced with a downward chevron that dismisses the page (still runs the zoom transition).
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            // Centered uploader identity (avatar + name + upload date), DropCard-style.
            ToolbarItem(placement: .principal) {
                HStack(spacing: Spacing.xs) {
                    AvatarView(url: currentPhoto.uploader?.avatarURL,
                               name: currentPhoto.uploader?.name ?? "?", size: 32)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(currentPhoto.uploader?.name ?? "Unknown")
                            .font(Typography.font(.sm, weight: .semiBold))
                            .foregroundStyle(Colors.white)
                            .lineLimit(1)
                        Text(Self.relativeFormatter.localizedString(for: currentPhoto.uploadedAt, relativeTo: Date()))
                            .font(Typography.font(.xs))
                            .foregroundStyle(Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
                // Animate as one cohesive unit with the nav transition (avatar + text don't
                // desync/snap as the page slides away).
                .geometryGroup()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let url = currentPhoto.imageURL {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button(role: .destructive) {
                        isShowingReportNotice = true
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                    .tint(Colors.error)
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .tint(Colors.white)
        // Zoom out of / back into the tapped grid tile (Instagram-style) instead of a slide push.
        .zoomNavigationTransition(sourceID: currentPhoto.id, in: zoomNamespace)
        // Keep the tab bar hidden on this deeper page too (Drop Detail already hides it).
        .hidesTabBarWhenPushed()
        .alert("Coming soon", isPresented: $isShowingReportNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Reporting will be available in a future update.")
        }
    }

    /// The current photo, blurred and dimmed almost to black — a BeReal-style ambient backdrop.
    /// Rendered as an overlay on a black base (not a ZStack sibling) so the frameless `scaledToFill`
    /// image can't inflate the page layout and blow out the photo card's width.
    private var background: some View {
        Color.black
            .overlay {
                if let url = currentPhoto.imageURL {
                    CachedImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.black
                    }
                    .blur(radius: 40)
                    .overlay(Colors.ink.opacity(0.6))
                }
            }
            .clipped()
            .ignoresSafeArea()
    }

    /// A 3:4 rounded card that fills the width and centers vertically — the `DropPhotoCard` look.
    /// The image is clipped to the tile before the rounded corners are applied so `scaledToFill`
    /// never spills past the card's bounds.
    private func photoCard(_ photo: PhotoWithUploader) -> some View {
        ZStack {
            Colors.surfaceDeep
            CachedImage(url: photo.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Colors.surfaceDeep
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
        .padding(.horizontal, Spacing.xs)
    }

    /// Fixed height of the placeholder container beneath the photo.
    private let placeholderHeight: CGFloat = 120

    /// Empty rounded container beneath the photo — a placeholder reserved for future content
    /// (caption, reactions, etc.). Fixed height so it never resizes the photo above it.
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
            .fill(Colors.surfaceDeep)
            .frame(maxWidth: .infinity)
            .frame(height: placeholderHeight)
            .padding(.horizontal, Spacing.xs)
    }
}
