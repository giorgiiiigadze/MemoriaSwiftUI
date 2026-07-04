import Foundation
import Supabase

/// Reads the current user's notifications and marks them read. The `actor:` and `drop:` embeds
/// pull each notification's actor profile and (for drop types) the drop's title/thumbnail/creator
/// through the `notifications.actor_id`, `notifications.drop_id`, and `drops.creator_id` foreign
/// keys in one query. Mirrors the RN app's `notifications.api`.
final class NotificationsService {
    private let client = SupabaseClient.shared

    /// The columns each notification row needs, with the actor + drop (and its creator) embedded.
    /// The `!actor_id` / `!drop_id` / `!creator_id` hints disambiguate the foreign keys. The `\`
    /// continuations keep this one PostgREST select string with no embedded newlines.
    private static let select = """
    id, user_id, type, drop_id, actor_id, read, created_at, \
    actor:profiles!actor_id(id, username, display_name, avatar_url), \
    drop:drops!drop_id(id, title, thumbnail_url, \
    creator:profiles!creator_id(id, username, display_name, avatar_url))
    """

    /// The user's notifications, newest first. Row-level security also scopes this to `auth.uid()`;
    /// the explicit `user_id` filter keeps the query intent clear and lets the index do the work.
    func fetchNotifications(userId: UUID) async throws -> [NotificationWithMeta] {
        try await client
            .from("notifications")
            .select(Self.select)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Flags a single notification as read. Only the recipient may update it — enforced by the
    /// `notifications` table's row-level security, not here.
    func markRead(id: UUID) async throws {
        try await client
            .from("notifications")
            .update(["read": true])
            .eq("id", value: id)
            .execute()
    }
}
