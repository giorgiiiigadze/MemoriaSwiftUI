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

    /// A single drop with its creator + participants embedded — the Drop Detail page's header.
    func fetchDrop(id: UUID) async throws -> DropWithParticipants {
        try await client
            .from("drops")
            .select(Self.feedSelect)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

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

    /// Invite more friends to an existing drop — inserts one `invited` `drop_participants` row per
    /// user. Callers must pass only users without an existing row, since the table's
    /// `(drop_id, user_id)` uniqueness would otherwise reject the whole batch. RLS scopes who may add
    /// participants to a drop.
    func inviteParticipants(dropID: UUID, userIDs: [UUID], invitedBy: UUID) async throws {
        guard !userIDs.isEmpty else { return }
        let rows = userIDs.map { NewParticipant(dropID: dropID, userID: $0, invitedBy: invitedBy) }
        try await client.from("drop_participants").insert(rows).execute()
    }

    /// Re-invite people who previously declined or left — flips their existing `drop_participants`
    /// rows back to `invited`. Used instead of an insert because their row already exists (the
    /// `(drop_id, user_id)` uniqueness would reject a fresh insert). The UPDATE RLS policy lets the
    /// drop's creator update any participant row on the drop.
    func reinviteParticipants(dropID: UUID, userIDs: [UUID]) async throws {
        guard !userIDs.isEmpty else { return }
        try await client
            .from("drop_participants")
            .update(["status": ParticipantStatus.invited.rawValue])
            .eq("drop_id", value: dropID)
            .in("user_id", values: userIDs.map(\.uuidString))
            .execute()
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

    /// Accept a drop invitation — flips the caller's own `drop_participants` row to `accepted`, which
    /// is what unlocks seeing the drop's photos (the `photos` RLS requires accepted status). RLS lets
    /// a user update their own participant row.
    func acceptInvite(dropID: UUID, userID: UUID) async throws {
        try await client
            .from("drop_participants")
            .update(["status": ParticipantStatus.accepted.rawValue])
            .eq("drop_id", value: dropID)
            .eq("user_id", value: userID)
            .execute()
    }

    /// Invite the current user to a drop from a scanned link/QR (`memoria://drop/<id>`). Calls the
    /// `join_drop` RPC, which adds the *current* user (derived server-side from the session, so this
    /// can only ever invite the caller) as an `invited` participant — they still Accept in the drop
    /// via the detail page's accept bar. Idempotent: a fresh scan invites, a previously declined/left
    /// membership is re-invited, and an existing invited/accepted membership is left untouched.
    func joinDrop(dropID: UUID) async throws {
        try await client
            .rpc("join_drop", params: ["p_drop_id": dropID])
            .execute()
    }

    /// Drops the current user and `other` are both active members of. We read `other`'s participant
    /// rows, but the `drop_participants` RLS only returns rows for drops the *caller* is also a member
    /// of — so the result is exactly the drops the two share. Declined/left memberships on either side
    /// are excluded (the caller's by RLS, the other user's by the status filter here).
    func sharedDrops(withUserID other: UUID) async throws -> [CalendarDrop] {
        let rows: [SharedDropRow] = try await client
            .from("drop_participants")
            .select("status, drop:drops!drop_id(id, creator_id, title, thumbnail_url, created_at, is_pinned, creator:profiles!creator_id(username, display_name))")
            .eq("user_id", value: other)
            .execute()
            .value
        return rows.compactMap { row in
            guard row.status != .declined, row.status != .removed else { return nil }
            return row.drop
        }
    }

    /// Decline a pending invitation. Flips the participant row to `declined` (rather than deleting
    /// it) so the invite doesn't simply reappear on the next sync and the creator can still see the
    /// person passed. RLS then drops the user's access to the drop's photos.
    func declineInvite(dropID: UUID, userID: UUID) async throws {
        try await client
            .from("drop_participants")
            .update(["status": ParticipantStatus.declined.rawValue])
            .eq("drop_id", value: dropID)
            .eq("user_id", value: userID)
            .execute()
    }

    /// Leave a drop the caller had accepted — flips their own `drop_participants` row to `removed`,
    /// which (like `declined`) drops it out of their feed via the `is_drop_participant` RLS check and
    /// revokes photo access. Their already-uploaded photos stay (the `photos` table forbids deletes).
    /// RLS lets a user update their own participant row.
    func leaveDrop(dropID: UUID, userID: UUID) async throws {
        try await client
            .from("drop_participants")
            .update(["status": ParticipantStatus.removed.rawValue])
            .eq("drop_id", value: dropID)
            .eq("user_id", value: userID)
            .execute()
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

    /// Decoding shape for `sharedDrops` — a participant row with the full `CalendarDrop` embedded.
    private struct SharedDropRow: Decodable {
        let status: ParticipantStatus
        let drop: CalendarDrop?
    }
}
