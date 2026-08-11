import Foundation

@MainActor
final class WatchProgressStore: ObservableObject {
    @Published private(set) var records: [WatchProgressRecord] = []

    private let defaults: UserDefaults
    private let accountService: NuvioAccountService
    private var profileID = 1

    init(
        defaults: UserDefaults = .standard,
        accountService: NuvioAccountService = NuvioAccountService()
    ) {
        self.defaults = defaults
        self.accountService = accountService
        load()
    }

    func selectProfile(_ profileID: Int) {
        guard self.profileID != profileID else { return }
        self.profileID = profileID
        load()
    }

    func record(
        summary: MetaSummary,
        videoID: String,
        season: Int?,
        episode: Int?,
        episodeTitle: String?,
        episodeThumbnail: String?,
        positionSeconds: Double,
        durationSeconds: Double
    ) {
        guard durationSeconds > 0 else { return }
        let position = Int64(max(positionSeconds, 0) * 1_000)
        let duration = Int64(durationSeconds * 1_000)
        let key = WatchProgressRecord.key(
            contentID: summary.id,
            videoID: videoID,
            season: season,
            episode: episode
        )
        let record = WatchProgressRecord(
            contentID: summary.id,
            contentType: summary.type,
            videoID: videoID,
            season: season,
            episode: episode,
            position: position,
            duration: duration,
            lastWatched: Int64(Date().timeIntervalSince1970 * 1_000),
            progressKey: key,
            summary: summary,
            episodeTitle: episodeTitle,
            episodeThumbnail: episodeThumbnail
        )
        upsert(record)
        save()
    }

    func resumablePosition(videoID: String, contentID: String) -> Double? {
        let record = records
            .filter { $0.videoID == videoID || $0.contentID == contentID }
            .max { $0.lastWatched < $1.lastWatched }
        guard let record, !record.isCompleted, record.position >= 15_000 else { return nil }
        return Double(record.position) / 1_000
    }

    func sync(auth: AuthStore, profileID: Int, service: StremioService = StremioService()) async {
        selectProfile(profileID)
        guard auth.session != nil else { return }
        do {
            let token = try await auth.validAccessToken()
            let remote = try await accountService.watchProgress(accessToken: token, profileID: profileID)
            for item in remote {
                let existing = records.first { $0.progressKey == item.progressKey }
                let summary: MetaSummary?
                if let cached = existing?.summary {
                    summary = cached
                } else {
                    summary = await metadataSummary(for: item, service: service)
                }
                upsert(WatchProgressRecord(
                    contentID: item.contentID,
                    contentType: item.contentType,
                    videoID: item.videoID,
                    season: item.season,
                    episode: item.episode,
                    position: item.position,
                    duration: item.duration,
                    lastWatched: item.lastWatched,
                    progressKey: item.progressKey,
                    summary: summary,
                    episodeTitle: existing?.episodeTitle,
                    episodeThumbnail: existing?.episodeThumbnail
                ))
            }
            try await accountService.save(records, accessToken: token, profileID: profileID)
            save()
        } catch {
            return
        }
    }

    var continueWatching: [ContinueWatchingCard] {
        records
            .filter { !$0.isCompleted && $0.position >= 5_000 && $0.summary != nil }
            .sorted { $0.lastWatched > $1.lastWatched }
            .prefix(30)
            .compactMap { record in
                guard let summary = record.summary else { return nil }
                return ContinueWatchingCard(
                    id: record.progressKey,
                    summary: summary,
                    videoID: record.videoID,
                    season: record.season,
                    episode: record.episode,
                    episodeTitle: record.episodeTitle,
                    episodeThumbnail: record.episodeThumbnail,
                    released: nil,
                    positionMilliseconds: record.position,
                    durationMilliseconds: record.duration,
                    lastWatchedMilliseconds: record.lastWatched,
                    isUpcoming: false
                )
            }
    }

    private func metadataSummary(for item: SyncWatchProgressRecord, service: StremioService) async -> MetaSummary? {
        try? await service.details(type: item.contentType, id: item.contentID).summary
    }

    private func upsert(_ record: WatchProgressRecord) {
        if let index = records.firstIndex(where: { $0.progressKey == record.progressKey }) {
            if record.lastWatched >= records[index].lastWatched { records[index] = record }
        } else {
            records.append(record)
        }
    }

    private var storageKey: String { "nuvio.tv.watchProgress.v2.\(profileID)" }

    private func load() {
        records = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([WatchProgressRecord].self, from: $0) } ?? []
    }

    private func save() {
        let newest = records.sorted { $0.lastWatched > $1.lastWatched }.prefix(300)
        defaults.set(try? JSONEncoder().encode(Array(newest)), forKey: storageKey)
    }
}
