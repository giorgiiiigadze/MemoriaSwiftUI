import SwiftUI
import UIKit

struct InitialAvatar: View {
    let name: String
    var size: CGFloat = 40
    /// Background circle colour. `nil` uses the deterministic per-name palette colour
    /// (`AvatarPalette`), which is the identity fallback; pass an explicit colour for neutral
    /// placeholders (e.g. the profile-setup photo picker).
    var backgroundColor: Color? = nil
    var foregroundColor: Color = Colors.white
    /// Local picked image data (e.g. from the profile-setup Photo step) shown instead of
    /// initials. Remote `avatar_url` rendering elsewhere in the app goes through an image
    /// loading library once that's added — this only covers already-in-memory `Data`.
    var imageData: Data? = nil

    var body: some View {
        Circle()
            .fill(backgroundColor ?? AvatarPalette.color(for: name))
            .frame(width: size, height: size)
            .overlay {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Text(AvatarPalette.initials(for: name))
                        .font(.system(size: size * AvatarPalette.initialScale, weight: .semibold))
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
