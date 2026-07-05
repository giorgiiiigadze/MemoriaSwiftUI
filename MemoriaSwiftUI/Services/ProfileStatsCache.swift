import Foundation

/// Best-effort cache of the Profile stat counts (friends, invited) so they render instantly on the
/// next open instead of counting up from 0 while their queries run. The fresh counts still load on
/// appear and overwrite this. Two small integers, so `UserDefaults` rather than a file.
///
/// `nonisolated static` (the project defaults types to `@MainActor`) — it's pure `UserDefaults` I/O
/// with no shared mutable state.
enum ProfileStatsCache {
    nonisolated private static let friendsKey = "profile_stat_friends"
    nonisolated private static let invitedKey = "profile_stat_invited"

    nonisolated static func load() -> (friends: Int, invited: Int)? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: friendsKey) != nil else { return nil }
        return (defaults.integer(forKey: friendsKey), defaults.integer(forKey: invitedKey))
    }

    nonisolated static func store(friends: Int, invited: Int) {
        let defaults = UserDefaults.standard
        defaults.set(friends, forKey: friendsKey)
        defaults.set(invited, forKey: invitedKey)
    }

    /// Wipes the cached counts — used when switching accounts so the incoming user never sees the
    /// previous user's stats before their own counts load.
    nonisolated static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: friendsKey)
        defaults.removeObject(forKey: invitedKey)
    }
}
