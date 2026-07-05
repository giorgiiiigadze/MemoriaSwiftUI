import Foundation
import Observation

/// One account the user can switch to without re-entering a password. Holds just enough profile
/// info to render the switcher row, plus the Supabase tokens needed to re-establish the session via
/// `auth.setSession(accessToken:refreshToken:)`.
struct SavedAccount: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var displayName: String?
    var avatarURL: String?
    var accessToken: String
    var refreshToken: String

    /// What the switcher row shows as the primary line.
    var title: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return username
    }
}

/// Persists the set of accounts the user has signed into on this device (in the Keychain, since the
/// refresh tokens are secrets) and tracks which one is active. Backs the Profile account switcher.
///
/// The Supabase SDK only ever holds one active session; this is the side-list that makes fast
/// switching possible. Whenever the active account's token rotates, `AppState` calls `upsert` again
/// so the stored refresh token stays fresh and a later switch back doesn't hit a stale token.
@Observable
final class AccountStore {
    private(set) var accounts: [SavedAccount] = []
    private(set) var activeID: UUID?

    private let storageKey = "saved_accounts_v1"

    init() {
        load()
    }

    /// The accounts other than the one currently signed in — i.e. the ones worth showing as
    /// switch targets.
    var switchable: [SavedAccount] {
        accounts.filter { $0.id != activeID }
    }

    /// Inserts or updates an account (matched by id) and marks it active. Called after every
    /// successful hydration to `.app` and on every token refresh, so tokens never go stale.
    func upsert(_ account: SavedAccount, active: Bool) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        if active { activeID = account.id }
        persist()
    }

    /// Forgets an account (e.g. the user removed it, or its refresh token turned out to be stale).
    func remove(id: UUID) {
        accounts.removeAll { $0.id == id }
        if activeID == id { activeID = nil }
        persist()
    }

    func account(id: UUID) -> SavedAccount? {
        accounts.first { $0.id == id }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        KeychainStore.set(data, for: storageKey)
    }

    private func load() {
        guard
            let data = KeychainStore.get(storageKey),
            let decoded = try? JSONDecoder().decode([SavedAccount].self, from: data)
        else { return }
        accounts = decoded
    }
}
