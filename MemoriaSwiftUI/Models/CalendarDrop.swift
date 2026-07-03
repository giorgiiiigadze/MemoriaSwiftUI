import Foundation

/// A drop as shown in the Calendar tab: just the fields a mini card needs, with the
/// creator's profile embedded via the `drops.creator_id → profiles` foreign key so we
/// can label each card with a name without a second round-trip.
struct CalendarDrop: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let creatorId: UUID
    let title: String
    let thumbnailURL: String?
    let createdAt: Date
    let creator: Creator?

    struct Creator: Codable, Hashable, Sendable {
        let username: String
        let displayName: String?

        /// Prefer the chosen display name; fall back to the handle so a card is never nameless.
        var name: String {
            if let displayName, !displayName.isEmpty { return displayName }
            return username
        }

        enum CodingKeys: String, CodingKey {
            case username
            case displayName = "display_name"
        }
    }

    /// The name to print on the card — the creator's, or a neutral fallback if the join
    /// came back empty (e.g. a deleted profile).
    var creatorName: String { creator?.name ?? "Unknown" }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case title
        case thumbnailURL = "thumbnail_url"
        case createdAt = "created_at"
        case creator
    }
}
