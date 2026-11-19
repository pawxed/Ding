import SwiftUI

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 200 }
    func image(for url: URL) -> UIImage? { cache.object(forKey: url.absoluteString as NSString) }
    func set(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url.absoluteString as NSString) }
}

struct CachedImage: View {
    let url: URL?
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .onAppear { load() }
    }
    private func load() {
        guard let url else { return }
        if let cached = ImageCache.shared.image(for: url) { image = cached; return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let ui = UIImage(data: data) {
                    let size = CGSize(width: 96, height: 96)
                    let renderer = UIGraphicsImageRenderer(size: size)
                    let small = renderer.image { _ in ui.draw(in: CGRect(origin: .zero, size: size)) }
                    ImageCache.shared.set(small, for: url)
                    await MainActor.run { image = small }
                }
            } catch {}
        }
    }
    }
}