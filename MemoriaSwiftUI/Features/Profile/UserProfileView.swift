import SwiftUI

/// A full profile page for viewing *another* user — pushed onto the navigation stack with the
/// native back button. Mirrors the Profile tab's identity block (large avatar + name), plus the
/// bio, the relationship action (Add / Requested / Accept + Decline / Friends), and the drops the
/// two share as a `MiniDropCard` grid. Fetches its own public profile + friendship, so any screen
/// can push it with just a user id (pass `initial` for an instant header while the rest loads).
struct UserProfileView: View {
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
    @State private var mutualFriends: [DropWithParticipants.ProfileRef] = []
    @State private var actionInProgress = false
    @State private var confirmingRemoveID: UUID?
    @State private var isConfirmingReport = false

    /// 3-up grid for the "Drops together" section, matching the Profile / Calendar drop grids.
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Spacing.xxs),
        count: 3
    )

    /// Shared height for the action button and its loading skeleton, so the two line up exactly.
    private let actionButtonHeight: CGFloat = 44

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
            ZStack {
                Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Profile-tab-style identity block: large centered avatar over the name.
                        VStack(spacing: Spacing.md) {
                            AvatarView(url: avatarURL, name: name, size: 112)
                                .padding(.top, Spacing.xl)

                            Text(name)
                                .font(Typography.font(.xl, weight: .strong))
                                .foregroundStyle(Colors.textPrimary)
                                .multilineTextAlignment(.center)

                            if !username.isEmpty {
                                Text("@\(username)")
                                    .font(Typography.font(.sm))
                                    .foregroundStyle(Colors.textSecondary)
                            }

                            if !mutualFriends.isEmpty {
                                mutualFriendsRow
                            }

                            if let bio = profile?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(Typography.font(.sm))
                                    .foregroundStyle(Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }

                            actionArea
                                .padding(.top, Spacing.xs)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.lg)

                        if relationship == .loading {
                            sharedDropsSkeleton
                        } else if !sharedDrops.isEmpty {
                            sharedDropsSection
                        } else if relationship != .isMe {
                            noSharedDropsState
                        }
                    }
                    .padding(.bottom, Spacing.xxxxl)
                }
            }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        isConfirmingReport = true
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                    .tint(Colors.error)
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .tint(Colors.textPrimary)
        }
        .task { await load() }
        .alert(
            "Remove friend?",
            isPresented: Binding(get: { confirmingRemoveID != nil },
                                 set: { if !$0 { confirmingRemoveID = nil } }),
            presenting: confirmingRemoveID
        ) { id in
            Button("Remove Friend", role: .destructive) { remove(id) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("You'll no longer be friends with \(name).")
        }
        .alert("Report \(name)?", isPresented: $isConfirmingReport) {
            Button("Report", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll review this profile.")
        }
    }

    // MARK: Action

    @ViewBuilder
    private var actionArea: some View {
        switch relationship {
        case .loading:
            // Skeleton placeholder in the action button's slot while the relationship loads.
            SkeletonBlock(cornerRadius: Radii.md)
                .frame(maxWidth: .infinity)
                .frame(height: actionButtonHeight)
        case .isMe:
            EmptyView()
        case .none, .blocked:
            // `.blocked` here is just a previously-declined request — still offer to add them.
            messageButton("Add Friend", systemImage: "person.fill.badge.plus") { add() }
        case .outgoing:
            messageButton("Requested", systemImage: "clock")
        case .incoming(let id):
            VStack(spacing: Spacing.sm) {
                messageButton("Accept Request", systemImage: "checkmark") { accept(id) }
                messageButton("Decline", systemImage: "xmark") { decline(id) }
            }
        case .friends(let id):
            messageButton("Friends", systemImage: "person.2.fill") { confirmingRemoveID = id }
        }
    }

    /// A full-width white action button with ink content — the app's primary action style, a filled
    /// rounded rectangle. Tappable only when an `action` is supplied.
    private func messageButton(
        _ title: String,
        systemImage: String,
        action: (() -> Void)? = nil
    ) -> some View {
        Button { action?() } label: {
            Label(title, systemImage: systemImage)
                .font(Typography.font(.body, weight: .semiBold))
                .foregroundStyle(Colors.ink)
                .frame(maxWidth: .infinity)
                .frame(height: actionButtonHeight)
                .background(
                    Colors.white,
                    in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(action == nil || actionInProgress)
    }

    // MARK: Mutual friends

    /// A few overlapping avatars + an "N mutual friends" label, shown under the handle.
    private var mutualFriendsRow: some View {
        HStack(spacing: Spacing.xs) {
            HStack(spacing: -Spacing.xs) {
                ForEach(Array(mutualFriends.prefix(3))) { friend in
                    AvatarView(url: friend.avatarURL, name: friend.name, size: 22)
                        .overlay(Circle().stroke(Colors.background, lineWidth: 2))
                }
            }
            Text(mutualFriends.count == 1 ? "1 mutual friend" : "\(mutualFriends.count) mutual friends")
                .font(Typography.font(.xs))
                .foregroundStyle(Colors.textSecondary)
        }
    }

    /// Shown in place of the grid when the two share no drops — matching the app's other empty states.
    private var noSharedDropsState: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: "photo.stack")
                .font(.system(size: 30))
                .foregroundStyle(Colors.textTertiary)
                .padding(.bottom, Spacing.xxs)
            Text("No drops together yet")
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
            Text("Drops you're both in will show up here.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxl)
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: Shared drops

    private var sharedDropsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Drops together")
                .font(Typography.font(.lg, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .padding(.horizontal, Spacing.lg)

            LazyVGrid(columns: columns, spacing: Spacing.xxs) {
                ForEach(sharedDrops) { drop in
                    NavigationLink {
                        DropDetailView(dropID: drop.id)
                    } label: {
                        MiniDropCard(drop: drop)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Skeleton grid shown in the "Drops together" slot while the profile loads.
    private var sharedDropsSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Drops together")
                .font(Typography.font(.lg, weight: .strong))
                .foregroundStyle(Colors.textPrimary)
                .padding(.horizontal, Spacing.lg)

            LazyVGrid(columns: columns, spacing: Spacing.xxs) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(cornerRadius: Radii.md)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        async let mutualFetch = friendsService.mutualFriends(with: userID)

        profile = try? await profileFetch
        relationship = Self.relationship(for: (try? await friendshipFetch) ?? nil, me: me)
        sharedDrops = (try? await sharedFetch) ?? []
        mutualFriends = (try? await mutualFetch) ?? []
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
            do {
                try await friendsService.requestFriend(userID)
            } catch {
                // The send failed — reconcile to the real state so the button doesn't lie.
                relationship = Self.relationship(for: (try? await friendsService.friendship(between: me, and: userID)) ?? nil, me: me)
            }
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
