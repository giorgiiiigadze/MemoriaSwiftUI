import Foundation
import Security

/// Minimal Keychain wrapper for storing small blobs (a JSON-encoded list of saved accounts, with
/// their refresh tokens) under a single service+account key. Tokens are secrets, so they live in the
/// Keychain — never `UserDefaults`. All operations are best-effort and synchronous.
///
/// This is intentionally separate from the Supabase SDK's own `KeychainLocalStorage`, which only
/// holds the *one* currently-active session; this stores the full set of accounts we can switch to.
enum KeychainStore {
    private static let service = "app.memoria.accounts"

    /// Stores `data` under `key`, replacing any existing value. Accessible after first unlock so a
    /// background refresh/switch can read it without the device being unlocked.
    static func set(_ data: Data, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
