import SwiftUI
import Supabase
import UIKit
import TipKit

/// The Drop Detail page (native port of the RN `DropDetailScreen`): a full-bleed cover with a glass
/// back button and (for the creator) an options menu, the drop's info, and its photos grouped by
/// uploader. While the drop is still collecting, photos are blurred and tapping shows a "locked"
/// note; once it opens they reveal and tapping opens a full-screen viewer. A camera button uploads
/// while the drop is open for contributions.
struct DropDetailView: View {
    let dropID: UUID

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let dropsService = DropsService()
    private let photosService = PhotosService()
    private let inviteTip = InviteFriendsTip()

    @State private var drop: DropWithParticipants?
    @State private var photos: [PhotoWithUploader]
    @State private var photosLoaded: Bool

    @State private var isUploading = false
    @State private var isAccepting = false
    @State private var isDeclining = false
    @State private var isLeaving = false
    @State private var isShowingCamera = false
    @State private var viewerIndex: Int?
    @State private var isShowingLockedNote = false
    @State private var isConfirmingDelete = false
    @State private var isConfirmingDecline = false
    @State private var isConfirmingLeave = false
    @State private var isInvitingFriends = false
    @State private var errorMessage: String?

    init(dropID: UUID, cachedDrop: DropWithParticipants? = nil) {
        self.dropID = dropID
        // Seed from whatever's available so the page paints instantly: a passed-in drop (from the
        // Home feed) or the last-seen disk copy of the header and photos. The fresh fetch in
        // `load()` still runs and overwrites these; the cache only bridges the gap before it lands.
        _drop = State(initialValue: cachedDrop ?? DropDetailCache.loadDrop(dropID))
        let cachedPhotos = DropDetailCache.loadPhotos(dropID)
        _photos = State(initialValue: cachedPhotos ?? [])
        _photosLoaded = State(initialValue: cachedPhotos != nil)
    }

    private var userID: UUID? { appState.profile?.id }
    private var isCreator: Bool { userID != nil && drop?.creatorId == userID }
    private var isLocked: Bool { drop?.state == .active || drop?.state == .ready }
    private var isOpen: Bool { drop?.state == .open || drop?.state == .expired }

    /// The current user's participant row on this drop (nil for the creator or a non-member).
    private var myParticipation: DropWithParticipants.Participant? {
        drop?.participants.first { $0.userId == userID }
    }
    /// Invited but hasn't joined yet — must accept before they can see photos or contribute.
    private var isInvited: Bool { myParticipation?.status == .invited || myParticipation?.status == .pending }
    private var isAcceptedMember: Bool { isCreator || myParticipation?.status == .accepted }
    /// An accepted, non-creator member — the only role that can leave the drop.
    private var canLeave: Bool { !isCreator && myParticipation?.status == .accepted }

    /// Contributions are open while the drop is still collecting (active/ready) — for members only.
    private var canUpload: Bool { isLocked && isAcceptedMember }

    /// An invited (non-member) user is prompted to accept before anything else.
    private var showAcceptBar: Bool { isInvited && !isCreator }
    private var hasBottomBar: Bool { showAcceptBar || canUpload }

    /// The empty drop is showing its "Be the first" prompt: an uploader is looking at a drop with no
    /// photos yet. The prompt carries its own inline "Upload first" button, so the floating camera
    /// control is suppressed in this one case.
    private var showsUploadPrompt: Bool { canUpload && photosLoaded && photos.isEmpty }

    /// Blur a photo out while the drop is still collecting — everyone's but your own. Your own
    /// uploads always show; others' reveal only once the drop opens.
    private func isBlurred(_ photo: PhotoWithUploader) -> Bool {
        isLocked && photo.uploaderId != userID
    }

    /// The photos the viewer may actually see full-screen — all when open, just your own while locked.
    private var viewablePhotos: [PhotoWithUploader] { photos.filter { !isBlurred($0) } }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xxs), count: 3)

    var body: some View {
        ZStack(alignment: .top) {
            Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    hero
                    photosContent
                }
                .padding(.bottom, hasBottomBar ? 120 : Spacing.xxxxl)
            }
            .scrollIndicators(.hidden)
            // Let the cover run up under the (transparent) nav bar, so it's already behind the
            // header the moment the page appears.
            .ignoresSafeArea(edges: .top)

            if showAcceptBar {
                acceptBar
            } else if canUpload && photosLoaded && !showsUploadPrompt {
                // Only once photos have loaded: while the skeleton grid shows we don't yet know
                // whether the drop is empty (→ inline prompt) or has photos (→ this button).
                captureButton
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hidesTabBarWhenPushed()
        .toolbar {
            // Invite + menu share one group so iOS 26 fuses them into a single Liquid Glass pill,
            // matching Home's bell/share control. Invite sits left of the ellipsis.
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Creator only: the `drop_participants` INSERT policy lets a member insert a row
                // only for themselves, so inviting others (rows with someone else's user_id) is
                // allowed just for the drop's creator.
                if isCreator {
                    Button {
                        inviteTip.invalidate(reason: .actionPerformed)
                        isInvitingFriends = true
                    } label: {
                        Image(systemName: "person.fill.badge.plus")
                    }
                    .popoverTip(inviteTip)
                }
                Menu {
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    if isCreator {
                        Button {
                            togglePin()
                        } label: {
                            Label(drop?.pinned == true ? "Unpin" : "Pin",
                                  systemImage: drop?.pinned == true ? "pin.slash" : "pin")
                        }
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label("Delete Drop", systemImage: "trash")
                        }
                        .tint(Colors.error)
                    }
                    if canLeave {
                        Button(role: .destructive) {
                            isConfirmingLeave = true
                        } label: {
                            Label("Leave Drop", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .tint(Colors.error)
                        .disabled(isLeaving)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .tint(Colors.textPrimary)
        .task { await load() }
        // Live drop: refetch when another participant uploads a photo, the drop opens/changes, or
        // someone accepts their invite — so the grid and header stay current without reopening.
        .task(id: dropID) { await observeLive() }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { image in Task { await upload(image) } }
                .ignoresSafeArea()
        }
        .fullScreenCover(item: viewerBinding) { start in
            PhotoViewer(photos: viewablePhotos, startIndex: start.index)
        }
        .alert("Drop is locked", isPresented: $isShowingLockedNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Photos are revealed when this drop opens on its scheduled date.")
        }
        .confirmationDialog("Delete Drop", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteDrop() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the drop and all its photos for everyone.")
        }
        .alert("Decline Invitation", isPresented: $isConfirmingDecline) {
            Button("Decline", role: .destructive) { decline() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This drop will disappear from your feed. The host can invite you again later.")
        }
        .alert("Leave Drop", isPresented: $isConfirmingLeave) {
            Button("Leave", role: .destructive) { leave() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll stop seeing this drop and its photos. The host can invite you again later.")
        }
        .sheet(isPresented: $isInvitingFriends) {
            if let userID {
                InviteFriendsSheet(
                    dropID: dropID,
                    participants: drop?.participants ?? [],
                    inviterID: userID
                )
            }
        }
        .alert("Something went wrong", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Hero + header

    private var hero: some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                CachedImage(url: URL(string: drop?.thumbnailURL ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Colors.surfaceDeep
                }
            }
            // Drop details overlaid inside the cover itself, over a bottom scrim.
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(drop?.title ?? " ")
                        .font(Typography.font(.sm, weight: .medium))
                        .foregroundStyle(Colors.white)

                    HStack(spacing: Spacing.xs) {
                        if let creator = drop?.creator {
                            AvatarView(url: creator.avatarURL, name: creator.name, size: 22)
                            Text(creator.name)
                                .font(Typography.font(.sm, weight: .medium))
                                .foregroundStyle(Colors.white)
                        }
                        if let created = drop?.createdAt {
                            Text("· \(Self.dateFormatter.string(from: created))")
                                .font(Typography.font(.sm))
                                .foregroundStyle(Colors.white.opacity(0.7))
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .clipped()
    }

    // MARK: Photos

    @ViewBuilder
    private var photosContent: some View {
        if !photosLoaded {
            skeleton
        } else if photos.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: Spacing.xxs) {
                ForEach(photos) { photo in
                    DropPhotoCard(
                        photo: photo,
                        blurred: isBlurred(photo),
                        canPin: canPin(photo),
                        onTogglePin: { togglePin(photo) },
                        onTap: { selectPhoto(photo) }
                    )
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
    }

    private var skeleton: some View {
        LazyVGrid(columns: columns, spacing: Spacing.xxs) {
            ForEach(0..<9, id: \.self) { _ in
                SkeletonBlock(cornerRadius: Radii.md)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xxs) {
            // In the upload-first case the inline "Upload first" button below carries the camera
            // affordance, so the decorative icon would be redundant; other empty states keep it.
            if !showsUploadPrompt {
                Image(systemName: emptyIcon)
                    .font(.system(size: 26))
                    .foregroundStyle(Colors.white)
                    .padding(.bottom, Spacing.xxs)
            }
            Text(emptyTitle)
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
            Text(emptySubtitle)
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.white.opacity(0.7))
                .multilineTextAlignment(.center)

            if showsUploadPrompt {
                CompactPillButton(title: "Upload first", systemImage: "camera.fill", isLoading: isUploading) {
                    isShowingCamera = true
                }
                .padding(.top, Spacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxxl)
        .padding(.horizontal, Spacing.xl)
    }

    /// An envelope for the not-yet-accepted invitee; the photo glyph for everyone else.
    private var emptyIcon: String {
        isInvited ? "envelope.open" : "photo.on.rectangle.angled"
    }

    private var emptyTitle: String {
        if isInvited { return "You're invited" }
        if isLocked && canUpload { return "Be the first" }
        if isLocked { return "No photos yet" }
        return "Nothing was shared"
    }

    private var emptySubtitle: String {
        if isInvited { return "Accept the invitation to see and add photos." }
        if isLocked && canUpload { return "Add the first photo to this drop." }
        if isLocked { return "Participants haven't uploaded anything yet." }
        return "No photos were uploaded before this drop closed."
    }

    // MARK: Capture

    private var captureButton: some View {
        VStack {
            Spacer()
            Button {
                isShowingCamera = true
            } label: {
                ZStack {
                    Circle().fill(Colors.white).frame(width: 62, height: 62)
                    if isUploading {
                        ProgressView().tint(Colors.ink)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Colors.ink)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isUploading)
            .padding(.bottom, Spacing.xxxl)
        }
        // Anchor to the true bottom edge (past the reserved-but-hidden tab bar space) so it sits
        // like a native bottom action, just above the home indicator — matching the accept bar.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: Accept invite

    private var acceptBar: some View {
        VStack {
            Spacer()
            HStack(spacing: Spacing.md) {
                Button {
                    accept()
                } label: {
                    Group {
                        if isAccepting {
                            ProgressView().tint(Colors.ink)
                        } else {
                            Text("Accept Invitation")
                                .font(Typography.font(.body, weight: .semiBold))
                        }
                    }
                    .foregroundStyle(Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Colors.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isAccepting || isDeclining)

                // Decline sits to the right of Accept as its destructive counterpart: a native
                // Liquid Glass circle (iOS 26) tinted the system red, so the xmark reads red on
                // clear glass. Same large-glass proportions as the header controls.
                Button {
                    isConfirmingDecline = true
                } label: {
                    Group {
                        if isDeclining {
                            ProgressView().tint(Colors.error)
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                }
                .glassChromeButton(
                    .circle,
                    fallbackShape: Circle(),
                    fallbackInsets: EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15),
                    tint: Colors.error
                )
                .disabled(isAccepting || isDeclining)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
        // Anchor to the true bottom edge (past the reserved-but-hidden tab bar space) so it sits
        // like a native bottom action, just above the home indicator.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: Actions

    private func canPin(_ photo: PhotoWithUploader) -> Bool {
        photo.uploaderId == userID || isCreator
    }

    private func selectPhoto(_ photo: PhotoWithUploader) {
        guard !isBlurred(photo) else {
            isShowingLockedNote = true
            return
        }
        viewerIndex = viewablePhotos.firstIndex { $0.id == photo.id } ?? 0
    }

    private func load() async {
        if let fetched = try? await dropsService.fetchDrop(id: dropID) {
            drop = fetched
            DropDetailCache.storeDrop(fetched)
        }
        if let fetched = try? await photosService.fetchPhotos(dropID: dropID) {
            photos = fetched
            DropDetailCache.storePhotos(fetched, for: dropID)
        }
        photosLoaded = true
    }

    /// Subscribes to this drop's photos, its own row, and its participant rows; any change refetches
    /// the drop + grid. So another member's upload lands live, the grid reveals the moment the drop
    /// opens, and the header updates as people accept. Torn down when the view goes away.
    private func observeLive() async {
        await RealtimeWatch.run(
            topic: "drop-detail-\(dropID.uuidString)",
            sources: [
                .init("photos", filter: .eq("drop_id", value: dropID.uuidString)),
                .init("drops", filter: .eq("id", value: dropID.uuidString)),
                .init("drop_participants", filter: .eq("drop_id", value: dropID.uuidString)),
            ],
            onChange: { await load() }
        )
    }

    private func accept() {
        guard let userID else { return }
        isAccepting = true
        Task {
            do {
                try await dropsService.acceptInvite(dropID: dropID, userID: userID)
                // Reload: the drop's participant status flips to accepted and the photos RLS now
                // returns the whole grid.
                await load()
            } catch {
                // Cancellations (view torn down mid-action) aren't real failures — stay silent.
                if !error.isCancellation {
                    errorMessage = "Could not accept the invitation. Please try again."
                }
            }
            isAccepting = false
        }
    }

    private func decline() {
        guard let userID else { return }
        isDeclining = true
        Task {
            do {
                try await dropsService.declineInvite(dropID: dropID, userID: userID)
                // They've opted out — leave the drop. RLS has already revoked their access, so
                // there's nothing left to show here.
                dismiss()
            } catch {
                if !error.isCancellation {
                    errorMessage = "Could not decline the invitation. Please try again."
                }
                isDeclining = false
            }
        }
    }

    private func leave() {
        guard let userID, !isLeaving else { return }
        isLeaving = true
        Task {
            do {
                try await dropsService.leaveDrop(dropID: dropID, userID: userID)
                // They've left — RLS has revoked their access, so drop back out of the drop.
                dismiss()
            } catch {
                if !error.isCancellation {
                    errorMessage = "Could not leave the drop. Please try again."
                }
                isLeaving = false
            }
        }
    }

    private func upload(_ image: UIImage) async {
        guard let userID else { return }
        isUploading = true
        defer { isUploading = false }
        do {
            try await photosService.uploadPhoto(dropID: dropID, uploaderID: userID, image: image)
            if let fetched = try? await photosService.fetchPhotos(dropID: dropID) {
                photos = fetched
                DropDetailCache.storePhotos(fetched, for: dropID)
            }
        } catch {
            if !error.isCancellation {
                errorMessage = "Could not upload your photo. Please try again."
            }
        }
    }

    private func togglePin(_ photo: PhotoWithUploader) {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        let next = !photos[index].isPinned
        photos[index].isPinned = next
        photos.sort(by: PhotosService.ordering)
        Task { try? await photosService.setPinned(photoID: photo.id, pinned: next) }
    }

    /// Pin or unpin the whole drop (creator only). Flips it locally, then persists.
    private func togglePin() {
        guard drop != nil else { return }
        let next = !(drop?.pinned ?? false)
        drop?.isPinned = next
        Task { try? await dropsService.setPinned(dropID: dropID, pinned: next) }
    }

    private var shareText: String {
        "Check out \"\(drop?.title ?? "this drop")\" on Memoria\nhttps://memoria.app/drop/\(dropID.uuidString.lowercased())"
    }

    private func deleteDrop() {
        Task {
            do {
                try await dropsService.deleteDrop(id: dropID)
                dismiss()
            } catch {
                if !error.isCancellation {
                    errorMessage = "Could not delete the drop."
                }
            }
        }
    }

    // MARK: Bindings

    private var viewerBinding: Binding<ViewerStart?> {
        Binding(
            get: { viewerIndex.map(ViewerStart.init) },
            set: { viewerIndex = $0?.index }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

/// Identifiable wrapper so a start index can drive a `fullScreenCover(item:)`.
private struct ViewerStart: Identifiable {
    let index: Int
    var id: Int { index }
}

/// A full-screen, swipeable viewer of a drop's photos (opened once the drop is open).
private struct PhotoViewer: View {
    let photos: [PhotoWithUploader]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(photos: [PhotoWithUploader], startIndex: Int) {
        self.photos = photos
        self.startIndex = startIndex
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                    CachedImage(url: photo.imageURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().tint(Colors.white)
                    }
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Colors.white)
                    .padding(12)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(Spacing.lg)
        }
    }
}
