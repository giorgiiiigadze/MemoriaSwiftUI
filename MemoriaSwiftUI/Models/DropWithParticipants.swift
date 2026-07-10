import Foundation

/// A drop as shown in the Home feed: the drop's own fields plus its creator's profile and the
/// list of participants (each with their profile), pulled through the `drops.creator_id` and
/// `drop_participants.user_id` foreign keys in a single query. Mirrors the RN app's
/// `DropWithParticipants`.
struct DropWithParticipants: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let creatorId: UUID
    let title: String
    let thumbnailURL: String?
    let state: DropState
    let openDate: Date?
    let createdAt: Date
    let creator: ProfileRef?
    let participants: [Participant]
    /// Optional so drops cached before this field existed still decode; read via `pinned`.
    var isPinned: Bool?

    /// Whether the drop is pinned, treating a missing value as not pinned.
    var pinned: Bool { isPinned ?? false }

    /// A trimmed `profiles` row — just what an avatar + name label needs.
    struct ProfileRef: Codable, Hashable, Sendable, Identifiable {
        let id: UUID
        let username: String
        let displayName: String?
        let avatarURL: String?

        /// Prefer the chosen display name; fall back to the handle so a row is never nameless.
        var name: String {
            if let displayName, !displayName.isEmpty { return displayName }
            return username
        }

        enum CodingKeys: String, CodingKey {
            case id, username
            case displayName = "display_name"
            case avatarURL = "avatar_url"
        }
    }

    /// One invited/joined user on a drop, with the subset of participant fields the card reads.
    struct Participant: Codable, Identifiable, Hashable, Sendable {
        let id: UUID
        let userId: UUID
        let status: ParticipantStatus
        let hasUploaded: Bool
        let profile: ProfileRef?

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case status
            case hasUploaded = "has_uploaded"
            case profile
        }
    }

    /// The creator's display label, or `nil` when the join came back empty (e.g. a deleted profile).
    var creatorName: String? { creator?.name }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case title
        case thumbnailURL = "thumbnail_url"
        case state
        case openDate = "open_date"
        case createdAt = "created_at"
        case creator
        case participants
        case isPinned = "is_pinned"
    }
}
