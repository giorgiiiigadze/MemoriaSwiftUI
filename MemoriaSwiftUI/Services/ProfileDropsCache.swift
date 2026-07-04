import Foundation

/// Best-effort disk cache for the Profile tab's "All drops" grid, so the user's drops render
/// instantly on the next open instead of waiting on a network round-trip. The fresh fetch still
/// runs on appear and overwrites this, so the cache only ever bridges the gap before the network
/// answers. Mirrors `CalendarDropsCache` / `HomeDropsCache`.
///
/// `nonisolated static` (the project defaults types to `@MainActor`) since it's pure disk I/O with
/// no shared mutable state. All I/O is best-effort: a miss just falls back to the network fetch.
enum ProfileDropsCache {
    nonisolated private static var fileURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("profile_drops.json")
    }

    nonisolated static func load() -> [CalendarDrop]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([CalendarDrop].self, from: data)
    }

    nonisolated static func store(_ drops: [CalendarDrop]) {
        guard let data = try? JSONEncoder().encode(drops) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
