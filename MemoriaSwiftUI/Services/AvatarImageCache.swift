import CryptoKit
import Foundation

/// Best-effort disk cache for avatar image bytes, so the Profile tab's photo renders instantly on
/// launch instead of waiting on a fresh network download every time (the avatar `URL` is already in
/// memory when the app opens — only its bytes weren't persisted).
///
/// Keyed by a SHA256 of the URL string (filesystem-safe, stable). All I/O is best-effort: any
/// failure just falls back to a network fetch, so callers never need to handle errors.
///
/// `nonisolated static` (the project defaults types to `@MainActor`) since it's pure disk I/O with
/// no shared mutable state — callable from any actor context.
enum AvatarImageCache {
    nonisolated private static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("AvatarImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func data(for url: URL) -> Data? {
        try? Data(contentsOf: fileURL(for: url))
    }

    /// Downloads and caches the avatar bytes if they aren't already on disk, so a later
    /// cache-first read (e.g. the Profile tab) renders instantly. Called during boot hydration
    /// while the splash is up. Best-effort and bounded: races the download against `timeout` and
    /// returns whichever finishes first, so a slow/dead network can't trap the user on the splash —
    /// a miss just falls back to the normal on-appear fetch.
    nonisolated static func prefetch(_ url: URL, timeout: Duration = .seconds(3)) async {
        guard data(for: url) == nil else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                if let (bytes, _) = try? await URLSession.shared.data(from: url) {
                    store(bytes, for: url)
                }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
            }
            await group.next()
            group.cancelAll()
        }
    }

    nonisolated static func store(_ data: Data, for url: URL) {
        try? data.write(to: fileURL(for: url), options: .atomic)
    }

    nonisolated private static func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }
}
