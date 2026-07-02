import SwiftUI

extension View {
    /// The common chrome for a single-line input field on a light-background screen —
    /// used across the ProfileSetup wizard's Name/Username/Age/Phone steps.
    func inputFieldStyle() -> some View {
        font(Typography.font(.body))
            .foregroundStyle(Colors.charcoal)
            .padding(Spacing.md)
            .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
    }
}
