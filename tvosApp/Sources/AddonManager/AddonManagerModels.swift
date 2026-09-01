import Foundation

/// Pure presentation models for the addon management module, ported from the
/// Android sources:
/// - `AddonManagerScreen.kt` / `AddonManagerViewModel.kt` (list, enable, reorder)
/// - `CatalogOrderViewModel.kt` (catalog order build, disable keys, titles)
/// - `AddonRepositoryImpl.applyDisplayNames` (name-safe duplicate suffixes)
/// - `HomeCatalogSyncSupport.kt` (catalog key formats, in CatalogOrderModels)
///
/// Everything in this file is value-typed and main-actor free so the
/// integration round can drive it from any store and test it in isolation.

// MARK: - Credential badge

/// Credential/configuration badge shown on addon rows. Grounded in Android
/// `AddonBehaviorHints.configurationRequired` plus the configured-URL
/// contract (a manifest URL carrying query parameters or a sub-path embeds
/// user credentials, e.g. debrid keys).
public enum AddonCredentialBadge: String, CaseIterable, Equatable, Sendable {
    case none
    /// URL embeds configuration/credentials.
    case configured
    /// Manifest requires configuration but the URL carries none.
    case setupRequired

    public init(configurationRequired: Bool, baseURL: String) {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let carriesConfig: Bool
        if trimmed.contains("?") {
            carriesConfig = true
        } else if let url = URL(string: trimmed) {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            carriesConfig = !path.isEmpty
        } else {
            carriesConfig = false
        }
        if carriesConfig {
            self = .configured
        } else {
            self = configurationRequired ? .setupRequired : .none
        }
    }

    public var displayText: String? {
        switch self {
        case .none: nil
        case .configured: "Configured"
        case .setupRequired: "Setup required"
        }
    }

    public var symbolName: String? {
        switch self {
        case .none: nil
        case .configured: "key.fill"
        case .setupRequired: "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - List entries

/// One row in the installed-addon list, composed like the Android `AddonCard`.
public struct AddonListEntry: Equatable, Sendable, Identifiable {
    public let id: String
    public let manifestID: String
    public let name: String
    public let displayName: String
    public let version: String
    public let types: [String]
    public var isEnabled: Bool
    public let isProtected: Bool
    public let catalogCount: Int
    public let credentialBadge: AddonCredentialBadge
    public let logoURL: String?

    public var canRemove: Bool { !isProtected }
    public var canToggleEnabled: Bool { !isProtected }

    /// Android renders `v${version}` only when the version is non-blank.
    public var versionLabel: String? {
        version.isEmpty ? nil : "v\(version)"
    }

    /// Android `addon_catalogs_types`: catalog count plus joined raw types.
    public var catalogSummary: String {
        let joined = types.joined(separator: ", ")
        return joined.isEmpty ? "\(catalogCount) catalogs" : "\(catalogCount) catalogs • \(joined)"
    }
}

// MARK: - Selection state machine

public enum AddonSelectionState: Equatable, Sendable {
    case idle
    case focused(addonID: String)
    case confirmingRemoval(addonID: String)
}

public enum AddonSelectionEvent: Equatable, Sendable {
    case focus(addonID: String)
    case clearFocus
    case requestRemoval(addonID: String)
    case confirmRemoval
    case cancelRemoval
}

/// Focus/removal selection flow for the manager list. Removal always passes
/// through an explicit confirmation state, as in `AddonManagerScreen.kt`
/// (`addonUrlPendingDeletion` dialog).
public struct AddonSelectionMachine: Equatable, Sendable {
    public private(set) var state: AddonSelectionState = .idle

    public init() {}

    /// Returns `true` when the event caused a transition.
    @discardableResult
    public mutating func send(_ event: AddonSelectionEvent) -> Bool {
        switch (state, event) {
        case let (_, .focus(addonID)):
            state = .focused(addonID: addonID)
            return true
        case (_, .clearFocus):
            guard state != .idle else { return false }
            state = .idle
            return true
        case let (_, .requestRemoval(addonID)):
            state = .confirmingRemoval(addonID: addonID)
            return true
        case let (.confirmingRemoval(addonID), .confirmRemoval):
            state = .idle
            return true
        case let (.confirmingRemoval(addonID), .cancelRemoval):
            state = .focused(addonID: addonID)
            return true
        case (.idle, .confirmRemoval), (.idle, .cancelRemoval),
             (.focused, .confirmRemoval), (.focused, .cancelRemoval):
            return false
        }
    }
}

// MARK: - List model

/// Ordered addon list with enable/reorder/removal rules, mirroring
/// `AddonManagerViewModel` list operations. Order is the persisted user
/// order; Android does not sort alphabetically.
public struct AddonListModel: Equatable, Sendable {
    /// Built-in default addons from `AddonPreferences.getDefaultAddons()`.
    public static let defaultProtectedBaseURLs: Set<String> = [
        "https://v3-cinemeta.strem.io",
        "https://opensubtitles-v3.strem.io"
    ]

    public private(set) var entries: [AddonListEntry]
    public private(set) var selection = AddonSelectionMachine()

    public init(addons: [AddonSnapshot]) {
        let names = AddonListModel.resolvedDisplayNames(for: addons)
        entries = addons.map { addon in
            AddonListEntry(
                id: addon.id,
                manifestID: addon.manifestID,
                name: addon.name,
                displayName: names[addon.id] ?? addon.name,
                version: addon.version,
                types: addon.types,
                isEnabled: addon.isEnabled,
                isProtected: addon.isProtected,
                catalogCount: addon.catalogs.count,
                credentialBadge: AddonCredentialBadge(
                    configurationRequired: addon.configurationRequired,
                    baseURL: addon.baseURL
                ),
                logoURL: addon.logoURL
            )
        }
    }

    public var orderedIDs: [String] { entries.map(\.id) }

    public func entry(for addonID: String) -> AddonListEntry? {
        entries.first { $0.id == addonID }
    }

    public func index(of addonID: String) -> Int? {
        entries.firstIndex { $0.id == addonID }
    }

    public func canMoveUp(_ addonID: String) -> Bool {
        index(of: addonID).map { $0 > 0 } ?? false
    }

    public func canMoveDown(_ addonID: String) -> Bool {
        index(of: addonID).map { $0 < entries.count - 1 } ?? false
    }

    /// `AddonManagerViewModel.moveAddonUp/Down`.
    @discardableResult
    public mutating func move(_ addonID: String, direction: Int) -> Bool {
        guard let index = index(of: addonID) else { return false }
        let target = index + direction
        guard entries.indices.contains(target) else { return false }
        entries.swapAt(index, target)
        return true
    }

    @discardableResult
    public mutating func moveUp(_ addonID: String) -> Bool { move(addonID, direction: -1) }

    @discardableResult
    public mutating func moveDown(_ addonID: String) -> Bool { move(addonID, direction: 1) }

    /// Protected addons stay enabled; the toggle is a no-op for them.
    @discardableResult
    public mutating func setEnabled(_ addonID: String, _ enabled: Bool) -> Bool {
        guard let index = index(of: addonID) else { return false }
        let entry = entries[index]
        guard entry.canToggleEnabled, entry.isEnabled != enabled else { return false }
        entries[index].isEnabled = enabled
        return true
    }

    /// Asks the selection machine to confirm a removal. Protected addons are
    /// rejected before any confirmation state is entered.
    @discardableResult
    public mutating func requestRemoval(_ addonID: String) -> Bool {
        guard let entry = entry(for: addonID), entry.canRemove else { return false }
        return selection.send(.requestRemoval(addonID: addonID))
    }

    /// Confirms the pending removal; returns the removed addon identity.
    @discardableResult
    public mutating func confirmRemoval() -> String? {
        guard case let .confirmingRemoval(addonID) = selection.state else { return nil }
        selection.send(.confirmRemoval)
        entries.removeAll { $0.id == addonID }
        return addonID
    }

    public mutating func cancelRemoval() {
        selection.send(.cancelRemoval)
    }

    /// Port of `AddonRepositoryImpl.applyDisplayNames`: user renames win;
    /// remaining duplicate manifest names get a ` (n)` occurrence suffix.
    static func resolvedDisplayNames(for addons: [AddonSnapshot]) -> [String: String] {
        var result: [String: String] = [:]
        var unrenamedIndices: [Int] = []
        for (index, addon) in addons.enumerated() {
            if let custom = addon.customName, !custom.isEmpty, custom != addon.name {
                result[addon.id] = custom
            } else {
                unrenamedIndices.append(index)
            }
        }
        var counts: [String: Int] = [:]
        for index in unrenamedIndices { counts[addons[index].name, default: 0] += 1 }
        var seen: [String: Int] = [:]
        for index in unrenamedIndices {
            let addon = addons[index]
            guard (counts[addon.name] ?? 0) > 1 else {
                result[addon.id] = addon.name
                continue
            }
            seen[addon.name, default: 0] += 1
            let occurrence = seen[addon.name] ?? 1
            result[addon.id] = occurrence == 1 ? addon.name : "\(addon.name) (\(occurrence))"
        }
        return result
    }
}
