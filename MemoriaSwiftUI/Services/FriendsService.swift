import Foundation
import Supabase

/// Minimal for now — just what the profile-setup wizard's Contacts step needs
/// ("send friend request inline"). Step 8 (Friends tab) extends this same file with
/// `acceptRequest`/`declineRequest`/`cancelRequest` rather than duplicating the insert.
final class FriendsService {
    private let client = SupabaseClient.shared

    /// Relies on the `friendships` table's `status` column defaulting to `'pending'`.
    func sendRequest(from requesterID: UUID, to addresseeID: UUID) async throws {
        try await client
            .from("friendships")
            .insert(["requester_id": requesterID, "addressee_id": addresseeID])
            .execute()
    }
}
