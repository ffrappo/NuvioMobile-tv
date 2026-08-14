import Foundation

final class TestURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        let statusCode: Int
        let data: Data
        let delay: Duration
    }

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> Stub)?
    nonisolated(unsafe) static var liveProtocols: Set<ObjectIdentifier> = []
    private static let lock = NSLock()

    static func setHandler(_ value: @escaping @Sendable (URLRequest) throws -> Stub) {
        lock.lock()
        handler = value
        liveProtocols.removeAll()
        lock.unlock()
    }

    static func clear() {
        lock.lock()
        handler = nil
        liveProtocols.removeAll()
        lock.unlock()
    }

    private static func registerLiveProtocol(_ identifier: ObjectIdentifier) {
        lock.lock()
        liveProtocols.insert(identifier)
        lock.unlock()
    }

    private static func unregister(_ identifier: ObjectIdentifier) {
        lock.lock()
        liveProtocols.remove(identifier)
        lock.unlock()
    }

    static func isLive(_ urlProtocol: TestURLProtocol) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return liveProtocols.contains(ObjectIdentifier(urlProtocol))
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
        Self.registerLiveProtocol(ObjectIdentifier(self))
        let urlProtocol = self
        Task {
            do {
                let stub = try currentHandler(request)
                if stub.delay > .zero {
                    let task = Task<Void, Never> {
                        try? await Task.sleep(for: stub.delay)
                    }
                    await withTaskCancellationHandler {
                        await task.value
                    } onCancel: {
                        task.cancel()
                    }
                    guard !Task.isCancelled, Self.isLive(urlProtocol) else {
                        urlProtocol.client?.urlProtocol(
                            urlProtocol,
                            didFailWithError: URLError(.cancelled)
                        )
                        return
                    }
                }
                guard Self.isLive(urlProtocol) else {
                    urlProtocol.client?.urlProtocol(
                        urlProtocol,
                        didFailWithError: URLError(.cancelled)
                    )
                    return
                }
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: stub.statusCode,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                urlProtocol.client?.urlProtocol(urlProtocol, didReceive: response, cacheStoragePolicy: .notAllowed)
                urlProtocol.client?.urlProtocol(urlProtocol, didLoad: stub.data)
                urlProtocol.client?.urlProtocolDidFinishLoading(urlProtocol)
            } catch {
                urlProtocol.client?.urlProtocol(urlProtocol, didFailWithError: error)
            }
            Self.unregister(ObjectIdentifier(urlProtocol))
        }
    }

    override func stopLoading() {
        Self.unregister(ObjectIdentifier(self))
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
