import Foundation
import Supabase

/// Reads public profile data for viewing another user. `profiles` SELECT is public (RLS `read any`),
/// so this pulls only the non-sensitive columns we display — never phone or age.
final class ProfilesService {
    private let client = SupabaseClient.shared

    func fetchPublicProfile(id: UUID) async throws -> PublicProfile {
        try await client
            .from("profiles")
            .select("id, username, display_name, avatar_url, bio")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
}
