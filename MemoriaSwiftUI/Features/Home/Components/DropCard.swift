import SwiftUI

/// A single Home-feed drop, rebuilt natively from the RN `DropCard`: a creator-identity header
/// (avatar, name, relative open-time) with an options menu, above the drop's 3:4 thumbnail with
/// participant avatars overlaid along the bottom.
struct DropCard: View {
    let drop: DropWithParticipants
    /// When `true` the header leads with the creator's name; otherwise it leads with the drop title.
    var showCreator: Bool = true
    /// The signed-in user's id, so the menu only offers "Delete" on the user's own drops.
    var currentUserID: UUID?
    /// Invoked after the user confirms deletion. The parent owns the feed list and the network
    /// delete so it can optimistically remove the row and roll back on failure.
    var onDelete: () -> Void = {}
    /// Invoked when the creator toggles the pin. The parent updates the feed + persists.
    var onTogglePin: () -> Void = {}

    @State private var isConfirmingDelete = false
    @State private var isShowingReportNotice = false

    private let avatarSize: CGFloat = 34
    /// Header inset (RN `SIDE`); the photo itself stays full-bleed.
    private let side: CGFloat = 10
    /// Square tap target around the ellipsis menu (Apple's 44pt minimum).
    private let menuHitTarget: CGFloat = 44
    /// Size of the picture glyph shown when a drop has no thumbnail.
    private let placeholderGlyphSize: CGFloat = 32

    private var creatorName: String? { showCreator ? drop.creator?.name : nil }
    private var primary: String { creatorName ?? drop.title }
    private var showAvatar: Bool { drop.creator?.avatarURL != nil || creatorName != nil }
    private var isCreator: Bool { currentUserID != nil && currentUserID == drop.creator?.id }
    private var dateLabel: String? { DropTime.label(state: drop.state, date: drop.openDate) }

    private var shareText: String {
        "Check out \"\(drop.title)\" on Memoria\nhttps://memoria.app/drop/\(drop.id.uuidString.lowercased())"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            header
            photo
        }
        // These presentation modifiers live on the card's root, not on the `Menu`: attached to a
        // `Menu` (inside the recycled feed `LazyVStack`) they silently fail to present, so the
        // Report/Delete actions would toggle their state but nothing would appear.
        .confirmationDialog(
            "Delete Drop",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(drop.title)\" will be permanently deleted for everyone.")
        }
        .alert("Coming soon", isPresented: $isShowingReportNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Reporting will be available in a future update.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            if showAvatar {
                AvatarView(url: drop.creator?.avatarURL, name: creatorName ?? "?", size: avatarSize)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(primary)
                    .font(Typography.font(.sm, weight: .medium))
                    .foregroundStyle(Colors.white)
                    .lineLimit(1)
                if let dateLabel {
                    Text(dateLabel)
                        .font(Typography.font(.sm))
                        .foregroundStyle(Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            menu
        }
        .padding(.horizontal, side)
    }

    private var menu: some View {
        Menu {
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            if isCreator {
                Button {
                    onTogglePin()
                } label: {
                    Label(drop.pinned ? "Unpin" : "Pin",
                          systemImage: drop.pinned ? "pin.slash" : "pin")
                }
            }
            Button {
                isShowingReportNotice = true
            } label: {
                Label("Report", systemImage: "exclamationmark.bubble")
            }
            if isCreator {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                // Force red so the trash icon is red too (the app-wide `.tint` otherwise colors it).
                .tint(Color.red)
            }
        } label: {
            // A 44×44 hit target with the ellipsis centred, matching the RN menu host.
            Image(systemName: "ellipsis")
                .font(Typography.font(.lg, weight: .semiBold))
                .foregroundStyle(Colors.white)
                .frame(width: menuHitTarget, height: menuHitTarget)
                .contentShape(Rectangle())
        }
    }

    // MARK: Photo

    private var photo: some View {
        // `Color.clear` fixes the 3:4 box so layout is driven by the frame, not the image. The
        // thumbnail fills that box via an overlay (so `scaledToFill` can't push the layout or
        // overflow), and the outer `clipShape` crops the fill to the rounded card.
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { thumbnail }
            .overlay(alignment: .bottomLeading) {
                if !drop.participants.isEmpty {
                    ParticipantAvatars(participants: drop.participants)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg)
                }
            }
            .overlay(alignment: .topTrailing) {
                if drop.pinned { pinBadge }
            }
            .background(Colors.surfaceDeep)
            .clipShape(RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
    }

    /// Same look as `MiniDropCard`'s pin badge — a white pin in a translucent dark circle — sized
    /// up a touch for this larger card.
    private var pinBadge: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Colors.white)
            .padding(7)
            .background(.black.opacity(0.45), in: Circle())
            .padding(Spacing.sm)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlString = drop.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    // `cover` fit: fill the 3:4 frame and let the surrounding `clipShape` crop.
                    image.resizable().scaledToFill()
                case .empty:
                    ZStack {
                        Colors.surfaceDeep
                        ProgressView().tint(Colors.textTertiary)
                    }
                case .failure:
                    placeholder
                @unknown default:
                    Colors.surfaceDeep
                }
            }
        } else {
            placeholder
        }
    }

    /// Shown when a drop has no thumbnail yet — a neutral surface with a picture glyph.
    private var placeholder: some View {
        ZStack {
            Colors.surfaceDeep
            Image(systemName: "photo")
                .font(.system(size: placeholderGlyphSize))
                .foregroundStyle(Colors.borderDefault)
        }
    }
}
