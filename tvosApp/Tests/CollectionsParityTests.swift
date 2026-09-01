import XCTest
@testable import NuvioTV

final class CollectionsParityTests: XCTestCase {
    // MARK: Fixtures

    private let collectionJSON = """
    {
      "id": "c1",
      "title": "Weekend",
      "backdropImageUrl": "https://example.test/backdrop.jpg",
      "pinToTop": true,
      "folders": [
        {
          "id": "f1",
          "title": "Movies",
          "coverImageUrl": "https://example.test/cover.jpg",
          "tileShape": "landscape",
          "hideTitle": false,
          "sources": [
            {"provider": "addon", "addonId": "cinemeta", "type": "movie", "catalogId": "top", "title": "Top movies"}
          ]
        },
        {
          "id": "f2",
          "title": "Shows",
          "tileShape": "poster",
          "hideTitle": true,
          "sources": [
            {"provider": "trakt", "traktListId": 42, "title": "Best of 2026", "mediaType": "movie", "sortBy": "rank", "sortHow": "asc"}
          ]
        }
      ]
    }
    """

    private func makeCollection() -> TVCollection {
        try! JSONDecoder().decode(TVCollection.self, from: Data(collectionJSON.utf8))
    }

    private func makeState(
        protected: Set<String> = [],
        options: [CollectionSourceOption] = []
    ) -> CollectionEditorState {
        let alpha = CollectionItemRef(type: "movie", id: "tt1", name: "Alpha")
        let beta = CollectionItemRef(type: "movie", id: "tt2", name: "Beta")
        let gamma = CollectionItemRef(type: "series", id: "tt3", name: "Gamma")
        let items = ["f1": [alpha, beta], "f2": [gamma]]
        return CollectionEditorState(
            collection: makeCollection(),
            folderItems: items,
            protectedFolderIDs: protected,
            sourceOptions: options
        )
    }

    private var traktOption: CollectionSourceOption {
        CollectionSourceOption(
            id: "trakt:99", kind: .trakt, title: "Trending 2026", subtitle: "Trending list",
            source: CollectionSourceDraft(
                provider: "trakt", title: "Trending 2026", traktListId: 99,
                mediaType: "movie", sortBy: "rank", sortHow: "asc"
            )
        )
    }

    private var tmdbOption: CollectionSourceOption {
        CollectionSourceOption(
            id: "tmdb:company:420:movie", kind: .tmdb, title: "Marvel Studios",
            subtitle: "Production company",
            source: CollectionSourceDraft(
                provider: "tmdb", title: "Marvel Studios", tmdbSourceType: "company",
                tmdbId: 420, mediaType: "movie", sortBy: "popularity.desc"
            )
        )
    }

    // MARK: Tile-shape geometry

    func testTileShapeGeometryMatchesAndroidFolderCard() {
        XCTAssertEqual(CollectionTileShape.poster.tileSize(), CGSize(width: 126, height: 189))
        XCTAssertEqual(CollectionTileShape.landscape.tileSize(), CGSize(width: 126 * 16.0 / 9.0, height: 126))
        XCTAssertEqual(CollectionTileShape.square.tileSize(), CGSize(width: 126, height: 126))
        XCTAssertEqual(
            CollectionTileShape.landscape.tileSize(baseSize: CGSize(width: 90, height: 135)),
            CGSize(width: 160, height: 90))
    }

    func testTileShapeParsingMatchesAndroidPosterShapeFromString() {
        XCTAssertEqual(CollectionTileShape(raw: "landscape"), .landscape)
        XCTAssertEqual(CollectionTileShape(raw: "LANDSCAPE"), .landscape)
        XCTAssertEqual(CollectionTileShape(raw: "square"), .square)
        XCTAssertEqual(CollectionTileShape(raw: "poster"), .poster)
        XCTAssertEqual(CollectionTileShape(raw: "nonsense"), .poster)
        XCTAssertEqual(CollectionTileShape(raw: nil), .poster)
        XCTAssertEqual(CollectionTileShape.landscape.displayName, "Wide")
    }

    // MARK: Dirty-state transitions

    func testInitialStateIsCleanAndMapsSyncedCollection() {
        let state = makeState()
        XCTAssertFalse(state.isDirty)
        XCTAssertTrue(state.divergentEdits.isEmpty)
        XCTAssertEqual(state.title, "Weekend")
        XCTAssertEqual(state.collectionID, "c1")
        XCTAssertFalse(state.isNew)
        XCTAssertEqual(state.folders.map(\.id), ["f1", "f2"])
        XCTAssertEqual(state.folders[0].tileShape, .landscape)
        XCTAssertEqual(state.folders[1].hideTitle, true)
        XCTAssertEqual(state.folders[0].items.map(\.key), ["movie:tt1", "movie:tt2"])
        XCTAssertEqual(state.folders[0].sources.first?.provider, "addon")
        XCTAssertEqual(state.folders[1].sources.first?.traktListId, 42)
    }

    func testCollectionLevelEditsTrackDirtyState() {
        var state = makeState()
        state.setTitle("Weekend Nights")
        XCTAssertTrue(state.isDirty)
        XCTAssertTrue(state.hasDivergentEdit(.renameCollection))
        state.setTitle("Weekend")
        XCTAssertFalse(state.isDirty, "Reverting the rename must clear dirty state")
        state.setPinToTop(false)
        XCTAssertTrue(state.hasDivergentEdit(.pinToTopChanged))
        state.setPinToTop(true)
        XCTAssertFalse(state.isDirty)
        state.setBackdropImageUrl("https://example.test/other.jpg")
        XCTAssertTrue(state.hasDivergentEdit(.backdropChanged))
        state.setBackdropImageUrl("https://example.test/backdrop.jpg")
        XCTAssertFalse(state.isDirty)
        state.markSaved()
        state.setTitle("Changed")
        state.markSaved()
        XCTAssertFalse(state.isDirty, "markSaved must rebase the baseline")
    }

    func testRenameAndFolderSettingEditsTrackDirtyState() {
        var state = makeState()
        XCTAssertTrue(state.renameFolder(id: "f1", to: "Films"))
        XCTAssertTrue(state.hasDivergentEdit(.renameFolder("f1")))
        XCTAssertFalse(state.hasDivergentEdit(.renameFolder("f2")))
        XCTAssertTrue(state.renameFolder(id: "f1", to: "Movies"))
        XCTAssertFalse(state.isDirty)

        state.setTileShape(.square, folderID: "f2")
        XCTAssertTrue(state.hasDivergentEdit(.folderSettings("f2")))
        state.setTileShape(.poster, folderID: "f2")
        XCTAssertFalse(state.isDirty)

        state.setHideTitle(true, folderID: "f1")
        XCTAssertTrue(state.hasDivergentEdit(.folderSettings("f1")))
        state.setHideTitle(false, folderID: "f1")
        XCTAssertFalse(state.isDirty)

        state.setCoverImageUrl("https://example.test/new.jpg", folderID: "f2")
        XCTAssertTrue(state.hasDivergentEdit(.folderSettings("f2")))
        state.setCoverImageUrl(nil, folderID: "f2")
        XCTAssertFalse(state.isDirty)
    }

    func testAddRemoveDeleteFolderTrackDirtyState() {
        var state = makeState()
        _ = state.addFolder(id: "f3", title: "Docs")!
        XCTAssertEqual(state.folders.map(\.id), ["f1", "f2", "f3"])
        XCTAssertTrue(state.hasDivergentEdit(.addFolder("f3")))
        XCTAssertTrue(state.isDirty)

        XCTAssertTrue(state.removeFolder(id: "f3"))
        XCTAssertFalse(state.isDirty, "Removing a just-added folder restores the baseline")
        XCTAssertTrue(state.removeFolder(id: "f2"))
        XCTAssertTrue(state.hasDivergentEdit(.removeFolder("f2")))
        XCTAssertFalse(state.addFolder(id: "f3", title: "Docs") == nil)
        XCTAssertNil(state.addFolder(id: "f1", title: "Duplicate"), "Duplicate IDs are refused")
    }

    func testReorderTracksDirtyState() {
        var state = makeState()
        state.moveFolderUp(1)
        XCTAssertEqual(state.folders.map(\.id), ["f2", "f1"])
        XCTAssertTrue(state.hasDivergentEdit(.reorderFolders))
        state.moveFolderDown(0)
        XCTAssertEqual(state.folders.map(\.id), ["f1", "f2"])
        XCTAssertFalse(state.isDirty)
    }

    func testItemEditsTrackDirtyState() {
        var state = makeState()
        let item = CollectionItemRef(type: "movie", id: "tt9", name: "Delta")
        XCTAssertTrue(state.addItem(item, toFolder: "f1"))
        XCTAssertFalse(state.addItem(item, toFolder: "f1"), "Duplicates are refused")
        XCTAssertTrue(state.hasDivergentEdit(.addItem(folderID: "f1", itemKey: "movie:tt9")))
        XCTAssertTrue(state.removeItem(itemKey: "movie:tt9", fromFolder: "f1"))
        XCTAssertFalse(state.isDirty)

        XCTAssertTrue(state.removeItem(itemKey: "movie:tt1", fromFolder: "f1"))
        XCTAssertTrue(state.hasDivergentEdit(.removeItem(folderID: "f1", itemKey: "movie:tt1")))
    }

    func testMoveItemTracksDirtyStateAndUpdatesFolders() {
        var state = makeState()
        XCTAssertTrue(state.moveItem(itemKey: "movie:tt1", fromFolder: "f1", toFolder: "f2"))
        XCTAssertEqual(state.folders[0].items.map(\.key), ["movie:tt2"])
        XCTAssertEqual(state.folders[1].items.map(\.key), ["series:tt3", "movie:tt1"],
                       "Moved items append to the end of the destination folder")
        XCTAssertTrue(state.hasDivergentEdit(.moveItem(itemKey: "movie:tt1", fromFolderID: "f1", toFolderID: "f2")))
        XCTAssertFalse(state.hasDivergentEdit(.removeItem(folderID: "f1", itemKey: "movie:tt1")))
        XCTAssertTrue(state.moveItem(itemKey: "movie:tt1", fromFolder: "f2", toFolder: "f1"))
        XCTAssertFalse(state.isDirty, "Moving back restores the baseline")
    }

    func testSourceImportTracksDirtyState() {
        var state = makeState(options: [traktOption])
        XCTAssertTrue(state.importSource(traktOption, intoFolder: "f1"))
        XCTAssertFalse(state.importSource(traktOption, intoFolder: "f1"), "Duplicate imports are refused")
        XCTAssertTrue(state.hasDivergentEdit(.importSource(folderID: "f1", fingerprint: traktOption.source.fingerprint)))
        XCTAssertEqual(state.sourcePicker.selectedOptionID, traktOption.id)
        XCTAssertTrue(state.hasImported(traktOption, folderID: "f1"))
        XCTAssertFalse(state.hasImported(traktOption, folderID: "f2"))

        XCTAssertTrue(state.removeSource(at: 1, fromFolder: "f1"))
        XCTAssertFalse(state.isDirty, "Removing the imported source restores the baseline")
    }

    // MARK: Validation

    func testNameValidationRules() {
        var state = makeState()
        XCTAssertTrue(state.canSave)
        XCTAssertTrue(state.validate().isEmpty)
        state.setTitle("   ")
        XCTAssertTrue(state.validate().contains(.collectionTitleEmpty))
        XCTAssertFalse(state.canSave)
        state.setTitle(String(repeating: "a", count: CollectionEditorState.maximumNameLength + 1))
        XCTAssertEqual(state.validate(), [.collectionTitleTooLong(limit: CollectionEditorState.maximumNameLength)])

        state.setTitle("Weekend")
        XCTAssertTrue(state.removeFolder(id: "f1"))
        XCTAssertTrue(state.removeFolder(id: "f2"))
        XCTAssertTrue(state.validate().contains(.collectionNeedsFolders))
        XCTAssertFalse(state.canSave)
    }

    func testFolderNameValidationAndSanitization() {
        var state = makeState()
        state.renameFolder(id: "f1", to: "  ")
        state.renameFolder(id: "f2", to: String(repeating: "b", count: CollectionEditorState.maximumNameLength + 1))
        XCTAssertEqual(state.validate(), [
            .folderNameEmpty(folderID: "f1"),
            .folderNameTooLong(folderID: "f2", limit: CollectionEditorState.maximumNameLength)
        ])
        var sanitized = state.sanitizedForSave()
        XCTAssertEqual(sanitized.folders[0].title, CollectionEditorState.untitledFolderName)
        XCTAssertEqual(sanitized.folders[1].title.count, CollectionEditorState.maximumNameLength + 1,
                       "Sanitization never truncates; validation owns length limits")

        sanitized.setTitle("")
        sanitized = sanitized.sanitizedForSave()
        XCTAssertEqual(sanitized.title, CollectionEditorState.untitledCollectionName)
    }

    // MARK: Reorder correctness

    func testFolderReorderRespectsBoundsLikeAndroid() {
        var state = makeState()
        state.moveFolderUp(0)
        XCTAssertEqual(state.folders.map(\.id), ["f1", "f2"], "Move up at the top is a no-op")
        state.moveFolderDown(state.folders.count - 1)
        XCTAssertEqual(state.folders.map(\.id), ["f1", "f2"], "Move down at the bottom is a no-op")
        XCTAssertFalse(state.isDirty)
        state.moveFolderDown(0)
        XCTAssertEqual(state.folders.map(\.id), ["f2", "f1"])
        state.moveFolderUp(1)
        XCTAssertEqual(state.folders.map(\.id), ["f1", "f2"])
        state.moveFolder(from: 5, to: 0)
        state.moveFolder(from: 0, to: 9)
        state.moveFolder(from: 1, to: 1)
        XCTAssertEqual(state.folders.map(\.id), ["f1", "f2"])
        XCTAssertFalse(state.isDirty)

        var three = makeState()
        three.addFolder(id: "f3", title: "Docs")
        three.moveFolderUp(2)
        XCTAssertEqual(three.folders.map(\.id), ["f1", "f3", "f2"])
        three.moveFolderDown(0)
        XCTAssertEqual(three.folders.map(\.id), ["f3", "f1", "f2"])
    }

    // MARK: Item updates

    func testRemoveAndMoveItemEdgeCases() {
        var state = makeState()
        XCTAssertFalse(state.removeItem(itemKey: "movie:missing", fromFolder: "f1"))
        XCTAssertFalse(state.removeItem(itemKey: "movie:tt1", fromFolder: "f2"))
        XCTAssertFalse(state.moveItem(itemKey: "movie:tt1", fromFolder: "f1", toFolder: "f1"),
                       "Moving inside one folder is a no-op")
        XCTAssertFalse(state.moveItem(itemKey: "movie:missing", fromFolder: "f1", toFolder: "f2"))
        XCTAssertFalse(state.moveItem(itemKey: "movie:tt1", fromFolder: "missing", toFolder: "f2"))
        XCTAssertFalse(state.isDirty)

        let crossFolder = CollectionItemRef(type: "series", id: "tt3", name: "Gamma")
        XCTAssertTrue(state.addItem(crossFolder, toFolder: "f1"),
                      "Folders are independent: a title in one folder may also be added to another")
        XCTAssertEqual(state.folders[1].items.map(\.key), ["series:tt3"],
                       "Adding to another folder never mutates the original folder")
        XCTAssertFalse(state.addItem(crossFolder, toFolder: "f1"),
                       "Duplicates inside one folder are refused")
    }

    // MARK: Source picker selection state

    func testSourcePickerSelectionState() {
        var picker = CollectionSourcePickerState(options: [traktOption, tmdbOption])
        XCTAssertFalse(picker.hasSelection)
        XCTAssertNil(picker.selectedOption())
        picker.select(traktOption.id)
        XCTAssertTrue(picker.isSelected(traktOption.id))
        XCTAssertFalse(picker.isSelected(tmdbOption.id))
        XCTAssertEqual(picker.selectedOption()?.id, traktOption.id)
        XCTAssertEqual(picker.activeProvider, .trakt)

        picker.select(nil)
        XCTAssertFalse(picker.hasSelection)
        XCTAssertEqual(picker.activeProvider, .trakt, "Deselecting keeps the provider context")

        picker.setActiveProvider(.tmdb)
        XCTAssertEqual(picker.selectedOptionID, tmdbOption.id,
                       "Switching providers selects the first option of the kind")
        XCTAssertEqual(picker.options(for: .trakt).map(\.id), [traktOption.id])
        XCTAssertEqual(picker.options(for: .tmdb).map(\.id), [tmdbOption.id])

        picker.recordImportFailure("No lists found")
        XCTAssertEqual(picker.importError, "No lists found")

        var state = makeState(options: [traktOption, tmdbOption])
        state.sourcePicker.select(tmdbOption.id)
        XCTAssertEqual(state.sourcePicker.selectedOption()?.title, "Marvel Studios")
    }

    // MARK: Protected folders

    func testProtectedDefaultFoldersCannotBeRenamedOrDeleted() {
        var state = makeState(protected: ["f1"])
        XCTAssertFalse(state.renameFolder(id: "f1", to: "Nope"))
        XCTAssertFalse(state.removeFolder(id: "f1"))
        XCTAssertFalse(state.isDirty)
        XCTAssertTrue(state.renameFolder(id: "f2", to: "Series"))
        XCTAssertTrue(state.isDirty, "Unprotected folders remain editable")
    }

    // MARK: Sync bridge

    func testEncodedPayloadRoundTripsThroughTVCollection() throws {
        var state = makeState()
        state.setTitle("Weekend Extended")
        state.addFolder(id: "f3", title: "Docs", tileShape: .square)
        state.importSource(traktOption, intoFolder: "f3")

        let data = try state.encodedCollectionPayload()
        let decoded = try JSONDecoder().decode(TVCollection.self, from: data)
        XCTAssertEqual(decoded.id, "c1")
        XCTAssertEqual(decoded.title, "Weekend Extended")
        XCTAssertEqual(decoded.backdropImageUrl, "https://example.test/backdrop.jpg")
        XCTAssertEqual(decoded.pinToTop, true)
        XCTAssertEqual(decoded.folders.map(\.id), ["f1", "f2", "f3"])
        XCTAssertEqual(decoded.folders[0].tileShape, "landscape")
        XCTAssertEqual(decoded.folders[2].tileShape, "square")
        XCTAssertEqual(decoded.folders[1].hideTitle, true)
        XCTAssertEqual(decoded.folders[2].sources.first?.provider, "trakt")
        XCTAssertEqual(decoded.folders[2].sources.first?.traktListId, 99)

        let reloaded = CollectionEditorState(
            collection: decoded,
            folderItems: ["f3": [CollectionItemRef(type: "movie", id: "tt7", name: "Epsilon")]]
        )
        XCTAssertFalse(reloaded.isDirty)
        XCTAssertEqual(reloaded.folders[2].items.map(\.key), ["movie:tt7"])
        XCTAssertTrue(reloaded.hasImported(traktOption, folderID: "f3"))
    }

    // MARK: Android TMDB presets

    func testTmdbPresetsMatchAndroidViewModel() {
        let presets = CollectionSourceOption.tmdbPresets
        XCTAssertEqual(presets.count, 11)
        XCTAssertEqual(Array(presets.map(\.title).prefix(5)),
                       ["Marvel Studios", "Walt Disney Pictures", "Pixar", "Lucasfilm", "Warner Bros."])
        XCTAssertEqual(Array(presets.map(\.title).suffix(6)),
                       ["Netflix", "HBO", "Disney+", "Prime Video", "Hulu", "Apple TV+"])
        XCTAssertEqual(presets[0].source.tmdbId, 420)
        XCTAssertEqual(presets[0].source.tmdbSourceType, "company")
        XCTAssertEqual(presets[0].source.mediaType, "movie")
        XCTAssertEqual(presets[5].source.tmdbSourceType, "network")
        XCTAssertEqual(presets[5].source.tmdbId, 213)
        XCTAssertEqual(presets[5].source.mediaType, "tv")
        XCTAssertEqual(presets[0].source.sortBy, "popularity.desc")
        XCTAssertTrue(presets.allSatisfy { $0.kind == .tmdb })
    }
}
