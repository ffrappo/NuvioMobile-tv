import UIKit
import XCTest
@testable import NuvioTV

final class ArtworkLoadingTests: XCTestCase {
    override func tearDown() {
        TestURLProtocol.clear()
        super.tearDown()
    }

    func testStaleValueIsReturnedBeforeRevalidationCompletes() async throws {
        let counter = ArtworkLoadingCounter()
        let firstData = try XCTUnwrap(Self.imageData(color: .systemBlue))
        let refreshedData = try XCTUnwrap(Self.imageData(color: .systemRed))
        let refreshStarted = expectation(description: "Refresh request started")
        TestURLProtocol.setHandler { _ in
            let requestNumber = counter.incrementAndRead()
            if requestNumber == 1 {
                return .init(statusCode: 200, data: firstData, delay: .zero)
            }
            refreshStarted.fulfill()
            return .init(statusCode: 200, data: refreshedData, delay: .milliseconds(250))
        }

        let loader = ArtworkLoader(
            session: TestURLProtocol.session(),
            staleInterval: 0
        )
        let url = URL(string: "https://example.test/stale-poster.png")!
        let seededResult = await loader.image(
            for: url,
            pixelSize: CGSize(width: 126, height: 189)
        )
        let seeded = try XCTUnwrap(seededResult)

        let start = Date()
        let stale = await loader.image(
            for: url,
            pixelSize: CGSize(width: 126, height: 189)
        )
        let deliveryTime = Date().timeIntervalSince(start)

        XCTAssertTrue(stale === seeded)
        XCTAssertLessThan(deliveryTime, 0.15)
        await fulfillment(of: [refreshStarted], timeout: 1)
        XCTAssertEqual(counter.value, 2)

        try await Task.sleep(for: .milliseconds(350))
        let refreshed = await loader.cachedImage(
            for: url,
            pixelSize: CGSize(width: 126, height: 189)
        )
        XCTAssertNotNil(refreshed)
        XCTAssertFalse(refreshed === seeded)
    }

    func testArtworkModeDefaultsPreserveAndroidGeometry() {
        XCTAssertEqual(NuvioArtworkMode.poster.defaultPixelSize, CGSize(width: 126, height: 189))
        XCTAssertEqual(NuvioArtworkMode.backdrop.defaultPixelSize, CGSize(width: 320, height: 180))
        XCTAssertEqual(NuvioArtworkMode.titleLogo.defaultPixelSize, CGSize(width: 190, height: 44))
        XCTAssertEqual(NuvioArtworkMode.poster.defaultCornerRadius, 12)
        XCTAssertEqual(NuvioArtworkMode.backdrop.defaultCornerRadius, 16)
        XCTAssertEqual(NuvioArtworkMode.titleLogo.defaultCornerRadius, 0)
        XCTAssertEqual(NuvioArtworkStatePresentation.surface, .surface)
        XCTAssertEqual(NuvioArtworkStatePresentation.transparent, .transparent)
    }

    func testDownsamplingUsesRequestedMaximumPixelDimension() async throws {
        XCTAssertEqual(
            ArtworkLoader.downsampleMaxPixelSize(
                for: CGSize(width: 126, height: 189)
            ),
            189
        )
        XCTAssertEqual(
            ArtworkLoader.downsampleMaxPixelSize(
                for: CGSize(width: 320.1, height: 180)
            ),
            321
        )
        XCTAssertEqual(
            ArtworkLoader.downsampleMaxPixelSize(for: .zero),
            1
        )

        let imageData = try XCTUnwrap(Self.imageData(
            color: .systemGreen,
            size: CGSize(width: 640, height: 360)
        ))
        TestURLProtocol.setHandler { _ in
            .init(statusCode: 200, data: imageData, delay: .zero)
        }
        let loader = ArtworkLoader(session: TestURLProtocol.session())
        let imageResult = await loader.image(
            for: URL(string: "https://example.test/backdrop.png")!,
            pixelSize: CGSize(width: 160, height: 90)
        )
        let image = try XCTUnwrap(imageResult)
        let decodedPixels = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        XCTAssertLessThanOrEqual(decodedPixels.width, 160)
        XCTAssertLessThanOrEqual(decodedPixels.height, 160)
        XCTAssertEqual(decodedPixels.width / decodedPixels.height, 16 / 9, accuracy: 0.02)
    }

    func testSizedArtworkRequestsRemainCoalesced() async throws {
        let counter = ArtworkLoadingCounter()
        let imageData = try XCTUnwrap(Self.imageData(color: .systemIndigo))
        TestURLProtocol.setHandler { _ in
            counter.increment()
            return .init(statusCode: 200, data: imageData, delay: .milliseconds(80))
        }
        let loader = ArtworkLoader(session: TestURLProtocol.session())
        let url = URL(string: "https://example.test/coalesced.png")!
        let pixelSize = CGSize(width: 126, height: 189)

        async let first = loader.image(for: url, pixelSize: pixelSize)
        async let second = loader.image(for: url, pixelSize: pixelSize)
        let images = await [first, second]

        XCTAssertTrue(images.allSatisfy { $0 != nil })
        XCTAssertEqual(counter.value, 1)
    }

    @MainActor
    func testArtworkModelTransitionsFromPlaceholderThroughLoadingToFailure() async {
        TestURLProtocol.setHandler { _ in
            .init(statusCode: 500, data: Data(), delay: .milliseconds(80))
        }
        let loader = ArtworkLoader(session: TestURLProtocol.session())
        let model = NuvioArtworkViewModel(loader: loader)
        XCTAssertEqual(model.phase, .placeholder)

        await model.load(url: nil, pixelSize: CGSize(width: 126, height: 189))
        XCTAssertEqual(model.phase, .placeholder)

        let task = Task {
            await model.load(
                url: URL(string: "https://example.test/failure.png"),
                pixelSize: CGSize(width: 126, height: 189)
            )
        }
        await Task.yield()
        XCTAssertEqual(model.phase, .loading)
        await task.value
        XCTAssertEqual(model.phase, .failure)
        XCTAssertNil(model.image)
    }

    private static func imageData(
        color: UIColor,
        size: CGSize = CGSize(width: 400, height: 600)
    ) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.pngData { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private final class ArtworkLoadingCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withLock { count } }

    func increment() {
        lock.withLock { count += 1 }
    }

    func incrementAndRead() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}
