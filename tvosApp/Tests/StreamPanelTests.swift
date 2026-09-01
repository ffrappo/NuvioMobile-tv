import XCTest
@testable import NuvioTV

final class StreamPanelTests: XCTestCase {
    // MARK: Fixtures

    private func makeStream(
        name: String,
        title: String? = nil,
        description: String? = nil,
        url: String? = "https://example.com/stream.mp4",
        videoSize: Int64? = nil,
        filename: String? = nil
    ) throws -> StremioStream {
        var payload: [String: Any] = ["name": name]
        if let title { payload["title"] = title }
        if let description { payload["description"] = description }
        if let url { payload["url"] = url }
        if let filename { payload["filename"] = filename }
        if let videoSize {
            payload["behaviorHints"] = ["videoSize": videoSize]
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(StremioStream.self, from: data)
    }

    private func makeSource(
        addon: String,
        name: String,
        title: String? = nil,
        description: String? = nil,
        url: String? = "https://example.com/stream.mp4",
        videoSize: Int64? = nil,
        filename: String? = nil,
        logo: String? = "https://example.com/logo.png"
    ) throws -> StreamSource {
        StreamSource(
            addonName: addon,
            addonLogoURL: logo,
            stream: try makeStream(
                name: name,
                title: title,
                description: description,
                url: url,
                videoSize: videoSize,
                filename: filename
            )
        )
    }

    private var hdFilter: StreamPanelPlaybackFilter {
        StreamPanelPlaybackFilter(
            capabilities: TVPlaybackCapabilities(modelIdentifier: "AppleTV5,3")
        )
    }

    private var modernFilter: StreamPanelPlaybackFilter {
        StreamPanelPlaybackFilter(
            capabilities: TVPlaybackCapabilities(modelIdentifier: "AppleTV14,1")
        )
    }

    private let gigabyte: Int64 = 1_073_741_824

    // MARK: Addon filtering with counts

    func testAddonFilteringWithCounts() throws {
        let sources = [
            try makeSource(addon: "Addon A", name: "A1"),
            try makeSource(addon: "Addon B", name: "B1"),
            try makeSource(addon: "Addon A", name: "A2"),
        ]

        let allSnapshot = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: sources, playbackFilter: modernFilter)
        )
        XCTAssertEqual(allSnapshot.rows.count, 3)
        XCTAssertEqual(allSnapshot.chips.map(\.displayName), ["All", "Addon A", "Addon B"])
        XCTAssertEqual(allSnapshot.chips.map(\.count), [3, 2, 1])
        XCTAssertTrue(allSnapshot.chips[0].isSelected)

        let filtered = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: sources,
                selectedAddon: "Addon A",
                playbackFilter: modernFilter
            )
        )
        XCTAssertEqual(filtered.rows.map(\.title), ["A1", "A2"])
        XCTAssertEqual(filtered.chips.map(\.isSelected), [false, true, false])
        XCTAssertEqual(filtered.totalStreamCount, 3)

        // Android AddonFilterChips falls back to the last addon when the
        // selected addon disappears.
        let fallback = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: sources,
                selectedAddon: "Removed Addon",
                playbackFilter: modernFilter
            )
        )
        XCTAssertEqual(fallback.rows.map(\.title), ["B1"])
        XCTAssertEqual(fallback.chips.map(\.isSelected), [false, false, true])
    }

    func testAddonChipStatusControlsSelectability() throws {
        let sources = [
            try makeSource(addon: "Slow", name: "S1"),
            try makeSource(addon: "Broken", name: "B1"),
        ]
        let snapshot = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: sources,
                playbackFilter: modernFilter,
                addonStatuses: [
                    "Slow": .loading,
                    "Broken": .failure,
                ]
            )
        )
        XCTAssertEqual(snapshot.chips.map(\.status), [.success, .loading, .failure])
        XCTAssertEqual(snapshot.chips.map(\.isSelectable), [true, false, false])
    }

    // MARK: Sort options

    func testSortOptionListMirrorsAndroidProfiles() {
        let snapshot = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: [], playbackFilter: modernFilter)
        )
        XCTAssertEqual(
            snapshot.sortOptions,
            [.original, .bestQuality, .largest, .smallest, .bestAudio, .language]
        )
        XCTAssertEqual(
            snapshot.sortOptions.map(\.displayName),
            [
                "Original order",
                "Best quality first",
                "Largest first",
                "Smallest first",
                "Best audio first",
                "Language first",
            ]
        )
    }

    func testEverySortOptionOrdering() throws {
        func stream(_ name: String, size: Int64) throws -> StreamSource {
            try makeSource(
                addon: "Addon",
                name: name,
                url: "https://example.com/\(name).mp4",
                videoSize: size
            )
        }
        let sources = [
            try stream("2160p BluRay REMUX", size: 40 * gigabyte), // s0
            try stream("1080p WEB-DL", size: 8 * gigabyte),        // s1
            try stream("1080p WEB-DL 7.1 Atmos", size: 10 * gigabyte), // s2
            try stream("720p", size: 2 * gigabyte),                // s3
        ]

        func order(_ option: StreamSortOption, languages: [String] = []) -> [String] {
            StreamPanelPresentation.snapshot(
                for: StreamPanelInput(
                    sources: sources,
                    sortOption: option,
                    playbackFilter: modernFilter,
                    preferredLanguages: languages
                )
            ).rows.map(\.title)
        }

        XCTAssertEqual(order(.original), [
            "2160p BluRay REMUX", "1080p WEB-DL", "1080p WEB-DL 7.1 Atmos", "720p",
        ])
        // Resolution, quality, visual, audio, channel, encode, size — all desc.
        XCTAssertEqual(order(.bestQuality), [
            "2160p BluRay REMUX", "1080p WEB-DL 7.1 Atmos", "1080p WEB-DL", "720p",
        ])
        XCTAssertEqual(order(.largest), [
            "2160p BluRay REMUX", "1080p WEB-DL 7.1 Atmos", "1080p WEB-DL", "720p",
        ])
        XCTAssertEqual(order(.smallest), [
            "720p", "1080p WEB-DL", "1080p WEB-DL 7.1 Atmos", "2160p BluRay REMUX",
        ])
        // Audio tag, channel, resolution, quality, size.
        XCTAssertEqual(order(.bestAudio), [
            "1080p WEB-DL 7.1 Atmos", "2160p BluRay REMUX", "1080p WEB-DL", "720p",
        ])
        // Preferred language first, then resolution, quality, size.
        let italianSources = [
            try makeSource(
                addon: "Addon",
                name: "2160p BluRay REMUX",
                url: "https://example.com/a.mp4",
                videoSize: 40 * gigabyte
            ),
            try makeSource(
                addon: "Addon",
                name: "1080p WEB-DL Italian",
                url: "https://example.com/b.mp4",
                videoSize: 8 * gigabyte
            ),
            try makeSource(
                addon: "Addon",
                name: "1080p WEB-DL 7.1 Atmos",
                url: "https://example.com/c.mp4",
                videoSize: 10 * gigabyte
            ),
            try makeSource(
                addon: "Addon",
                name: "720p",
                url: "https://example.com/d.mp4",
                videoSize: 2 * gigabyte
            ),
        ]
        let languageOrder = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: italianSources,
                sortOption: .language,
                playbackFilter: modernFilter,
                preferredLanguages: ["Italian"]
            )
        ).rows.map(\.title)
        XCTAssertEqual(languageOrder, [
            "1080p WEB-DL Italian", "2160p BluRay REMUX", "1080p WEB-DL 7.1 Atmos", "720p",
        ])
    }

    // MARK: Badge composition

    func testBadgeCompositionFromRichFixture() throws {
        let source = try makeSource(
            addon: "Torrents",
            name: "Torrent 4K HDR DV x265 5.1",
            description: "8 seeders",
            videoSize: 6 * gigabyte
        )
        let snapshot = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: [source], playbackFilter: modernFilter)
        )
        let row = try XCTUnwrap(snapshot.rows.first)
        XCTAssertEqual(
            row.badges.map(\.text),
            ["4K", "6.0 GB", "8 seeds", "HEVC", "DV", "5.1"]
        )
        XCTAssertEqual(
            row.badges.map(\.kind),
            [.quality, .size, .seeds, .codec, .hdr, .audio]
        )
        XCTAssertTrue(row.badges.first { $0.kind == .hdr }?.isProminent ?? false)
    }

    func testBadgeCompositionFromSparseFixture() throws {
        let source = try makeSource(addon: "Plain", name: "Plain source", url: nil)
        let snapshot = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: [source], playbackFilter: modernFilter)
        )
        let row = try XCTUnwrap(snapshot.rows.first)
        XCTAssertTrue(row.badges.isEmpty)
        XCTAssertEqual(row.compatibilityIssue, "Unavailable")
        XCTAssertFalse(row.isPlayable)
    }

    // MARK: Capability filtering

    func testCapabilityFilteringMarksAndOmits() throws {
        let sources = [
            try makeSource(addon: "A", name: "1080p", url: "https://example.com/1.mp4"),
            try makeSource(addon: "A", name: "4K", url: "https://example.com/2.mp4"),
            try makeSource(addon: "A", name: "AV1 1080p", url: "https://example.com/3.mp4"),
            try makeSource(addon: "A", name: "No URL", url: nil),
        ]

        let marked = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: sources, playbackFilter: hdFilter)
        )
        XCTAssertEqual(marked.rows.count, 4)
        XCTAssertEqual(marked.playableCount, 1)
        XCTAssertEqual(marked.limitedCount, 3)
        XCTAssertEqual(marked.rows[0].compatibilityIssue, nil)
        XCTAssertEqual(marked.rows[1].compatibilityIssue, "Requires Apple TV 4K")
        XCTAssertEqual(marked.rows[2].compatibilityIssue, "Requires newer Apple TV hardware")
        XCTAssertEqual(marked.rows[3].compatibilityIssue, "Unavailable")

        let omitted = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: sources,
                playbackFilter: StreamPanelPlaybackFilter(
                    capabilities: hdFilter.capabilities,
                    omitUnplayable: true
                )
            )
        )
        XCTAssertEqual(omitted.rows.count, 1)
        XCTAssertEqual(omitted.rows.first?.title, "1080p")
        XCTAssertEqual(omitted.totalStreamCount, 4)

        let modern = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: Array(sources.prefix(3)),
                playbackFilter: modernFilter
            )
        )
        XCTAssertEqual(modern.rows.count, 3)
        XCTAssertEqual(modern.playableCount, 3)
    }
}
