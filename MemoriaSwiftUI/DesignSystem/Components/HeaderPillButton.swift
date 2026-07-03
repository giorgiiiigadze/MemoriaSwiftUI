import SwiftUI

/// A compact capsule button for library/header rows — e.g. the "Select" action that sits opposite
/// the library's segmented toggle. Uses `Colors.surfaceRaised` for its capsule fill so it reads as
/// header chrome at the same visual elevation as the toggle on the other side of the row.
struct HeaderPillButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.font(.md, weight: .semiBold))
                .foregroundStyle(Colors.textPrimary)
                // Match the segmented control's label insets so both pills share a height.
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Colors.surfaceRaised, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HeaderPillButton("Select") {}
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Colors.background)
}
