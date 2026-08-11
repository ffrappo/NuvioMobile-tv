import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var items: [MetaSummary] = []

    private let defaults: UserDefaults
    private let key = "nuvio.tv.library.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func contains(_ id: String) -> Bool {
        items.contains { $0.id == id }
    }

    func toggle(_ item: MetaSummary) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        } else {
            items.insert(item, at: 0)
        }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MetaSummary].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class AddonStore: ObservableObject {
    @Published private(set) var addons: [AddonEndpoint] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var syncMessage: String?

    private let defaults: UserDefaults
    private let service: StremioService
    private let accountService: NuvioAccountService
    private let key = "nuvio.tv.addonBases.v1"
    private var storedBases: [String]

    init(
        defaults: UserDefaults = .standard,
        service: StremioService = StremioService(),
        accountService: NuvioAccountService = NuvioAccountService()
    ) {
        self.defaults = defaults
        self.service = service
        self.accountService = accountService
        storedBases = defaults.stringArray(forKey: key) ?? []
        addons = storedBases.map {
            AddonEndpoint(baseURL: $0, name: URL(string: $0)?.host ?? "Saved addon", detail: nil, providesStreams: true)
        }
    }

    func syncFromAccount(auth: AuthStore) async {
        syncMessage = "Syncing account addons..."
        do {
            let token = try await auth.validAccessToken()
            let owner = try await accountService.effectiveOwner(accessToken: token)
            let remote = try await accountService.addons(accessToken: token, ownerID: owner)
                .filter(\.enabled)
                .sorted { $0.sortOrder < $1.sortOrder }
            let remoteURLs = remote.map(\.url)
            if !remoteURLs.isEmpty || storedBases.isEmpty {
                storedBases = remoteURLs
                persist()
            }
            await refreshManifests()
            syncMessage = "Synced \(remoteURLs.count) account addon\(remoteURLs.count == 1 ? "" : "s")."
        } catch {
            syncMessage = "Addon sync failed: \(error.localizedDescription)"
        }
    }

    func clearForLogout() {
        storedBases = []
        addons = []
        syncMessage = nil
        persist()
    }

    func add(manifestURL: String) async throws {
        let result = try await service.manifest(at: manifestURL)
        let base = result.base.absoluteString
        let endpoint = AddonEndpoint(
            baseURL: base,
            name: result.manifest.name,
            detail: result.manifest.description,
            providesStreams: result.manifest.providesStreams
        )
        if let index = addons.firstIndex(where: { $0.baseURL == base }) {
            addons[index] = endpoint
        } else {
            addons.append(endpoint)
        }
        storedBases = addons.map(\.baseURL)
        persist()
    }

    func remove(_ addon: AddonEndpoint) {
        addons.removeAll { $0.baseURL == addon.baseURL }
        storedBases = addons.map(\.baseURL)
        persist()
    }

    func refreshManifests() async {
        guard !storedBases.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var refreshed: [AddonEndpoint] = []
        for base in storedBases {
            do {
                let result = try await service.manifest(at: base)
                refreshed.append(AddonEndpoint(
                    baseURL: result.base.absoluteString,
                    name: result.manifest.name,
                    detail: result.manifest.description,
                    providesStreams: result.manifest.providesStreams
                ))
            } catch {
                refreshed.append(AddonEndpoint(
                    baseURL: base,
                    name: URL(string: base)?.host ?? "Unavailable addon",
                    detail: "Could not refresh this manifest.",
                    providesStreams: true
                ))
            }
        }
        addons = refreshed
    }

    private func persist() {
        defaults.set(storedBases, forKey: key)
    }
}

