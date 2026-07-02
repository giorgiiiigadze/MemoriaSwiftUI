import SwiftUI
import UserNotifications

/// Only requests permission — device-token registration is step 12's job (the APNs rewrite
/// of `send-push`), so the granted/denied result isn't acted on here.
struct NotificationsStepView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 40))
                .foregroundStyle(Colors.accent)
                .padding(.top, Spacing.xxl)

            Text("Stay in the loop")
                .font(Typography.font(.xl, weight: .semiBold))
                .foregroundStyle(Colors.charcoal)

            Text("Get notified when drops open, friends invite you, or new photos are added.")
                .font(Typography.font(.sm))
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            Spacer()

            ProfileSetupContinueButton(
                title: "Enable Notifications",
                isLoading: isRequesting,
                action: requestAndContinue
            )

            Button("Skip", action: onContinue)
                .font(Typography.font(.sm, weight: .medium))
                .foregroundStyle(Colors.textTertiary)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
    }

    private func requestAndContinue() {
        isRequesting = true
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isRequesting = false
            onContinue()
        }
    }
}

#Preview {
    NotificationsStepView(onContinue: {})
        .background(Colors.lightBackground)
}
