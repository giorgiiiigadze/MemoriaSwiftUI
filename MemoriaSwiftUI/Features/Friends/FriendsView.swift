import Contacts
import SwiftUI
import UIKit

/// The Friends tab (step 8), a native port of the RN `FriendsScreen`: a username search that swaps
/// the page into results mode, plus (when not searching) an invite card, contact-based suggestions,
/// incoming requests, and the friends list. Adding / accepting / declining update optimistically and
/// reconcile against a background refetch.
struct FriendsView: View {
    @Environment(AppState.self) private var appState

    @State private var connections = FriendConnections()
    @State private var isLoaded = false
    @State private var errorMessage: String?

    @State private var query = ""
    @State private var searchResults: [DropWithParticipants.ProfileRef] = []
    @State private var isSearching = false

    @State private var suggested: [SuggestedProfile] = []
    @State private var addedIDs: Set<UUID> = []
    @State private var actionInProgress = false
    /// The friend pending an unfriend confirmation; non-nil drives the confirmation alert.
    @State private var friendToUnfriend: Friend?

    private let service = FriendsService()
    private let contactsService = ContactsMatchingService()

    init() {
        // The native `.searchable` field shows its own inline clear (✕) button *and* the search
        // bar's outer Cancel control — two ✕s. Hide the inline one so only the outer Cancel remains;
        // it both clears the text and dismisses search.
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).clearButtonMode = .never
    }

    private var userID: UUID? { appState.profile?.id }
    private var isSearchMode: Bool { query.trimmingCharacters(in: .whitespaces).count >= 2 }
    private var visibleSuggested: [SuggestedProfile] { suggested.filter { !addedIDs.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xxl) {
                        if isSearchMode {
                            searchSection
                        } else {
                            inviteCard
                            if !isLoaded {
                                loadingSkeleton
                            } else if let errorMessage {
                                errorView(errorMessage)
                            } else {
                                suggestedSection
                                requestsSection
                                friendsSection
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xxxxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search by username…")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Friends")
                        .font(Typography.font(.xl, weight: .strong))
                        .foregroundStyle(Colors.textPrimary)
                }
            }
            .tint(Colors.textPrimary)
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        // Debounced search: re-runs whenever the query changes; the sleep is cancelled if it
        // changes again before firing.
        .task(id: query) { await runSearch() }
        .alert(
            "Remove friend?",
            isPresented: Binding(get: { friendToUnfriend != nil },
                                 set: { if !$0 { friendToUnfriend = nil } }),
            presenting: friendToUnfriend
        ) { friend in
            Button("Unfriend", role: .destructive) { unfriend(friend) }
            Button("Cancel", role: .cancel) {}
        } message: { friend in
            Text("You'll no longer be friends with \(friend.profile.name).")
        }
    }

    // MARK: Search results

    @ViewBuilder
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isSearching {
                ForEach(0..<3, id: \.self) { _ in FriendRowSkeleton() }
            } else if searchResults.isEmpty {
                searchEmptyState
            } else {
                ForEach(searchResults, id: \.id) { profile in
                    FriendRow(profile: profile) { chip(for: profile) }
                }
            }
        }
    }

    /// The trailing control for a search result, based on the current relationship.
    @ViewBuilder
    private func chip(for profile: DropWithParticipants.ProfileRef) -> some View {
        if connections.friends.contains(where: { $0.id == profile.id }) {
            FriendChip(label: "Friends", variant: .card)
        } else if connections.outgoing.contains(where: { $0.profile.id == profile.id }) {
            FriendChip(label: "Pending", variant: .card)
        } else if let request = connections.incoming.first(where: { $0.profile.id == profile.id }) {
            FriendChip(label: "Accept", variant: .green, action: { accept(request) }, disabled: actionInProgress)
        } else {
            FriendChip(label: "Add", variant: .white, action: { add(profile) }, disabled: actionInProgress)
        }
    }

    // MARK: Invite

    private var inviteCard: some View {
        NavigationLink {
            InviteView()
        } label: {
            GlassCard {
                HStack(spacing: Spacing.md) {
                    AvatarView(url: appState.profile?.avatarURL, name: myName, size: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite your friends")
                            .font(Typography.font(.md, weight: .semiBold))
                            .foregroundStyle(Colors.textPrimary)
                        Text("Invite your people. Fill a Drop together.")
                            .font(Typography.font(.sm))
                            .foregroundStyle(Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Colors.white)
                }
                .padding(Spacing.lg)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Suggested (from contacts)

    @ViewBuilder
    private var suggestedSection: some View {
        if !visibleSuggested.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionLabel("Suggested")
                ForEach(visibleSuggested) { item in
                    FriendRow(profile: item.profileRef) {
                        FriendChip(label: "Add", variant: .white,
                                   action: { addSuggested(item) }, disabled: actionInProgress)
                    }
                }
            }
        }
    }

    // MARK: Requests

    @ViewBuilder
    private var requestsSection: some View {
        if !connections.incoming.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionLabel("Requests")
                ForEach(connections.incoming) { request in
                    FriendRow(profile: request.profile) {
                        HStack(spacing: Spacing.xs) {
                            FriendChip(label: "Accept", variant: .green,
                                       action: { accept(request) }, disabled: actionInProgress)
                            FriendChip(label: "Decline", variant: .muted,
                                       action: { decline(request) }, disabled: actionInProgress)
                        }
                    }
                }
            }
        }
    }

    // MARK: Friends list

    @ViewBuilder
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if connections.friends.isEmpty {
                emptyState(icon: "person.2.fill", title: "No friends yet",
                           subtitle: "Search for people to add.")
            } else {
                sectionLabel("Friends")
                ForEach(connections.friends) { friend in
                    FriendRow(profile: friend.profile, since: friend.since) {
                        Button {
                            friendToUnfriend = friend
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Colors.textTertiary)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(actionInProgress)
                    }
                }
            }
        }
    }

    /// Shimmering placeholder rows for the initial page load — same look as the search skeleton
    /// (and the Notifications / Calendar skeletons), so first open reads as loading, not empty.
    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<6, id: \.self) { _ in FriendRowSkeleton() }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Text(message)
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textTertiary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await load() } }
                .font(Typography.font(.sm, weight: .medium))
                .foregroundStyle(Colors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: Building blocks

    /// Section header styled like the Calendar's month titles: large and near-white.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.font(.lg, weight: .semiBold))
            .foregroundStyle(Colors.textPrimary)
            .padding(.bottom, Spacing.xs)
    }

    private var searchEmptyState: some View {
        emptyState(icon: "person.2.fill", title: "No users found",
                   subtitle: "Try a different username.")
    }

    /// Friendly empty state: an icon over a white headline and a softer suggestion line, pushed
    /// down from the top. Shared by the search-no-results and no-friends states.
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Colors.white)
                .padding(.bottom, Spacing.xxs)
            Text(title)
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.white)
            Text(subtitle)
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxxl)
        .padding(.bottom, Spacing.xxxl)
    }

    private var myName: String {
        appState.profile?.displayName ?? appState.profile?.username ?? "?"
    }

    // MARK: Data

    private func load() async {
        // Always clear the skeleton, even if there's no user yet — otherwise an early return here
        // leaves the page stuck on `loadingSkeleton` forever.
        defer { isLoaded = true }
        guard let userID else { return }
        do {
            connections = try await service.fetchConnections(userID: userID)
            errorMessage = nil
            await loadSuggested()
        } catch {
            // Cancellations (fast tab switches / re-runs) aren't real failures — stay silent.
            if connections.friends.isEmpty && !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func runSearch() async {
        guard isSearchMode, let userID else {
            searchResults = []
            return
        }
        // Debounce: wait before hitting the network; a new keystroke cancels this task.
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        searchResults = (try? await service.search(query: query, excluding: userID)) ?? []
    }

    /// Best-effort contact suggestions — only when contacts access is already granted (no prompt
    /// here, matching the RN screen). Filters out anyone already connected.
    private func loadSuggested() async {
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized, let userID else { return }
        do {
            let contacts = try await contactsService.fetchDeviceContacts()
            let (onMemoria, _) = try await contactsService.matchProfiles(for: contacts, excluding: userID)

            let connected = Set(
                connections.friends.map(\.id)
                    + connections.incoming.map(\.profile.id)
                    + connections.outgoing.map(\.profile.id)
            )
            var seen = Set<UUID>()
            var results: [SuggestedProfile] = []
            for match in onMemoria {
                let id = match.profile.id
                guard !connected.contains(id), !seen.contains(id) else { continue }
                seen.insert(id)
                results.append(SuggestedProfile(profile: match.profile, contactName: match.contact.name))
                if results.count >= 3 { break }
            }
            suggested = results
        } catch {
            // Suggestions are best-effort; a failure just leaves the section empty.
        }
    }

    // MARK: Actions

    private func add(_ profile: DropWithParticipants.ProfileRef) {
        sendRequest(to: profile.id) {
            // Optimistically reflect the sent request so the chip flips to "Pending".
            connections.outgoing.append(FriendRequest(friendshipID: UUID(), profile: profile))
        }
    }

    private func addSuggested(_ item: SuggestedProfile) {
        addedIDs.insert(item.id)
        sendRequest(to: item.id) {
            connections.outgoing.append(FriendRequest(friendshipID: UUID(), profile: item.profileRef))
        }
    }

    private func sendRequest(to addresseeID: UUID, onSent: () -> Void) {
        guard let userID, !actionInProgress else { return }
        actionInProgress = true
        onSent()
        Task {
            try? await service.sendRequest(from: userID, to: addresseeID)
            actionInProgress = false
            await load()
        }
    }

    private func accept(_ request: FriendRequest) {
        guard !actionInProgress else { return }
        actionInProgress = true
        // Optimistically move the request into the friends list.
        connections.incoming.removeAll { $0.id == request.id }
        connections.friends.insert(
            Friend(friendshipID: request.friendshipID, profile: request.profile, since: Date()),
            at: 0
        )
        Task {
            try? await service.accept(friendshipID: request.friendshipID)
            actionInProgress = false
            await load()
        }
    }

    private func unfriend(_ friend: Friend) {
        guard !actionInProgress else { return }
        actionInProgress = true
        connections.friends.removeAll { $0.id == friend.id }
        Task {
            try? await service.unfriend(friendshipID: friend.friendshipID)
            actionInProgress = false
            await load()
        }
    }

    private func decline(_ request: FriendRequest) {
        guard !actionInProgress else { return }
        actionInProgress = true
        connections.incoming.removeAll { $0.id == request.id }
        Task {
            try? await service.decline(friendshipID: request.friendshipID)
            actionInProgress = false
            await load()
        }
    }
}

/// A contact-matched profile suggestion, carrying the on-device contact name to show above the handle.
private struct SuggestedProfile: Identifiable {
    let profile: Profile
    let contactName: String
    var id: UUID { profile.id }

    /// Adapts the full `Profile` to the trimmed `ProfileRef` the rows render, preferring the
    /// contact's name so the row reads the way the user knows this person.
    var profileRef: DropWithParticipants.ProfileRef {
        DropWithParticipants.ProfileRef(
            id: profile.id,
            username: profile.username,
            displayName: contactName.isEmpty ? profile.displayName : contactName,
            avatarURL: profile.avatarURL
        )
    }
}

#Preview {
    FriendsView()
        .environment(AppState())
}
