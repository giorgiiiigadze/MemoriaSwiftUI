import SwiftUI

extension View {
    /// The common chrome for a single-line input field on a dark-background screen —
    /// used across the ProfileSetup wizard's Name/Username/Age/Phone steps.
    func inputFieldStyle() -> some View {
        font(Typography.font(.body))
            .foregroundStyle(Colors.textPrimary)
            .padding(Spacing.md)
            .background(Colors.surfaceInput, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
    }
}
