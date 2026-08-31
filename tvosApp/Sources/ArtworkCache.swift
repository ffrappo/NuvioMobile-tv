import Foundation
import ImageIO
import UIKit

actor ArtworkLoader {
    static let shared = ArtworkLoader()

    private struct CacheKey: Hashable {
        let url: URL
        let maxPixelSize: Int

        var storageKey: NSString {
            "\(url.absoluteString)#maxPixelSize=\(maxPixelSize)" as NSString
        }
    }

    private final class CacheEntry: NSObject {
        let image: UIImage
        let storedAt: Date

        init(image: UIImage, storedAt: Date) {
            self.image = image
            self.storedAt = storedAt
        }
    }

    private struct InFlightRequest {
        let id: UUID
        let task: Task<UIImage?, Never>
    }

    private let cache = NSCache<NSString, CacheEntry>()
    private let session: URLSession
    private let defaultMaxPixelSize: Int
    private let staleInterval: TimeInterval
    private let now: @Sendable () -> Date
    private var inFlight: [CacheKey: InFlightRequest] = [:]

    init(
        session: URLSession? = nil,
        countLimit: Int = 320,
        totalCostLimit: Int = 160 * 1_024 * 1_024,
        defaultMaxPixelSize: Int = 1_200,
        staleInterval: TimeInterval = 15 * 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        self.defaultMaxPixelSize = max(defaultMaxPixelSize, 1)
        self.staleInterval = max(staleInterval, 0)
        self.now = now
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
        cachedImage(for: url, pixelSize: nil)
    }

    func cachedImage(for url: URL, pixelSize: CGSize?) -> UIImage? {
        cache.object(forKey: cacheKey(for: url, pixelSize: pixelSize).storageKey)?.image
    }

    func image(for url: URL, pixelSize: CGSize? = nil) async -> UIImage? {
        let key = cacheKey(for: url, pixelSize: pixelSize)
        if let entry = cache.object(forKey: key.storageKey) {
            if now().timeIntervalSince(entry.storedAt) >= staleInterval {
                startBackgroundRefresh(for: key)
            }
            return entry.image
        }
        if let request = inFlight[key] {
            return await request.task.value
        }

        let request = makeRequest(for: key, cachePolicy: .returnCacheDataElseLoad)
        inFlight[key] = request
        let image = await request.task.value
        finish(request, for: key, image: image)
        return image
    }

    func clear() {
        inFlight.values.forEach { $0.task.cancel() }
        inFlight.removeAll()
        cache.removeAllObjects()
    }

    nonisolated static func downsampleMaxPixelSize(for requestedPixelSize: CGSize) -> Int {
        let width = requestedPixelSize.width.isFinite ? requestedPixelSize.width : 0
        let height = requestedPixelSize.height.isFinite ? requestedPixelSize.height : 0
        return max(Int(ceil(max(width, height))), 1)
    }

    private func cacheKey(for url: URL, pixelSize: CGSize?) -> CacheKey {
        CacheKey(
            url: url,
            maxPixelSize: pixelSize.map(Self.downsampleMaxPixelSize) ?? defaultMaxPixelSize
        )
    }

    private func startBackgroundRefresh(for key: CacheKey) {
        guard inFlight[key] == nil else { return }
        let request = makeRequest(for: key, cachePolicy: .reloadRevalidatingCacheData)
        inFlight[key] = request
        Task { [weak self] in
            let image = await request.task.value
            await self?.finish(request, for: key, image: image)
        }
    }

    private func makeRequest(
        for key: CacheKey,
        cachePolicy: URLRequest.CachePolicy
    ) -> InFlightRequest {
        let task = Task<UIImage?, Never> { [session] in
            var request = URLRequest(url: key.url, cachePolicy: cachePolicy)
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else { return nil }
                return await Self.decodeThumbnail(data, maxPixelSize: key.maxPixelSize)
            } catch {
                return nil
            }
        }
        return InFlightRequest(id: UUID(), task: task)
    }

    private func finish(_ request: InFlightRequest, for key: CacheKey, image: UIImage?) {
        guard inFlight[key]?.id == request.id else { return }
        inFlight[key] = nil
        guard let image else { return }
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let cost = Int(pixelWidth * pixelHeight * 4)
        cache.setObject(
            CacheEntry(image: image, storedAt: now()),
            forKey: key.storageKey,
            cost: cost
        )
    }

    private nonisolated static func decodeThumbnail(
        _ data: Data,
        maxPixelSize: Int
    ) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
                return nil
            }
            let thumbnailOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1),
                kCGImageSourceShouldCacheImmediately: true,
            ] as CFDictionary
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
                return nil
            }
            return UIImage(cgImage: image)
        }.value
    }
}
