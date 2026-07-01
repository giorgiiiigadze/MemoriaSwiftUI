import SwiftUI
import Supabase

struct ProfileView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Profile",
            subtitle: "Profile tab — step 10",
            actionTitle: "Log Out",
            action: { Task { try? await SupabaseClient.shared.auth.signOut() } }
        )
    }
}

#Preview {
    ProfileView()
}
