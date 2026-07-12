import SwiftUI

/// A single drop photo, full-screen — its own page, pushed natively (right-slide transition + the
/// system back button in a transparent nav bar). The photo is shown in a `DropCard`-style 3:4
/// rounded container over a solid black backdrop. One photo per page — tapping a different photo
/// opens its own page.
struct PhotoViewerView: View {
    let photos: [PhotoWithUploader]
    let startIndex: Int

    @State private var isShowingReportNotice = false

    /// The photo being viewed — drives the card, the header's uploader + date, and the backdrop.
    private var currentPhoto: PhotoWithUploader { photos[startIndex] }

    /// Relative "1 minute ago" / "3 hours ago" / "1 week ago" style for the upload time.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        ZStack {
            background

            VStack(spacing: Spacing.md) {
                photoCard(currentPhoto)
                placeholder
                Spacer(minLength: 0)
            }
            .padding(.top, Spacing.md)
        }
        // Native header: transparent bar carrying the system back button, tinted for the dark viewer.
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
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
        // Keep the tab bar hidden on this deeper page too (Drop Detail already hides it).
        .hidesTabBarWhenPushed()
        .alert("Coming soon", isPresented: $isShowingReportNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Reporting will be available in a future update.")
        }
    }

    /// Solid black backdrop behind the photo card.
    private var background: some View {
        Color.black.ignoresSafeArea()
    }

    /// A 3:4 rounded card that fills the width and centers vertically — the DropCard thumbnail look.
    private func photoCard(_ photo: PhotoWithUploader) -> some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                CachedImage(url: photo.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Colors.surfaceDeep
                }
            }
            .background(Colors.surfaceDeep)
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
