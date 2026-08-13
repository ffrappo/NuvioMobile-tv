import Foundation

struct NuvioDeepLink: Equatable {
    enum Destination: Equatable {
        case details(type: String, id: String)
    }

    let destination: Destination

    init?(url: URL) {
        guard url.scheme?.lowercased() == "nuvio",
              url.host?.lowercased() == "details" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let values = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
                item.value.map { (item.name.lowercased(), $0) }
            }
        )
        guard let type = values["type"]?.trimmedNonEmpty,
              let id = values["id"]?.trimmedNonEmpty else { return nil }
        destination = .details(type: type, id: id)
    }

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

@MainActor
final class NuvioDeepLinkStore: ObservableObject {
    @Published private(set) var pending: NuvioDeepLink?

    func receive(_ url: URL) {
        pending = NuvioDeepLink(url: url)
    }

    func consume(_ deepLink: NuvioDeepLink) {
        if pending == deepLink { pending = nil }
    }
}
