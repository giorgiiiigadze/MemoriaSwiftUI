import Foundation

/// Remembers, per `(account, drop)`, whether this device has already played the one-time
/// "reveal" animation — the cinematic un-blur that runs the first time a member opens a
/// drop after it has opened. Backed by `UserDefaults` (a single string list), mirroring the
/// lightweight persistence of the other drop caches like `DropDetailCache`.
///
/// Keys are `"<userID>:<dropID>"`, so the flag is naturally scoped per account and never
/// bleeds across a multi-account switch — there's nothing to clear on logout.
enum DropRevealStore {
    private static let key = "dropRevealSeen"

    private static func identifier(dropID: UUID, userID: UUID) -> String {
        "\(userID.uuidString.lowercased()):\(dropID.uuidString.lowercased())"
    }

    private static func seen() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    /// Whether the reveal has already played for this member on this drop.
    static func hasRevealed(dropID: UUID, userID: UUID) -> Bool {
        seen().contains(identifier(dropID: dropID, userID: userID))
    }

    /// Records that the reveal has now played, so it never replays on a later open.
    static func markRevealed(dropID: UUID, userID: UUID) {
        var set = seen()
        set.insert(identifier(dropID: dropID, userID: userID))
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}
