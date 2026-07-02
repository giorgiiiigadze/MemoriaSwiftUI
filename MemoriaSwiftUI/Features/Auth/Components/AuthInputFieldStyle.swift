import SwiftUI

extension View {
    /// BeReal-style auth input: no background fill, text (and its placeholder) centered and
    /// enlarged, so the field reads as bold centered type rather than a boxed form control.
    /// Used by the sign-up email/password steps. The placeholder colour is still set per-field
    /// via the `TextField`/`SecureField` `prompt`; this only governs layout, size, and weight —
    /// which the prompt inherits.
    func authInputFieldStyle() -> some View {
        font(Typography.font(.xxl, weight: .semiBold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Colors.textPrimary)
            .padding(.vertical, Spacing.md)
    }
}
