import SwiftUI
import UIKit

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

    @State private var drop: DropWithParticipants?
    @State private var photos: [PhotoWithUploader] = []
    @State private var photosLoaded = false

    @State private var isUploading = false
    @State private var isAccepting = false
    @State private var isShowingCamera = false
    @State private var viewerIndex: Int?
    @State private var isShowingLockedNote = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    init(dropID: UUID, cachedDrop: DropWithParticipants? = nil) {
        self.dropID = dropID
        _drop = State(initialValue: cachedDrop)
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

    /// Contributions are open while the drop is still collecting (active/ready) — for members only.
    private var canUpload: Bool { isLocked && isAcceptedMember }

    /// An invited (non-member) user is prompted to accept before anything else.
    private var showAcceptBar: Bool { isInvited && !isCreator }
    private var hasBottomBar: Bool { showAcceptBar || canUpload }

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
            // Let the cover run up under the (transparent) nav bar, so it's already behind the
            // header the moment the page appears.
            .ignoresSafeArea(edges: .top)

            if showAcceptBar {
                acceptBar
            } else if canUpload {
                captureButton
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isCreator {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label("Delete Drop", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .tint(Colors.textPrimary)
        .task { await load() }
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
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32))
                .foregroundStyle(Colors.textSecondary)
                .padding(.bottom, Spacing.xxs)
            Text(emptyMessage)
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, Spacing.xl)
    }

    private var emptyMessage: String {
        if isLocked && canUpload { return "Be the first to add a photo using the camera below." }
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
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: Accept invite

    private var acceptBar: some View {
        VStack {
            Spacer()
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
            .disabled(isAccepting)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
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
        if let fetched = try? await dropsService.fetchDrop(id: dropID) { drop = fetched }
        if let fetched = try? await photosService.fetchPhotos(dropID: dropID) { photos = fetched }
        photosLoaded = true
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
                errorMessage = "Could not accept the invitation. Please try again."
            }
            isAccepting = false
        }
    }

    private func upload(_ image: UIImage) async {
        guard let userID else { return }
        isUploading = true
        defer { isUploading = false }
        do {
            try await photosService.uploadPhoto(dropID: dropID, uploaderID: userID, image: image)
            if let fetched = try? await photosService.fetchPhotos(dropID: dropID) { photos = fetched }
        } catch {
            errorMessage = "Could not upload your photo. Please try again."
        }
    }

    private func togglePin(_ photo: PhotoWithUploader) {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        let next = !photos[index].isPinned
        photos[index].isPinned = next
        photos.sort(by: PhotosService.ordering)
        Task { try? await photosService.setPinned(photoID: photo.id, pinned: next) }
    }

    private func deleteDrop() {
        Task {
            do {
                try await dropsService.deleteDrop(id: dropID)
                dismiss()
            } catch {
                errorMessage = "Could not delete the drop."
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
