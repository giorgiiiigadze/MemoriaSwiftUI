import Foundation
import Observation
import Supabase

enum RootPhase {
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
    /// to sign-in. On a live action (`isColdBoot == false`) a missing profile row is expected
    /// for a brand-new sign-up (the row isn't created until the profile-setup wizard), so it
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
                try? await client.auth.signOut()
                return
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
