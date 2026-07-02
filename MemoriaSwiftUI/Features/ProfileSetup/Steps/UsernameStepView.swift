import SwiftUI

struct UsernameStepView: View {
    @Environment(ProfileSetupStore.self) private var store
    let onContinue: () -> Void

    @State private var availability: ProfileSetupStore.UsernameAvailability = .idle

    private var statusText: String? {
        switch availability {
        case .idle: nil
        case .checking: "Checking availability…"
        case .available: "Available"
        case .taken: "That username is taken"
        case .invalid: "3-30 characters: lowercase letters, numbers, underscores"
        case .error(let message): message
        }
    }

    private var statusColor: Color {
        switch availability {
        case .available: Colors.success
        case .taken, .invalid, .error: Colors.error
        case .idle, .checking: Colors.textSecondary
        }
    }

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Pick a username")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
                .padding(.top, Spacing.xxl)

            TextField("", text: $store.username, prompt: Text("username").foregroundStyle(Colors.textPlaceholder))
                .inputFieldStyle()
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: store.username) { _, newValue in
                    let sanitized = String(
                        newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }.prefix(30)
                    )
                    if sanitized != newValue {
                        store.username = sanitized
                    }
                }
                .task(id: store.username) {
                    let candidate = store.username
                    guard !candidate.isEmpty else {
                        availability = .idle
                        return
                    }
                    availability = .checking
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    let result = await store.checkUsernameAvailability(candidate)
                    guard !Task.isCancelled else { return }
                    availability = result
                }

            if let statusText {
                Text(statusText)
                    .font(Typography.font(.sm))
                    .foregroundStyle(statusColor)
            }

            Spacer()

            ProfileSetupContinueButton(isEnabled: availability == .available, action: onContinue)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
    }
}

#Preview {
    UsernameStepView(onContinue: {})
        .environment(ProfileSetupStore(userID: UUID()))
        .background(Colors.background)
}
