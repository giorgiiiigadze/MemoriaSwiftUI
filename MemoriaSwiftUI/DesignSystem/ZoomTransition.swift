import SwiftUI

/// Instagram-style zoom navigation transition helpers. The pushed page grows out of the tapped
/// source view and, on dismiss, shrinks back into it (instead of the default slide). Available on
/// iOS 18+; on iOS 17 these are no-ops so the app falls back to the standard push/pop.
extension View {
    /// Marks this view as the source a zoom-transitioned page grows out of / returns into. Apply to
    /// the tappable thumbnail; pair with `zoomNavigationTransition(sourceID:in:)` on the destination
    /// using the same `id` and `namespace`.
    @ViewBuilder
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Makes this destination page zoom out of / back into its matching `zoomTransitionSource`.
    @ViewBuilder
    func zoomNavigationTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}
