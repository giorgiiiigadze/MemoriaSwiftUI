import Foundation

/// Best-effort disk cache for the Notifications list, so rows render instantly on the next open
/// instead of waiting on a network round-trip. The fresh fetch still runs on appear and overwrites
/// this, so the cache only ever bridges the gap before the network answers. Mirrors
/// `CalendarDropsCache` / `HomeDropsCache`.
///
/// `nonisolated static` (the project defaults types to `@MainActor`) since it's pure disk I/O with
/// no shared mutable state. All I/O is best-effort: a miss just falls back to the network fetch.
enum NotificationsCache {
    nonisolated private static var fileURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("notifications.json")
    }

    nonisolated static func load() -> [NotificationWithMeta]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([NotificationWithMeta].self, from: data)
    }

    nonisolated static func store(_ notifications: [NotificationWithMeta]) {
        guard let data = try? JSONEncoder().encode(notifications) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
