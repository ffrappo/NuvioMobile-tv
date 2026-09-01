import Foundation

/// Detail presentation model for the single-addon page. The tvOS detail
/// composition (manifest facts + catalog list + install/remove actions)
/// follows the addon-card grammar of `AddonManagerScreen.kt` /
/// `PluginScreen.kt`; the Android repository has no dedicated addon detail
/// route, so this model is the contract the integrator drives from the
/// installed list.

/// One catalog row on the detail page.
public struct AddonDetailCatalog: Equatable, Sendable, Identifiable {
    public let key: String
    public let name: String
    public let type: String
    /// `CatalogDescriptor.isSearchOnlyCatalog()`.
    public let isSearchOnly: Bool

    public var id: String { key }

    /// Capitalized type label as the Android order screen renders it.
    public var typeLabel: String {
        type.prefix(1).uppercased() + type.dropFirst()
    }

    public var caption: String {
        isSearchOnly ? "Search-only" : "Home catalog"
    }
}

/// Single-addon presentation, mirroring the manifest facts the Android
/// screens surface (name, version, types, catalogs, behavior hints).
public struct AddonDetailModel: Equatable, Sendable {
    public let id: String
    public let manifestID: String
    public let displayName: String
    public let version: String
    public let description: String?
    public let baseURL: String
    public let logoURL: String?
    public let types: [String]
    public let providesStreams: Bool
    public let configurationRequired: Bool
    public let credentialBadge: AddonCredentialBadge
    public let isProtected: Bool
    public let isInstalled: Bool
    public let catalogs: [AddonDetailCatalog]

    public init(snapshot: AddonSnapshot, isInstalled: Bool = true) {
        let display = snapshot.customName.flatMap { $0.isEmpty ? nil : $0 } ?? snapshot.name
        id = snapshot.id
        manifestID = snapshot.manifestID
        displayName = display
        version = snapshot.version
        description = snapshot.description
        baseURL = snapshot.baseURL
        logoURL = snapshot.logoURL
        types = snapshot.types
        providesStreams = snapshot.providesStreams
        configurationRequired = snapshot.configurationRequired
        credentialBadge = AddonCredentialBadge(
            configurationRequired: snapshot.configurationRequired,
            baseURL: snapshot.baseURL
        )
        isProtected = snapshot.isProtected
        self.isInstalled = isInstalled
        catalogs = snapshot.catalogs.map { catalog in
            AddonDetailCatalog(
                key: AddonCatalogKeys.homeCatalogKey(
                    addonID: snapshot.manifestID,
                    type: catalog.type,
                    catalogID: catalog.id
                ),
                name: catalog.name,
                type: catalog.type,
                isSearchOnly: catalog.isSearchOnly
            )
        }
    }

    public var versionLabel: String? {
        version.isEmpty ? nil : "v\(version)"
    }

    public var typesLabel: String {
        types.joined(separator: ", ")
    }

    public var catalogSummary: String {
        let count = catalogs.count
        let noun = count == 1 ? "catalog" : "catalogs"
        return "\(count) \(noun) • \(typesLabel)"
    }

    /// Install action only makes sense for not-yet-installed addons.
    public var showsInstallAction: Bool { !isInstalled }

    /// Protected (built-in) addons have no remove action.
    public var showsRemoveAction: Bool { isInstalled && !isProtected }

    public var protectedNote: String? {
        isProtected ? "Built-in addon. It stays enabled and cannot be removed." : nil
    }
}
