import XCTest
@testable import NuvioTV

/// Guards the bridge between the parity settings tree and the live app:
/// the layout picker must persist to the key `CatalogView` reads, and every
/// other change must survive a store relaunch.
@MainActor
final class SettingsParityBridgeTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "settings-bridge-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testLayoutChangeMirrorsLiveKey() {
        let store = NuvioSettingsStore(defaults: defaults)
        store.handle(NuvioSettingsChange(settingID: "layout.homeLayout", value: .option(NuvioHomeLayout.classic.rawValue)))
        XCTAssertEqual(
            defaults.string(forKey: NuvioSettingsStore.homeLayoutLiveKey),
            "classic"
        )
        XCTAssertEqual(store.state.homeLayout, .classic)

        store.handle(NuvioSettingsChange(settingID: "layout.homeLayout", value: .option(NuvioHomeLayout.grid.rawValue)))
        XCTAssertEqual(defaults.string(forKey: NuvioSettingsStore.homeLayoutLiveKey), "grid")
    }

    func testLayoutModeResolvesPersistedSetting() {
        defaults.set("classic", forKey: NuvioSettingsStore.homeLayoutLiveKey)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "classic"), .classic)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "Classic View"), .classic)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: nil), .modern)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "bogus"), .modern)
    }

    func testChangesSurviveRelaunch() {
        let store = NuvioSettingsStore(defaults: defaults)
        store.handle(NuvioSettingsChange(settingID: "playback.skipIntroButton", value: .toggle(false)))
        store.handle(NuvioSettingsChange(settingID: "layout.homeLayout", value: .option(NuvioHomeLayout.grid.rawValue)))
        store.handle(NuvioSettingsChange(settingID: "playback.subtitleSize", value: .number(150)))

        let reloaded = NuvioSettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.state.skipIntroEnabled)
        XCTAssertEqual(reloaded.state.homeLayout, .grid)
        XCTAssertEqual(reloaded.state.subtitleSizePercent, 150)
    }

    func testCatalogOrderRoundTripThroughPreferenceKeys() {
        let store = NuvioSettingsStore(defaults: defaults)
        let preferences = HomePreferencesStore(defaults: defaults)

        // The catalog-order sheet persists colon-format definition keys.
        let orderKeys = ["com.example:movie:top", "com.other:series:year"]
        preferences.applyCatalogOrder(
            orderKeys: orderKeys,
            disabledKeys: ["com.other:series:year"]
        )

        let item = preferences.value.preference(for: "com.other:series:year")
        XCTAssertNotNil(item, "the colon-format key the Home store reads must resolve")
        XCTAssertEqual(item?.enabled, false)
        XCTAssertEqual(item?.order, 1)
        XCTAssertEqual(preferences.value.preference(for: "com.example:movie:top")?.order, 0)
        XCTAssertNil(preferences.value.preference(for: "com.example|movie|top|"), "pipe-format keys must not appear")

        // Relaunch keeps the order and disable state.
        let reloaded = HomePreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.value.preference(for: "com.other:series:year")?.enabled, false)
        XCTAssertEqual(reloaded.value.preference(for: "com.example:movie:top")?.order, 0)
        _ = store
    }

    func testClampedValuesPersistClamped() {
        let store = NuvioSettingsStore(defaults: defaults)
        // The Android clamp caps subtitle size at 200 percent.
        store.handle(NuvioSettingsChange(settingID: "playback.subtitleSize", value: .number(999)))
        XCTAssertLessThanOrEqual(store.state.subtitleSizePercent, 200)

        let reloaded = NuvioSettingsStore(defaults: defaults)
        XCTAssertLessThanOrEqual(reloaded.state.subtitleSizePercent, 200)
    }
}
