import Foundation
import Supabase

/// Thin wrapper around `SupabaseClient.shared.auth` for the sign-in/sign-up screen.
/// Routing after a successful call is handled by `AppState`'s standing listener on
/// `auth.authStateChanges` (both `signIn` and `signUp` emit `.signedIn` there) — this
/// store only needs to surface the one outcome that stream can't: whether a sign-up
/// requires email confirmation, since no session (and so no stream event) exists yet.
final class AuthStore {
    enum SignUpOutcome {
        case signedIn
        case confirmationRequired
    }

    private let client = SupabaseClient.shared

    func signIn(email: String, password: String) async throws {
        let email = Self.normalized(email)
        Self.logCredentialShape(context: "signIn", email: email, password: password)
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws -> SignUpOutcome {
        let email = Self.normalized(email)
        Self.logCredentialShape(context: "signUp", email: email, password: password)
        let response = try await client.auth.signUp(email: email, password: password)
        return response.session != nil ? .signedIn : .confirmationRequired
    }

    /// Predictive text / autocapitalization can leave a stray leading or trailing space in
    /// the email field, which fails Supabase's exact-match lookup with the same generic
    /// "invalid credentials" error as a wrong password — trim it before it ever reaches the SDK.
    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Never logs the raw password — only enough shape info (length, stray whitespace) to
    /// diagnose a credential-corruption bug without printing a secret to the console.
    private static func logCredentialShape(context: String, email: String, password: String) {
        #if DEBUG
        let hasLeadingSpace = password.first?.isWhitespace ?? false
        let hasTrailingSpace = password.last?.isWhitespace ?? false
        print("[AuthStore.\(context)] email=\"\(email)\" (\(email.count) chars) password.count=\(password.count) leadingSpace=\(hasLeadingSpace) trailingSpace=\(hasTrailingSpace)")
        #endif
    }
}
