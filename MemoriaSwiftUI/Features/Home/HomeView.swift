import SwiftUI

/// The Home tab (step 5 — drop feed). Native navigation header with the centered "Memoria"
/// wordmark (matching the auth flow's styling) as the principal item.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background.ignoresSafeArea()
                PlaceholderScreen(title: "Home", subtitle: "Drop feed — step 5")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Memoria")
                        .font(Typography.font(.xl, weight: .strong))
                        .foregroundStyle(Colors.textPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    HomeView()
}
