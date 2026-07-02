import SwiftUI
import UIKit

struct InitialAvatar: View {
    let name: String
    var size: CGFloat = 40
    var backgroundColor: Color = Colors.surfaceRaised
    var foregroundColor: Color = Colors.textPrimary
    /// Local picked image data (e.g. from the profile-setup Photo step) shown instead of
    /// initials. Remote `avatar_url` rendering elsewhere in the app goes through an image
    /// loading library once that's added — this only covers already-in-memory `Data`.
    var imageData: Data? = nil

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
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Text(initials)
                        .font(Typography.font(.sm, weight: .semiBold))
                        .foregroundStyle(foregroundColor)
                }
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
