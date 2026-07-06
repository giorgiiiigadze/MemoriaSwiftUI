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
    /// Server-side onboarding flag: `false` until the user creates their first drop (flipped by a DB
    /// trigger on `drops` insert). Drives the Home feed's "Create your first drop" tile.
    var hasCreatedFirstDrop: Bool
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
        case hasCreatedFirstDrop = "has_created_first_drop"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
