import Foundation

enum DropState: String, Codable, Sendable {
    case active, ready, open, expired
}

struct Drop: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var creatorId: UUID
    var title: String
    var thumbnailURL: String?
    var state: DropState
    var openDate: Date?
    var openedAt: Date?
    var isPrivate: Bool
    var isPinned: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case title
        case thumbnailURL = "thumbnail_url"
        case state
        case openDate = "open_date"
        case openedAt = "opened_at"
        case isPrivate = "is_private"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
