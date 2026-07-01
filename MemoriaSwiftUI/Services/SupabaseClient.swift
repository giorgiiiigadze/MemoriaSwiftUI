import Foundation
import Supabase

private enum SupabaseSecrets {
    static let url: URL = {
        guard
            let host = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL_HOST") as? String,
            !host.isEmpty,
            let url = URL(string: "https://\(host)")
        else {
            fatalError("Missing SUPABASE_URL_HOST in Info.plist — fill in SUPABASE_PROJECT_URL_HOST in Secrets.xcconfig")
        }
        return url
    }()

    static let anonKey: String = {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        else {
            fatalError("Missing SUPABASE_ANON_KEY — fill it in Secrets.xcconfig")
        }
        return key
    }()
}

extension SupabaseClient {
    /// Auth session persistence uses `supabase-swift`'s default `KeychainLocalStorage` —
    /// never `UserDefaults` for tokens.
    ///
    /// `emitLocalSessionAsInitialSession: true` opts into the SDK's upcoming default: the
    /// locally stored session (if any) is always emitted as `.initialSession`, even if
    /// expired, instead of silently becoming `nil` when a background refresh attempt fails.
    /// `AppState.hydrate` checks `session.isExpired` to account for this.
    static let shared = SupabaseClient(
        supabaseURL: SupabaseSecrets.url,
        supabaseKey: SupabaseSecrets.anonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true)
        )
    )
}
