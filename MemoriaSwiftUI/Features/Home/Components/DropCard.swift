import SwiftUI

/// A single Home-feed drop, rebuilt natively from the RN `DropCard`: a creator-identity header
/// (avatar, name, relative open-time) with an options menu, above the drop's 3:4 thumbnail with
/// participant avatars overlaid along the bottom.
struct DropCard: View {
    let drop: DropWithParticipants
    /// When `true` the header lead line appends the creator after the drop name ("Name · Creator");
    /// otherwise it shows the drop name alone.
    var showCreator: Bool = true
    /// The signed-in user's id, so the menu only offers "Delete" on the user's own drops.
    var currentUserID: UUID?
    /// Invoked after the user confirms deletion. The parent owns the feed list and the network
    /// delete so it can optimistically remove the row and roll back on failure.
    var onDelete: () -> Void = {}
    /// Invoked when the creator toggles the pin. The parent updates the feed + persists.
    var onTogglePin: () -> Void = {}
    /// Invoked when the viewer taps "Upload" on the still-collecting prompt. The parent owns the
    /// camera + upload so the flow is shared with the drop detail page.
    var onUpload: () -> Void = {}
    /// Invoked when the viewer taps the creator's avatar/name in the header — opens their profile.
    var onTapCreator: () -> Void = {}

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
    /// Header lead line: the drop's name, then the creator when shown — e.g. "Beach Day · Alex".
    private var primary: String {
        if let creatorName { return "\(drop.title) · \(creatorName)" }
        return drop.title
    }
    private var showAvatar: Bool { drop.creator?.avatarURL != nil || creatorName != nil }
    private var isCreator: Bool { currentUserID != nil && currentUserID == drop.creator?.id }
    private var dateLabel: String? { DropTime.label(state: drop.state, date: drop.openDate) }

    /// The viewer's participant row on this drop, if they're on it.
    private var myParticipation: DropWithParticipants.Participant? {
        drop.participants.first { $0.userId == currentUserID }
    }
    /// Show the "add yours" prompt while the drop is still collecting (active/ready) to an accepted
    /// member who hasn't uploaded yet — the BeReal-style nudge to contribute before it opens.
    private var showUploadPrompt: Bool {
        guard drop.state == .active || drop.state == .ready else { return false }
        guard let me = myParticipation else { return false }
        return me.status == .accepted && !me.hasUploaded
    }

    private var shareText: String {
        "Check out \"\(drop.title)\" on Memoria\nhttps://memoria.app/drop/\(drop.id.uuidString.lowercased())"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            header
            NavigationLink {
                DropDetailView(dropID: drop.id, cachedDrop: drop)
            } label: {
                photo
            }
            .buttonStyle(.plain)
            // Layered outside the NavigationLink label (a button inside a link's label misbehaves):
            // the scrim + text stay non-interactive so tapping the card still opens the drop, while
            // the pill intercepts its own taps to launch the upload.
            .overlay { if showUploadPrompt { uploadPromptOverlay } }
        }
        // These presentation modifiers live on the card's root, not on the `Menu`: attached to a
        // `Menu` (inside the recycled feed `LazyVStack`) they silently fail to present, so the
        // Report/Delete actions would toggle their state but nothing would appear.
        .alert("Delete Drop", isPresented: $isConfirmingDelete) {
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
            // The creator identity cluster opens their profile; the menu keeps its own taps.
            Button {
                onTapCreator()
            } label: {
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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

    /// BeReal-style prompt over a still-collecting drop's cover: a short nudge and the shared white
    /// pill to upload. Only the pill takes taps — the scrim and text stay non-interactive so tapping
    /// elsewhere still opens the drop.
    private var uploadPromptOverlay: some View {
        ZStack {
            Colors.ink.opacity(0.55)
                .allowsHitTesting(false)
            VStack(spacing: Spacing.xs) {
                Text("You haven't added a photo")
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.white)
                    .allowsHitTesting(false)
                Text("Drop yours before this one opens")
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .allowsHitTesting(false)
                CompactPillButton(title: "Upload", systemImage: "camera.fill") { onUpload() }
                    .padding(.top, Spacing.xs)
            }
            .padding(Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radii.lg, style: .continuous))
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
            CachedImage(url: url) { image in
                // `cover` fit: fill the 3:4 frame and let the surrounding `clipShape` crop.
                image.resizable().scaledToFill()
            } placeholder: {
                // Cached photos render instantly; a real miss shows the neutral surface briefly.
                Colors.surfaceDeep
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

/// Shimmering placeholder matching `DropCard`'s layout — a header (avatar + two text lines) above
/// the 3:4 photo block — so the Home feed has real shape while the first load lands, instead of a
/// bare spinner. Reuses the shared `SkeletonBlock` shimmer so it stays in phase with the rest.
struct DropCardSkeleton: View {
    private let avatarSize: CGFloat = 34
    private let side: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                SkeletonBlock(cornerRadius: avatarSize / 2)
                    .frame(width: avatarSize, height: avatarSize)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SkeletonBlock(cornerRadius: Radii.sm)
                        .frame(width: 150, height: 13)
                    SkeletonBlock(cornerRadius: Radii.sm)
                        .frame(width: 90, height: 11)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, side)

            SkeletonBlock(cornerRadius: Radii.lg)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
        .allowsHitTesting(false)
    }
}
