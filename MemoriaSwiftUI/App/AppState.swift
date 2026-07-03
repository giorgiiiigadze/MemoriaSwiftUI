import Foundation
import Observation
import Supabase

enum RootPhase: Equatable {
    case splash
    case onboarding
    case auth
    case profileSetup
    case app
}

@Observable
final class AppState {
    private(set) var phase: RootPhase = .splash
    private(set) var session: Session?
    private(set) var profile: Profile?

    private let client = SupabaseClient.shared
    private var authStateTask: Task<Void, Never>?

    private var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenOnboarding") }
    }

    func start() {
        guard authStateTask == nil else { return }
        authStateTask = Task {
            for await (event, session) in client.auth.authStateChanges {
                await handle(event: event, session: session)
            }
        }
    }

    /// Stand-in for the real 4-slide onboarding carousel's "done" action (step 4)
    /// so the auth screen is reachable before that carousel exists.
    func skipOnboarding() {
        hasSeenOnboarding = true
        phase = .auth
    }

    /// Called by `ProfileSetupFlowView` once its confirmation screen's final upsert succeeds.
    /// No new `authStateChanges` event fires for a Postgrest write, so the wizard hands the
    /// finished `Profile` back directly instead of waiting on the stream listener.
    func completeProfileSetup(_ profile: Profile) {
        self.profile = profile
        hasSeenOnboarding = true
        phase = .app
    }

    /// Called by `AuthView` right after a successful sign-up that returns a session
    /// immediately (no email confirmation step). Skips straight to `.profileSetup` instead
    /// of waiting on the `authStateChanges` listener to independently pick up `.signedIn`
    /// and run `hydrate`'s `profiles` lookup — a fresh sign-up's row (from
    /// `handle_new_user()`) never has `display_name` set, so that lookup's outcome is
    /// already known here without the extra network round-trip.
    ///
    /// `hydrate` still runs when the listener's own `.signedIn` event arrives moments
    /// later; it's a harmless, redundant re-confirmation of the same `.profileSetup` phase.
    func beginProfileSetup(session: Session) {
        self.session = session
        phase = .profileSetup
    }

    private func handle(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .tokenRefreshed:
            // `.initialSession` fires exactly once, at listener startup — cold-boot state
            // restoration. `.tokenRefreshed` can complete a boot-time refresh of an expired
            // stored session, so it's treated as part of the same cold-boot path.
            await hydrate(session: session, isColdBoot: true)
        case .signedIn:
            // A live action in this app session (the user just tapped Sign In or Sign Up),
            // not a relaunch — see `hydrate`'s `isColdBoot` handling for why this matters.
            await hydrate(session: session, isColdBoot: false)
        case .signedOut:
            self.session = nil
            self.profile = nil
            phase = .auth
        case .passwordRecovery, .userUpdated, .userDeleted, .mfaChallengeVerified:
            break
        }
    }

    /// Boot hydration: no session → onboarding (first launch) or sign-in; a session with
    /// no usable profile means signup never finished.
    ///
    /// On a cold boot this mirrors the RN app's defensive behavior: sign out and send back
    /// to sign-in. On a live action (`isColdBoot == false`) an unusable profile — either no
    /// row at all, or the bare row `handle_new_user()` inserts synchronously on sign-up
    /// (username + phone, no display_name) — is expected for a brand-new sign-up, so it
    /// routes into `.profileSetup` instead — signing the user out here would immediately
    /// dead-end a successful sign-up.
    ///
    /// An expired session is left alone: the SDK kicks off its own background refresh for
    /// expired sessions emitted via `.initialSession`, which resolves as a later
    /// `.tokenRefreshed` (re-enters this method) or `.signedOut` event.
    private func hydrate(session: Session?, isColdBoot: Bool) async {
        guard let session else {
            phase = hasSeenOnboarding ? .auth : .onboarding
            return
        }
        guard !session.isExpired else { return }
        self.session = session

        do {
            let profile: Profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: session.user.id)
                .single()
                .execute()
                .value

            guard let displayName = profile.displayName, !displayName.isEmpty else {
                // `handle_new_user()` inserts a bare `profiles` row (username + phone, no
                // display_name) synchronously on every sign-up, so this — not a missing row —
                // is what a brand-new signup actually looks like on a live action.
                if !isColdBoot {
                    phase = .profileSetup
                } else {
                    try? await client.auth.signOut()
                }
                return
            }

            // Warm the avatar into the on-disk cache while the splash is still up, so the Profile
            // tab's photo is instant the moment the tabs appear instead of downloading on-appear.
            if let avatarURL = profile.avatarURL, let url = URL(string: avatarURL) {
                await AvatarImageCache.prefetch(url)
            }

            self.profile = profile
            hasSeenOnboarding = true
            phase = .app
        } catch {
            if !isColdBoot, let postgrestError = error as? PostgrestError, postgrestError.code == "PGRST116" {
                phase = .profileSetup
                return
            }
            try? await client.auth.signOut()
        }
    }
}
