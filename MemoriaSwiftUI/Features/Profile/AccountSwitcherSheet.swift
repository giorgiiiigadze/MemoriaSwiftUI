import SwiftUI

/// Presented from the tappable username in the Profile header. Lists every account signed into on
/// this device, marks the active one, and lets the user switch to another (no password) or add a
/// new one. Switching is instant: it swaps the Supabase session via `AppState.switchAccount`.
struct AccountSwitcherSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var accounts: [SavedAccount] { appState.accounts.accounts }
    private var activeID: UUID? { appState.accounts.activeID }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(accounts) { account in
                        accountRow(account)
                    }
                    .onDelete(perform: removeAccounts)

                    addAccountRow
                    createAccountRow
                }
            }
            .listRowSeparator(.hidden)
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(Colors.textPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func accountRow(_ account: SavedAccount) -> some View {
        Button {
            switchTo(account)
        } label: {
            HStack(spacing: Spacing.sm) {
                AvatarView(url: account.avatarURL, name: account.title, size: 44)

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.title)
                        .font(Typography.font(.body, weight: .semiBold))
                        .foregroundStyle(Colors.textPrimary)
                        .lineLimit(1)
                    Text("@\(account.username)")
                        .font(Typography.font(.xs))
                        .foregroundStyle(Colors.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if account.id == activeID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Colors.white)
                }
            }
            .contentShape(Rectangle())
        }
    }

    /// Signs into an account that already exists (opens the log-in flow).
    private var addAccountRow: some View {
        accountActionRow(icon: "plus", title: "Add account", mode: .signIn)
    }

    /// Creates a brand-new account (opens the sign-up flow), keeping the current one saved.
    private var createAccountRow: some View {
        accountActionRow(icon: "person.fill.badge.plus", title: "Create account", mode: .signUp)
    }

    private func accountActionRow(icon: String, title: String, mode: AddAccountMode) -> some View {
        Button {
            dismiss()
            appState.beginAddAccount(mode: mode)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(Colors.white)
                    .frame(width: 44, height: 44)
                Text(title)
                    .font(Typography.font(.body, weight: .semiBold))
                    .foregroundStyle(Colors.textPrimary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
    }

    private func switchTo(_ account: SavedAccount) {
        guard account.id != activeID else { dismiss(); return }
        dismiss()
        Task { await appState.switchAccount(to: account.id) }
    }

    /// Forgets accounts (swipe-to-delete). Removing the active account isn't offered here — that's
    /// what Log Out in Settings does — so this only affects inactive, switch-target accounts.
    private func removeAccounts(at offsets: IndexSet) {
        for index in offsets {
            let account = accounts[index]
            guard account.id != activeID else { continue }
            appState.accounts.remove(id: account.id)
        }
    }
}

#Preview {
    AccountSwitcherSheet()
        .environment(AppState())
}
