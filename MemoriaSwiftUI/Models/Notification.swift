import Foundation

enum NotificationType: String, Codable, Sendable {
    case dropInvited = "drop_invited"
    case dropReady = "drop_ready"
    case dropOpened = "drop_opened"
    case dropOpeningSoon = "drop_opening_soon"
    case dropExpired = "drop_expired"
    case participantUploaded = "participant_uploaded"
    case friendRequest = "friend_request"
    case friendAccepted = "friend_accepted"
}

/// Named `AppNotification` rather than `Notification` — the latter collides with
/// Foundation's `Notification` (NSNotification) in every file that imports Foundation.
struct AppNotification: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var userId: UUID
    var type: NotificationType
    var dropId: UUID?
    var actorId: UUID?
    var read: Bool
    var sentPush: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case dropId = "drop_id"
        case actorId = "actor_id"
        case read
        case sentPush = "sent_push"
        case createdAt = "created_at"
    }
}
