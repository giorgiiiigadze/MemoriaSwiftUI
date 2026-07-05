import Foundation

/// Best-effort disk cache for the Drop Detail page, keyed by drop id, so a drop's header and its
/// photo grid render instantly on re-open instead of flashing a skeleton while the network answers.
/// The fresh fetch in `load()` still runs on appear and overwrites this, so the cache only ever
/// bridges the gap before the network responds. Mirrors `ProfileDropsCache` / `CalendarDropsCache`.
///
/// Unlike the other drop caches this stays on the main actor (the project's default isolation)
/// rather than `nonisolated`, because `DropWithParticipants`' synthesized `Codable` conformance is
/// main-actor-isolated. It's only ever called from the Drop Detail view's `init` / `load`, both of
/// which already run on the main actor, so there's no cost. All I/O is best-effort: a miss just
/// falls back to the network fetch.
enum DropDetailCache {
    /// One file per drop under a dedicated subdirectory, so drops don't grow one giant blob.
    private static func directory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DropDetail", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func dropURL(_ id: UUID) -> URL {
        directory().appendingPathComponent("\(id.uuidString.lowercased()).json")
    }

    private static func photosURL(_ id: UUID) -> URL {
        directory().appendingPathComponent("\(id.uuidString.lowercased())-photos.json")
    }

    static func loadDrop(_ id: UUID) -> DropWithParticipants? {
        guard let data = try? Data(contentsOf: dropURL(id)) else { return nil }
        return try? JSONDecoder().decode(DropWithParticipants.self, from: data)
    }

    static func storeDrop(_ drop: DropWithParticipants) {
        guard let data = try? JSONEncoder().encode(drop) else { return }
        try? data.write(to: dropURL(drop.id), options: .atomic)
    }

    static func loadPhotos(_ id: UUID) -> [PhotoWithUploader]? {
        guard let data = try? Data(contentsOf: photosURL(id)) else { return nil }
        return try? JSONDecoder().decode([PhotoWithUploader].self, from: data)
    }

    static func storePhotos(_ photos: [PhotoWithUploader], for id: UUID) {
        guard let data = try? JSONEncoder().encode(photos) else { return }
        try? data.write(to: photosURL(id), options: .atomic)
    }

    /// Wipes every cached drop + photo list — used when switching accounts so the incoming user
    /// never opens a drop and briefly sees the previous user's cached copy.
    static func clear() {
        try? FileManager.default.removeItem(at: directory())
    }
}
