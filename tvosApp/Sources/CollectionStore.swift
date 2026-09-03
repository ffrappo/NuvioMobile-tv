import Foundation

@MainActor
final class CollectionStore: ObservableObject {
    @Published private(set) var collections: [TVCollection] = []
    @Published private(set) var message: String?

    private let accountService: NuvioAccountService
    private let repository: CatalogRepository

    init(
        accountService: NuvioAccountService = NuvioAccountService(),
        repository: CatalogRepository = .shared
    ) {
        self.accountService = accountService
        self.repository = repository
    }

    func sync(auth: AuthStore, profileID: Int) async {
        guard auth.session != nil else {
            collections = []
            return
        }
        AppLog.sync.notice("collections.start profile=\(profileID)")
        do {
            let token = try await auth.validAccessToken()
            collections = try await accountService.collections(
                accessToken: token,
                profileID: profileID
            ).sorted { first, second in
                if first.pinToTop != second.pinToTop { return first.pinToTop }
                return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            }
            message = nil
            AppLog.sync.notice("collections.complete profile=\(profileID) count=\(self.collections.count)")
        } catch {
            let detail = AppLog.safeDescription(error)
            AppLog.sync.error("collections.fail profile=\(profileID) detail=\(detail, privacy: .public)")
            message = "Collections could not be synchronized. \(detail)"
        }
    }

    func clearForLogout() {
        collections = []
        message = nil
    }

    /// Pushes the full collection list (`sync_push_collections`) and
    /// adopts it locally, keeping the pull's ordering.
    func save(
        _ updated: [TVCollection],
        auth: AuthStore,
        profileID: Int
    ) async {
        guard auth.session != nil else { return }
        do {
            let token = try await auth.validAccessToken()
            try await accountService.pushCollections(updated, profileID: profileID, accessToken: token)
            collections = updated.sorted {
                if $0.pinToTop != $1.pinToTop { return $0.pinToTop }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            message = nil
        } catch {
            let detail = AppLog.safeDescription(error)
            AppLog.sync.error("Collection push failed profile=\(profileID) detail=\(detail, privacy: .public)")
            message = "Collections could not be saved. \(detail)"
        }
    }

    func items(for folder: TVCollectionFolder, addons: [HomeAddon]) async -> [MetaSummary] {
        let descriptors = folder.sources.compactMap { descriptor(for: $0, addons: addons) }
        let batches = AsyncBatcher.batches(descriptors, limit: 3) { [repository] descriptor in
            do {
                return try await repository.firstPage(of: descriptor).items
            } catch {
                return []
            }
        }
        var loaded: [MetaSummary] = []
        for await batch in batches {
            try? Task.checkCancellation()
            if Task.isCancelled { return [] }
            loaded.append(contentsOf: batch.flatMap(\.value))
        }
        var seen = Set<String>()
        return loaded.filter { seen.insert("\($0.type):\($0.id)").inserted }
    }

    func descriptors(
        for folder: TVCollectionFolder,
        addons: [HomeAddon]
    ) -> [CatalogDescriptor] {
        folder.sources.compactMap { descriptor(for: $0, addons: addons) }
    }

    func listing(
        for source: TVCollectionSource,
        addons: [HomeAddon],
        items: [MetaSummary] = []
    ) -> CatalogListing? {
        guard let descriptor = descriptor(for: source, addons: addons) else { return nil }
        return CatalogListing(
            descriptor: descriptor,
            items: items,
            nextSkip: CatalogRepository.nextSkip(
                currentSkip: 0,
                supportsPagination: descriptor.supportsPagination,
                receivedCount: items.count
            )
        )
    }

    private func descriptor(
        for source: TVCollectionSource,
        addons: [HomeAddon]
    ) -> CatalogDescriptor? {
        guard source.provider.lowercased() == "addon",
              let addonID = source.addonId,
              let addon = addons.first(where: { $0.manifest.id == addonID }),
              let type = source.type,
              let catalogID = source.catalogId else { return nil }
        let catalog = addon.manifest.catalogs.first {
            $0.id == catalogID && $0.type == type
        }
        return CatalogDescriptor(
            baseURL: addon.baseURL,
            addonID: addonID,
            addonName: addon.name,
            type: type,
            catalogID: catalogID,
            catalogName: source.title?.trimmedNonEmpty ?? catalog?.name ?? catalogID,
            genre: source.genre,
            genres: catalog?.extra.first { $0.name == "genre" }?.options ?? [],
            supportsPagination: catalog?.extra.contains { $0.name == "skip" } ?? true
        )
    }
}
