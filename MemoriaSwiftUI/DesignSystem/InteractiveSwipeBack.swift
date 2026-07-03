import SwiftUI
import UIKit

/// Re-enables the interactive edge-swipe-back gesture on the enclosing `UINavigationController`.
///
/// Hiding the system back button (`navigationBarBackButtonHidden(true)`) — which the login push
/// does so only the app's custom glass header shows — also disables `UINavigationController`'s
/// `interactivePopGestureRecognizer`, so the screen can only be dismissed via the header button.
/// Clearing the gesture's delegate restores the swipe-back, and NavigationStack still updates the
/// driving `isPresented` binding when the pop completes.
private struct InteractiveSwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    /// Grabs the gesture on `didMove(toParent:)`, once the view is actually in the navigation
    /// hierarchy — `navigationController` is nil at init time.
    private final class SwipeBackController: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

extension View {
    /// Restores the native edge-swipe-back gesture on a pushed screen whose system back button is
    /// hidden. Apply to the pushed view's content.
    func interactiveSwipeBack() -> some View {
        background(InteractiveSwipeBackEnabler())
    }
}
