import SwiftUI
import Combine

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    
    func image(for url: URL) -> UIImage? { 
        cache.object(forKey: url as NSURL) 
    }
    
    func set(_ image: UIImage, for url: URL) { 
        cache.setObject(image, forKey: url as NSURL) 
    }
}

struct RemoteImage: View {
    let url: URL
    @State private var image: UIImage?
    @State private var cancellable: AnyCancellable?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.06))
            if let ui = image {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ProgressView()
            }
        }
        .onAppear { load() }
        .onDisappear { cancellable?.cancel() }
    }

    private func load() {
        if let cached = ImageCache.shared.image(for: url) {
            self.image = cached
            return
        }
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { img in
                guard let img else { return }
                ImageCache.shared.set(img, for: url)
                self.image = img
            }
    }
}