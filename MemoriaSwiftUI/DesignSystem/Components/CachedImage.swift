import SwiftUI
import UIKit

/// A cache-first remote image, the drop-photo counterpart to `AsyncImage`: it renders instantly
/// from `RemoteImageCache` (memory → disk) when the bytes are already around — so a card scrolling
/// back into view doesn't re-download or flash — and only hits the network on a true miss. Mirrors
/// `AsyncImage`'s `content` / `placeholder` shape so call sites read the same.
struct CachedImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            uiImage = nil
            return
        }
        // Instant path: already cached in memory or on disk.
        if let cached = RemoteImageCache.image(for: url) {
            uiImage = cached
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return }
        RemoteImageCache.store(image, data: data, for: url)
        uiImage = image
    }
}
