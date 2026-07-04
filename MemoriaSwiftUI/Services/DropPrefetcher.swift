import Foundation
import UIKit

/// Warms the Drop Detail caches ahead of time so opening a drop from a feed or grid card is instant
/// on the *first* open, not just repeat opens. As cards scroll into view, `prefetch` pulls the
/// drop's header + photos into `DropDetailCache` and downloads the cover and the first screenful of
/// photos into `RemoteImageCache` — all in the background, deduped so scrolling doesn't refetch.
///
/// Main-actor (the project's default isolation): it drives the same `@MainActor` services the views
/// use and guards a small in-memory dedupe set, so there's no shared cross-thread state.
@MainActor
final class DropPrefetcher {
    static let shared = DropPrefetcher()
    private init() {}

    private let dropsService = DropsService()
    private let photosService = PhotosService()

    /// Drops already prefetched (or in flight) this session — so a card scrolling in and out of view
    /// doesn't re-hit the network each time.
    private var seen: Set<UUID> = []

    /// Cap on how many photo images we speculatively download per drop — enough to fill the detail
    /// grid's first viewport. The rest still cache their metadata and lazy-load on open.
    private let imageWarmLimit = 6

    /// Prefetch a drop we only know by id (Calendar / Profile cards carry no full detail).
    func prefetch(dropID: UUID) {
        guard claim(dropID) else { return }
        Task {
            if let drop = try? await dropsService.fetchDrop(id: dropID) {
                DropDetailCache.storeDrop(drop)
                await warmCover(drop)
            }
            await prefetchPhotos(dropID)
        }
    }

    /// Prefetch a drop whose header we already hold (the Home feed embeds it), skipping the redundant
    /// header fetch — just persist it and pull the photos + images.
    func prefetch(_ drop: DropWithParticipants) {
        guard claim(drop.id) else { return }
        DropDetailCache.storeDrop(drop)
        Task {
            await warmCover(drop)
            await prefetchPhotos(drop.id)
        }
    }

    /// Returns true and marks the drop the first time it's seen; false on repeats.
    private func claim(_ id: UUID) -> Bool {
        guard !seen.contains(id) else { return false }
        seen.insert(id)
        return true
    }

    private func prefetchPhotos(_ dropID: UUID) async {
        guard let photos = try? await photosService.fetchPhotos(dropID: dropID) else { return }
        DropDetailCache.storePhotos(photos, for: dropID)
        for photo in photos.prefix(imageWarmLimit) {
            if let url = photo.imageURL { await warmImage(url) }
        }
    }

    private func warmCover(_ drop: DropWithParticipants) async {
        if let url = drop.thumbnailURL.flatMap({ URL(string: $0) }) { await warmImage(url) }
    }

    /// Download + store an image into the shared cache, unless it's already there.
    private func warmImage(_ url: URL) async {
        if RemoteImageCache.image(for: url) != nil { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return }
        RemoteImageCache.store(image, data: data, for: url)
    }
}
