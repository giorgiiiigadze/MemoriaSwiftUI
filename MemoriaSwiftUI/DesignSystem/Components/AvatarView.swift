import SwiftUI
import UIKit

/// A circular avatar that renders a user's remote photo cache-first — instant when the bytes are
/// already on disk (from `AvatarImageCache`, warmed during boot) — and falls back to their initials
/// otherwise. Reusable at any `size`: the profile page's large TikTok-style photo, friend rows, etc.
struct AvatarView: View {
    let url: String?
    let name: String
    var size: CGFloat = 96

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Colors.surfaceRaised)
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Colors.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url) { await load() }
    }

    private var initials: String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private func load() async {
        guard let url, let resolved = URL(string: url) else {
            image = nil
            return
        }
        // Instant path: last-cached bytes render before the first frame.
        if let cached = AvatarImageCache.data(for: resolved), let img = UIImage(data: cached) {
            image = img
        }
        // Refresh + re-cache so a changed photo (same stable URL) heals within one appearance.
        if let (data, _) = try? await URLSession.shared.data(from: resolved) {
            AvatarImageCache.store(data, for: resolved)
            if let img = UIImage(data: data) { image = img }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        AvatarView(url: nil, name: "Giorgi Giorgadze", size: 112)
        AvatarView(url: nil, name: "Ada", size: 56)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Colors.background)
}
