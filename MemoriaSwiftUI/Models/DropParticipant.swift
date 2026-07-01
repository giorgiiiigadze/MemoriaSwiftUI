import Foundation

enum ParticipantStatus: String, Codable, Sendable {
    case invited, accepted, declined, pending, removed
}

struct DropParticipant: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var dropId: UUID
    var userId: UUID
    var status: ParticipantStatus
    var invitedBy: UUID?
    var hasUploaded: Bool
    var uploadCount: Int
    let joinedAt: Date
    var uploadedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case dropId = "drop_id"
        case userId = "user_id"
        case status
        case invitedBy = "invited_by"
        case hasUploaded = "has_uploaded"
        case uploadCount = "upload_count"
        case joinedAt = "joined_at"
        case uploadedAt = "uploaded_at"
    }
}
