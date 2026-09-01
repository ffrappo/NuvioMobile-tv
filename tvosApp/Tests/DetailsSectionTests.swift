import XCTest
@testable import NuvioTV

final class DetailsSectionTests: XCTestCase {
    // MARK: - Fixtures

    private func decode(_ json: String) throws -> MetaDetail {
        try JSONDecoder().decode(MetaDetail.self, from: Data(json.utf8))
    }

    private func richSeriesJSON() -> String {
        """
        {
          "id": "tt1234567",
          "type": "series",
          "name": "Cosmos",
          "logo": "https://example.com/logo.png",
          "background": "https://example.com/backdrop.jpg",
          "description": "A documentary series.",
          "releaseInfo": "2014–2019",
          "released": "2014-03-09",
          "runtime": "45",
          "imdbRating": "8.6",
          "genres": ["science-fiction", "documentary"],
          "director": ["Alice Director"],
          "writer": ["Bob Writer"],
          "cast": ["Carol Actor", "Dan Actor", "alice director"],
          "language": "English",
          "videos": [
            {"id": "e1", "name": "Pilot", "season": 1, "episode": 1,
             "released": "2014-03-09T00:00:00.000Z", "thumbnail": "https://img/e1.jpg", "runtime": 45},
            {"id": "e2", "name": "Second", "season": 1, "episode": 2,
             "released": "2014-03-16", "thumbnail": "https://img/e2.jpg", "runtime": 45},
            {"id": "e3", "name": "Third", "season": 1, "episode": 3, "runtime": 45},
            {"id": "s2e1", "name": "New World", "season": 2, "episode": 1, "runtime": 45},
            {"id": "s2e2", "name": "Return", "season": 2, "episode": 2, "runtime": 45},
            {"id": "sp1", "name": "Special", "season": 0, "episode": 1}
          ]
        }
        """
    }

    private func sparseMovieJSON() -> String {
        """
        {"id": "tt7654321", "type": "movie", "name": "Bare"}
        """
    }

    private func summary(id: String, name: String, releaseInfo: String? = nil) -> MetaSummary {
        MetaSummary(id: id, type: "movie", name: name, releaseInfo: releaseInfo)
    }

    // MARK: - Hero meta rows

    func testRichMetaRowComposition() throws {
        let presentation = DetailsPresentation(
            meta: try decode(richSeriesJSON()),
            showFullReleaseDate: false
        )
        let hero = presentation.hero
        XCTAssertEqual(hero.primaryLeadingTexts, ["Series", "Science Fiction"])
        XCTAssertEqual(hero.primaryTrailingTexts, ["45m", "2014–2019"])
        XCTAssertEqual(hero.imdbRatingText, "8.6")
        XCTAssertEqual(hero.yearText, "2014–2019")
        XCTAssertEqual(hero.runtimeText, "45m")
        XCTAssertEqual(hero.languageText, "ENGLISH")
        XCTAssertTrue(hero.hasSecondaryMeta)
        XCTAssertTrue(presentation.isSeries)
    }

    func testMovieFullReleaseDateYear() throws {
        let json = """
        {"id": "m1", "type": "movie", "name": "Dated",
         "releaseInfo": "2024", "released": "2024-03-15"}
        """
        let presentation = DetailsPresentation(meta: try decode(json))
        XCTAssertEqual(presentation.hero.yearText, "March 15, 2024")
        XCTAssertEqual(presentation.hero.primaryTrailingTexts, ["March 15, 2024"])
    }

    func testSparseMetaRowComposition() throws {
        let presentation = DetailsPresentation(meta: try decode(sparseMovieJSON()))
        let hero = presentation.hero
        XCTAssertEqual(hero.primaryLeadingTexts, ["Movie"])
        XCTAssertTrue(hero.primaryTrailingTexts.isEmpty)
        XCTAssertNil(hero.imdbRatingText)
        XCTAssertNil(hero.yearText)
        XCTAssertNil(hero.runtimeText)
        XCTAssertNil(hero.statusBadgeText)
        XCTAssertNil(hero.secondaryHighlightText)
        XCTAssertNil(hero.languageText)
        XCTAssertFalse(hero.hasSecondaryMeta)
        XCTAssertFalse(presentation.isSeries)
    }

    func testStatusMappingMatchesAndroid() {
        XCTAssertEqual(DetailsStatusMapper.badge(status: "Returning Series", isSeries: true), "ONGOING")
        XCTAssertEqual(DetailsStatusMapper.badge(status: "ended", isSeries: true), "ENDED")
        XCTAssertEqual(DetailsStatusMapper.badge(status: "Cancelled", isSeries: false), "CANCELLED")
        XCTAssertEqual(DetailsStatusMapper.badge(status: "post production", isSeries: true), "POST PRODUCTION")
        XCTAssertEqual(DetailsStatusMapper.badge(status: "  Mystery Status  ", isSeries: false), "MYSTERY STATUS")
        XCTAssertNil(DetailsStatusMapper.badge(status: "   ", isSeries: true))
        XCTAssertNil(DetailsStatusMapper.badge(status: nil, isSeries: false))
    }

    func testRuntimeFormattingMatchesAndroid() {
        XCTAssertEqual(DetailsMetaFormatter.formatRuntime("2:14"), "2h 14m")
        XCTAssertEqual(DetailsMetaFormatter.formatRuntime("142"), "2h 22m")
        XCTAssertEqual(DetailsMetaFormatter.formatRuntime("1h 30m"), "1h 30m")
        XCTAssertEqual(DetailsMetaFormatter.formatRuntime("59"), "59m")
        XCTAssertEqual(DetailsMetaFormatter.formatRuntime("  "), nil)
        XCTAssertEqual(DetailsMetaFormatter.formatRuntime("nonsense"), "nonsense")
    }

    func testGenreLabelLocalization() {
        XCTAssertEqual(DetailsGenreLabels.label(for: "science-fiction"), "Science Fiction")
        XCTAssertEqual(DetailsGenreLabels.label(for: "Sci-Fi & Fantasy"), "Sci-Fi & Fantasy")
        XCTAssertEqual(DetailsGenreLabels.label(for: "tv movie"), "TV Movie")
        XCTAssertEqual(DetailsGenreLabels.label(for: "Unknown Genre"), "Unknown Genre")
    }

    // MARK: - Episode watched projection

    func testEpisodeWatchedProjectionAllWatched() throws {
        let meta = try decode(richSeriesJSON())
        let allIDs = Set(meta.videos.map(\.id))
        let presentation = DetailsPresentation(
            meta: meta,
            watchedEpisodeIDs: allIDs
        )
        for season in presentation.seasons {
            for episode in presentation.episodes(season: season.season) {
                XCTAssertTrue(episode.isWatched, "episode \(episode.id) should be watched")
                XCTAssertFalse(episode.isContinueTarget)
            }
        }
        XCTAssertNil(presentation.continueTargetEpisodeID)
    }

    func testEpisodeWatchedProjectionPartialMarksNextContinueTarget() throws {
        let meta = try decode(richSeriesJSON())
        let presentation = DetailsPresentation(
            meta: meta,
            watchedEpisodeIDs: ["e1"],
            completedEpisodeIDs: ["e2"],
            progressByEpisodeID: ["e3": 0.35]
        )
        XCTAssertEqual(presentation.continueTargetEpisodeID, "e3")
        let seasonOne = presentation.episodes(season: 1)
        XCTAssertTrue(seasonOne[0].isWatched) // watchedEpisodeIDs
        XCTAssertTrue(seasonOne[1].isWatched) // completed flag
        XCTAssertFalse(seasonOne[2].isWatched)
        XCTAssertTrue(seasonOne[2].isContinueTarget)
        XCTAssertEqual(seasonOne[2].progressFraction, 0.35)
        // Episodes in season 2 follow the continue target and stay plain.
        XCTAssertFalse(presentation.episodes(season: 2)[0].isContinueTarget)
        XCTAssertNil(seasonOne[0].progressFraction)
        // A watched episode never shows progress.
        XCTAssertNil(seasonOne[1].progressFraction)
    }

    func testEpisodeRatingsBadge() throws {
        let presentation = DetailsPresentation(
            meta: try decode(richSeriesJSON()),
            episodeRatings: [DetailsEpisodeKey(season: 1, episode: 3): 8.45]
        )
        let episode = presentation.episodes(season: 1)[2]
        XCTAssertEqual(episode.imdbRatingText, "8.4")
    }

    func testEpisodeAirDateFormatting() throws {
        let presentation = DetailsPresentation(meta: try decode(richSeriesJSON()))
        XCTAssertEqual(presentation.episodes(season: 1)[0].airDateText, "March 9, 2014")
        XCTAssertEqual(presentation.episodes(season: 1)[1].airDateText, "March 16, 2014")
        XCTAssertNil(presentation.episodes(season: 1)[2].airDateText)
    }

    func testAndroidWatchedProjectionResolverParity() {
        // watchedByVideoId == true wins unless optimistically unmarked, in
        // which case Android falls back to the current flag.
        XCTAssertTrue(DetailsEpisodeWatchedProjection.resolve(
            currentlyWatched: false, completedByProgress: false,
            optimisticallyMarked: false, optimisticallyUnmarked: false,
            watchedByVideoID: true))
        XCTAssertTrue(DetailsEpisodeWatchedProjection.resolve(
            currentlyWatched: true, completedByProgress: true,
            optimisticallyMarked: false, optimisticallyUnmarked: true,
            watchedByVideoID: true))
        // Fresh progress data unmarks a previously watched episode.
        XCTAssertFalse(DetailsEpisodeWatchedProjection.resolve(
            currentlyWatched: true, completedByProgress: false,
            optimisticallyMarked: false, optimisticallyUnmarked: false,
            watchedByVideoID: false))
        // Unknown video state falls back to the current flag.
        XCTAssertTrue(DetailsEpisodeWatchedProjection.resolve(
            currentlyWatched: true, completedByProgress: false,
            optimisticallyMarked: false, optimisticallyUnmarked: false,
            watchedByVideoID: nil))
    }

    // MARK: - Season tabs

    func testSeasonTabModelCompleteness() throws {
        let presentation = DetailsPresentation(meta: try decode(richSeriesJSON()))
        XCTAssertEqual(presentation.seasons.map(\.season), [1, 2, 0])
        XCTAssertEqual(presentation.seasons.map(\.label), ["Season 1", "Season 2", "Specials"])
        XCTAssertEqual(presentation.seasons.map(\.episodeCount), [3, 2, 1])
        XCTAssertEqual(presentation.episodes(season: 1).map(\.id), ["e1", "e2", "e3"])
        XCTAssertEqual(presentation.episodes(season: 2).map(\.episode), [1, 2])
        XCTAssertEqual(presentation.episodes(season: 0).map(\.id), ["sp1"])
    }

    func testSeasonTabsHiddenWithoutEpisodes() throws {
        let presentation = DetailsPresentation(meta: try decode(sparseMovieJSON()))
        XCTAssertTrue(presentation.seasons.isEmpty)
    }

    // MARK: - Section visibility

    func testSectionVisibilityRules() throws {
        let sparse = DetailsPresentation(meta: try decode(sparseMovieJSON()))
        XCTAssertNil(sparse.similarSection)
        XCTAssertNil(sparse.collectionSection)
        XCTAssertNil(sparse.castSection)
        XCTAssertTrue(sparse.trailerItems.isEmpty)
        XCTAssertTrue(sparse.networkCompanies.isEmpty)
        XCTAssertTrue(sparse.productionCompanies.isEmpty)
        XCTAssertEqual(sparse.commentsHeader.title, "Comments")

        let rich = DetailsPresentation(
            meta: try decode(richSeriesJSON()),
            similar: [summary(id: "s1", name: "Similar One", releaseInfo: "2019")],
            collectionName: "Cosmos Collection",
            collection: [summary(id: "c1", name: "Collection Item")],
            networks: [DetailsCompanyItem(name: "HBO")],
            productionCompanies: [DetailsCompanyItem(name: "Pixar", logoURLString: "https://logo.png")],
            trailers: [DetailsTrailerInput(id: "t1", sourceName: "Trailer", languageCode: "en", ytID: "abc123")]
        )
        XCTAssertEqual(rich.similarSection?.items.map(\.title), ["Similar One"])
        XCTAssertEqual(rich.similarSection?.items.first?.subtitle, "2019")
        XCTAssertEqual(rich.collectionSection?.title, "Cosmos Collection")
        XCTAssertEqual(rich.castSection?.leadingMembers.first?.roleLabel, "Director")
        XCTAssertEqual(rich.networkCompanies.map(\.name), ["HBO"])
        XCTAssertEqual(rich.productionCompanies.count, 1)
        XCTAssertEqual(rich.trailerItems.first?.url, "https://www.youtube.com/watch?v=abc123")
        XCTAssertEqual(
            rich.trailerItems.first?.thumbnailURLString,
            "https://img.youtube.com/vi/abc123/hqdefault.jpg"
        )
        XCTAssertEqual(rich.trailerItems.first?.subtitle, "Trailer • EN")
    }

    func testTrailerWithoutURLIsDropped() throws {
        let presentation = DetailsPresentation(
            meta: try decode(sparseMovieJSON()),
            trailers: [
                DetailsTrailerInput(id: "t1"),
                DetailsTrailerInput(id: "t2", title: "Custom", url: "https://example.com/t.mp4"),
            ]
        )
        XCTAssertEqual(presentation.trailerItems.map(\.title), ["Custom"])
        XCTAssertEqual(presentation.trailerItems.first?.url, "https://example.com/t.mp4")
    }

    func testCastModelExcludesLeadingCreditsFromCastRail() throws {
        let presentation = DetailsPresentation(meta: try decode(richSeriesJSON()))
        let cast = try XCTUnwrap(presentation.castSection)
        XCTAssertEqual(cast.leadingMembers.map(\.name), ["Alice Director"])
        XCTAssertEqual(cast.castMembers.map(\.name), ["Carol Actor", "Dan Actor"])
        XCTAssertEqual(cast.directorNames, ["Alice Director"])
        XCTAssertEqual(cast.writerNames, ["Bob Writer"])
    }

    func testCastSectionHiddenWithoutPeople() throws {
        let json = """
        {"id": "x1", "type": "movie", "name": "No Credits",
         "cast": [], "director": [], "writer": []}
        """
        let presentation = DetailsPresentation(meta: try decode(json))
        XCTAssertNil(presentation.castSection)
    }
}
