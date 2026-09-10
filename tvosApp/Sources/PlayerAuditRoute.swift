import Foundation

#if DEBUG
extension PlayerRoute {
    static var sampleAuditRoute: PlayerRoute {
        let sampleURL = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
        let summary = MetaSummary(
            id: "tt0903747",
            type: "series",
            name: "Breaking Bad",
            poster: "https://images.metahub.space/poster/medium/tt0903747/img.jpg",
            background: "https://images.metahub.space/background/medium/tt0903747/img.jpg",
            description: "A high school chemistry teacher diagnosed with inoperable lung cancer turns to manufacturing and selling methamphetamine in order to secure his family's future.",
            releaseInfo: "2008-2013",
            genres: ["Crime", "Drama", "Thriller"]
        )
        return PlayerRoute(
            url: sampleURL,
            contentID: "tt0903747:1:1",
            imdbID: "tt0903747",
            title: "Breaking Bad",
            sourceName: "1080p HEVC • Torrentio",
            summary: summary,
            videoID: "tt0903747:1:1",
            seasonNumber: 1,
            episodeNumber: 1,
            episodeTitle: "Pilot",
            availableSources: [
                PlayerSourceOption(
                    id: UUID(),
                    url: sampleURL,
                    name: "Breaking.Bad.S01E01.1080p.BluRay.x265",
                    addonName: "Torrentio",
                    displaySummary: "1080p • 1.8 GB",
                    compatibilityIssue: nil,
                    requestHeaders: [:],
                    responseHeaders: [:]
                ),
                PlayerSourceOption(
                    id: UUID(),
                    url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4#4k")!,
                    name: "Breaking.Bad.S01E01.2160p.UHD.HDR.x265",
                    addonName: "Torrentio",
                    displaySummary: "4K HDR • 5.2 GB",
                    compatibilityIssue: nil,
                    requestHeaders: [:],
                    responseHeaders: [:]
                ),
                PlayerSourceOption(
                    id: UUID(),
                    url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4#720p")!,
                    name: "Breaking.Bad.S01E01.720p.HDTV",
                    addonName: "Torrentio",
                    displaySummary: "720p • 800 MB",
                    compatibilityIssue: nil,
                    requestHeaders: [:],
                    responseHeaders: [:]
                )
            ],
            streamSources: [],
            episodes: [
                PlayerEpisodeOption(id: "tt0903747:1:1", title: "Pilot", seasonNumber: 1, episodeNumber: 1),
                PlayerEpisodeOption(id: "tt0903747:1:2", title: "Cat's in the Bag...", seasonNumber: 1, episodeNumber: 2),
                PlayerEpisodeOption(id: "tt0903747:1:3", title: "...And the Bag's in the River", seasonNumber: 1, episodeNumber: 3),
                PlayerEpisodeOption(id: "tt0903747:1:4", title: "Cancer Man", seasonNumber: 1, episodeNumber: 4),
                PlayerEpisodeOption(id: "tt0903747:1:5", title: "Gray Matter", seasonNumber: 1, episodeNumber: 5),
                PlayerEpisodeOption(id: "tt0903747:1:6", title: "Crazy Handful of Nothin'", seasonNumber: 1, episodeNumber: 6),
                PlayerEpisodeOption(id: "tt0903747:1:7", title: "A No-Rough-Stuff-Type Deal", seasonNumber: 1, episodeNumber: 7)
            ],
            onSelectEpisode: { _ in }
        )
    }
}
#endif

