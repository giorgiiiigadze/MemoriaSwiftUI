import Foundation

struct Photo: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var dropId: UUID
    var uploaderId: UUID
    var storagePath: String
    var cdnURL: String
    var width: Int?
    var height: Int?
    var takenAt: Date?
    let uploadedAt: Date
    var sortOrder: Int
    var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case dropId = "drop_id"
        case uploaderId = "uploader_id"
        case storagePath = "storage_path"
        case cdnURL = "cdn_url"
        case width
        case height
        case takenAt = "taken_at"
        case uploadedAt = "uploaded_at"
        case sortOrder = "sort_order"
        case isPinned = "is_pinned"
    }
}
