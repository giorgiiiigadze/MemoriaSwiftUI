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
            .select("id, creator_id, title, thumbnail_url, created_at, is_pinned, creator:profiles(username, display_name)")
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Drops created by a single user, newest first — the Profile tab's "All drops" grid. Same
    /// trimmed shape as the Calendar cards so both render `CalendarDrop`s through `MiniDropCard`.
    func fetchUserDrops(creatorId: UUID) async throws -> [CalendarDrop] {
        try await client
            .from("drops")
            .select("id, creator_id, title, thumbnail_url, created_at, is_pinned, creator:profiles(username, display_name)")
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
    id, creator_id, title, thumbnail_url, state, open_date, created_at, is_pinned, \
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

    /// Creates a drop: uploads the cover photo to the public `photos` bucket, inserts the `drops`
    /// row (creator + title + open date + thumbnail), then invites the chosen friends as
    /// `drop_participants`. Returns the new drop's id. RLS scopes the insert to `creator_id = me`
    /// and lets the creator add participants.
    @discardableResult
    func createDrop(
        creatorID: UUID,
        title: String,
        openDate: Date,
        thumbnail: Data,
        invitedUserIDs: [UUID]
    ) async throws -> UUID {
        let path = "\(creatorID.uuidString.lowercased())/\(UUID().uuidString).jpg"
        try await client.storage
            .from("photos")
            .upload(path, data: thumbnail, options: FileOptions(contentType: "image/jpeg", upsert: false))
        let thumbnailURL = try client.storage.from("photos").getPublicURL(path: path).absoluteString

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let newDrop = NewDrop(
            creatorID: creatorID,
            title: title,
            openDate: iso.string(from: openDate),
            thumbnailURL: thumbnailURL
        )
        let created: InsertedDrop = try await client
            .from("drops")
            .insert(newDrop)
            .select("id")
            .single()
            .execute()
            .value

        if !invitedUserIDs.isEmpty {
            let participants = invitedUserIDs.map {
                NewParticipant(dropID: created.id, userID: $0, invitedBy: creatorID)
            }
            try await client.from("drop_participants").insert(participants).execute()
        }
        return created.id
    }

    /// How many drops the user has been invited to — i.e. their `drop_participants` rows. Uses a
    /// head/count request so no rows travel back.
    func invitedDropCount(userID: UUID) async throws -> Int {
        let response = try await client
            .from("drop_participants")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: userID)
            .execute()
        return response.count ?? 0
    }

    /// Pin or unpin a drop. Only the creator may — enforced by the `drops` table's RLS.
    func setPinned(dropID: UUID, pinned: Bool) async throws {
        try await client
            .from("drops")
            .update(["is_pinned": pinned])
            .eq("id", value: dropID)
            .execute()
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

    /// Insert payload for a new drop. `state` / `is_private` fall to their table defaults.
    private struct NewDrop: Encodable {
        let creatorID: UUID
        let title: String
        let openDate: String
        let thumbnailURL: String

        enum CodingKeys: String, CodingKey {
            case creatorID = "creator_id"
            case title
            case openDate = "open_date"
            case thumbnailURL = "thumbnail_url"
        }
    }

    /// Insert payload for one invited participant. `status` defaults to `'invited'`.
    private struct NewParticipant: Encodable {
        let dropID: UUID
        let userID: UUID
        let invitedBy: UUID

        enum CodingKeys: String, CodingKey {
            case dropID = "drop_id"
            case userID = "user_id"
            case invitedBy = "invited_by"
        }
    }

    /// The `id` returned from the drop insert.
    private struct InsertedDrop: Decodable { let id: UUID }
}
