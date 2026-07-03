import SwiftUI
import Supabase

/// Pushed natively from the Profile tab's gear button (native slide + back button). Home for
/// account/app settings; for now it hosts Log Out (relocated here from the Profile screen, which is
/// where a gear → settings path conventionally leads).
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    Task { try? await SupabaseClient.shared.auth.signOut() }
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .preferredColorScheme(.dark)
}
