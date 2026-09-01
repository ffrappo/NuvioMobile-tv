import XCTest
@testable import NuvioTV

final class AddonManagerParityTests: XCTestCase {
    // MARK: - Fixtures

    private func snapshot(
        baseURL: String,
        manifestID: String? = nil,
        name: String,
        customName: String? = nil,
        version: String = "1.0.0",
        types: [String] = ["movie", "series"],
        catalogs: [AddonCatalogSnapshot] = [
            AddonCatalogSnapshot(type: "movie", id: "top", name: "Popular"),
            AddonCatalogSnapshot(type: "series", id: "top", name: "Popular")
        ],
        configurationRequired: Bool = false,
        isEnabled: Bool = true,
        isProtected: Bool = false
    ) -> AddonSnapshot {
        AddonSnapshot(
            baseURL: baseURL,
            manifestID: manifestID ?? baseURL,
            name: name,
            customName: customName,
            version: version,
            types: types,
            catalogs: catalogs,
            configurationRequired: configurationRequired,
            isEnabled: isEnabled,
            isProtected: isProtected
        )
    }

    private var defaultProtectedURLs: Set<String> {
        AddonListModel.defaultProtectedBaseURLs
    }

    // MARK: - List composition and sort

    func testListCompositionPreservesUserOrderAndBuildsEntries() {
        let model = AddonListModel(addons: [
            snapshot(baseURL: "https://b.example.com", name: "Beta", version: "0.4.2"),
            snapshot(baseURL: "https://a.example.com", name: "Alpha", version: "", types: ["movie"])
        ])
        XCTAssertEqual(model.orderedIDs, ["https://b.example.com", "https://a.example.com"])
        XCTAssertEqual(model.entries[0].displayName, "Beta")
        XCTAssertEqual(model.entries[0].versionLabel, "v0.4.2")
        XCTAssertNil(model.entries[1].versionLabel, "blank versions have no label, as in Android")
        XCTAssertEqual(model.entries[0].catalogCount, 2)
        XCTAssertEqual(model.entries[1].catalogSummary, "2 catalogs • movie")
        XCTAssertEqual(model.entries[0].catalogSummary, "2 catalogs • movie, series")
    }

    func testDuplicateManifestNamesGetOccurrenceSuffixes() throws {
        let model = AddonListModel(addons: [
            snapshot(baseURL: "https://one.example.com", name: "Torrentio"),
            snapshot(baseURL: "https://two.example.com", name: "Torrentio"),
            snapshot(baseURL: "https://three.example.com", name: "Torrentio"),
            snapshot(baseURL: "https://renamed.example.com", name: "Torrentio", customName: "My scraper")
        ])
        let names = model.entries.map(\.displayName)
        XCTAssertEqual(names, ["Torrentio", "Torrentio (2)", "Torrentio (3)", "My scraper"])
    }

    func testDefaultProtectedAddonURLsMatchAndroidDefaults() {
        XCTAssertEqual(
            defaultProtectedURLs,
            ["https://v3-cinemeta.strem.io", "https://opensubtitles-v3.strem.io"]
        )
    }

    // MARK: - Enable/disable and protected rules

    func testToggleEnabledUpdatesState() {
        var model = AddonListModel(addons: [snapshot(baseURL: "https://a.example.com", name: "Alpha")])
        XCTAssertTrue(model.setEnabled("https://a.example.com", false))
        XCTAssertEqual(model.entry(for: "https://a.example.com")?.isEnabled, false)
        XCTAssertFalse(model.setEnabled("https://a.example.com", false), "same value is a no-op")
        XCTAssertFalse(model.setEnabled("https://missing.example.com", true), "unknown id is rejected")
    }

    func testProtectedAddonCannotBeDisabledOrRemoved() {
        var model = AddonListModel(addons: [
            snapshot(baseURL: "https://v3-cinemeta.strem.io", name: "Cinemeta", isProtected: true)
        ])
        XCTAssertFalse(model.setEnabled("https://v3-cinemeta.strem.io", false))
        XCTAssertEqual(model.entry(for: "https://v3-cinemeta.strem.io")?.isEnabled, true)
        XCTAssertEqual(model.entry(for: "https://v3-cinemeta.strem.io")?.canRemove, false)
        XCTAssertEqual(model.entry(for: "https://v3-cinemeta.strem.io")?.canToggleEnabled, false)
        XCTAssertFalse(model.requestRemoval("https://v3-cinemeta.strem.io"))
        XCTAssertEqual(model.selection.state, .idle, "no confirmation state may open for protected addons")
    }

    func testRemovalRequiresConfirmationFlow() {
        var model = AddonListModel(addons: [
            snapshot(baseURL: "https://a.example.com", name: "Alpha"),
            snapshot(baseURL: "https://b.example.com", name: "Beta")
        ])
        model.requestRemoval("https://a.example.com")
        XCTAssertEqual(model.selection.state, .confirmingRemoval(addonID: "https://a.example.com"))
        model.cancelRemoval()
        XCTAssertEqual(model.selection.state, .focused(addonID: "https://a.example.com"))
        XCTAssertEqual(model.orderedIDs.count, 2)

        model.requestRemoval("https://a.example.com")
        XCTAssertEqual(model.confirmRemoval(), "https://a.example.com")
        XCTAssertEqual(model.orderedIDs, ["https://b.example.com"])
        XCTAssertNil(model.confirmRemoval(), "confirming with nothing pending is a no-op")
    }

    func testMoveOperationsRespectBounds() {
        var model = AddonListModel(addons: [
            snapshot(baseURL: "https://a.example.com", name: "Alpha"),
            snapshot(baseURL: "https://b.example.com", name: "Beta"),
            snapshot(baseURL: "https://c.example.com", name: "Gamma")
        ])
        XCTAssertFalse(model.moveUp("https://a.example.com"))
        XCTAssertTrue(model.moveDown("https://a.example.com"))
        XCTAssertEqual(model.orderedIDs, ["https://b.example.com", "https://a.example.com", "https://c.example.com"])
        XCTAssertFalse(model.moveDown("https://c.example.com"))
        XCTAssertTrue(model.moveUp("https://c.example.com"))
        XCTAssertEqual(model.orderedIDs, ["https://b.example.com", "https://c.example.com", "https://a.example.com"])
        XCTAssertFalse(model.moveUp("https://missing.example.com"))
    }

    // MARK: - Credential badge rules

    func testCredentialBadgeRules() {
        XCTAssertEqual(
            AddonCredentialBadge(configurationRequired: false, baseURL: "https://cinemeta.strem.io"),
            .none
        )
        XCTAssertEqual(
            AddonCredentialBadge(configurationRequired: true, baseURL: "https://cinemeta.strem.io"),
            .setupRequired
        )
        XCTAssertEqual(
            AddonCredentialBadge(
                configurationRequired: true,
                baseURL: "https://torrentio.example.com/manifest.json?key=abc"
            ),
            .configured,
            "an embedded query wins over configurationRequired"
        )
        XCTAssertEqual(
            AddonCredentialBadge(
                configurationRequired: false,
                baseURL: "https://torrentio.example.com/abcdef123/manifest.json"
            ),
            .configured,
            "a key path segment marks a configured addon"
        )
        XCTAssertNil(AddonCredentialBadge.none.displayText)
        XCTAssertEqual(AddonCredentialBadge.setupRequired.displayText, "Setup required")
        XCTAssertEqual(AddonCredentialBadge.configured.displayText, "Configured")
    }

    func testListEntryCarriesCredentialBadge() {
        let model = AddonListModel(addons: [
            snapshot(
                baseURL: "https://debrid.example.com/config123",
                name: "Debrid addon",
                configurationRequired: true
            )
        ])
        XCTAssertEqual(model.entries[0].credentialBadge, .configured)
    }

    // MARK: - Catalog order

    private func orderableAddons() -> [AddonSnapshot] {
        [
            snapshot(
                baseURL: "https://cinemeta.example.com",
                manifestID: "com.meta",
                name: "Cinemeta",
                catalogs: [
                    AddonCatalogSnapshot(type: "movie", id: "top", name: "Popular"),
                    AddonCatalogSnapshot(type: "series", id: "top", name: "Popular"),
                    AddonCatalogSnapshot(
                        type: "movie", id: "search", name: "Search",
                        isSearchOnly: true
                    )
                ]
            ),
            snapshot(
                baseURL: "https://trakt.example.com",
                manifestID: "com.trakt",
                name: "Trakt",
                catalogs: [AddonCatalogSnapshot(type: "movie", id: "trending", name: "Trending")]
            )
        ]
    }

    func testCatalogOrderBuildFiltersSearchOnlyAndAppliesSavedOrder() {
        let model = CatalogOrderModel(addons: orderableAddons())
        XCTAssertEqual(
            model.orderKeys,
            ["com.meta_movie_top", "com.meta_series_top", "com.trakt_movie_trending"],
            "search-only catalogs are excluded and unknown saved keys dropped"
        )
        XCTAssertEqual(model.items.map(\.addonName), ["Cinemeta", "Cinemeta", "Trakt"])
        XCTAssertEqual(model.items[0].displayTitle, "Popular - Movie")
        XCTAssertFalse(model.items[0].canMoveUp)
        XCTAssertFalse(model.items[2].canMoveDown)
        XCTAssertTrue(model.items[1].canMoveUp)
        XCTAssertTrue(model.items[1].canMoveDown)

        let reordered = CatalogOrderModel(
            addons: orderableAddons(),
            savedOrderKeys: [
                "com.trakt_movie_trending",
                "com.meta_series_top",
                "com.meta_movie_top",
                "unknown_key"
            ]
        )
        XCTAssertEqual(
            reordered.orderKeys,
            ["com.trakt_movie_trending", "com.meta_series_top", "com.meta_movie_top"]
        )
    }

    func testDisabledAddonCatalogsAreExcluded() {
        let addons = orderableAddons().map { addon in
            addon.baseURL.contains("trakt") ? addon.with(isEnabled: false) : addon
        }
        let model = CatalogOrderModel(addons: addons)
        XCTAssertEqual(model.orderKeys, ["com.meta_movie_top", "com.meta_series_top"])
    }

    func testLegacyDisableKeyIsRespected() {
        let key = "com.trakt_movie_trending"
        let legacy = AddonCatalogKeys.legacyDisabledCatalogKey(
            addonBaseURL: "https://trakt.example.com",
            type: "movie",
            catalogID: "trending",
            catalogName: "Trending"
        )
        let model = CatalogOrderModel(addons: orderableAddons(), disabledKeys: [legacy])
        XCTAssertEqual(model.items.first(where: { $0.key == key })?.isDisabled, true)
        XCTAssertEqual(model.disabledKeys, [legacy])
    }

    func testCatalogMoveOperations() {
        var model = CatalogOrderModel(addons: orderableAddons())
        XCTAssertTrue(model.moveUp("com.meta_series_top"))
        XCTAssertEqual(
            model.orderKeys,
            ["com.meta_series_top", "com.meta_movie_top", "com.trakt_movie_trending"]
        )
        XCTAssertEqual(model.items[0].displayTitle, "Popular - Series")
        XCTAssertFalse(model.moveDown("com.trakt_movie_trending"))
        XCTAssertFalse(model.moveUp("com.meta_series_top"))
        XCTAssertFalse(model.moveUp("missing"))
    }

    func testCatalogToggleDisabled() {
        var model = CatalogOrderModel(addons: orderableAddons())
        model.toggleDisabled("com.meta_movie_top")
        XCTAssertEqual(model.items[0].isDisabled, true)
        XCTAssertEqual(model.disabledKeys, ["com.meta_movie_top"])
        model.toggleDisabled("com.meta_movie_top")
        XCTAssertEqual(model.items[0].isDisabled, false)
        XCTAssertTrue(model.disabledKeys.isEmpty)
    }

    func testCatalogResetOrderRestoresManifestOrder() {
        var model = CatalogOrderModel(addons: orderableAddons())
        model.moveUp("com.meta_series_top")
        model.moveDown("com.meta_movie_top")
        XCTAssertNotEqual(
            model.orderKeys,
            ["com.meta_movie_top", "com.meta_series_top", "com.trakt_movie_trending"]
        )
        model.resetOrder()
        XCTAssertEqual(
            model.orderKeys,
            ["com.meta_movie_top", "com.meta_series_top", "com.trakt_movie_trending"]
        )
    }

    func testRenameValidationRules() {
        XCTAssertEqual(CatalogNameValidator.validate("  Popular Movies  "), .success("Popular Movies"))
        XCTAssertEqual(CatalogNameValidator.validate("   "), .success(nil), "blank resets to the manifest name")
        XCTAssertEqual(
            CatalogNameValidator.validate(String(repeating: "a", count: 61)),
            .failure(.tooLong(maxLength: 60))
        )
        XCTAssertEqual(
            CatalogNameValidator.validate(String(repeating: "a", count: 60)),
            .success(String(repeating: "a", count: 60))
        )
        XCTAssertEqual(
            CatalogNameValidator.validate("Bad\nName"),
            .failure(.invalidCharacters)
        )
        XCTAssertEqual(
            CatalogNameValidator.validate("Bad\tName"),
            .failure(.invalidCharacters)
        )
    }

    func testRenameAppliesAndClearsCustomTitles() throws {
        var model = CatalogOrderModel(addons: orderableAddons())
        let key = "com.meta_movie_top"
        let applied = model.rename(key, rawTitle: "  Trending Films  ")
        XCTAssertNil(applied)
        XCTAssertEqual(model.items.first(where: { $0.key == key })?.catalogName, "Trending Films")
        XCTAssertEqual(model.items.first(where: { $0.key == key })?.displayTitle, "Trending Films - Movie")
        XCTAssertEqual(model.customTitles[key], "Trending Films")

        let cleared = model.rename(key, rawTitle: " ")
        XCTAssertNil(cleared)
        XCTAssertEqual(model.items.first(where: { $0.key == key })?.catalogName, "Popular")
        XCTAssertNil(model.customTitles[key], "blank rename clears the custom title")

        let rejected = model.rename(key, rawTitle: String(repeating: "b", count: 200))
        XCTAssertEqual(rejected, .tooLong(maxLength: 60))
        XCTAssertEqual(model.items.first(where: { $0.key == key })?.catalogName, "Popular")
    }

    // MARK: - Detail model from a manifest fixture

    private func manifestFixtureData() throws -> Data {
        let payload: [String: Any] = [
            "id": "com.stremio.cinemeta",
            "name": "Cinemeta",
            "version": "3.0.1",
            "description": "Provides catalogs and metadata",
            "logo": "https://images.example.com/cinemeta.png",
            "resources": ["catalog", "meta", "stream"],
            "types": ["movie", "series"],
            "idPrefixes": ["tt"],
            "catalogs": [
                ["type": "movie", "id": "top", "name": "Popular"],
                ["type": "series", "id": "top", "name": "Popular"],
                [
                    "type": "movie", "id": "search", "name": "Search",
                    "extra": [["name": "search", "isRequired": true]]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    func testDetailModelFromManifestFixture() throws {
        let manifest = try JSONDecoder().decode(AddonManifest.self, from: manifestFixtureData())
        let snapshot = AddonSnapshot(
            manifest: manifest,
            baseURL: "https://v3-cinemeta.strem.io",
            isProtected: true
        )
        XCTAssertEqual(snapshot.manifestID, "com.stremio.cinemeta")
        XCTAssertTrue(snapshot.providesStreams)
        XCTAssertEqual(snapshot.catalogs.count, 3)
        XCTAssertEqual(snapshot.catalogs[2].isSearchOnly, true)
        XCTAssertEqual(snapshot.catalogs[0].isSearchOnly, false)

        let detail = AddonDetailModel(snapshot: snapshot)
        XCTAssertEqual(detail.displayName, "Cinemeta")
        XCTAssertEqual(detail.versionLabel, "v3.0.1")
        XCTAssertEqual(detail.typesLabel, "movie, series")
        XCTAssertEqual(detail.catalogSummary, "3 catalogs • movie, series")
        XCTAssertEqual(detail.credentialBadge, .none)
        XCTAssertTrue(detail.isProtected)
        XCTAssertFalse(detail.showsRemoveAction, "protected addons hide the remove action")
        XCTAssertFalse(detail.showsInstallAction, "installed addons hide the install action")
        XCTAssertNotNil(detail.protectedNote)
        XCTAssertEqual(detail.catalogs.map(\.name), ["Popular", "Popular", "Search"])
        XCTAssertEqual(detail.catalogs.map(\.typeLabel), ["Movie", "Series", "Movie"])
        XCTAssertEqual(detail.catalogs[2].caption, "Search-only")
        XCTAssertEqual(detail.catalogs[0].caption, "Home catalog")
        XCTAssertEqual(detail.catalogs[0].key, "com.stremio.cinemeta_movie_top")
    }

    func testDetailModelInstallActionForUninstalledAddon() {
        let snapshot = snapshot(
            baseURL: "https://new.example.com",
            name: "New addon",
            configurationRequired: true
        )
        let detail = AddonDetailModel(snapshot: snapshot, isInstalled: false)
        XCTAssertTrue(detail.showsInstallAction)
        XCTAssertFalse(detail.showsRemoveAction)
        XCTAssertNil(detail.protectedNote)
        XCTAssertEqual(detail.credentialBadge, .setupRequired)
    }
}
