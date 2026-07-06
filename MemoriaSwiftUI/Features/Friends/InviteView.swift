import Contacts
import SwiftUI

/// Pushed from the Friends tab's invite card. A native invite container: a share-link button up top,
/// then the user's device contacts who aren't on Memoria yet — each with an "Invite" button that
/// opens Messages with a prefilled text. Reuses `ContactsMatchingService` (same matching the
/// Suggested section uses), so "not on Memoria" is exactly the complement of the matched profiles.
struct InviteView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    private enum Phase { case loading, needsPermission, loaded, failed }

    @State private var phase: Phase = .loading
    @State private var contacts: [DeviceContact] = []
    @State private var invitedPhones: Set<String> = []

    private let service = ContactsMatchingService()

    private var userID: UUID? { appState.profile?.id }
    private var inviteText: String { "Join me on Memoria — let's fill a Drop together.\nhttps://memoria.app" }

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    shareLinkButton
                    contactsSection
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxxl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Invite")
                    .font(Typography.font(.xl, weight: .strong))
                    .foregroundStyle(Colors.textPrimary)
            }
        }
        .task { await start() }
    }

    // MARK: Share link

    private var shareLinkButton: some View {
        ShareLink(item: inviteText) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                Text("Share invite link")
                    .font(Typography.font(.body, weight: .semiBold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Colors.ink)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.lg)
            .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Contacts

    @ViewBuilder
    private var contactsSection: some View {
        switch phase {
        case .loading:
            VStack(alignment: .leading, spacing: 0) {
                sectionLabel("From your contacts")
                ForEach(0..<7, id: \.self) { _ in FriendRowSkeleton() }
            }
        case .needsPermission:
            permissionPrompt
        case .failed:
            VStack(spacing: Spacing.md) {
                infoText("Couldn't load your contacts.")
                Button {
                    Task { await loadContacts() }
                } label: {
                    Text("Try again")
                        .font(Typography.font(.body, weight: .semiBold))
                        .foregroundStyle(Colors.ink)
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.xl)
                        .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        case .loaded:
            if contacts.isEmpty {
                infoText("Everyone in your contacts is already on Memoria. 🎉")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    sectionLabel("From your contacts")
                    ForEach(contacts, id: \.normalizedPhone) { contact in
                        contactRow(contact)
                    }
                }
            }
        }
    }

    private func contactRow(_ contact: DeviceContact) -> some View {
        HStack(spacing: Spacing.sm) {
            InitialAvatar(name: contact.name, size: 48)

            VStack(alignment: .leading, spacing: 1) {
                Text(contact.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Colors.white)
                    .lineLimit(1)
                Text(contact.normalizedPhone)
                    .font(Typography.font(.xs))
                    .foregroundStyle(Colors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if invitedPhones.contains(contact.normalizedPhone) {
                FriendChip(label: "Invited", variant: .card)
            } else {
                FriendChip(label: "Invite", variant: .white) { invite(contact) }
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var permissionPrompt: some View {
        VStack(spacing: Spacing.md) {
            Text("Find friends to invite")
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
            Text("Connect your contacts to invite the people not on Memoria yet.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadContacts() }
            } label: {
                Text("Connect Contacts")
                    .font(Typography.font(.body, weight: .semiBold))
                    .foregroundStyle(Colors.ink)
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.xl)
                    .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.font(.sm, weight: .semiBold))
            .foregroundStyle(Colors.white)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
    }

    private func infoText(_ text: String) -> some View {
        Text(text)
            .font(Typography.font(.sm))
            .foregroundStyle(Colors.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
    }

    // MARK: Data

    private func start() async {
        // Only auto-load when access is already granted; otherwise show the connect prompt rather
        // than surprising the user with a permission dialog the moment the screen opens.
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            await loadContacts()
        } else {
            phase = .needsPermission
        }
    }

    private func loadContacts() async {
        // No profile yet → surface the retryable failed state rather than hanging on the skeleton.
        guard let userID else {
            phase = .failed
            return
        }
        phase = .loading
        do {
            let all = try await service.fetchDeviceContacts()
            let (_, notOnMemoria) = try await service.matchProfiles(for: all, excluding: userID)

            // A contact can contribute several phone entries; keep one row per number.
            var seen = Set<String>()
            let unique = notOnMemoria.filter { seen.insert($0.normalizedPhone).inserted }
            contacts = unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            phase = .loaded
        } catch ContactsMatchingError.accessDenied {
            phase = .needsPermission
        } catch {
            phase = .failed
        }
    }

    private func invite(_ contact: DeviceContact) {
        let body = inviteText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "sms:\(contact.normalizedPhone)&body=\(body)") else { return }
        openURL(url)
        invitedPhones.insert(contact.normalizedPhone)
    }
}

#Preview {
    NavigationStack {
        InviteView()
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}
