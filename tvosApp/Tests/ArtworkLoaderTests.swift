import XCTest
@testable import NuvioTV

final class ArtworkLoaderTests: XCTestCase {
    override func tearDown() {
        TestURLProtocol.clear()
        super.tearDown()
    }

    func testArtworkLoaderCoalescesAndCachesRequests() async throws {
        let counter = ArtworkCounter()
        let imageData = try XCTUnwrap(Self.imageData())
        TestURLProtocol.setHandler { _ in
            counter.increment()
            return .init(statusCode: 200, data: imageData, delay: .milliseconds(80))
        }
        let loader = ArtworkLoader(session: TestURLProtocol.session())
        let url = URL(string: "https://example.test/poster.png")!
        async let first = loader.image(for: url)
        async let second = loader.image(for: url)
        let images = await [first, second]
        XCTAssertTrue(images.allSatisfy { $0 != nil })
        XCTAssertEqual(counter.value, 1)
        _ = await loader.image(for: url)
        XCTAssertEqual(counter.value, 1)
        await loader.clear()
        _ = await loader.image(for: url)
        XCTAssertEqual(counter.value, 2)
    }

    private static func imageData() -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        return renderer.pngData { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }
}

private final class ArtworkCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}
