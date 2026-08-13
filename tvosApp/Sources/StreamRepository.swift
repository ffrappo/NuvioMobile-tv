import Foundation

struct StreamAddonResult: Sendable {
    let index: Int
    let addonName: String
    let sources: [StreamSource]
    let failure: String?
}

struct StreamRequest: Hashable, Sendable {
    let type: String
    let id: String
    let addons: [AddonEndpoint]

    var key: String {
        ([type, id] + addons.map { "\($0.baseURL)|\($0.providesStreams)" }).joined(separator: "|")
    }
}

actor StreamRepository {
    static let shared = StreamRepository()

    private let service: StremioService

    init(service: StremioService = StremioService()) {
        self.service = service
    }

    func results(for request: StreamRequest, limit: Int = 3) -> AsyncStream<StreamAddonResult> {
        service.streamResults(type: request.type, id: request.id, addons: request.addons, limit: limit)
    }
}

extension StremioService {
    func streamResults(
        type: String,
        id: String,
        addons: [AddonEndpoint],
        limit: Int = 3
    ) -> AsyncStream<StreamAddonResult> {
        let eligible = addons.enumerated().filter { $0.element.providesStreams }
        let indexed = eligible.map { IndexedAddon(index: $0.offset, addon: $0.element) }
        return AsyncStream { continuation in
            let task = Task {
                let batches = AsyncBatcher.batches(indexed, limit: limit) { [self] entry in
                    await streamResult(type: type, id: id, entry: entry)
                }
                for await batch in batches {
                    for result in batch { continuation.yield(result.value) }
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    func streams(type: String, id: String, addons: [AddonEndpoint]) async -> StreamFetchReport {
        var results: [StreamAddonResult] = []
        for await result in streamResults(type: type, id: id, addons: addons) {
            results.append(result)
        }
        results.sort { $0.index < $1.index }
        return StreamFetchReport(
            sources: results.flatMap(\.sources),
            failures: results.compactMap { result in
                result.failure.map { "\(result.addonName): \($0)" }
            }
        )
    }

    private func streamResult(
        type: String,
        id: String,
        entry: IndexedAddon
    ) async -> StreamAddonResult {
        do {
            let url = try AddonTransport.resourceURL(
                baseURL: entry.addon.baseURL,
                resource: "stream",
                type: type,
                id: id
            )
            let response: StreamResponse = try await request(url)
            return StreamAddonResult(
                index: entry.index,
                addonName: entry.addon.name,
                sources: response.streams.map {
                    StreamSource(
                        addonName: entry.addon.name,
                        addonLogoURL: entry.addon.manifest?.logoURL,
                        stream: $0
                    )
                },
                failure: nil
            )
        } catch {
            return StreamAddonResult(
                index: entry.index,
                addonName: entry.addon.name,
                sources: [],
                failure: error.userMessage
            )
        }
    }
}

private struct IndexedAddon: Sendable {
    let index: Int
    let addon: AddonEndpoint
}
