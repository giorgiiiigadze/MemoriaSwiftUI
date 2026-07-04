import Foundation

/// A drop photo with its uploader's profile embedded (through `photos.uploader_id`), so the detail
/// page can group photos by who added them without a second query. Mirrors the RN `PhotoWithUploader`.
struct PhotoWithUploader: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var dropId: UUID
    var uploaderId: UUID
    var storagePath: String
    var cdnURL: String
    var width: Int?
    var height: Int?
    let uploadedAt: Date
    var sortOrder: Int
    var isPinned: Bool
    let uploader: DropWithParticipants.ProfileRef?

    var imageURL: URL? { URL(string: cdnURL) }

    enum CodingKeys: String, CodingKey {
        case id
        case dropId = "drop_id"
        case uploaderId = "uploader_id"
        case storagePath = "storage_path"
        case cdnURL = "cdn_url"
        case width
        case height
        case uploadedAt = "uploaded_at"
        case sortOrder = "sort_order"
        case isPinned = "is_pinned"
        case uploader
    }
}
