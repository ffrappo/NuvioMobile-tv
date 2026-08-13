import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var addonStore: AddonStore
    @EnvironmentObject private var integrationStore: IntegrationStore
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var profileStore: TVProfileStore
    @EnvironmentObject private var deepLinkStore: NuvioDeepLinkStore
    @Environment(\.nuvioTheme) private var theme
    @State private var selection: AppSection = .home
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            TabView(selection: $selection) {
                Tab("Home", systemImage: "house", value: .home) {
                    CatalogView(onSelect: showDetails, onOpenCatalog: showCatalog)
                        .safeAreaPadding(.leading, 360)
                }
                Tab("Discover", systemImage: "safari", value: .discover) {
                    DiscoverView(onSelect: showDetails)
                        .safeAreaPadding(.leading, 360)
                }
                Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                    SearchView(onSelect: showDetails)
                        .safeAreaPadding(.leading, 360)
                }
                Tab("Library", systemImage: "rectangle.stack", value: .library) {
                    LibraryView(onSelect: showDetails)
                        .safeAreaPadding(.leading, 360)
                }
                Tab("Addons", systemImage: "puzzlepiece.extension", value: .addons) {
                    AddonsView()
                        .safeAreaPadding(.leading, 360)
                }
                Tab("Settings", systemImage: "gearshape", value: .settings) {
                    SettingsView()
                        .safeAreaPadding(.leading, 360)
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .background(theme.background.ignoresSafeArea())
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .details(let summary):
                    DetailsView(summary: summary)
                case .catalog(let listing):
                    CatalogGridScreen(listing: listing, onSelect: showDetails)
                }
            }
        }
        .task(id: authStore.signedInEmail) { await synchronizeAccount() }
        .task(id: deepLinkStore.pending) {
            guard let deepLink = deepLinkStore.pending else { return }
            await route(deepLink)
        }
    }

    @MainActor
    private func route(_ deepLink: NuvioDeepLink) async {
        defer { deepLinkStore.consume(deepLink) }
        switch deepLink.destination {
        case let .details(type, id):
            do {
                let detail = try await StremioService().details(type: type, id: id)
                selection = .home
                path = [.details(detail.summary)]
            } catch {
                AppLog.provider.error(
                    "Deep link metadata failed type=\(type, privacy: .public) id=\(id, privacy: .public) detail=\(AppLog.safeDescription(error), privacy: .public)"
                )
            }
        }
    }

    private func showDetails(_ summary: MetaSummary) {
        path.append(.details(summary))
    }

    private func showCatalog(_ listing: CatalogListing) {
        path.append(.catalog(listing))
    }

    private func synchronizeAccount() async {
        guard authStore.session != nil else {
            await addonStore.refreshManifests()
            return
        }
        await profileStore.sync(auth: authStore)
        let profileID = profileStore.activeProfileID
        let addonProfileID = profileStore.activeProfile?.usesPrimaryAddons == true ? 1 : profileID
        async let addons: Void = addonStore.syncFromAccount(auth: authStore, profileID: addonProfileID)
        async let integrations: Void = integrationStore.syncFromAccount(auth: authStore)
        async let library: Void = libraryStore.syncFromAccount(auth: authStore, profileID: profileID)
        _ = await (addons, integrations, library)
    }
}

enum AppRoute: Hashable {
    case details(MetaSummary)
    case catalog(CatalogListing)
}

enum AppSection: String, Hashable {
    case home, discover, search, library, addons, settings
}
