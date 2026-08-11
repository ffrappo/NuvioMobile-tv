import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var addons: AddonStore
    @EnvironmentObject private var integrations: IntegrationStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var profiles: TVProfileStore
    @EnvironmentObject private var homePreferences: HomePreferencesStore
    @EnvironmentObject private var watchProgress: WatchProgressStore
    @EnvironmentObject private var collections: CollectionStore
    @EnvironmentObject private var home: HomeStore
    @State private var cacheMessage: String?
    @State private var showLogout = false
    @FocusState private var focus: Action?

    private enum Action: Hashable {
        case clearCache, account, logout, skipIntro, syncIntegrations
        case profile(Int), hero, catalogType, unreleased, homeItem(String, Int)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))
                appCard
                accountCard
                profileCard
                homeCard
                integrationsCard
                cacheCard
                Text("Direct HTTP and HTTPS playback uses MPV with Apple TV system media controls.")
                    .font(.callout)
                    .foregroundStyle(NuvioTheme.secondaryText)
            }
            .padding(48)
        }
        .defaultFocus($focus, .clearCache)
        .confirmationDialog("Sign out of Nuvio?", isPresented: $showLogout, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task {
                    addons.clearForLogout()
                    library.clearForLogout()
                    watchProgress.clearForLogout()
                    collections.clearForLogout()
                    home.clearForLogout()
                    profiles.clear()
                    integrations.clearForLogout()
                    homePreferences.clearForLogout()
                    PlaybackProgressStore().clearAll()
                    await auth.logout()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Account data and synchronized addons will be removed from this Apple TV.")
        }
    }

    private var appCard: some View {
        HStack(alignment: .top, spacing: 28) {
            Image("NuvioLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            VStack(alignment: .leading, spacing: 12) {
                Text("Nuvio for Apple TV").font(.title.weight(.bold))
                infoRow("Version", value: appVersion)
                infoRow("Device", value: UIDevice.current.model)
                infoRow("System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                infoRow("Architecture", value: architecture)
            }
        }
        .padding(28)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account").font(.title2.weight(.semibold))
            if let email = auth.signedInEmail {
                Label(email.tvSafe, systemImage: "person.crop.circle.badge.checkmark")
                    .font(.title3.weight(.semibold))
                Text(addons.syncMessage ?? "Your account addons are synchronized on this Apple TV.")
                    .foregroundStyle(NuvioTheme.secondaryText)
                NuvioButton(title: "Sign Out", symbol: "rectangle.portrait.and.arrow.right", focused: focus == .logout, destructive: true) {
                    showLogout = true
                }
                .frame(width: 280)
                .focused($focus, equals: .logout)
            } else {
                Text("Guest mode stores library and addons on this Apple TV.")
                    .foregroundStyle(NuvioTheme.secondaryText)
                NuvioButton(title: "Sign In", symbol: "person.crop.circle.badge.checkmark", focused: focus == .account, prominent: true) {
                    auth.showSignIn()
                }
                .frame(width: 280)
                .focused($focus, equals: .account)
            }
        }
        .padding(28)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Profile").font(.title2.weight(.semibold))
            if profiles.profiles.isEmpty {
                Text("Primary profile").foregroundStyle(NuvioTheme.secondaryText)
            } else {
                HStack(spacing: 16) {
                    ForEach(profiles.profiles) { profile in
                        NuvioButton(
                            title: profile.name.tvSafe,
                            symbol: profile.profileIndex == profiles.activeProfileID ? "checkmark.circle.fill" : "person.circle",
                            focused: focus == .profile(profile.profileIndex),
                            prominent: profile.profileIndex == profiles.activeProfileID
                        ) {
                            profiles.select(profile.profileIndex)
                            Task { await addons.syncFromAccount(auth: auth, profileID: profile.profileIndex) }
                        }
                        .focused($focus, equals: .profile(profile.profileIndex))
                    }
                }
            }
        }
        .padding(28)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))
    }

    private var homeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Home").font(.title2.weight(.semibold))
            Toggle("Show featured hero", isOn: Binding(
                get: { homePreferences.value.heroEnabled },
                set: { homePreferences.setHeroEnabled($0); pushHomePreferences() }
            ))
            .focused($focus, equals: .hero)
            Toggle("Show catalog media type", isOn: Binding(
                get: { homePreferences.value.showCatalogType },
                set: { homePreferences.setShowCatalogType($0); pushHomePreferences() }
            ))
            .focused($focus, equals: .catalogType)
            Toggle("Hide unreleased content", isOn: Binding(
                get: { homePreferences.value.hideUnreleasedContent },
                set: { homePreferences.setHideUnreleasedContent($0); pushHomePreferences() }
            ))
            .focused($focus, equals: .unreleased)

            ForEach(homePreferences.value.items.sorted(by: { $0.order < $1.order }), id: \.key) { item in
                HStack(spacing: 14) {
                    Toggle(item.customTitle.trimmedNonEmpty ?? homeItemName(item.key), isOn: Binding(
                        get: { homePreferences.value.preference(for: item.key)?.enabled ?? true },
                        set: { homePreferences.setEnabled(key: item.key, enabled: $0); pushHomePreferences() }
                    ))
                    Spacer()
                    NuvioButton(title: "Up", symbol: "arrow.up", focused: focus == .homeItem(item.key, -1)) {
                        homePreferences.move(key: item.key, direction: -1)
                        pushHomePreferences()
                    }
                    .frame(width: 150).focused($focus, equals: .homeItem(item.key, -1))
                    NuvioButton(title: "Down", symbol: "arrow.down", focused: focus == .homeItem(item.key, 1)) {
                        homePreferences.move(key: item.key, direction: 1)
                        pushHomePreferences()
                    }
                    .frame(width: 170).focused($focus, equals: .homeItem(item.key, 1))
                }
            }
        }
        .padding(28)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))
    }

    private func pushHomePreferences() {
        homePreferences.schedulePush(auth: auth, profileID: profiles.activeProfileID)
    }

    private func homeItemName(_ key: String) -> String {
        key.hasPrefix("collection_") ? "Collection" : key.split(separator: ":").last.map(String.init) ?? "Catalog"
    }

    private var integrationsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Integrations").font(.title2.weight(.semibold))
                Spacer()
                if integrations.isSyncing { ProgressView() }
            }
            integrationRow(
                title: "AniSkip",
                detail: "Community anime opening, ending, and recap timestamps",
                symbol: "forward.end.circle.fill",
                status: integrations.settings.skipIntroEnabled ? "Active" : "Disabled"
            )
            integrationRow(
                title: "Anime Skip",
                detail: "Synchronized from your mobile playback settings",
                symbol: "sparkles.tv.fill",
                status: integrations.settings.animeSkipReady ? "Connected" : "Set up on mobile"
            )
            integrationRow(
                title: "Stremio Addons",
                detail: "Catalogs, metadata, streams, and source request headers",
                symbol: "puzzlepiece.extension.fill",
                status: "\(addons.addons.count) enabled"
            )
            Toggle("Show skip controls during playback", isOn: Binding(
                get: { integrations.settings.skipIntroEnabled },
                set: integrations.setSkipIntroEnabled
            ))
            .focused($focus, equals: .skipIntro)
            if auth.session != nil {
                NuvioButton(
                    title: "Sync Mobile Integrations",
                    symbol: "arrow.triangle.2.circlepath",
                    focused: focus == .syncIntegrations
                ) {
                    Task { await integrations.syncFromAccount(auth: auth) }
                }
                .frame(width: 360)
                .focused($focus, equals: .syncIntegrations)
            }
            if let message = integrations.syncMessage {
                Text(message.tvSafe).font(.callout).foregroundStyle(NuvioTheme.secondaryText)
            }
        }
        .padding(28)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))
    }

    private func integrationRow(
        title: String,
        detail: String,
        symbol: String,
        status: String
    ) -> some View {
        HStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(NuvioTheme.accent)
                .frame(width: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(NuvioTheme.secondaryText)
            }
            Spacer()
            Text(status)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private var cacheCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Cache").font(.title2.weight(.semibold))
            Text("Clear cached artwork and addon responses. Your library and addon list stay saved.")
                .foregroundStyle(NuvioTheme.secondaryText)
            NuvioButton(title: "Clear Cache", symbol: "trash", focused: focus == .clearCache) {
                URLCache.shared.removeAllCachedResponses()
                cacheMessage = "Cache cleared."
            }
            .frame(width: 280)
            .focused($focus, equals: .clearCache)
            if let cacheMessage { Text(cacheMessage).foregroundStyle(.green) }
        }
        .padding(28)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var architecture: String {
#if arch(arm64)
        return "arm64"
#elseif arch(x86_64)
        return "x86_64"
#else
        return "Unknown"
#endif
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label).foregroundStyle(NuvioTheme.secondaryText)
            Text(value.tvSafe).fontWeight(.semibold)
        }
    }
}
