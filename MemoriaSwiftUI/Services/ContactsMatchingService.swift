import Contacts
import Foundation
import Supabase

struct DeviceContact: Hashable {
    let name: String
    let normalizedPhone: String
}

struct MatchedContact: Identifiable, Hashable {
    let contact: DeviceContact
    let profile: Profile

    var id: UUID { profile.id }
}

enum ContactsMatchingError: Error {
    case accessDenied
}

/// Reused by both the profile-setup wizard's Contacts step and the Friends tab's
/// "Suggested" section (step 8) — same normalization and matching logic in both places
/// so a user's own `profiles.phone` (written via the same `normalize(_:)`) is found
/// consistently regardless of which flow is doing the matching.
final class ContactsMatchingService {
    private let client = SupabaseClient.shared

    /// Keeps a leading `+` as-is; otherwise assumes a bare 10-digit number is US and
    /// prefixes `+1` — also accepting the common 11-digit "1XXXXXXXXXX" form (a leading
    /// US country-code digit with no `+`, e.g. how contacts are frequently stored on-device).
    /// Anything else can't be normalized reliably, so it's dropped.
    ///
    /// `nonisolated` (the type defaults to `@MainActor`) because it's a pure string
    /// transform with no actor state — this lets `fetchDeviceContacts`' off-main-actor
    /// `enumerateContacts` closure call it directly.
    nonisolated static func normalize(_ raw: String) -> String? {
        let allowed = raw.filter { $0.isNumber || $0 == "+" }
        if allowed.hasPrefix("+") {
            return allowed
        }
        var digits = allowed.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("1") {
            digits.removeFirst()
        }
        guard digits.count == 10 else { return nil }
        return "+1" + digits
    }

    /// `nonisolated` so the blocking `enumerateContacts(with:)` call below runs off the main
    /// actor — this project defaults every type to `@MainActor` isolation
    /// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), and Apple's Contacts framework
    /// explicitly documents that method as unsafe to call on the main thread.
    nonisolated func fetchDeviceContacts() async throws -> [DeviceContact] {
        let store = CNContactStore()
        let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
        guard granted else { throw ContactsMatchingError.accessDenied }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)

        var contacts: [DeviceContact] = []
        try store.enumerateContacts(with: request) { contact, _ in
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !name.isEmpty else { return }

            for labeledPhone in contact.phoneNumbers {
                if let normalized = Self.normalize(labeledPhone.value.stringValue) {
                    contacts.append(DeviceContact(name: name, normalizedPhone: normalized))
                }
            }
        }
        return contacts
    }

    /// Splits `contacts` into those whose normalized phone matches an existing `profiles.phone`
    /// (excluding `userID`, the caller's own row) and those that don't, in a single query.
    func matchProfiles(
        for contacts: [DeviceContact],
        excluding userID: UUID
    ) async throws -> (onMemoria: [MatchedContact], notOnMemoria: [DeviceContact]) {
        guard !contacts.isEmpty else { return ([], []) }

        let phoneNumbers = Array(Set(contacts.map(\.normalizedPhone)))
        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .in("phone", values: phoneNumbers)
            .neq("id", value: userID)
            .execute()
            .value

        let profilesByPhone = Dictionary(
            profiles.compactMap { profile -> (String, Profile)? in
                guard let phone = profile.phone else { return nil }
                return (phone, profile)
            },
            uniquingKeysWith: { first, _ in first }
        )

        var onMemoria: [MatchedContact] = []
        var notOnMemoria: [DeviceContact] = []
        for contact in contacts {
            if let profile = profilesByPhone[contact.normalizedPhone] {
                onMemoria.append(MatchedContact(contact: contact, profile: profile))
            } else {
                notOnMemoria.append(contact)
            }
        }
        return (onMemoria, notOnMemoria)
    }
}
