import SwiftUI

struct ContactsStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    @Environment(\.openURL) private var openURL
    let onContinue: () -> Void

    private enum LoadState {
        case idle
        case loading
        case denied
        case error(String)
        case loaded(onMemoria: [MatchedContact], notOnMemoria: [DeviceContact])
    }

    @State private var loadState: LoadState = .idle
    @State private var sentRequestIDs: Set<UUID> = []

    private let contactsService = ContactsMatchingService()
    private let friendsService = FriendsService()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Find friends on Memoria")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
                .padding(.top, Spacing.xxl)

            Text("Connect your contacts to find friends already here and invite the rest.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)

            content

            Spacer(minLength: Spacing.lg)

            ProfileSetupContinueButton(action: onContinue)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .idle:
            Button {
                connect()
            } label: {
                Text("Connect Contacts")
                    .font(Typography.font(.body, weight: .semiBold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .foregroundStyle(Colors.ink)
            .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))

        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)

        case .denied:
            Text("Contacts access was denied. You can enable it later in Settings.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)

        case .error(let message):
            Text(message)
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.error)

        case .loaded(let onMemoria, let notOnMemoria):
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if !onMemoria.isEmpty {
                        section(title: "On Memoria") {
                            ForEach(onMemoria) { match in
                                contactRow(name: match.contact.name) {
                                    if sentRequestIDs.contains(match.profile.id) {
                                        Text("Requested")
                                            .font(Typography.font(.sm, weight: .medium))
                                            .foregroundStyle(Colors.textTertiary)
                                    } else {
                                        Button("Add") {
                                            Task { await sendRequest(to: match.profile) }
                                        }
                                        .font(Typography.font(.sm, weight: .medium))
                                        .foregroundStyle(Colors.accent)
                                    }
                                }
                            }
                        }
                    }

                    if !notOnMemoria.isEmpty {
                        section(title: "Invite Friends") {
                            ForEach(notOnMemoria, id: \.self) { contact in
                                contactRow(name: contact.name) {
                                    Button("Invite") {
                                        invite(contact)
                                    }
                                    .font(Typography.font(.sm, weight: .medium))
                                    .foregroundStyle(Colors.accent)
                                }
                            }
                        }
                    }

                    if onMemoria.isEmpty && notOnMemoria.isEmpty {
                        Text("No matching contacts found.")
                            .font(Typography.font(.sm))
                            .foregroundStyle(Colors.textSecondary)
                    }
                }
            }
        }
    }

    private func section(title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.font(.sm, weight: .semiBold))
                .foregroundStyle(Colors.textSecondary)
            VStack(spacing: Spacing.xxs) {
                rows()
            }
        }
    }

    private func contactRow(name: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(name)
                .font(Typography.font(.body))
                .foregroundStyle(Colors.textPrimary)
            Spacer()
            trailing()
        }
        .padding(Spacing.md)
        .background(Colors.surfaceInput, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
    }

    private func connect() {
        loadState = .loading
        Task {
            do {
                let contacts = try await contactsService.fetchDeviceContacts()
                let (onMemoria, notOnMemoria) = try await contactsService.matchProfiles(
                    for: contacts,
                    excluding: store.userID
                )
                loadState = .loaded(onMemoria: onMemoria, notOnMemoria: notOnMemoria)
            } catch ContactsMatchingError.accessDenied {
                loadState = .denied
            } catch {
                loadState = .error(error.localizedDescription)
            }
        }
    }

    private func sendRequest(to profile: Profile) async {
        do {
            try await friendsService.sendRequest(from: store.userID, to: profile.id)
            sentRequestIDs.insert(profile.id)
        } catch {
            // Inline row action — a failed request just doesn't mark as sent; the user can retry.
        }
    }

    private func invite(_ contact: DeviceContact) {
        let body = "Join me on Memoria!"
        guard
            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "sms:\(contact.normalizedPhone)&body=\(encodedBody)")
        else { return }
        openURL(url)
    }
}

#Preview {
    ContactsStepView(onContinue: {})
        .environment(ProfileSetupStore(userID: UUID()))
        .background(Colors.background)
}
