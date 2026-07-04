import Foundation
import Supabase

/// Reads and mutates the `friendships` graph for the Friends tab (step 8) and the profile-setup
/// wizard's Contacts step. All writes stay within the table's row-level security: a request may be
/// inserted only with `requester_id = me`, and accepted/declined only by the `addressee`.
final class FriendsService {
    private let client = SupabaseClient.shared

    /// Relies on the `friendships` table's `status` column defaulting to `'pending'`.
    func sendRequest(from requesterID: UUID, to addresseeID: UUID) async throws {
        try await client
            .from("friendships")
            .insert(["requester_id": requesterID, "addressee_id": addresseeID])
            .execute()
    }

    /// Both profiles of each friendship embedded through the `requester_id` / `addressee_id`
    /// foreign keys, so partitioning into friends/incoming/outgoing needs no extra round-trip.
    private static let connectionsSelect = """
    id, requester_id, addressee_id, status, created_at, updated_at, \
    requester:profiles!requester_id(id, username, display_name, avatar_url), \
    addressee:profiles!addressee_id(id, username, display_name, avatar_url)
    """

    /// Every friendship the user is part of (RLS already scopes it to them), split into the three
    /// buckets the Friends tab renders. Accepted friendships collapse to "the other person".
    func fetchConnections(userID: UUID) async throws -> FriendConnections {
        let id = userID.uuidString.lowercased()
        let rows: [FriendshipRow] = try await client
            .from("friendships")
            .select(Self.connectionsSelect)
            .or("requester_id.eq.\(id),addressee_id.eq.\(id)")
            .execute()
            .value

        var result = FriendConnections()
        for row in rows {
            let iAmRequester = row.requesterId == userID
            guard let other = iAmRequester ? row.addressee : row.requester else { continue }
            switch row.status {
            case .accepted:
                result.friends.append(Friend(friendshipID: row.id, profile: other, since: row.updatedAt))
            case .pending:
                let request = FriendRequest(friendshipID: row.id, profile: other)
                if iAmRequester { result.outgoing.append(request) } else { result.incoming.append(request) }
            case .blocked:
                break
            }
        }
        result.friends.sort { $0.since > $1.since }
        return result
    }

    /// Username search (case-insensitive substring), excluding the caller. `profiles` SELECT is
    /// public, so this reaches anyone; callers gate it on a ≥2-character query.
    func search(query: String, excluding userID: UUID) async throws -> [DropWithParticipants.ProfileRef] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return [] }
        return try await client
            .from("profiles")
            .select("id, username, display_name, avatar_url")
            .ilike("username", pattern: "%\(term)%")
            .neq("id", value: userID)
            .limit(20)
            .execute()
            .value
    }

    /// Remove a friendship entirely. Either party may delete their accepted friendship (RLS allows
    /// both the requester and the addressee), so the pair can friend again later.
    func unfriend(friendshipID: UUID) async throws {
        try await client
            .from("friendships")
            .delete()
            .eq("id", value: friendshipID)
            .execute()
    }

    /// Accept a received request — only the addressee may, enforced by RLS.
    func accept(friendshipID: UUID) async throws {
        try await client
            .from("friendships")
            .update(["status": FriendStatus.accepted.rawValue])
            .eq("id", value: friendshipID)
            .execute()
    }

    /// Decline a received request. Only the addressee may write here and RLS forbids them deleting
    /// the row (that's the requester's right), so a decline moves it to `blocked` — a terminal state
    /// that drops it out of both users' pending lists.
    func decline(friendshipID: UUID) async throws {
        try await client
            .from("friendships")
            .update(["status": FriendStatus.blocked.rawValue])
            .eq("id", value: friendshipID)
            .execute()
    }
}

/// Decoding shape for the `fetchConnections` query — a friendship row with both profiles embedded.
private struct FriendshipRow: Decodable {
    let id: UUID
    let requesterId: UUID
    let addresseeId: UUID
    let status: FriendStatus
    let createdAt: Date
    let updatedAt: Date
    let requester: DropWithParticipants.ProfileRef?
    let addressee: DropWithParticipants.ProfileRef?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case requester
        case addressee
    }
}
