import Foundation

@MainActor
final class HomeStore: ObservableObject {
    @Published private(set) var snapshot = HomeSnapshot()

    private let service: StremioService
    private let repository: CatalogRepository
    private let accountService: NuvioAccountService
    private let preferences: HomePreferencesStore
    private let progress: WatchProgressStore
    private let collections: CollectionStore
    private var cachedSections: [String: HomeCatalogSection] = [:]
    private var generation = UUID()

    init(
        service: StremioService = StremioService(),
        accountService: NuvioAccountService = NuvioAccountService(),
        preferences: HomePreferencesStore,
        progress: WatchProgressStore,
        collections: CollectionStore,
        repository: CatalogRepository? = nil
    ) {
        self.service = service
        self.repository = repository ?? CatalogRepository(service: service)
        self.accountService = accountService
        self.preferences = preferences
        self.progress = progress
        self.collections = collections
    }

    func load(
        addons: [HomeAddon],
        auth: AuthStore,
        profileID: Int,
        force: Bool = false
    ) async {
        generation = UUID()
        let requestGeneration = generation
        snapshot.isLoading = true
        snapshot.message = nil

        if auth.session != nil {
            async let progressSync: Void = progress.sync(auth: auth, profileID: profileID)
            async let collectionSync: Void = collections.sync(auth: auth, profileID: profileID)
            async let settingsSync: Void = syncPreferences(auth: auth, profileID: profileID)
            _ = await (progressSync, collectionSync, settingsSync)
        }
        guard !Task.isCancelled, requestGeneration == generation else { return }

        let definitions = buildDefinitions(addons: addons)
        preferences.reconcile(definitions: definitions, collections: collections.collections)
        let active = orderedDefinitions(definitions)
        let hideUnreleased = preferences.value.hideUnreleasedContent
        var sections = force ? [:] : cachedSections.filter { key, _ in
            active.contains { $0.id == key }
        }
        let missing = active.filter { force || sections[$0.id] == nil }
        var failures = 0

        let batches = AsyncBatcher.batches(missing, limit: 3) { [repository] definition -> HomeCatalogSection? in
            do {
                let page = try await repository.firstPage(
                    of: CatalogDescriptor(definition),
                    ignoringCache: force
                )
                let items = HomeReleaseFilter.releasedItems(page.items, enabled: hideUnreleased)
                return HomeCatalogSection(definition: definition, items: items)
            } catch {
                return nil
            }
        }
        for await batch in batches {
            guard !Task.isCancelled, requestGeneration == generation else { return }
            for result in batch {
                if let section = result.value, !section.items.isEmpty {
                    sections[section.id] = section
                } else {
                    failures += 1
                }
            }
            publish(sections: sections, active: active, failures: failures, loading: true)
        }
        guard requestGeneration == generation else { return }
        cachedSections = sections
        publish(sections: sections, active: active, failures: failures, loading: false)
    }

    func clearForLogout() {
        generation = UUID()
        cachedSections = [:]
        snapshot = HomeSnapshot()
    }

    private func publish(
        sections: [String: HomeCatalogSection],
        active: [HomeCatalogDefinition],
        failures: Int,
        loading: Bool
    ) {
        let orderedSections = active.compactMap { sections[$0.id] }
        let collectionRows = collections.collections.filter {
            preferences.value.preference(for: "collection_\($0.id)")?.enabled != false
        }
        snapshot.heroItems = makeHero(sections: orderedSections)
        snapshot.sections = orderedSections
        snapshot.continueWatching = progress.continueWatching
        snapshot.collections = collectionRows
        snapshot.isLoading = loading
        snapshot.message = failures > 0
            ? "Some Home sections could not be refreshed. Check the connection and retry."
            : collections.message
        snapshot.isOffline = failures > 0
        if !loading { Task { snapshot.upcoming = await buildUpcoming(from: progress.records) } }
    }

    private func syncPreferences(auth: AuthStore, profileID: Int) async {
        do {
            let token = try await auth.validAccessToken()
            if let remote = try await accountService.homePreferences(
                accessToken: token,
                profileID: profileID
            ), !remote.items.isEmpty {
                preferences.applyRemote(remote)
            }
        } catch {
            AppLog.sync.error(
                "Home preferences sync failed profile=\(profileID) detail=\(AppLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    private func buildDefinitions(addons: [HomeAddon]) -> [HomeCatalogDefinition] {
        CatalogDescriptors.browse(from: addons).map(HomeCatalogDefinition.init)
    }

    private func orderedDefinitions(_ definitions: [HomeCatalogDefinition]) -> [HomeCatalogDefinition] {
        definitions.filter {
            preferences.value.preference(for: $0.id)?.enabled != false
        }.sorted {
            let left = preferences.value.preference(for: $0.id)?.order ?? Int.max
            let right = preferences.value.preference(for: $1.id)?.order ?? Int.max
            return left == right ? $0.id < $1.id : left < right
        }
    }

    private func makeHero(sections: [HomeCatalogSection]) -> [MetaSummary] {
        guard preferences.value.heroEnabled else { return [] }
        var seen = Set<String>()
        return sections.flatMap(\.items)
            .filter { seen.insert("\($0.type):\($0.id)").inserted }
            .prefix(8).map { $0 }
    }

    private func buildUpcoming(from records: [WatchProgressRecord]) async -> [ContinueWatchingCard] {
        var upcoming: [ContinueWatchingCard] = []
        for record in records.filter({ $0.contentType.lowercased() == "series" && $0.isCompleted }).prefix(12) {
            guard let summary = record.summary else { continue }
            do {
                let detail = try await service.details(
                    type: record.contentType,
                    id: record.contentID,
                    baseURL: summary.metadataBaseURL ?? StremioService.cinemetaBaseURL.absoluteString
                )
                guard let next = HomeUpcomingResolver.nextEpisode(after: record, videos: detail.videos) else { continue }
                upcoming.append(ContinueWatchingCard(
                    id: "upcoming:\(record.contentID):\(next.id)", summary: summary,
                    videoID: next.id, season: next.season, episode: next.episode,
                    episodeTitle: next.name, episodeThumbnail: next.thumbnail,
                    released: next.released, positionMilliseconds: 0, durationMilliseconds: 0,
                    lastWatchedMilliseconds: record.lastWatched, isUpcoming: true
                ))
            } catch {
                AppLog.home.error(
                    "Upcoming enrichment failed content=\(record.contentID, privacy: .private(mask: .hash)) detail=\(AppLog.safeDescription(error), privacy: .public)"
                )
            }
        }
        return upcoming.sorted { ($0.released ?? "") < ($1.released ?? "") }
    }
}

private extension CatalogDescriptor {
    init(_ definition: HomeCatalogDefinition) {
        self.init(
            baseURL: definition.addonBaseURL, addonID: definition.addonID,
            addonName: definition.addonName, type: definition.type,
            catalogID: definition.catalogID, catalogName: definition.catalogName,
            genre: nil, genres: [], supportsPagination: definition.supportsPagination
        )
    }
}

private extension HomeCatalogDefinition {
    init(_ descriptor: CatalogDescriptor) {
        self.init(
            addonBaseURL: descriptor.baseURL, addonID: descriptor.addonID,
            addonName: descriptor.addonName, type: descriptor.type,
            catalogID: descriptor.catalogID, catalogName: descriptor.catalogName,
            supportsPagination: descriptor.supportsPagination
        )
    }
}
