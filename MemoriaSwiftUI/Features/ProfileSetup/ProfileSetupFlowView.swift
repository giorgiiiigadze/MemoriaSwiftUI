import SwiftUI

/// Full-screen, dark BeReal-style 7-step wizard shown after a fresh sign-up (or a sign-in
/// that never finished setup). Custom step chrome — no `NavigationStack` — since the spec
/// wants a bespoke header (glass back button, centered wordmark, glass Skip), not a system
/// nav bar.
struct ProfileSetupFlowView: View {
    let userID: UUID
    let onComplete: (Profile) -> Void

    @State private var store: ProfileSetupStore
    @State private var step: ProfileSetupStep = .name
    @State private var isShowingConfirmation = false

    init(userID: UUID, onComplete: @escaping (Profile) -> Void) {
        self.userID = userID
        self.onComplete = onComplete
        _store = State(initialValue: ProfileSetupStore(userID: userID))
    }

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()

            if isShowingConfirmation {
                ConfirmationStepView(onComplete: onComplete)
            } else {
                VStack(spacing: 0) {
                    ProfileSetupHeader(
                        onBack: headerBackAction,
                        onSkip: headerSkipAction
                    )

                    Group {
                        switch step {
                        case .name:
                            NameStepView(onContinue: goNext)
                        case .username:
                            UsernameStepView(onContinue: goNext)
                        case .photo:
                            PhotoStepView(onContinue: goNext)
                        case .age:
                            AgeStepView(onContinue: goNext)
                        case .phone:
                            // Phone's own Skip also needs the early-upsert side effect (with
                            // inline loading/error), so it renders its own Skip button rather
                            // than using the header's generic one — see `headerSkipAction`.
                            PhoneStepView(onContinue: goNext)
                        case .contacts:
                            ContactsStepView(onContinue: goNext)
                        case .notifications:
                            NotificationsStepView(onContinue: goNext)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .environment(store)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: step)
        .task {
            await store.loadExistingProfile()
        }
    }

    private var headerBackAction: (() -> Void)? {
        if step == .name { return nil }
        return { goBack() }
    }

    private var headerSkipAction: (() -> Void)? {
        guard step.isSkippable, step != .phone else { return nil }
        return { goNext() }
    }

    private func goNext() {
        if let next = ProfileSetupStep(rawValue: step.rawValue + 1) {
            step = next
        } else {
            isShowingConfirmation = true
        }
    }

    private func goBack() {
        if let previous = ProfileSetupStep(rawValue: step.rawValue - 1) {
            step = previous
        }
    }
}
