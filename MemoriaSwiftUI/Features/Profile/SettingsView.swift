import SwiftUI
import Supabase

/// Pushed natively from the Profile tab's gear button (native slide + back button). Home for
/// account/app settings; for now it hosts Log Out (relocated here from the Profile screen, which is
/// where a gear → settings path conventionally leads).
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}
