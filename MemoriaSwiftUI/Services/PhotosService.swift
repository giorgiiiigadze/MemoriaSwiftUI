import Foundation
import Supabase
import UIKit

/// Reads and mutates a drop's photos for the Drop Detail page. Uploads go to the public `photos`
/// bucket; inserts/pins are scoped by the `photos` table RLS (upload as yourself when the drop
/// allows it; pin your own photos or any photo on a drop you created). Per-photo delete is blocked
/// at the database, so it isn't exposed here.
final class PhotosService {
    private let client = SupabaseClient.shared

    private static let select = """
    id, drop_id, uploader_id, storage_path, cdn_url, width, height, uploaded_at, sort_order, is_pinned, \
    uploader:profiles!uploader_id(id, username, display_name, avatar_url)
    """

    /// A drop's photos, pinned first, then by `sort_order`, then oldest upload first.
    func fetchPhotos(dropID: UUID) async throws -> [PhotoWithUploader] {
        let photos: [PhotoWithUploader] = try await client
            .from("photos")
            .select(Self.select)
            .eq("drop_id", value: dropID)
            .execute()
            .value
        return photos.sorted(by: Self.ordering)
    }

    /// Uploads a captured photo: JPEG → public `photos` bucket → `photos` row (as the uploader).
    func uploadPhoto(dropID: UUID, uploaderID: UUID, image: UIImage) async throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let path = "\(dropID.uuidString.lowercased())/\(uploaderID.uuidString.lowercased())/\(UUID().uuidString).jpg"
        try await client.storage
            .from("photos")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
        let cdnURL = try client.storage.from("photos").getPublicURL(path: path).absoluteString

        let newPhoto = NewPhoto(
            dropID: dropID,
            uploaderID: uploaderID,
            storagePath: path,
            cdnURL: cdnURL,
            width: Int(image.size.width),
            height: Int(image.size.height)
        )
        try await client.from("photos").insert(newPhoto).execute()
    }

    /// Pin or unpin a photo (uploader, or the drop's creator — enforced by RLS).
    func setPinned(photoID: UUID, pinned: Bool) async throws {
        try await client
            .from("photos")
            .update(["is_pinned": pinned])
            .eq("id", value: photoID)
            .execute()
    }

    /// Pinned first, then by explicit sort order, then oldest first. Mirrors the RN `sortPhotos`.
    static func ordering(_ a: PhotoWithUploader, _ b: PhotoWithUploader) -> Bool {
        if a.isPinned != b.isPinned { return a.isPinned }
        if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
        return a.uploadedAt < b.uploadedAt
    }

    /// Insert payload for a new photo. `sort_order` / `is_pinned` fall to their table defaults.
    private struct NewPhoto: Encodable {
        let dropID: UUID
        let uploaderID: UUID
        let storagePath: String
        let cdnURL: String
        let width: Int
        let height: Int

        enum CodingKeys: String, CodingKey {
            case dropID = "drop_id"
            case uploaderID = "uploader_id"
            case storagePath = "storage_path"
            case cdnURL = "cdn_url"
            case width
            case height
        }
    }
}
