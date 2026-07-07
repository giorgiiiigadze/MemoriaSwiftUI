import Foundation

enum NotificationType: String, Codable, Sendable {
    case dropInvited = "drop_invited"
    case dropReady = "drop_ready"
    case dropOpened = "drop_opened"
    case dropOpeningSoon = "drop_opening_soon"
    case dropExpired = "drop_expired"
    case dropEmptyWarning = "drop_empty_warning"
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

/// A notification enriched with the actor's profile and — for drop-related types — the drop's
/// title, thumbnail, and creator, all pulled through the `actor_id`, `drop_id`, and
/// `drops.creator_id` foreign keys in a single query. Mirrors the RN app's `NotificationWithMeta`.
struct NotificationWithMeta: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var userId: UUID
    var type: NotificationType
    var dropId: UUID?
    var actorId: UUID?
    var read: Bool
    let createdAt: Date
    let actor: DropWithParticipants.ProfileRef?
    let drop: DropRef?

    /// The subset of a drop a notification row needs: its title, thumbnail, and creator profile.
    struct DropRef: Codable, Sendable, Hashable {
        let id: UUID
        let title: String?
        let thumbnailURL: String?
        let creator: DropWithParticipants.ProfileRef?

        enum CodingKeys: String, CodingKey {
            case id, title
            case thumbnailURL = "thumbnail_url"
            case creator
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case dropId = "drop_id"
        case actorId = "actor_id"
        case read
        case createdAt = "created_at"
        case actor
        case drop
    }
}

extension NotificationWithMeta {
    /// True when this notification was created today (drives the Today / Earlier sectioning).
    var isToday: Bool { Calendar.current.isDateInToday(createdAt) }

    /// The actor's label: chosen display name, else `@handle`, else "Someone". Mirrors RN `notifText`.
    private var actorLabel: String {
        if let displayName = actor?.displayName, !displayName.isEmpty { return displayName }
        if let username = actor?.username, !username.isEmpty { return "@\(username)" }
        return "Someone"
    }

    /// The drop's label: its quoted title, else "a drop".
    private var dropLabel: String {
        if let title = drop?.title, !title.isEmpty { return "\"\(title)\"" }
        return "a drop"
    }

    /// The human-readable notification line, mirroring the RN `notifText` copy exactly.
    var text: String {
        switch type {
        case .dropInvited: "\(actorLabel) invited you to \(dropLabel)"
        case .dropOpened: "\(dropLabel) is now open — see the photos"
        case .dropReady: "\(dropLabel) is ready to open"
        case .friendRequest: "\(actorLabel) sent you a friend request"
        case .friendAccepted: "\(actorLabel) accepted your friend request"
        case .participantUploaded: "\(actorLabel) uploaded photos to \(dropLabel)"
        case .dropOpeningSoon: "\(dropLabel) opens soon"
        case .dropExpired: "\(dropLabel) has expired"
        case .dropEmptyWarning: "\(dropLabel) has no photos yet — add one before it opens or it'll be removed"
        }
    }

    /// A compact relative timestamp: "just now", "5m ago", "3h ago", "2d ago". Mirrors RN `timeAgo`.
    var timeAgo: String {
        let minutes = Int(Date().timeIntervalSince(createdAt) / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}
