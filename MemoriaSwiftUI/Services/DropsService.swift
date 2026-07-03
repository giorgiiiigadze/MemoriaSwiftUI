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
}
