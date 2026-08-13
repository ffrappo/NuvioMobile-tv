import Foundation

struct TopShelfCatalogSection {
    let title: String
    let items: [TopShelfCatalogEntry]
}

struct TopShelfCatalogEntry: Decodable {
    let id: String
    let type: String
    let name: String
    let poster: String?
}

private struct TopShelfCatalogResponse: Decodable {
    let metas: [TopShelfCatalogEntry]
}

struct TopShelfCatalogService {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 4 * 1_024 * 1_024,
            diskCapacity: 16 * 1_024 * 1_024
        )
        session = URLSession(configuration: configuration)
    }

    func sections() async -> [TopShelfCatalogSection] {
        await withTaskGroup(of: (Int, TopShelfCatalogSection?).self) { group in
            for (index, request) in Self.requests.enumerated() {
                group.addTask {
                    do {
                        let entries = try await load(request.url)
                        return (
                            index,
                            TopShelfCatalogSection(
                                title: request.title,
                                items: Array(entries.prefix(10))
                            )
                        )
                    } catch {
                        return (index, nil)
                    }
                }
            }
            var sections: [(Int, TopShelfCatalogSection)] = []
            for await (index, section) in group {
                if let section, !section.items.isEmpty {
                    sections.append((index, section))
                }
            }
            return sections.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func load(_ url: URL) async throws -> [TopShelfCatalogEntry] {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 5
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(TopShelfCatalogResponse.self, from: data).metas
    }

    private static let requests: [(title: String, url: URL)] = [
        ("Popular Movies", URL(string: "https://v3-cinemeta.strem.io/catalog/movie/top.json")!),
        ("Popular Series", URL(string: "https://v3-cinemeta.strem.io/catalog/series/top.json")!),
    ]
}

enum NuvioTopShelfLink {
    static func detailsURL(type: String, id: String) -> URL? {
        var components = URLComponents()
        components.scheme = "nuvio"
        components.host = "details"
        components.queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "id", value: id),
        ]
        return components.url
    }
}
