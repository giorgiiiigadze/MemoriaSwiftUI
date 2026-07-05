import SwiftUI

/// Modal to invite more friends to an existing drop. Native sheet chrome — a nav bar with an X to
/// cancel and a checkmark to confirm — over the system background. Only friends not already on the
/// drop are listed; confirming inserts an `invited` `drop_participants` row for each selection.
struct InviteFriendsSheet: View {
    let dropID: UUID
    /// The drop's current participant rows, so we can tell who's already active (excluded) from who
    /// previously declined or left (shown, and re-invited via an update rather than a fresh insert).
    let participants: [DropWithParticipants.Participant]
    let inviterID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private let friendsService = FriendsService()
    private let dropsService = DropsService()

    @State private var friends: [Friend] = []
    @State private var friendsLoaded = false
    @State private var selected: Set<UUID> = []
    @State private var isInviting = false
    @State private var errorMessage: String?

    /// Someone who declined their invite or left — still has a row, so re-inviting is an update.
    private static func isRejoinable(_ status: ParticipantStatus) -> Bool {
        status == .declined || status == .removed
    }

    /// Active members (invited/pending/accepted) — excluded, they're already on the drop.
    private var activeIDs: Set<UUID> {
        Set(participants.filter { !Self.isRejoinable($0.status) }.map(\.userId))
    }
    /// Declined/left members — shown so the creator can re-invite them.
    private var rejoinableIDs: Set<UUID> {
        Set(participants.filter { Self.isRejoinable($0.status) }.map(\.userId))
    }

    /// Friends not already active on the drop: brand-new invitees plus anyone who left/declined.
    private var invitable: [Friend] {
        friends.filter { !activeIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Invite Friends")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { confirm() } label: {
                            if isInviting {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark")
                            }
                        }
                        .disabled(selected.isEmpty || isInviting)
                    }
                }
        }
        .task { await loadFriends() }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if !friendsLoaded {
            List {
                ForEach(0..<6, id: \.self) { _ in
                    FriendRowSkeleton()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        } else if friends.isEmpty {
            noFriendsState
        } else if invitable.isEmpty {
            emptyState
        } else {
            List(invitable) { friend in
                Button {
                    toggle(friend.id)
                } label: {
                    FriendRow(profile: friend.profile) {
                        let isSelected = selected.contains(friend.id)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isSelected ? Colors.white : Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }

    /// The app's usual empty-state message (icon over title over dimmed subtitle), sized up and
    /// centred to fill the sheet — a replica of the DropDetail / Friends / Profile empty states.
    private var emptyState: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 40))
                .foregroundStyle(Colors.white)
                .padding(.bottom, Spacing.xxs)
            Text("No one left to invite")
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
            Text("Everyone you're friends with is already on this drop.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.xl)
    }

    /// Shown when the user has no friends yet — the same empty-state layout, but with a "Find
    /// friends" pill (like the Profile's "Create a drop" prompt) that dismisses the sheet and jumps
    /// to the Friends tab where they can search and add people.
    private var noFriendsState: some View {
        VStack(spacing: Spacing.xxs) {
            Text("No friends yet")
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
            Text("Add friends to invite them to this drop.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.white.opacity(0.7))
                .multilineTextAlignment(.center)

            CompactPillButton(title: "Find friends", systemImage: "person.fill.badge.plus") {
                dismiss()
                appState.requestedTab = .friends
            }
            .padding(.top, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.xl)
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func loadFriends() async {
        friends = (try? await friendsService.fetchConnections(userID: inviterID))?.friends ?? []
        friendsLoaded = true
    }

    private func confirm() {
        guard !selected.isEmpty, !isInviting else { return }
        isInviting = true
        Task {
            do {
                // Brand-new friends get a fresh invite row; those who declined/left already have a
                // row, so they're flipped back to `invited` via an update instead.
                let rejoins = Array(selected.intersection(rejoinableIDs))
                let fresh = Array(selected.subtracting(rejoinableIDs))
                try await dropsService.inviteParticipants(
                    dropID: dropID,
                    userIDs: fresh,
                    invitedBy: inviterID
                )
                try await dropsService.reinviteParticipants(dropID: dropID, userIDs: rejoins)
                // The drop detail's realtime watch on `drop_participants` picks up the changes and
                // refreshes the avatar row, so there's nothing to hand back.
                dismiss()
            } catch {
                errorMessage = "Could not send the invites. Please try again."
                isInviting = false
            }
        }
    }
}
