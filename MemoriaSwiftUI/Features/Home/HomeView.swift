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
                // Two buttons in one ToolbarItemGroup → the system renders them as a single
                // native Liquid Glass pill on iOS 26 (BeReal's top control), no custom capsule.
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        // TODO: notifications
                    } label: {
                        Image(systemName: "bell.fill")
                    }
                    Button {
                        // TODO: share / invite
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Memoria")
                        .font(Typography.font(.xl, weight: .strong))
                        .foregroundStyle(Colors.textPrimary)
                }
            }
            .tint(Colors.textPrimary)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    HomeView()
}
