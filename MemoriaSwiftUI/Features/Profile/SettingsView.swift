import SwiftUI
import Supabase

/// Pushed natively from the Profile tab's gear button (native slide + back button). Home for
/// account/app settings; for now it hosts Log Out (relocated here from the Profile screen, which is
/// where a gear → settings path conventionally leads).
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    private var profile: Profile? { appState.profile }

    /// Shown in the profile row. Falls back to the handle, then empty, so it never renders a raw nil.
    private var displayName: String {
        profile?.displayName ?? profile?.username ?? ""
    }

    var body: some View {
        List {
            // FIRST section: the Apple-ID-style profile row — avatar + name + handle, into the
            // profile screen.
            Section {
                NavigationLink {
                    ProfileDetailsView()
                } label: {
                    HStack(spacing: Spacing.md) {
                        AvatarView(url: profile?.avatarURL, name: displayName, size: 56)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(displayName)
                                .font(Typography.font(.md, weight: .semiBold))
                                .foregroundStyle(Colors.textPrimary)
                            if let username = profile?.username {
                                Text("@\(username)")
                                    .font(Typography.font(.sm))
                                    .foregroundStyle(Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xxs)
                }
            }

            Section {
                settingsRow("Notifications", systemImage: "bell.fill") { NotificationSettingsView() }
                settingsRow("Privacy & Safety", systemImage: "lock.fill") { PrivacySettingsView() }
            } header: {
                sectionHeader("Preferences")
            }

            Section {
                settingsRow("Data & Storage", systemImage: "externaldrive.fill") { DataStorageSettingsView() }
                settingsRow("About", systemImage: "info.circle.fill") { AboutView() }
            } header: {
                sectionHeader("General")
            }

            // LAST section: sign out.
            Section {
                Button(role: .destructive) {
                    // Logs out the active account; if another account is saved, switches straight to
                    // it instead of dropping all the way back to the sign-in screen.
                    Task { await appState.logOutActiveAccount() }
                } label: {
                    Text("Log Out")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Colors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A bold, sentence-case section title matching the Profile tab's drop-section headers (rather
    /// than the List's default tiny uppercase grey caption).
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.font(.md, weight: .strong))
            .foregroundStyle(Colors.textPrimary)
            .textCase(nil)
    }

    /// A standard settings row: an SF Symbol + title that pushes `destination`.
    private func settingsRow<Destination: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
            }
            .foregroundStyle(Colors.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}
