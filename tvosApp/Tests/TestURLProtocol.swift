import Foundation

final class TestURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        let statusCode: Int
        let data: Data
        let delay: Duration
    }

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> Stub)?
    private static let lock = NSLock()

    static func setHandler(_ value: @escaping @Sendable (URLRequest) throws -> Stub) {
        lock.lock()
        handler = value
        lock.unlock()
    }

    static func clear() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let currentHandler = Self.handler
        Self.lock.unlock()
        guard let currentHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        Task {
            do {
                let stub = try currentHandler(request)
                if stub.delay > .zero { try await Task.sleep(for: stub.delay) }
                guard !Task.isCancelled else { return }
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: stub.statusCode,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: stub.data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
