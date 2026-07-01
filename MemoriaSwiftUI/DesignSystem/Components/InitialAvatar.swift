import SwiftUI

struct InitialAvatar: View {
    let name: String
    var size: CGFloat = 40
    var backgroundColor: Color = Colors.surfaceRaised
    var foregroundColor: Color = Colors.textPrimary

    private var initials: String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var body: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(Typography.font(.sm, weight: .semiBold))
                    .foregroundStyle(foregroundColor)
            }
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        InitialAvatar(name: "Giorgi Giorgadze")
        InitialAvatar(name: "Ada", size: 56, backgroundColor: Colors.accent, foregroundColor: Colors.ink)
        InitialAvatar(name: "")
    }
    .padding()
    .background(Colors.background)
}
