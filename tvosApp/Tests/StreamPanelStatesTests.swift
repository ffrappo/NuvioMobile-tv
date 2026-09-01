import XCTest
@testable import NuvioTV

/// Focus restoration, empty/loading, and failure states for the stream panel.
final class StreamPanelStatesTests: XCTestCase {
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

    // MARK: Focus anchor and playing index

    func testFocusAnchorFollowsPlayingRow() throws {
        let sources = [
            try makeSource(addon: "A", name: "First", url: "https://example.com/1.mp4"),
            try makeSource(addon: "A", name: "Second", url: "https://example.com/2.mp4"),
            try makeSource(addon: "A", name: "Third", url: "https://example.com/3.mp4"),
        ]
        let snapshot = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: sources,
                playing: StreamPlayingReference(
                    url: "https://example.com/2.mp4",
                    addonName: "A"
                ),
                playbackFilter: modernFilter
            )
        )
        XCTAssertEqual(snapshot.playingIndex, 1)
        XCTAssertEqual(snapshot.focusAnchor.rowIndex, 1)
        XCTAssertEqual(snapshot.focusAnchorRowID, snapshot.rows[1].id)
        XCTAssertTrue(snapshot.rows[1].isPlaying)
        XCTAssertFalse(snapshot.rows[0].isPlaying)
    }

    func testFocusAnchorPrefersAddonThenUrlMatching() throws {
        let sources = [
            try makeSource(addon: "A", name: "Same", url: "https://example.com/dup.mp4"),
            try makeSource(addon: "B", name: "Same", url: "https://example.com/dup.mp4"),
        ]
        let snapshot = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: sources,
                playing: StreamPlayingReference(
                    url: "https://example.com/dup.mp4",
                    addonName: "B"
                ),
                playbackFilter: modernFilter
            )
        )
        XCTAssertEqual(snapshot.playingIndex, 1)

        let urlOnly = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: sources,
                playing: StreamPlayingReference(url: "https://example.com/dup.mp4"),
                playbackFilter: modernFilter
            )
        )
        XCTAssertEqual(urlOnly.playingIndex, 0)
    }

    func testFocusAnchorFallsBackToFirstPlayableRow() throws {
        let sources = [
            try makeSource(addon: "A", name: "4K", url: "https://example.com/1.mp4"),
            try makeSource(addon: "A", name: "1080p", url: "https://example.com/2.mp4"),
        ]
        // Playing stream is filtered out by the addon filter: fall back to
        // the first playable row.
        let snapshot = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: sources,
                selectedAddon: "A",
                playing: StreamPlayingReference(url: "https://example.com/other.mp4"),
                playbackFilter: hdFilter
            )
        )
        XCTAssertNil(snapshot.playingIndex)
        XCTAssertEqual(snapshot.focusAnchor.rowIndex, 1)

        let empty = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: [], playbackFilter: modernFilter)
        )
        XCTAssertNil(empty.focusAnchor.rowIndex)
        XCTAssertNil(empty.focusAnchorRowID)
        XCTAssertFalse(empty.focusAnchor.hasRows)
    }

    // MARK: Empty and failure states

    func testEmptyAndLoadingStates() {
        let empty = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: [], playbackFilter: modernFilter)
        )
        XCTAssertEqual(empty.contentState, .empty)
        XCTAssertEqual(empty.rows, [])
        XCTAssertEqual(empty.headerCountLabel, "0 streams")

        let loading = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: [], isLoading: true, playbackFilter: modernFilter)
        )
        XCTAssertEqual(loading.contentState, .loading)
        XCTAssertTrue(loading.isLoading)

        let loadingWithPartial = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: [try! makeSource(addon: "A", name: "Partial")],
                isLoading: true,
                playbackFilter: modernFilter
            )
        )
        XCTAssertEqual(loadingWithPartial.contentState, .loading)
    }

    func testFailureStates() throws {
        let failures = ["Broken addon: timeout", "Other addon: 500"]
        let failureOnly = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: [],
                failures: failures,
                playbackFilter: modernFilter
            )
        )
        XCTAssertEqual(failureOnly.contentState, .failure(failures))

        let partial = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: [try makeSource(addon: "A", name: "Works")],
                failures: failures,
                playbackFilter: modernFilter
            )
        )
        XCTAssertEqual(partial.contentState, .content)
        XCTAssertEqual(partial.failures, failures)
        XCTAssertEqual(partial.rows.count, 1)
    }

    func testHeaderCountLabel() throws {
        let sources = [
            try makeSource(addon: "A", name: "1080p", url: "https://example.com/1.mp4"),
            try makeSource(addon: "A", name: "4K", url: "https://example.com/2.mp4"),
        ]
        let clean = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: sources, playbackFilter: modernFilter)
        )
        XCTAssertEqual(clean.headerCountLabel, "2 streams")

        let limited = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: sources, playbackFilter: hdFilter)
        )
        XCTAssertEqual(limited.headerCountLabel, "2 streams · 1 ready · 1 limited")
    }

    func testFileSizeBadgeVisibilityToggle() throws {
        let source = try makeSource(
            addon: "A",
            name: "1080p",
            url: "https://example.com/1.mp4",
            videoSize: 2 * gigabyte
        )
        let withSize = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(sources: [source], playbackFilter: modernFilter)
        )
        XCTAssertTrue(withSize.rows[0].badges.contains { $0.kind == .size })

        let withoutSize = StreamPanelPresentation.snapshot(
            for: StreamPanelInput(
                sources: [source],
                playbackFilter: modernFilter,
                showFileSizeBadges: false
            )
        )
        XCTAssertFalse(withoutSize.rows[0].badges.contains { $0.kind == .size })
    }
}
