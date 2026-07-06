import Foundation

/// One place to wipe every *user-scoped* on-disk/`UserDefaults` cache. Called when switching
/// accounts (or signing out) so the incoming user never briefly sees the previous user's feed,
/// notifications, drops, or stats before their own fetch lands.
///
/// Deliberately does *not* clear the image caches (`RemoteImageCache` / `AvatarImageCache`): those
/// are keyed by the image URL, which is globally unique, so there's no cross-user leak and keeping
/// them avoids re-downloading shared assets.
enum UserCaches {
    /// Runs on the main actor (the project's default isolation) because `DropDetailCache` is
    /// main-actor-isolated. Only ever called from the account-switch / sign-out paths, both on main.
    static func clear() {
        HomeDropsCache.clear()
        NotificationsCache.clear()
        CalendarDropsCache.clear()
        ProfileDropsCache.clear()
        ProfileStatsCache.clear()
        DropDetailCache.clear()
        ProfileCache.clear()
    }
}
