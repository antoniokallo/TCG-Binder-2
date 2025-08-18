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
            // Background with 5:7 aspect ratio (card proportions)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.06))
                .aspectRatio(5.0/7.0, contentMode: .fit)
            
            if let ui = image {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            // No placeholder - just empty space when no image
        }
        .onAppear { load() }
        .onDisappear { cancellable?.cancel() }
    }

    private func load() {
        // Skip loading for dummy URLs
        if url.absoluteString == "about:blank" {
            return
        }
        
        // Handle shape URLs
        if url.scheme == "shape" {
            self.image = generateShapeImage(for: url.host ?? "circle")
            return
        }
        
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
    
    private func generateShapeImage(for shape: String) -> UIImage? {
        let size = CGSize(width: 200, height: 280)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cgContext = context.cgContext
            
            // Set fill color
            cgContext.setFillColor(UIColor.systemBlue.cgColor)
            
            switch shape.lowercased() {
            case "circle":
                let radius = min(size.width, size.height) * 0.3
                let center = CGPoint(x: size.width/2, y: size.height/2)
                cgContext.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            case "triangle":
                let center = CGPoint(x: size.width/2, y: size.height/2)
                let radius = min(size.width, size.height) * 0.3
                cgContext.move(to: CGPoint(x: center.x, y: center.y - radius))
                cgContext.addLine(to: CGPoint(x: center.x - radius * 0.866, y: center.y + radius * 0.5))
                cgContext.addLine(to: CGPoint(x: center.x + radius * 0.866, y: center.y + radius * 0.5))
                cgContext.closePath()
                cgContext.fillPath()
            case "square":
                let sideLength = min(size.width, size.height) * 0.6
                let origin = CGPoint(x: (size.width - sideLength)/2, y: (size.height - sideLength)/2)
                cgContext.fill(CGRect(x: origin.x, y: origin.y, width: sideLength, height: sideLength))
            case "pentagon":
                drawPolygon(context: cgContext, sides: 5, center: CGPoint(x: size.width/2, y: size.height/2), radius: min(size.width, size.height) * 0.3)
            case "hexagon":
                drawPolygon(context: cgContext, sides: 6, center: CGPoint(x: size.width/2, y: size.height/2), radius: min(size.width, size.height) * 0.3)
            case "star":
                drawStar(context: cgContext, center: CGPoint(x: size.width/2, y: size.height/2), radius: min(size.width, size.height) * 0.3)
            default:
                let radius = min(size.width, size.height) * 0.3
                let center = CGPoint(x: size.width/2, y: size.height/2)
                cgContext.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
        }
    }
    
    private func drawPolygon(context: CGContext, sides: Int, center: CGPoint, radius: CGFloat) {
        let angleStep = 2 * CGFloat.pi / CGFloat(sides)
        let startAngle = -CGFloat.pi / 2
        
        context.move(to: CGPoint(
            x: center.x + radius * cos(startAngle),
            y: center.y + radius * sin(startAngle)
        ))
        
        for i in 1..<sides {
            let angle = startAngle + angleStep * CGFloat(i)
            context.addLine(to: CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            ))
        }
        
        context.closePath()
        context.fillPath()
    }
    
    private func drawStar(context: CGContext, center: CGPoint, radius: CGFloat) {
        let points = 5
        let outerRadius = radius
        let innerRadius = radius * 0.4
        let angleStep = CGFloat.pi / CGFloat(points)
        let startAngle = -CGFloat.pi / 2
        
        context.move(to: CGPoint(
            x: center.x + outerRadius * cos(startAngle),
            y: center.y + outerRadius * sin(startAngle)
        ))
        
        for i in 1..<(points * 2) {
            let angle = startAngle + angleStep * CGFloat(i)
            let currentRadius = i % 2 == 0 ? outerRadius : innerRadius
            context.addLine(to: CGPoint(
                x: center.x + currentRadius * cos(angle),
                y: center.y + currentRadius * sin(angle)
            ))
        }
        
        context.closePath()
        context.fillPath()
    }
}

