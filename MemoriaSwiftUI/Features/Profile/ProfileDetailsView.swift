import SwiftUI

/// Pushed from the profile row at the top of `SettingsView` (native slide + back button). Placeholder
/// for now — the real profile details / editing screen lands here later.
struct ProfileDetailsView: View {
    var body: some View {
        PlaceholderScreen(title: "Profile", subtitle: "Profile details are coming soon.")
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProfileDetailsView()
    }
    .preferredColorScheme(.dark)
}
