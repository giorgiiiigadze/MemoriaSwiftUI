import SwiftUI

struct Chip: View {
    let label: String
    var textColor: Color = Colors.textPrimary
    var backgroundColor: Color = Colors.surfaceRaised

    var body: some View {
        Text(label)
            .font(Typography.font(.xs, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(backgroundColor, in: Capsule())
    }
}

#Preview {
    HStack(spacing: Spacing.xs) {
        Chip(label: "Collecting", backgroundColor: Colors.stateActive)
        Chip(label: "Ready", backgroundColor: Colors.stateReady)
        Chip(label: "Open", backgroundColor: Colors.stateOpen)
        Chip(label: "Expired", backgroundColor: Colors.stateExpired)
    }
    .padding()
    .background(Colors.background)
}
