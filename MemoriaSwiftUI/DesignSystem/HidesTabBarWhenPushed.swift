import ObjectiveC
import SwiftUI
import UIKit

extension View {
    /// Fades the tab bar out while this screen is pushed on a `NavigationStack`, and fades it back
    /// in when it's popped — animating in sync with the push/pop transition (including the
    /// interactive swipe-back gesture). Unlike `.toolbar(.hidden, for: .tabBar)`, which cuts the bar
    /// in and out with no animation, this drives the real `UITabBar`'s alpha through the navigation
    /// transition coordinator.
    ///
    /// Correctly handles *stacked* hiding screens (e.g. Notifications → Drop Detail): the bar stays
    /// hidden across a deeper push and only reappears once you land back on a screen that shows it.
    func hidesTabBarWhenPushed() -> some View {
        background(TabBarHider().frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

private var hidesTabBarKey: UInt8 = 0
extension UIViewController {
    /// Tags a pushed controller whose screen wants the tab bar hidden, so a screen being popped can
    /// tell whether the screen it's revealing also wants it hidden.
    fileprivate var memoriaHidesTabBar: Bool {
        get { (objc_getAssociatedObject(self, &hidesTabBarKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &hidesTabBarKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

/// Cross-fades the enclosing `UITabBar`'s alpha alongside the navigation transition. Hooks
/// `viewWillAppear` / `viewWillDisappear` so it stays glued to the push, the pop, and the
/// interactive back-swipe; the coordinator's cancellation callback restores the prior alpha if a
/// swipe-back is abandoned.
private struct TabBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navStackController?.memoriaHidesTabBar = true
            // This (hiding) screen is becoming the top of the stack — hide the bar.
            setTabBar(hidden: true, animated: animated)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let nav = navigationController, let mine = navStackController else {
                setTabBar(hidden: false, animated: animated)
                return
            }
            if nav.viewControllers.contains(mine) {
                // Still in the stack — a deeper screen was pushed over us. Keep the bar hidden.
                setTabBar(hidden: true, animated: animated)
            } else {
                // We're being popped off — reveal the bar only if the screen we're returning to
                // doesn't also want it hidden.
                let targetHides = nav.viewControllers.last?.memoriaHidesTabBar ?? false
                setTabBar(hidden: targetHides, animated: animated)
            }
        }

        /// Our own controller at the navigation-stack level (the pushed hosting controller), found by
        /// walking up parents until the one whose parent is the navigation controller.
        private var navStackController: UIViewController? {
            guard let nav = navigationController else { return nil }
            var vc: UIViewController = self
            while let parent = vc.parent, parent !== nav { vc = parent }
            return vc.parent === nav ? vc : nil
        }

        private func setTabBar(hidden: Bool, animated: Bool) {
            guard let tabBar = tabBarController?.tabBar else { return }
            let target: CGFloat = hidden ? 0 : 1
            guard animated, let coordinator = transitionCoordinator else {
                tabBar.alpha = target
                return
            }
            coordinator.animate(alongsideTransition: { _ in
                tabBar.alpha = target
            }, completion: { [weak self] _ in
                // Reconcile to whatever screen actually landed on top once the transition settles.
                // This is what makes a *cancelled* interactive swipe-back correct: when you drag
                // back only slightly and let go, the gesture heads toward the (bar-showing) screen
                // underneath — but on release we snap back to this hiding screen, so the bar must
                // return to hidden. Reading the live top view controller (rather than restoring a
                // guessed pre-swipe alpha) keeps the bar in sync whether the swipe committed or not.
                guard let self else { return }
                tabBar.alpha = self.topHidesTabBar ? 0 : 1
            })
        }

        /// Whether the screen currently on top of the navigation stack wants the tab bar hidden.
        private var topHidesTabBar: Bool {
            navigationController?.topViewController?.memoriaHidesTabBar ?? false
        }
    }
}
