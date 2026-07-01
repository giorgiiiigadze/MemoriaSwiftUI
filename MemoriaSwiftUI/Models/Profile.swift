import Foundation

struct Profile: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var username: String
    var displayName: String?
    var avatarURL: String?
    var phone: String?
    var bio: String?
    var age: Int?
    var pushToken: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case phone
        case bio
        case age
        case pushToken = "push_token"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
