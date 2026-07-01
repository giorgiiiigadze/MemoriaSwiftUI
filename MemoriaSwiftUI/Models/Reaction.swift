import Foundation

struct Reaction: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var photoId: UUID
    var userId: UUID
    var emoji: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case userId = "user_id"
        case emoji
        case createdAt = "created_at"
    }
}
