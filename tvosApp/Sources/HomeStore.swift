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
    private var activeOrder: [HomeCatalogDefinition] = []
    private var lastFailures = 0
    private var loadingSectionIDs: Set<String> = []
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
        activeOrder = active
        loadingSectionIDs = []
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
                return HomeCatalogSection(definition: definition, items: items, nextSkip: page.nextSkip)
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
        lastFailures = failures
        cachedSections = sections
        publish(sections: sections, active: active, failures: failures, loading: false)
    }

    /// Android parity: rails request more catalog pages as focus approaches the
    /// end of a row (loadMoreCatalogItems in HomeViewModel).
    func loadMore(sectionID: String) async {
        guard var section = cachedSections[sectionID], section.nextSkip != nil,
              !loadingSectionIDs.contains(sectionID) else { return }
        let requestGeneration = generation
        loadingSectionIDs.insert(sectionID)
        publish(
            sections: cachedSections, active: activeOrder,
            failures: lastFailures, loading: snapshot.isLoading
        )
        var listing = CatalogListing.from(section)
        listing.nextSkip = section.nextSkip
        do {
            let page = try await repository.nextPage(of: listing)
            guard !Task.isCancelled, requestGeneration == generation else { return }
            if let page {
                let hideUnreleased = preferences.value.hideUnreleasedContent
                let newItems = HomeReleaseFilter.releasedItems(page.items, enabled: hideUnreleased)
                var seen = Set(section.items.map { "\($0.type):\($0.id)" })
                let appended = newItems.filter { seen.insert("\($0.type):\($0.id)").inserted }
                section.items += appended
                // A page with no new items means the catalog repeats or ended;
                // stop paginating either way.
                section.nextSkip = appended.isEmpty ? nil : page.nextSkip
            } else {
                section.nextSkip = nil
            }
        } catch {
            section.nextSkip = nil
        }
        guard requestGeneration == generation else { return }
        loadingSectionIDs.remove(sectionID)
        cachedSections[sectionID] = section
        publish(
            sections: cachedSections, active: activeOrder,
            failures: lastFailures, loading: snapshot.isLoading
        )
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
        snapshot.watchedContentKeys = Set(
            progress.records
                .filter(\.isCompleted)
                .map { "\($0.contentType.lowercased()):\($0.contentID)" }
        )
        snapshot.loadingSectionIDs = loadingSectionIDs
        if !loading {
            let generation = generation
            Task { [weak self] in
                guard let self else { return }
                let upcoming = await self.buildUpcoming(from: self.progress.records)
                guard !Task.isCancelled, generation == self.generation else { return }
                self.snapshot.upcoming = upcoming
            }
        }
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
        let candidates = Array(
            records.filter { $0.contentType.lowercased() == "series" && $0.isCompleted }.prefix(12)
        )
        let batches = AsyncBatcher.batches(candidates, limit: 3) { [service] record -> ContinueWatchingCard? in
            guard let summary = record.summary else { return nil }
            do {
                let detail = try await service.details(
                    type: record.contentType,
                    id: record.contentID,
                    baseURL: summary.metadataBaseURL ?? StremioService.cinemetaBaseURL.absoluteString
                )
                guard let next = HomeUpcomingResolver.nextEpisode(after: record, videos: detail.videos) else {
                    return nil
                }
                return ContinueWatchingCard(
                    id: "upcoming:\(record.contentID):\(next.id)", summary: summary,
                    videoID: next.id, season: next.season, episode: next.episode,
                    episodeTitle: next.name, episodeThumbnail: next.thumbnail,
                    released: next.released, positionMilliseconds: 0, durationMilliseconds: 0,
                    lastWatchedMilliseconds: record.lastWatched, isUpcoming: true
                )
            } catch {
                AppLog.home.error(
                    "Upcoming enrichment failed content=\(record.contentID, privacy: .private(mask: .hash)) detail=\(AppLog.safeDescription(error), privacy: .public)"
                )
                return nil
            }
        }
        var upcoming: [ContinueWatchingCard] = []
        for await batch in batches {
            guard !Task.isCancelled else { return [] }
            upcoming.append(contentsOf: batch.compactMap(\.value))
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
