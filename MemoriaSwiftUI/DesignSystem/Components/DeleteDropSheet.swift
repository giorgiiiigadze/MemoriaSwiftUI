import SwiftUI

/// Why the user is deleting a drop. Collected in the delete sheet for product insight; not persisted
/// or sent anywhere today — the delete proceeds regardless of the choice.
enum DropDeleteReason: String, CaseIterable, Identifiable {
    case mistake, wrongPhoto, privacy, cleaningUp, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mistake: "Posted by mistake"
        case .wrongPhoto: "Wrong or bad photo"
        case .privacy: "Privacy concern"
        case .cleaningUp: "Just cleaning up"
        case .other: "Other"
        }
    }
}

/// A bottom sheet that confirms deleting a drop by first asking *why*. Styled to match the Calendar
/// month picker (`MonthPickerSheet`): the sheet supplies its own `surfaceGrouped` background via
/// `.presentationBackground`, and the confirm control is the same white pill. The user must pick a
/// reason before the "Delete drop" button enables.
struct DeleteDropSheet: View {
    let dropTitle: String
    var onConfirm: (DropDeleteReason) -> Void

    @State private var selected: DropDeleteReason?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                Text("Delete drop")
                    .font(Typography.font(.lg, weight: .strong))
                    .foregroundStyle(Colors.textPrimary)

                Text("\"\(dropTitle)\" and all its photos will be permanently deleted for everyone.")
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.xs) {
                ForEach(DropDeleteReason.allCases) { reason in
                    reasonRow(reason)
                }
            }

            Button {
                if let selected { onConfirm(selected) }
            } label: {
                Text("Delete drop")
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
            }
            .disabled(selected == nil)
            .opacity(selected == nil ? 0.5 : 1)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }

    private func reasonRow(_ reason: DropDeleteReason) -> some View {
        let isSelected = selected == reason
        return Button {
            selected = reason
        } label: {
            HStack {
                Text(reason.label)
                    .font(Typography.font(.body))
                    .foregroundStyle(Colors.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(isSelected ? Colors.white : Colors.textTertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .background(
                Colors.surfaceRaised,
                in: RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
