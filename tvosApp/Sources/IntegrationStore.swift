import Foundation

struct TVIntegrationSettings: Equatable {
    var skipIntroEnabled = true
    var animeSkipEnabled = false
    var animeSkipClientID = ""

    var animeSkipReady: Bool { animeSkipEnabled && !animeSkipClientID.isEmpty }
}

@MainActor
final class IntegrationStore: ObservableObject {
    @Published private(set) var settings: TVIntegrationSettings
    @Published private(set) var isSyncing = false
    @Published private(set) var syncMessage: String?

    private let defaults: UserDefaults
    private let accountService: NuvioAccountService
    private let key = "nuvio.tv.integrations.v1"
    /// True once the user toggles skip intro locally; the local choice then
    /// wins over the server-synced mobile value (the tvOS client cannot
    /// safely write the full mobile settings blob back).
    private let overrideKey = "nuvio.tv.skipIntro.localOverride.v1"

    init(
        defaults: UserDefaults = .standard,
        accountService: NuvioAccountService = NuvioAccountService()
    ) {
        self.defaults = defaults
        self.accountService = accountService
        settings = Self.load(defaults: defaults, key: key)
    }

    func syncFromAccount(auth: AuthStore) async {
        isSyncing = true
        syncMessage = "Syncing mobile integrations..."
        defer { isSyncing = false }
        do {
            let token = try await auth.validAccessToken()
            if let remote = try await accountService.profileSettings(accessToken: token) {
                settings = remote
                if defaults.bool(forKey: overrideKey) {
                    // The user set skip intro on this device; keep it.
                    settings.skipIntroEnabled = Self.load(
                        defaults: defaults, key: key
                    ).skipIntroEnabled
                }
                persist()
                syncMessage = "Mobile playback integrations are synchronized."
            } else {
                syncMessage = "No mobile integration settings were found."
            }
        } catch {
            let detail = AppLog.safeDescription(error)
            AppLog.sync.error("Integration sync failed detail=\(detail, privacy: .public)")
            syncMessage = "Integration sync failed: \(detail)"
        }
    }

    func setSkipIntroEnabled(_ enabled: Bool) {
        settings.skipIntroEnabled = enabled
        defaults.set(true, forKey: overrideKey)
        persist()
    }

    func clearForLogout() {
        settings = TVIntegrationSettings()
        syncMessage = nil
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: overrideKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(StoredIntegrationSettings(settings)) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults, key: String) -> TVIntegrationSettings {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode(StoredIntegrationSettings.self, from: data) else {
            return TVIntegrationSettings()
        }
        return stored.value
    }
}

private struct StoredIntegrationSettings: Codable {
    let skipIntroEnabled: Bool
    let animeSkipEnabled: Bool
    let animeSkipClientID: String

    init(_ value: TVIntegrationSettings) {
        skipIntroEnabled = value.skipIntroEnabled
        animeSkipEnabled = value.animeSkipEnabled
        animeSkipClientID = value.animeSkipClientID
    }

    var value: TVIntegrationSettings {
        TVIntegrationSettings(
            skipIntroEnabled: skipIntroEnabled,
            animeSkipEnabled: animeSkipEnabled,
            animeSkipClientID: animeSkipClientID
        )
    }
}
