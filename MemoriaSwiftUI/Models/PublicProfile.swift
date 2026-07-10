import Foundation

/// The public-facing subset of a user's profile — what we show when viewing *someone else*. Never
/// carries private fields (phone, age); `profiles` SELECT is public, so we deliberately fetch only
/// these columns.
struct PublicProfile: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let username: String
    let displayName: String?
    let avatarURL: String?
    let bio: String?

    /// Prefer the chosen display name; fall back to the handle so a card is never nameless.
    var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return username
    }

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}
