import SwiftUI

@main
struct NuvioTVApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var addonStore = AddonStore()
    @StateObject private var integrationStore: IntegrationStore
    @StateObject private var libraryStore: LibraryStore
    @StateObject private var profileStore: TVProfileStore
    @StateObject private var homePreferences: HomePreferencesStore
    @StateObject private var watchProgressStore: WatchProgressStore
    @StateObject private var collectionStore: CollectionStore
    @StateObject private var homeStore: HomeStore
    @StateObject private var deepLinkStore = NuvioDeepLinkStore()

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            UserDefaults.standard.set(true, forKey: "nuvio.tv.continueAsGuest.v1")
            UserDefaults.standard.set(
                [StremioService.cinemetaBaseURL.absoluteString],
                forKey: "nuvio.tv.addonBases.v1"
            )
        }
        let preferences = HomePreferencesStore()
        let progress = WatchProgressStore()
        let collections = CollectionStore()
        _authStore = StateObject(wrappedValue: AuthStore())
        _addonStore = StateObject(wrappedValue: AddonStore())
        _integrationStore = StateObject(wrappedValue: IntegrationStore())
        _libraryStore = StateObject(wrappedValue: LibraryStore())
        _profileStore = StateObject(wrappedValue: TVProfileStore())
        _homePreferences = StateObject(wrappedValue: preferences)
        _watchProgressStore = StateObject(wrappedValue: progress)
        _collectionStore = StateObject(wrappedValue: collections)
        _homeStore = StateObject(wrappedValue: HomeStore(
            preferences: preferences,
            progress: progress,
            collections: collections
        ))
    }

    var body: some Scene {
        WindowGroup {
            AccountGateView()
                .environmentObject(authStore)
                .environmentObject(addonStore)
                .environmentObject(integrationStore)
                .environmentObject(libraryStore)
                .environmentObject(profileStore)
                .environmentObject(homePreferences)
                .environmentObject(watchProgressStore)
                .environmentObject(collectionStore)
                .environmentObject(homeStore)
                .environmentObject(deepLinkStore)
                .nuvioThemeEnvironment()
                .preferredColorScheme(.dark)
                .onOpenURL(perform: deepLinkStore.receive)
        }
    }
}

extension String {
    var tvSafe: String {
        replacingOccurrences(of: "\u{0026}", with: "and")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
    }
}
