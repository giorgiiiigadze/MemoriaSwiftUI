import SwiftUI

/// Pushed natively from the Home header's bell button (native slide-from-right + back button).
/// Lists the user's notifications; shows a native empty state until the feed is wired to Supabase.
struct NotificationsView: View {
    /// Real notifications will replace this once the fetch service lands.
    private let notifications: [AppNotification] = []

    var body: some View {
        ZStack {
            Colors.background.ignoresSafeArea()

            if notifications.isEmpty {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "bell.slash",
                    description: Text("You're all caught up. New activity will show up here.")
                )
            } else {
                List(notifications) { notification in
                    NotificationRow(notification: notification)
                        .listRowBackground(Colors.background)
                }
                .scrollContentBackground(.hidden)
                .background(Colors.background)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A single notification line. Icon + human-readable title, styled to match the app's dark palette.
private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Colors.accent)
                .frame(width: 28)

            Text(title)
                .font(Typography.font(.sm, weight: .medium))
                .foregroundStyle(Colors.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xs)
    }

    private var iconName: String {
        switch notification.type {
        case .dropInvited: "person.2.fill"
        case .dropReady, .dropOpened: "photo.stack.fill"
        case .dropOpeningSoon: "clock.fill"
        case .dropExpired: "hourglass"
        case .participantUploaded: "photo.badge.plus.fill"
        case .friendRequest: "person.crop.circle.badge.plus"
        case .friendAccepted: "person.crop.circle.badge.checkmark"
        }
    }

    private var title: String {
        switch notification.type {
        case .dropInvited: "You were invited to a drop"
        case .dropReady: "Your drop is ready"
        case .dropOpened: "A drop was opened"
        case .dropOpeningSoon: "A drop is opening soon"
        case .dropExpired: "A drop expired"
        case .participantUploaded: "Someone added a photo"
        case .friendRequest: "New friend request"
        case .friendAccepted: "Friend request accepted"
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
    .preferredColorScheme(.dark)
}
