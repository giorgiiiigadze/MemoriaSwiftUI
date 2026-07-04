import CryptoKit
import Foundation
import UIKit

/// Two-tier cache for remote images (drop covers, thumbnails): an in-memory `NSCache` for instant
/// re-display while scrolling, backed by a disk cache so images survive relaunches and don't
/// re-download every time a card scrolls back into view. Keyed by a SHA256 of the URL string.
///
/// `nonisolated` (the project defaults types to `@MainActor`) — pure cache I/O with no shared
/// mutable state of our own; `NSCache` is itself thread-safe, hence `nonisolated(unsafe)`.
enum RemoteImageCache {
    nonisolated(unsafe) private static let memory = NSCache<NSString, UIImage>()

    nonisolated private static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("RemoteImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Cache-first lookup: memory, then disk (promoting a disk hit into memory), else nil.
    nonisolated static func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        if let cached = memory.object(forKey: key) { return cached }
        guard let data = try? Data(contentsOf: fileURL(for: url)), let image = UIImage(data: data) else {
            return nil
        }
        memory.setObject(image, forKey: key)
        return image
    }

    nonisolated static func store(_ image: UIImage, data: Data, for url: URL) {
        memory.setObject(image, forKey: cacheKey(for: url))
        try? data.write(to: fileURL(for: url), options: .atomic)
    }

    nonisolated private static func cacheKey(for url: URL) -> NSString {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() as NSString
    }

    nonisolated private static func fileURL(for url: URL) -> URL {
        directory.appendingPathComponent(cacheKey(for: url) as String)
    }
}
