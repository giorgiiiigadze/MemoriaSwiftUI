import Foundation

enum FriendStatus: String, Codable, Sendable {
    case pending, accepted, blocked
}

struct Friendship: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var requesterId: UUID
    var addresseeId: UUID
    var status: FriendStatus
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
