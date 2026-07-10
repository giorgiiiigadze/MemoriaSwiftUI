import SwiftUI

/// A compact, Memoria-styled card for viewing *another* user: avatar, name, handle, bio, and a
/// single relationship action (Add / Requested / Accept + Decline / Friends). Presented as a
/// medium-detent sheet — a quick "who is this?" peek from a participant, friend row, or search
/// result. Fetches its own public profile + friendship, so any screen can present it with just a
/// user id (pass `initial` for an instant header while the rest loads).
struct UserProfileSheet: View {
    let userID: UUID
    var initial: DropWithParticipants.ProfileRef?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private let profilesService = ProfilesService()
    private let friendsService = FriendsService()
    private let dropsService = DropsService()

    @State private var profile: PublicProfile?
    @State private var relationship: Relationship = .loading
    @State private var sharedDrops: [CalendarDrop] = []
    @State private var actionInProgress = false
    @State private var confirmingRemoveID: UUID?

    /// Width of each mini card in the "Drops together" strip; its 3:4 aspect drives the height.
    private let sharedDropWidth: CGFloat = 104

    /// The current user's standing with this person — drives which action the card offers.
    private enum Relationship: Equatable {
        case loading
        case isMe
        case none
        case outgoing            // I've requested them
        case incoming(UUID)      // they've requested me — friendship id to accept/decline
        case friends(UUID)       // friendship id to remove
        case blocked             // a terminal declined/blocked row — no action
    }

    // Header falls back to the `initial` ref (instant) until the full profile loads.
    private var name: String { profile?.name ?? initial?.name ?? "" }
    private var username: String { profile?.username ?? initial?.username ?? "" }
    private var avatarURL: String? { profile?.avatarURL ?? initial?.avatarURL }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Horizontal identity header: avatar on the left, name over handle on the right.
                HStack(spacing: Spacing.md) {
                    AvatarView(url: avatarURL, name: name, size: 72)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(name)
                            .font(Typography.font(.xl, weight: .strong))
                            .foregroundStyle(Colors.textPrimary)
                            .lineLimit(1)
                        if !username.isEmpty {
                            Text("@\(username)")
                                .font(Typography.font(.sm))
                                .foregroundStyle(Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }

                if let bio = profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Typography.font(.sm))
                        .foregroundStyle(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                actionArea

                if !sharedDrops.isEmpty {
                    sharedDropsSection
                }

                Spacer(minLength: 0)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .tint(Colors.textPrimary)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task { await load() }
        .confirmationDialog(
            "Remove friend?",
            isPresented: Binding(get: { confirmingRemoveID != nil },
                                 set: { if !$0 { confirmingRemoveID = nil } }),
            presenting: confirmingRemoveID
        ) { id in
            Button("Remove Friend", role: .destructive) { remove(id) }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Action

    @ViewBuilder
    private var actionArea: some View {
        switch relationship {
        case .loading:
            ProgressView()
                .tint(Colors.textSecondary)
                .frame(maxWidth: .infinity)
        case .isMe, .blocked:
            EmptyView()
        case .none:
            messageButton("Add Friend", systemImage: "person.fill.badge.plus") { add() }
        case .outgoing:
            messageButton("Requested", systemImage: "clock", prominent: false)
        case .incoming(let id):
            VStack(spacing: Spacing.sm) {
                messageButton("Accept Request", systemImage: "checkmark") { accept(id) }
                messageButton("Decline", systemImage: "xmark", prominent: false) { decline(id) }
            }
        case .friends(let id):
            messageButton("Friends", systemImage: "checkmark", prominent: false) { confirmingRemoveID = id }
        }
    }

    /// A full-width iOS-style "Message" button: a filled, rounded-rectangle control (not a pill) over
    /// a neutral surface. `prominent` labels stay bright (actionable); non-prominent ones read as a
    /// muted status (Requested / Friends). Tappable only when an `action` is supplied.
    private func messageButton(
        _ title: String,
        systemImage: String,
        prominent: Bool = true,
        action: (() -> Void)? = nil
    ) -> some View {
        Button { action?() } label: {
            Label(title, systemImage: systemImage)
                .font(Typography.font(.body, weight: .semiBold))
                .foregroundStyle(prominent ? Colors.white : Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    Colors.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(action == nil || actionInProgress)
    }

    // MARK: Shared drops

    private var sharedDropsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Drops together")
                .font(Typography.font(.sm, weight: .semiBold))
                .foregroundStyle(Colors.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(sharedDrops) { drop in
                        MiniDropCard(drop: drop)
                            .frame(width: sharedDropWidth)
                    }
                }
            }
        }
    }

    // MARK: Data

    private func load() async {
        guard let me = appState.profile?.id else { return }

        // Viewing yourself: just show the header — no friend action, no "shared" drops with yourself.
        if me == userID {
            relationship = .isMe
            profile = try? await profilesService.fetchPublicProfile(id: userID)
            return
        }

        async let profileFetch = profilesService.fetchPublicProfile(id: userID)
        async let friendshipFetch = friendsService.friendship(between: me, and: userID)
        async let sharedFetch = dropsService.sharedDrops(withUserID: userID)

        profile = try? await profileFetch
        relationship = Self.relationship(for: (try? await friendshipFetch) ?? nil, me: me)
        sharedDrops = (try? await sharedFetch) ?? []
    }

    private static func relationship(for friendship: Friendship?, me: UUID) -> Relationship {
        guard let friendship else { return .none }
        switch friendship.status {
        case .accepted: return .friends(friendship.id)
        case .pending: return friendship.requesterId == me ? .outgoing : .incoming(friendship.id)
        case .blocked: return .blocked
        }
    }

    // MARK: Mutations — optimistic; the sheet is short-lived so it doesn't refetch.

    private func add() {
        guard let me = appState.profile?.id, !actionInProgress else { return }
        actionInProgress = true
        relationship = .outgoing
        Task {
            try? await friendsService.sendRequest(from: me, to: userID)
            actionInProgress = false
        }
    }

    private func accept(_ id: UUID) {
        guard !actionInProgress else { return }
        actionInProgress = true
        relationship = .friends(id)
        Task {
            try? await friendsService.accept(friendshipID: id)
            actionInProgress = false
        }
    }

    private func decline(_ id: UUID) {
        guard !actionInProgress else { return }
        actionInProgress = true
        relationship = .blocked
        Task {
            try? await friendsService.decline(friendshipID: id)
            actionInProgress = false
        }
    }

    private func remove(_ id: UUID) {
        guard !actionInProgress else { return }
        actionInProgress = true
        relationship = .none
        Task {
            try? await friendsService.unfriend(friendshipID: id)
            actionInProgress = false
        }
    }
}
