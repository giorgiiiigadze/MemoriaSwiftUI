import Foundation

/// Best-effort disk cache for the Home feed's drop list, so the feed renders instantly on the
/// next open instead of waiting on a network round-trip. The fresh fetch still runs on appear and
/// overwrites this, so the cache only ever bridges the gap before the network answers. Mirrors
/// `CalendarDropsCache`.
///
/// `nonisolated static` (the project defaults types to `@MainActor`) since it's pure disk I/O with
/// no shared mutable state. All I/O is best-effort: a miss just falls back to the network fetch.
enum HomeDropsCache {
    nonisolated private static var fileURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("home_drops.json")
    }

    nonisolated static func load() -> [DropWithParticipants]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([DropWithParticipants].self, from: data)
    }

    nonisolated static func store(_ drops: [DropWithParticipants]) {
        guard let data = try? JSONEncoder().encode(drops) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Wipes the cache — used when switching accounts so the incoming user never sees the previous
    /// user's feed flash before their own fetch lands.
    nonisolated static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
