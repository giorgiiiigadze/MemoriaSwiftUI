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
    @State private var isSkippingPhone = false

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
        guard step.isSkippable else { return nil }
        // Phone's Skip carries the early `profiles` upsert side effect, so it routes through the
        // store instead of a plain advance — but it's still the header pill, like every other
        // skippable step.
        if step == .phone {
            return isSkippingPhone ? nil : { skipPhone() }
        }
        return { goNext() }
    }

    private func skipPhone() {
        guard !isSkippingPhone else { return }
        isSkippingPhone = true
        Task {
            defer { isSkippingPhone = false }
            if await store.submitPhone(rawInput: nil) {
                goNext()
            }
        }
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
