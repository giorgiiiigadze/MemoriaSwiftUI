import Foundation
import Supabase

/// Reads drops for the Calendar tab. The `creator:profiles(...)` embed pulls each drop's
/// creator row through the `drops_creator_id_fkey` foreign key in one query.
final class DropsService {
    private let client = SupabaseClient.shared

    /// All drops, oldest first — the Calendar renders months top-to-bottom ending at "today".
    func fetchCalendarDrops() async throws -> [CalendarDrop] {
        try await client
            .from("drops")
            .select("id, creator_id, title, thumbnail_url, created_at, creator:profiles(username, display_name)")
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Drops created by a single user, newest first — the Profile tab's "All drops" grid. Same
    /// trimmed shape as the Calendar cards so both render `CalendarDrop`s through `MiniDropCard`.
    func fetchUserDrops(creatorId: UUID) async throws -> [CalendarDrop] {
        try await client
            .from("drops")
            .select("id, creator_id, title, thumbnail_url, created_at, creator:profiles(username, display_name)")
            .eq("creator_id", value: creatorId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// The columns the Home feed's `DropCard` needs: the drop, its participants (each with a
    /// trimmed profile), and its creator's profile — all embedded through foreign keys so the
    /// feed is one round-trip. The `!user_id` / `!creator_id` hints disambiguate the two
    /// `profiles` relationships. The `\` continuations keep this one PostgREST select string
    /// with no embedded newlines.
    private static let feedSelect = """
    id, creator_id, title, thumbnail_url, state, open_date, created_at, \
    participants:drop_participants(id, user_id, status, has_uploaded, \
    profile:profiles!user_id(id, username, display_name, avatar_url)), \
    creator:profiles!creator_id(id, username, display_name, avatar_url)
    """

    /// All drops for the Home feed, newest first, each with its creator + participants embedded.
    func fetchDrops() async throws -> [DropWithParticipants] {
        try await client
            .from("drops")
            .select(Self.feedSelect)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Permanently deletes a drop for everyone. Only the creator may delete — enforced by the
    /// `drops` table's row-level security, not here.
    func deleteDrop(id: UUID) async throws {
        try await client
            .from("drops")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
