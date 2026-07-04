import UIKit

/// Keeps the native edge swipe-to-go-back gesture working even on screens that hide the navigation
/// bar / back button (e.g. `DropDetailView`), where UIKit otherwise disables it. Re-points the
/// interactive pop gesture at our own delegate, which only allows it when there's something to pop
/// back to. Applies to every `NavigationStack` in the app (all backed by `UINavigationController`).
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
