import SwiftUI

extension View {
    /// BeReal-style input for the auth and profile-setup flows: no background fill, text (and its
    /// placeholder) centered and enlarged, so the field reads as bold centered type rather than a
    /// boxed form control. Shrinks to fit so a long value (e.g. an email) stays on one line.
    ///
    /// The placeholder colour is still set per-field via the `TextField`/`SecureField` `prompt`;
    /// this only governs layout, size, and weight — which the prompt inherits.
    func inputFieldStyle() -> some View {
        font(Typography.font(.xxxl, weight: .semiBold))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Colors.textPrimary)
            .padding(.vertical, Spacing.md)
            .padding(.top, Spacing.sm)
    }
}
