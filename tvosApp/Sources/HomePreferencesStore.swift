import Foundation

@MainActor
final class HomePreferencesStore: ObservableObject {
    @Published private(set) var value: HomePreferences
    /// Bumped on every local mutation; Home includes it in its reload key.
    @Published private(set) var revision = 0

    private let defaults: UserDefaults
    private let key = "nuvio.tv.home.preferences.v2"
    private var pushTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(HomePreferences.self, from: data) {
            value = decoded
        } else {
            value = HomePreferences()
        }
    }

    func reconcile(definitions: [HomeCatalogDefinition], collections: [TVCollection]) {
        let keys = definitions.map(\.id) + collections.map { "collection_\($0.id)" }
        var byKey = Dictionary(uniqueKeysWithValues: value.items.map { ($0.key, $0) })
        var nextOrder = (value.items.map(\.order).max() ?? -1) + 1
        for key in keys where byKey[key] == nil {
            byKey[key] = HomeCatalogPreference(key: key, enabled: true, order: nextOrder, customTitle: "")
            nextOrder += 1
        }
        let reconciled = byKey.values
            .filter { keys.contains($0.key) }
            .sorted { $0.order < $1.order }
            .enumerated()
            .map { index, item in
                var copy = item
                copy.order = index
                return copy
            }
        guard reconciled != value.items else { return }
        value.items = reconciled
        save()
    }

    func setHeroEnabled(_ enabled: Bool) {
        value.heroEnabled = enabled
        save()
    }

    func setShowCatalogType(_ enabled: Bool) {
        value.showCatalogType = enabled
        save()
    }

    func setHideUnreleasedContent(_ enabled: Bool) {
        value.hideUnreleasedContent = enabled
        save()
    }

    func setEnabled(key: String, enabled: Bool) {
        update(key) { $0.enabled = enabled }
    }

    func move(key: String, direction: Int) {
        var ordered = value.items.sorted { $0.order < $1.order }
        guard let index = ordered.firstIndex(where: { $0.key == key }) else { return }
        let destination = index + direction
        guard ordered.indices.contains(destination) else { return }
        ordered.swapAt(index, destination)
        value.items = ordered.enumerated().map { offset, item in
            var copy = item
            copy.order = offset
            return copy
        }
        save()
    }

    /// Bulk-applies a catalog order (definition keys, first to last) and a
    /// disabled set, renumbering sequentially. Driven by the parity catalog
    /// order screen.
    func applyCatalogOrder(orderKeys: [String], disabledKeys: Set<String>) {
        var byKey = Dictionary(uniqueKeysWithValues: value.items.map { ($0.key, $0) })
        for (offset, key) in orderKeys.enumerated() {
            if byKey[key] != nil {
                byKey[key]?.order = offset
                byKey[key]?.enabled = !disabledKeys.contains(key)
            } else {
                byKey[key] = HomeCatalogPreference(
                    key: key,
                    enabled: !disabledKeys.contains(key),
                    order: offset,
                    customTitle: ""
                )
            }
        }
        value.items = byKey.values.sorted { $0.order < $1.order }
        save()
    }

    func applyRemote(_ preferences: HomePreferences) {
        let localHeroEnabled = value.heroEnabled
        var next = preferences
        next.heroEnabled = localHeroEnabled
        guard next != value else { return }
        value = next
        save()
    }

    func clearForLogout() {
        pushTask?.cancel()
        value = HomePreferences()
        defaults.removeObject(forKey: key)
        objectWillChange.send()
    }

    func schedulePush(auth: AuthStore, profileID: Int, service: NuvioAccountService = NuvioAccountService()) {
        guard auth.session != nil else { return }
        pushTask?.cancel()
        let payload = value
        pushTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            do {
                let token = try await auth.validAccessToken()
                try await service.saveHomePreferences(payload, accessToken: token, profileID: profileID)
            } catch {
                AppLog.sync.error("Home preferences push failed profile=\(profileID) detail=\(AppLog.safeDescription(error), privacy: .public)")
            }
        }
    }

    private func update(_ key: String, mutation: (inout HomeCatalogPreference) -> Void) {
        guard let index = value.items.firstIndex(where: { $0.key == key }) else { return }
        mutation(&value.items[index])
        save()
    }

    private func save() {
        revision += 1
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
        objectWillChange.send()
    }
}
