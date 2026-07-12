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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    /// Ties each grid tile to the pushed photo viewer so the viewer zooms out of / back into the
    /// tapped thumbnail (Instagram-style) rather than sliding.
    @Namespace private var photoZoom
    @State private var isShowingLockedNote = false
    @State private var isConfirmingDelete = false
    @State private var isConfirmingDecline = false
    @State private var isConfirmingLeave = false
    @State private var isInvitingFriends = false
    @State private var isShowingQR = false
    @State private var errorMessage: String?

    // The one-time "reveal" moment (first open after the drop opens), staged in two acts:
    //   1. curtain  — the whole grid frosted, a line held over it to build anticipation;
    //   2. revealing — the line clears and the photos melt in, tile-by-tile.
    private enum RevealPhase { case idle, curtain, revealing }
    @State private var revealPhase: RevealPhase = .idle
    @State private var didEvaluateReveal = false
    /// Visibility of the curtain UI (dim scrim + line); toggled with a fade between the acts.
    @State private var showCurtainUI = false
    /// One-shot toggles that fire the arc's bookend haptics: the sharp hit as the curtain lands,
    /// and the resolving success once the whole cascade has landed.
    @State private var startPulse = false
    @State private var revealClimaxed = false

    /// The pause before the first tile clears, then the per-tile stagger — a held breath, then
    /// a cascade. Named (not inline) per the project's no-magic-numbers rule.
    private let revealHoldBeat: Double = 0.35
    private let revealStagger: Double = 0.12
    /// Mirrors `DropPhotoCard.revealDuration` — used only to time the climax haptic to the end of
    /// the cascade.
    private let revealUnblurApprox: Double = 1.1
    /// Act 1 timings: how long the line holds over the frosted grid, the cross-fade between acts,
    /// and the clean beat after the line is gone before the photos start clearing.
    private let curtainHold: Double = 1.3
    private let curtainFade: Double = 0.45
    private let actGap: Double = 0.2

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

    /// The open/reveal date to count down to — only while the drop is still collecting and that date
    /// is still in the future (nil hides the countdown, e.g. once it opens or has no scheduled date).
    private var countdownOpenDate: Date? {
        guard isLocked, let openDate = drop?.openDate, openDate > Date() else { return nil }
        return openDate
    }

    /// The current user's participant row on this drop (nil for the creator or a non-member).
    private var myParticipation: DropWithParticipants.Participant? {
        drop?.participants.first { $0.userId == userID }
    }
    /// Invited but hasn't joined yet — must accept before they can see photos or contribute.
    private var isInvited: Bool { myParticipation?.status == .invited || myParticipation?.status == .pending }
    private var isAcceptedMember: Bool { isCreator || myParticipation?.status == .accepted }
    /// An accepted, non-creator member — the only role that can leave the drop.
    private var canLeave: Bool { !isCreator && myParticipation?.status == .accepted }

    /// Max photos one person may add to a single drop — mirrors the `enforce_photo_limit` DB trigger,
    /// which rejects the insert past this count. Kept in sync so the UI hides the camera at the cap
    /// instead of letting the upload fail at the database.
    private static let photoLimit = 20
    /// How many photos the viewer has already contributed to this drop.
    private var myPhotoCount: Int { photos.filter { $0.uploaderId == userID }.count }
    /// The viewer has hit the per-person photo cap for this drop.
    private var atPhotoLimit: Bool { myPhotoCount >= Self.photoLimit }

    /// Contributions are open while the drop is still collecting (active/ready), for members who
    /// haven't yet hit the per-person photo cap.
    private var canUpload: Bool { isLocked && isAcceptedMember && !atPhotoLimit }

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

    /// True when the grid holds at least one photo that *was* blurred for this viewer (someone
    /// else's contribution) — i.e. there's actually something to reveal. A drop of only your own
    /// photos was never hidden, so it gets no reveal.
    private var hasRevealablePhotos: Bool {
        guard let userID else { return false }
        return photos.contains { $0.uploaderId != userID }
    }

    /// Gap between photo tiles (both columns and rows), tuned to match BeReal's grid — a named
    /// constant rather than a token since it sits between `xxs` (4) and `xs` (8).
    private static let photoGridSpacing: CGFloat = 3
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Self.photoGridSpacing), count: 3)

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
            // Live countdown to the reveal, centered in the header while the drop is still collecting.
            if let openDate = countdownOpenDate {
                ToolbarItem(placement: .principal) {
                    DropCountdownView(openDate: openDate)
                }
            }
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
                    // A QR of the drop's share link, for inviting someone in person by scan.
                    Button {
                        isShowingQR = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
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
        // Decide from cached state first (so a drop that's already open on entry starts the reveal
        // without a network wait), then let the fresh `load()` re-check for the live-open path.
        .task { evaluateReveal(); await load() }
        // Tension arc: a sharp hit as the curtain lands, the cards' rising taps through the
        // cascade, then a resolving success "release" once every photo has landed.
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.75), trigger: startPulse)
        .sensoryFeedback(.success, trigger: revealClimaxed)
        .overlay { if showCurtainUI { revealCurtainOverlay } }
        // Live drop: refetch when another participant uploads a photo, the drop opens/changes, or
        // someone accepts their invite — so the grid and header stay current without reopening.
        .task(id: dropID) { await observeLive() }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraView { image in await upload(image) }
                .ignoresSafeArea()
        }
        // Native right-slide push into the photo viewer page (system back button dismisses it).
        .navigationDestination(item: viewerBinding) { start in
            PhotoViewerView(photos: viewablePhotos, startIndex: start.index, zoomNamespace: photoZoom)
        }
        .alert("Drop is locked", isPresented: $isShowingLockedNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Photos are revealed when this drop opens on its scheduled date.")
        }
        .alert("Delete Drop", isPresented: $isConfirmingDelete) {
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
        // Reload on dismiss so freshly-invited participants show in the avatar row immediately,
        // rather than waiting for the realtime `drop_participants` event.
        .sheet(isPresented: $isInvitingFriends, onDismiss: { Task { await load() } }) {
            if let userID {
                InviteFriendsSheet(
                    dropID: dropID,
                    participants: drop?.participants ?? [],
                    inviterID: userID
                )
            }
        }
        .sheet(isPresented: $isShowingQR) {
            // Encode the custom-scheme deep link so scanning opens the app straight to this drop
            // (and invites the scanner, pending their Accept), rather than the plain web URL used for
            // text shares.
            DropQRSheet(dropTitle: drop?.title ?? "this drop", linkURL: DeepLink.drop(dropID).absoluteString)
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
            LazyVGrid(columns: columns, spacing: Self.photoGridSpacing) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    DropPhotoCard(
                        photo: photo,
                        blurred: isBlurred(photo),
                        // Act 1 frosts the whole grid (even your own photos) so the curtain is
                        // uniform; act 2 melts every tile back in, cascading top-left → bottom-right.
                        revealCurtain: revealPhase == .curtain,
                        revealing: revealPhase == .revealing,
                        revealDelay: revealHoldBeat + Double(index) * revealStagger,
                        revealIntensity: revealTapIntensity(index: index, total: photos.count),
                        canPin: canPin(photo),
                        onTogglePin: { togglePin(photo) },
                        onTap: { selectPhoto(photo) }
                    )
                    // Source anchor for the zoom transition into the photo viewer.
                    .zoomTransitionSource(id: photo.id, in: photoZoom)
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
    }

    /// How many distinct people contributed to this drop — drives the personalized reveal line.
    private var contributorCount: Int { Set(photos.map(\.uploaderId)).count }

    /// The reveal line is personalized and kept casual (no dashes or full stops) so it reads like
    /// a friend talking, not a system message.
    private var revealHeadline: String {
        contributorCount >= 2 ? "\(contributorCount) friends" : "your moment"
    }
    private var revealSubline: String {
        contributorCount >= 2 ? "one moment" : "is finally here"
    }

    /// Act 1: a dim scrim over the frosted grid carrying the personalized line. The scrim deepens
    /// legibility and focus; tapping anywhere skips straight to the photos.
    private var revealCurtainOverlay: some View {
        ZStack {
            Colors.ink.opacity(0.35).ignoresSafeArea()
            // One evenly-weighted block (both lines same size/weight/color) so it reads as a single
            // statement, not a headline + subtitle.
            Text("\(revealHeadline)\n\(revealSubline)")
                .font(Typography.font(.xxxl, weight: .strong))
                .foregroundStyle(Colors.white)
                .multilineTextAlignment(.center)
                .lineSpacing(Spacing.xxs)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                .padding(.horizontal, Spacing.xl)
        }
        .contentShape(Rectangle())
        .onTapGesture { skipCurtain() }
        .transition(.opacity)
    }

    private var skeleton: some View {
        LazyVGrid(columns: columns, spacing: Self.photoGridSpacing) {
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
                            Text("Accept to see and add photos.")
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

                // Decline sits to the right of Accept as a quiet, neutral alternative — declining
                // isn't destructive, so it reads in muted grey on clear glass rather than red.
                // Same large-glass proportions as the header controls.
                Button {
                    isConfirmingDecline = true
                } label: {
                    Group {
                        if isDeclining {
                            ProgressView().tint(Colors.textSecondary)
                        } else {
                            Text("Decline")
                                .font(Typography.font(.body, weight: .semiBold))
                        }
                    }
                }
                .glassChromeButton(
                    .capsule,
                    fallbackShape: Capsule(),
                    fallbackInsets: EdgeInsets(top: 15, leading: 22, bottom: 15, trailing: 22),
                    tint: Colors.textSecondary
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
        // Fetch the drop and its photos concurrently, then assign both in one synchronous block. On
        // an accept-triggered reload the drop's status flips to `accepted` and the photos RLS opens
        // up at the same moment — assigning them together (no `await` between) coalesces into a single
        // SwiftUI update, so the grid never renders as "accepted but empty" (the "No photos yet" /
        // "Be the first" flash) in the gap before the photos land.
        async let dropFetch = dropsService.fetchDrop(id: dropID)
        async let photosFetch = photosService.fetchPhotos(dropID: dropID)
        let fetchedDrop = try? await dropFetch
        let fetchedPhotos = try? await photosFetch

        if let fetchedDrop {
            drop = fetchedDrop
            DropDetailCache.storeDrop(fetchedDrop)
        }
        if let fetchedPhotos {
            photos = fetchedPhotos
            DropDetailCache.storePhotos(fetchedPhotos, for: dropID)
        }
        photosLoaded = true
        // Runs synchronously right after the state above, so SwiftUI coalesces it into one update:
        // the tiles never render clear before flipping into the reveal (no blur-back flash).
        evaluateReveal()
    }

    /// Decides — at most once per view lifetime — whether to play the reveal, and kicks it off.
    /// Fires whether the drop was already open on entry or opens live while the user is watching
    /// (both funnel through `load()`), and only the first time for this member (persisted in
    /// `DropRevealStore`). Marks it seen up front so it can never replay mid-animation.
    private func evaluateReveal() {
        guard !didEvaluateReveal, photosLoaded, isOpen, let userID else { return }
        didEvaluateReveal = true
        guard hasRevealablePhotos, !DropRevealStore.hasRevealed(dropID: dropID, userID: userID) else { return }
        DropRevealStore.markRevealed(dropID: dropID, userID: userID)

        startPulse.toggle() // the sharp hit that opens the arc

        // Reduce Motion skips the theatrical curtain — go straight to a quick, gentle un-blur.
        guard !reduceMotion else {
            revealPhase = .revealing
            scheduleClimax(after: revealHoldBeat)
            return
        }

        // Act 1: frost the whole grid and fade the line in over it.
        revealPhase = .curtain
        withAnimation(.easeIn(duration: curtainFade)) { showCurtainUI = true }
        Task {
            try? await Task.sleep(for: .seconds(curtainHold))
            beginReveal()
        }
    }

    /// Transitions from the held curtain into the photo reveal: fade the line out, a clean beat,
    /// then melt the tiles in and schedule the release haptic. Guarded so a tap-to-skip that
    /// already started the reveal can't run it twice.
    private func beginReveal() {
        guard revealPhase == .curtain else { return }
        withAnimation(.easeOut(duration: curtainFade)) { showCurtainUI = false }
        Task {
            try? await Task.sleep(for: .seconds(curtainFade + actGap))
            revealPhase = .revealing
            scheduleClimax(after: revealHoldBeat + Double(max(photos.count - 1, 0)) * revealStagger + revealUnblurApprox)
        }
    }

    /// Tap-to-skip: jump past the held line straight into the photo reveal.
    private func skipCurtain() { beginReveal() }

    /// Fires the resolving success haptic once the whole cascade has landed.
    private func scheduleClimax(after delay: Double) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            revealClimaxed = true
        }
    }

    /// Ramps each tile's reveal tap firmer as the cascade progresses (0.5 → 1.0), so the haptics
    /// tighten into mounting tension instead of staying flat.
    private func revealTapIntensity(index: Int, total: Int) -> Double {
        guard total > 1 else { return 0.9 }
        return 0.5 + (Double(index) / Double(total - 1)) * 0.5
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
                appState.showToast("Joined \(drop?.title ?? "the drop")", systemImage: "checkmark.circle.fill")
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
                // there's nothing left to show here. Drop it from every list at once.
                appState.markDropRemoved(dropID)
                appState.showToast("Invitation declined")
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
                // They've left — RLS has revoked their access, so drop back out of the drop. Drop it
                // from every list at once.
                appState.markDropRemoved(dropID)
                appState.showToast("Left the drop")
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
                // The DB's `enforce_photo_limit` trigger rejects uploads past the per-person cap;
                // surface that as its own actionable message rather than a generic "try again".
                if "\(error)".localizedCaseInsensitiveContains("photos per participant") {
                    errorMessage = "You've reached the \(Self.photoLimit)-photo limit for this drop."
                } else {
                    errorMessage = "Could not upload your photo. Please try again."
                }
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

    /// The canonical per-drop link, shared verbatim by both the QR code and the share sheet.
    private var dropShareURL: String {
        "https://memoria.app/drop/\(dropID.uuidString.lowercased())"
    }

    private var shareText: String {
        "Check out \"\(drop?.title ?? "this drop")\" on Memoria\n\(dropShareURL)"
    }

    private func deleteDrop() {
        Task {
            do {
                try await dropsService.deleteDrop(id: dropID)
                // Drop it from every list at once (feed / profile / calendar) before dismissing.
                appState.markDropRemoved(dropID)
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

/// Wrapper so a start index can drive `navigationDestination(item:)`.
private struct ViewerStart: Identifiable, Hashable {
    let index: Int
    var id: Int { index }
}

