import Foundation

/// Best-effort disk cache for the signed-in user's own `Profile`, so a returning user can be booted
/// straight into the app from the last-known-good profile when the network is unreachable — instead
/// of being signed out just because the boot-time `profiles` fetch failed. The fresh fetch still
/// runs and overwrites this whenever it succeeds. Cleared on sign-out / account switch (via
/// `UserCaches`) so a signed-out or swapped-away user's profile never lingers. Mirrors
/// `HomeDropsCache`, but stays on the main actor (unlike the other caches) since `Profile`'s Codable
/// conformance is main-actor-isolated and its only caller, `AppState`, is already main-actor.
enum ProfileCache {
    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("active_profile.json")
    }

    static func load() -> Profile? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: data)
    }

    static func store(_ profile: Profile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
