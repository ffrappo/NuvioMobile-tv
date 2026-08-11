import Foundation

@MainActor
final class CollectionStore: ObservableObject {
    @Published private(set) var collections: [TVCollection] = []
    @Published private(set) var message: String?

    private let accountService: NuvioAccountService

    init(accountService: NuvioAccountService = NuvioAccountService()) {
        self.accountService = accountService
    }

    func sync(auth: AuthStore, profileID: Int) async {
        guard auth.session != nil else {
            collections = []
            return
        }
        do {
            let token = try await auth.validAccessToken()
            collections = try await accountService.collections(accessToken: token, profileID: profileID)
                .sorted { first, second in
                    if first.pinToTop != second.pinToTop { return first.pinToTop }
                    return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
                }
            message = nil
        } catch {
            let detail = AppLog.safeDescription(error)
            AppLog.sync.error("Collections sync failed profile=\(profileID) detail=\(detail, privacy: .public)")
            message = "Collections could not be synchronized. \(detail)"
        }
    }

    func items(
        for folder: TVCollectionFolder,
        addons: [HomeAddon],
        service: StremioService = StremioService()
    ) async -> [MetaSummary] {
        var loaded: [MetaSummary] = []
        for source in folder.sources where source.provider.lowercased() == "addon" {
            guard let addonID = source.addonId,
                  let addon = addons.first(where: { $0.manifest.id == addonID }),
                  let type = source.type,
                  let catalogID = source.catalogId else { continue }
            let items: [MetaSummary]
            do {
                items = try await service.catalog(
                    baseURL: addon.baseURL,
                    type: type,
                    id: catalogID,
                    genre: source.genre
                )
            } catch {
                let detail = AppLog.safeDescription(error)
                AppLog.provider.error("Collection catalog failed folder=\(folder.id, privacy: .public) addon=\(addon.manifest.id, privacy: .public) type=\(type, privacy: .public) catalog=\(catalogID, privacy: .public) detail=\(detail, privacy: .public)")
                continue
            }
            loaded.append(contentsOf: items)
        }
        var seen = Set<String>()
        return loaded.filter { seen.insert("\($0.type):\($0.id)").inserted }
    }
}
