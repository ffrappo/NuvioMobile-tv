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
    @State private var showProfileGateway = false

    var body: some View {
        NavigationStack(path: $path) {
            TabView(selection: $selection) {
                Tab("Home", systemImage: "house", value: .home) {
                    CatalogView(
                        onSelect: showDetails,
                        onOpenCatalog: showCatalog,
                        onOpenCollection: showCollection
                    )
                }
                Tab("Discover", systemImage: "safari", value: .discover) {
                    DiscoverView(onSelect: showDetails)
                }
                Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                    SearchView(onSelect: showDetails)
                }
                Tab("Library", systemImage: "rectangle.stack", value: .library) {
                    LibraryView(onSelect: showDetails)
                }
                Tab("Addons", systemImage: "puzzlepiece.extension", value: .addons) {
                    AddonsView()
                }
                Tab("Settings", systemImage: "gearshape", value: .settings) {
                    SettingsView()
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
                case .collection(let collection):
                    CollectionDetailView(collection: collection, onSelect: showDetails)
                }
            }
        }
        .fullScreenCover(isPresented: $showProfileGateway) {
            profileGatewayCover
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

    private func showCollection(_ collection: TVCollection) {
        path.append(.collection(collection))
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
        if profileStore.profiles.count > 1 {
            showProfileGateway = true
        }
    }

    /// The parity profile gateway (Android `ProfileSelectionScreen.kt`),
    /// shown over the shell until a profile is confirmed. PIN verification
    /// hits the server `verify_profile_pin` RPC, honoring its lockout
    /// window on failure.
    private var profileGatewayCover: some View {
        ProfileGatewayView(
            profiles: profileStore.profiles.map { profile in
                var gateway = GatewayProfile(tvProfile: profile, lock: gatewayLock(for: profile))
                // Resolve the catalog avatar image like the Android card.
                if let resolved = ProfileAvatarCatalog.shared.displayURL(
                    avatarID: gateway.avatarID,
                    customURL: gateway.avatarURL
                ) {
                    gateway.avatarURL = resolved.absoluteString
                }
                return gateway
            },
            activeProfileID: profileStore.activeProfileID,
            verifyPIN: { profile, pin, completion in
                Task { @MainActor in
                    let result = await profileStore.verifyPin(profile.id, pin: pin, auth: authStore)
                    if result.unlocked {
                        completion(.success)
                    } else {
                        completion(.failure(retryAfterSeconds: result.retryAfterSeconds))
                    }
                }
            },
            onSelection: { outcome in
                profileStore.select(outcome.profile.id)
                showProfileGateway = false
            }
        )
    }

    private func gatewayLock(for profile: TVProfile) -> ProfileLockState {
        profileStore.isPinEnabled(profile.profileIndex) ? .pinLocked : .unlocked
    }
}

enum AppRoute: Hashable {
    case details(MetaSummary)
    case catalog(CatalogListing)
    case collection(TVCollection)
}

enum AppSection: String, Hashable {
    case home, discover, search, library, addons, settings
}
