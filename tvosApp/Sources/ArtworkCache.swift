import ImageIO
import UIKit

actor ArtworkLoader {
    static let shared = ArtworkLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let maxPixelSize = 1_200

    init(
        session: URLSession? = nil,
        countLimit: Int = 320,
        totalCostLimit: Int = 160 * 1_024 * 1_024
    ) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.urlCache = URLCache.shared
            configuration.requestCachePolicy = .returnCacheDataElseLoad
            configuration.timeoutIntervalForRequest = 20
            self.session = URLSession(configuration: configuration)
        }
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        if let task = inFlight[url] { return await task.value }

        let task = Task<UIImage?, Never> { [session, maxPixelSize] in
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else { return nil }
                return await Self.decodeThumbnail(data, maxPixelSize: maxPixelSize)
            } catch {
                return nil
            }
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
        }
        return image
    }

    func clear() {
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
        cache.removeAllObjects()
    }

    private static func decodeThumbnail(_ data: Data, maxPixelSize: Int) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
            let thumbnailOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true,
            ] as CFDictionary
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
                return nil
            }
            return UIImage(cgImage: image)
        }.value
    }
}
