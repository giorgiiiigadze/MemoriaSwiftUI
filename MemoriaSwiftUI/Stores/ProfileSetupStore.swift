import Foundation
import Observation
import Supabase
import UIKit

enum ProfileSetupError: Error {
    case invalidImage
    case usernameUnavailable
}

/// Shared across all 7 wizard steps (unlike `AuthStore`, which is stateless and
/// view-owned) since every step reads/writes the same in-progress profile.
@Observable
final class ProfileSetupStore {
    let userID: UUID

    var name = ""
    var username = ""
    var avatarURL: String?
    var age: Int?
    var phone: String?

    /// Surfaced on the Phone step for either entry point (Continue button or header Skip pill),
    /// since both now run through `submitPhone(rawInput:)`.
    var phoneEntryError: String?

    private let client = SupabaseClient.shared

    init(userID: UUID) {
        self.userID = userID
    }

    /// Restores progress already persisted for this user — either the bare row
    /// `handle_new_user()` inserts synchronously on sign-up (placeholder username + phone),
    /// or a fuller row from an earlier, interrupted run through this wizard (`upsertEarly()`
    /// writes name/username/avatar/age/phone together). Called once when the flow appears;
    /// failures are silently ignored so a row that can't be read yet just leaves every field
    /// at its default.
    ///
    /// Without this, every field starts blank on each run, which is how Skip on the Phone
    /// step used to silently overwrite an already-saved `phone` with `NULL` on upsert.
    func loadExistingProfile() async {
        guard let profile: Profile = try? await client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value
        else { return }

        if let displayName = profile.displayName, !displayName.isEmpty {
            name = displayName
        }
        // Leave the trigger's placeholder username out so the Username step still starts
        // blank for a real choice — only a username the user (or a prior run through this
        // wizard) actually chose is worth pre-filling.
        if profile.username != Self.placeholderUsername(for: userID) {
            username = profile.username
        }
        avatarURL = profile.avatarURL
        age = profile.age
        phone = profile.phone
    }

    /// Mirrors `'user_' || substr(new.id::text, 1, 8)` from the `handle_new_user()` trigger.
    private static func placeholderUsername(for userID: UUID) -> String {
        "user_" + userID.uuidString.lowercased().prefix(8)
    }

    enum UsernameAvailability: Equatable {
        case idle
        case checking
        case available
        case taken
        case invalid
        case error(String)
    }

    func checkUsernameAvailability(_ candidate: String) async -> UsernameAvailability {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            trimmed.count >= 3,
            trimmed.count <= 30,
            trimmed.range(of: "^[a-z0-9_]+$", options: .regularExpression) != nil
        else {
            return .invalid
        }

        do {
            let response = try await client
                .from("profiles")
                .select("id", head: true, count: .exact)
                .eq("username", value: trimmed)
                .neq("id", value: userID)
                .execute()
            return (response.count ?? 0) > 0 ? .taken : .available
        } catch {
            return .error(error.localizedDescription)
        }
    }

    /// Always re-encodes to JPEG for a predictable path/extension/size regardless of the
    /// source format (HEIC, PNG, etc.) the photo library hands back.
    func uploadAvatar(_ data: Data) async throws -> String {
        guard
            let image = UIImage(data: data),
            let jpegData = image.jpegData(compressionQuality: 0.85)
        else {
            throw ProfileSetupError.invalidImage
        }

        // Lowercased to match `auth.uid()::text` (Postgres UUIDs are lowercase) — the avatars
        // bucket's RLS policy scopes writes to `{auth.uid()}/…`, and Swift's `UUID` interpolates
        // as uppercase, which would fail that folder check.
        let path = "\(userID.uuidString.lowercased())/avatar.jpg"
        try await client.storage.from("avatars").upload(
            path,
            data: jpegData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let publicURL = try client.storage.from("avatars").getPublicURL(path: path).absoluteString
        avatarURL = publicURL
        // Seed the disk cache with the bytes we already have, so the Profile tab shows this photo
        // instantly on the first entry into `.app` right after setup — no download round-trip.
        if let url = URL(string: publicURL) {
            AvatarImageCache.store(jpegData, for: url)
        }
        return publicURL
    }

    /// Called from the Phone step — both its Continue and Skip actions.
    func upsertEarly() async throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await performUpsert(username: trimmed)
    }

    /// The Phone step's shared submit path, used by both its Continue button and the header
    /// Skip pill. `rawInput == nil` (Skip) advances without recording a number; a non-empty
    /// entry is validated/normalized first. Persists via `upsertEarly()`. Returns whether the
    /// step may advance; on failure `phoneEntryError` holds the message to show.
    func submitPhone(rawInput: String?) async -> Bool {
        phoneEntryError = nil

        if let rawInput {
            let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                guard let normalized = ContactsMatchingService.normalize(trimmed) else {
                    phoneEntryError = "That doesn't look like a valid phone number."
                    return false
                }
                phone = normalized
            }
        }

        do {
            try await upsertEarly()
            return true
        } catch {
            phoneEntryError = error.localizedDescription
            return false
        }
    }

    /// Called from the confirmation screen. Falls back to an auto-generated username in the
    /// (should-be-unreachable) case it's somehow still empty at this point, per spec.
    func finalize() async throws -> Profile {
        var finalUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalUsername.isEmpty {
            finalUsername = Self.generateUsername(from: name)
        }
        return try await performUpsert(username: finalUsername)
    }

    private struct ProfileUpsertPayload: Encodable {
        let id: UUID
        let username: String
        let displayName: String
        let avatarURL: String?
        let age: Int?
        let phone: String?

        enum CodingKeys: String, CodingKey {
            case id, username
            case displayName = "display_name"
            case avatarURL = "avatar_url"
            case age, phone
        }
    }

    /// Retries with a random 4-digit suffix on a `username` unique-violation race (someone
    /// else took the same name between the step-2 availability check and this write), bounded
    /// so a pathological run can't loop forever.
    private func performUpsert(username: String) async throws -> Profile {
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var attemptUsername = username

        for attempt in 0..<5 {
            let payload = ProfileUpsertPayload(
                id: userID,
                username: attemptUsername,
                displayName: displayName,
                avatarURL: avatarURL,
                age: age,
                phone: phone
            )
            do {
                let profile: Profile = try await client
                    .from("profiles")
                    .upsert(payload)
                    .select()
                    .single()
                    .execute()
                    .value
                self.username = attemptUsername
                return profile
            } catch let error as PostgrestError where error.code == "23505" {
                if attempt == 4 { throw error }
                attemptUsername = "\(username)\(Int.random(in: 1000...9999))"
            }
        }

        throw ProfileSetupError.usernameUnavailable
    }

    private static func generateUsername(from name: String) -> String {
        let base = name
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
            .prefix(20)
        let normalizedBase = base.isEmpty ? "user" : String(base)
        return "\(normalizedBase)\(Int.random(in: 1000...9999))"
    }
}
