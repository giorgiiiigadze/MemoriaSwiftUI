import SwiftUI

/// Placeholder destinations for the Settings rows. Each is pushed from `SettingsView` and reuses the
/// shared `PlaceholderScreen` until its real content lands (Notification Settings ships with the
/// notification system; the rest fill in per feature).

struct NotificationSettingsView: View {
    var body: some View {
        PlaceholderScreen(title: "Notifications", subtitle: "Per-type push toggles and quiet hours are coming soon.")
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        PlaceholderScreen(title: "Privacy & Safety", subtitle: "Blocked users and invite controls are coming soon.")
            .navigationTitle("Privacy & Safety")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataStorageSettingsView: View {
    var body: some View {
        PlaceholderScreen(title: "Data & Storage", subtitle: "Cache and storage controls are coming soon.")
            .navigationTitle("Data & Storage")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        PlaceholderScreen(title: "About", subtitle: "Help, feedback, and legal are coming soon.")
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
    }
}
