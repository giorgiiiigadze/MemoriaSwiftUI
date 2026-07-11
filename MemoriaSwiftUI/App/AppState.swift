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

/// A primary tab another view can ask `MainTabView` to switch to — e.g. an empty state's
/// "Find friends" button buried in a modal, which can't reach the tab selection directly.
enum AppTab {
    case home, friends, calendar, profile
}

/// Which auth flow the add-account cover opens on: `signIn` (existing account) or `signUp`
/// (create a new account), both presented over the app without losing the current session.
enum AddAccountMode {
    case signIn, signUp
}

/// A transient bottom notice (e.g. after a drop action — joined, left, declined). Owned by
/// `AppState.toast` and rendered once at the app root by `ToastView`, so any screen can raise one.
struct ToastState: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var systemImage: String?
}

/// One drop removed from the user's world (deleted, left, or declined). The `token` forces a fresh
/// value per removal, so observers re-fire even when the same drop id is removed twice (e.g. re-join
/// then leave again). See `AppState.markDropRemoved`.
struct DropRemoval: Equatable {
    let dropID: UUID
    private let token = UUID()
}

@Observable
final class AppState {
    private(set) var phase: RootPhase = .splash
    private(set) var session: Session?
    private(set) var profile: Profile?

    /// The accounts signed into on this device and which one is active. Backs the Profile account
    /// switcher; kept in sync by `hydrate` (which re-saves the active account, tokens and all, on
    /// every successful load and token refresh).
    let accounts = AccountStore()

    /// Drives the add-account cover: while true, `RootView` presents the auth flow over the app so
    /// the user can sign into another account without losing the current one.
    var isAddingAccount = false

    /// Which auth flow the add-account cover shows — sign in to an existing account, or create a
    /// brand-new one. Set by `beginAddAccount(mode:)` before the cover appears.
    var addAccountMode: AddAccountMode = .signIn

    /// Set when a switch fails because the stored token was stale; surfaced as an alert, then cleared.
    var switchErrorMessage: String?

    /// A one-shot request to switch primary tab, honored and cleared by `MainTabView`. Lets a deep
    /// view (e.g. the invite sheet's "Find friends" button) route to a tab it can't reach directly.
    var requestedTab: AppTab?

    /// The drop to open from an invite deep link (`memoria://drop/<id>`), once the user is joined.
    /// Observed by the Home tab's `.navigationDestination`, and cleared when that screen is popped.
    var pendingDropID: UUID?

    /// Bumped after a mutation outside the Home feed adds to it — currently joining a drop via a
    /// scanned QR — so the feed reloads at once instead of waiting on realtime or a manual pull.
    private(set) var homeFeedReloadToken = 0

    /// The most recent drop removed anywhere — deleted, left, or declined. Every list that shows
    /// drops (Home feed, Profile grid, Calendar) observes this and drops the matching card at once,
    /// so it's already gone on whichever screen you land on, without waiting for the realtime event.
    private(set) var lastDropRemoval: DropRemoval?

    /// A transient bottom toast (drop actions like joining or leaving). Raised via `showToast`; the
    /// app root renders it and it auto-clears after a couple of seconds.
    private(set) var toast: ToastState?
    private var toastDismissTask: Task<Void, Never>?

    /// A drop id captured from a deep link that arrived before we were signed in and in `.app`.
    /// Held until `enterApp`, then processed by `processLinkedDropIfReady`.
    private var linkedDropID: UUID?

    private let client = SupabaseClient.shared
    private let dropsService = DropsService()
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
        startBootWatchdog()
    }

    /// Safety net for boot: if an expired session is left waiting on a background refresh that never
    /// completes (e.g. launched offline, so no `.tokenRefreshed`/`.signedOut` ever arrives), we'd sit
    /// on the splash forever. After a generous grace period, fall back to a usable screen. A real
    /// refresh that lands later still flips us into `.app` via `hydrate`.
    private func startBootWatchdog() {
        Task {
            try? await Task.sleep(for: .seconds(12))
            guard phase == .splash else { return }
            phase = hasSeenOnboarding ? .auth : .onboarding
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

    /// Mirrors the DB trigger's `has_created_first_drop` flip locally once the user has a drop, so
    /// the Home "Create your first drop" tile hides immediately without waiting for a profile
    /// refetch. A no-op once already set.
    func markFirstDropCreated() {
        guard profile?.hasCreatedFirstDrop == false else { return }
        profile?.hasCreatedFirstDrop = true
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
        isAddingAccount = false
    }

    // MARK: Deep links

    /// Entry point for an incoming custom-scheme URL (`.onOpenURL`). Parses a `memoria://drop/<id>`
    /// link and remembers the target; if we're already signed in it opens right away, otherwise it's
    /// processed after `enterApp`. Non-drop or malformed links are ignored.
    func handleDeepLink(_ url: URL) {
        guard let dropID = DeepLink.dropID(from: url) else { return }
        linkedDropID = dropID
        Task { await processLinkedDropIfReady() }
    }

    /// If a deep-linked drop is pending and the app is ready (signed in, in `.app`), invite the
    /// caller to it (idempotent, best-effort) and route the Home tab to open it. The invite makes the
    /// drop readable under RLS, so `DropDetailView` can load it and show its Accept/Decline bar.
    private func processLinkedDropIfReady() async {
        guard phase == .app, session != nil, let dropID = linkedDropID else { return }
        linkedDropID = nil
        // Best-effort: if the invite fails (already a member, or a transient error) still try to open;
        // the detail screen will surface its own error if the drop truly isn't reachable.
        try? await dropsService.joinDrop(dropID: dropID)
        // Invite is committed — refresh the feed now so the drop is already there when the user backs
        // out of it, rather than depending on realtime latency.
        homeFeedReloadToken += 1
        requestedTab = .home
        pendingDropID = dropID
    }

    // MARK: Toast

    /// Raise a transient bottom toast. Replaces any current one and restarts the auto-dismiss timer.
    func showToast(_ text: String, systemImage: String? = nil) {
        toast = ToastState(text: text, systemImage: systemImage)
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    /// Dismiss the current toast immediately (e.g. on tap).
    func dismissToast() {
        toastDismissTask?.cancel()
        toast = nil
    }

    // MARK: Drop removal

    /// Signal that a drop was removed (deleted, left, or declined) so every drops list drops it
    /// optimistically — instant, without waiting for realtime. A new value each call (fresh token)
    /// so repeat removals of the same drop still fire.
    func markDropRemoved(_ id: UUID) {
        lastDropRemoval = DropRemoval(dropID: id)
    }

    // MARK: Account switching

    /// Presents the auth flow over the app so the user can add another account without signing out
    /// of the current one. The current session stays active (and already saved) until a new sign-in
    /// (or sign-up) replaces it, so cancelling just returns to the current account. `mode` picks
    /// whether the cover opens on the log-in flow (default) or the create-account (sign-up) flow.
    func beginAddAccount(mode: AddAccountMode = .signIn) {
        addAccountMode = mode
        isAddingAccount = true
    }

    func cancelAddAccount() {
        isAddingAccount = false
    }

    /// Swaps the active session to a previously-saved account — no password needed. Clears the
    /// user-scoped caches first so the incoming user never sees the previous user's data, then hands
    /// off to `setSession`, whose `.signedIn` event flows through `hydrate` like any other sign-in.
    func switchAccount(to id: UUID) async {
        guard id != accounts.activeID, let account = accounts.account(id: id) else { return }

        UserCaches.clear()
        phase = .splash
        do {
            _ = try await client.auth.setSession(
                accessToken: account.accessToken,
                refreshToken: account.refreshToken
            )
            // `.signedIn` fires → `hydrate` loads the new user and flips to `.app`.
        } catch {
            // The stored token was stale (rotated/expired) — this account needs a fresh login.
            accounts.remove(id: id)
            switchErrorMessage = "Couldn't switch to that account. Please add it again."
            // Recover to whatever session is still active in the SDK, or fall back to auth.
            if let current = try? await client.auth.session {
                await hydrate(session: current, isColdBoot: true)
            } else {
                session = nil
                profile = nil
                phase = .auth
            }
        }
    }

    /// Logs out of the *active* account. If another saved account exists, switches straight to it;
    /// otherwise clears caches and signs out fully, landing on the auth screen.
    func logOutActiveAccount() async {
        let currentID = accounts.activeID ?? session?.user.id
        if let currentID { accounts.remove(id: currentID) }

        // Switch to another saved account if one remains — never back to the one we just logged out.
        if let next = accounts.accounts.first(where: { $0.id != currentID }) {
            await switchAccount(to: next.id)
        } else {
            UserCaches.clear()
            try? await client.auth.signOut()
        }
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
            UserCaches.clear()
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
                    // Cold boot on an unfinished account (e.g. a second "Create account" that was
                    // abandoned): recover to another saved account rather than stranding the user.
                    recoverFromUnusableSession(currentUserID: session.user.id)
                }
                return
            }

            // Warm the avatar into the on-disk cache while the splash is still up, so the Profile
            // tab's photo is instant the moment the tabs appear instead of downloading on-appear.
            if let avatarURL = profile.avatarURL, let url = URL(string: avatarURL) {
                await AvatarImageCache.prefetch(url)
            }

            enterApp(with: profile, session: session)
        } catch {
            // A row that genuinely doesn't exist yet: brand-new signup on a live action → setup;
            // on cold boot it's a broken/half-deleted account → recover.
            if let postgrestError = error as? PostgrestError, postgrestError.code == "PGRST116" {
                if !isColdBoot {
                    phase = .profileSetup
                } else {
                    recoverFromUnusableSession(currentUserID: session.user.id)
                }
                return
            }

            // Transient connectivity failure: NEVER tear down a valid session just because the
            // network is unreachable. Fall back to the last cached profile so a returning user
            // opening offline stays signed in; with no cache, land softly and let a later launch or
            // the SDK's background refresh retry — the session is left intact either way.
            if error.isConnectivityError {
                if let cached = ProfileCache.load(), cached.id == session.user.id {
                    enterApp(with: cached, session: session)
                } else {
                    phase = hasSeenOnboarding ? .auth : .onboarding
                }
                return
            }

            // Any other error is a definitive server/auth rejection (e.g. revoked token) → don't sit
            // in a broken app; recover to a saved account or sign out cleanly.
            recoverFromUnusableSession(currentUserID: session.user.id)
        }
    }

    /// Enters the app with a loaded (fresh or cached) profile: sets state, caches the profile for
    /// offline boots, and re-saves this account with its current tokens so it stays a fast-switch
    /// target and its stored refresh token never goes stale.
    private func enterApp(with profile: Profile, session: Session) {
        self.profile = profile
        ProfileCache.store(profile)
        hasSeenOnboarding = true
        phase = .app
        isAddingAccount = false
        accounts.upsert(
            SavedAccount(
                id: session.user.id,
                username: profile.username,
                displayName: profile.displayName,
                avatarURL: profile.avatarURL,
                accessToken: session.accessToken,
                refreshToken: session.refreshToken
            ),
            active: true
        )
        // A deep link may have arrived on a cold boot before we were signed in — open it now.
        Task { await processLinkedDropIfReady() }
    }

    /// A session we can't turn into a usable `.app` state (unfinished/missing/rejected profile). If
    /// another saved account exists, switch to it so the user isn't dumped on the sign-in screen
    /// (with the switcher out of reach); otherwise forget this account and sign out cleanly. Excludes
    /// the current user id so a broken saved account can't loop back into itself.
    private func recoverFromUnusableSession(currentUserID: UUID?) {
        if let fallback = accounts.accounts.first(where: { $0.id != currentUserID }) {
            Task { await switchAccount(to: fallback.id) }
        } else {
            if let currentUserID { accounts.remove(id: currentUserID) }
            Task { try? await client.auth.signOut() }
        }
    }
}
