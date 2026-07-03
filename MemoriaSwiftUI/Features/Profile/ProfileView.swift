import SwiftUI

/// The Profile tab (step 10). TikTok-style: a large circular avatar with the user's name beneath,
/// a native header whose gear button pushes `SettingsView`. The user's drops grid will render below
/// the name later — not built yet.
struct ProfileView: View {
    @Environment(AppState.self) private var appState

    private var profile: Profile? { appState.profile }

    /// Shown under the avatar. Falls back to the handle, then empty, so it never shows a raw nil.
    private var displayName: String {
        profile?.displayName ?? profile?.username ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.md) {
                        AvatarView(url: profile?.avatarURL, name: displayName, size: 112)
                            .padding(.top, Spacing.xl)

                        Text(displayName)
                            .font(Typography.font(.xl, weight: .strong))
                            .foregroundStyle(Colors.textPrimary)

                        // The user's drops grid will render here later.
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Spacing.lg)
                }
            }
            .navigationTitle(profile.map { "@\($0.username)" } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .tint(Colors.textPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
