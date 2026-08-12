import UIKit

final class ArtworkStore {
    static let shared = ArtworkStore()
    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let maxDimension: CGFloat = 1200

    init() {
        cache.countLimit = 400
        cache.totalCostLimit = 220 * 1_024 * 1_024
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let image = UIImage(data: data) else { return nil }
            let scaled = await downsample(image)
            let cost = Int(scaled.size.width * scaled.size.height * 4)
            cache.setObject(scaled, forKey: url.absoluteString as NSString, cost: cost)
            return scaled
        } catch {
            return nil
        }
    }

    private func downsample(_ image: UIImage) async -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        if let thumbnail = await image.byPreparingThumbnail(ofSize: target) {
            return thumbnail
        }
        return image
    }
}
