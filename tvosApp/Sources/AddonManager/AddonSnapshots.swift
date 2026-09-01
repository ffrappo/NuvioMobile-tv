import Foundation

// MARK: - Catalog keys (HomeCatalogSyncSupport.kt)

public enum AddonCatalogKeys {
    /// `homeCatalogKey(addonId, type, catalogId)`.
    public static func homeCatalogKey(addonID: String, type: String, catalogID: String) -> String {
        "\(addonID)_\(type)_\(catalogID)"
    }

    /// `homeLegacyDisabledCatalogKey(addonBaseUrl, type, catalogId, catalogName)`.
    public static func legacyDisabledCatalogKey(
        addonBaseURL: String,
        type: String,
        catalogID: String,
        catalogName: String
    ) -> String {
        "\(addonBaseURL)_\(type)_\(catalogID)_\(catalogName)"
    }
}

// MARK: - Snapshots (integrator-supplied inputs)

/// One catalog descriptor as the manager needs it, mirroring the fields of
/// the Android `CatalogDescriptor` that the addon screens read.
public struct AddonCatalogSnapshot: Equatable, Hashable, Sendable {
    public let type: String
    public let id: String
    public let name: String
    /// `CatalogDescriptor.isSearchOnlyCatalog`: a required `search` extra.
    public let isSearchOnly: Bool

    public init(type: String, id: String, name: String, isSearchOnly: Bool = false) {
        self.type = type
        self.id = id
        self.name = name
        self.isSearchOnly = isSearchOnly
    }
}

extension AddonCatalogSnapshot {
    /// Convenience over the app's decoded manifest catalog type
    /// (`AddonCatalog` is internal to the module).
    init(catalog: AddonCatalog) {
        self.init(
            type: catalog.type,
            id: catalog.id,
            name: catalog.name,
            isSearchOnly: catalog.extra.contains {
                $0.name.caseInsensitiveCompare("search") == .orderedSame && $0.isRequired
            }
        )
    }
}

/// Immutable addon input the integrator maps from `AddonStore` / manifests.
/// Mirrors the Android `Addon` fields the manager screens consume.
public struct AddonSnapshot: Equatable, Sendable, Identifiable {
    /// Stable identity: the manifest base URL, as in Android (`addon.baseUrl`).
    public var id: String { baseURL }
    public let baseURL: String
    public let manifestID: String
    /// Manifest name (`Addon.name`).
    public let name: String
    /// User-set rename, when different from the manifest name
    /// (`AddonPreferences` user-set names in Android).
    public let customName: String?
    public let version: String
    public let description: String?
    public let logoURL: String?
    public let types: [String]
    public let catalogs: [AddonCatalogSnapshot]
    public let providesStreams: Bool
    /// `AddonBehaviorHints.configurationRequired`.
    public let configurationRequired: Bool
    public let isEnabled: Bool
    /// Protected addons cannot be disabled or removed (built-in defaults).
    public let isProtected: Bool

    public init(
        baseURL: String,
        manifestID: String,
        name: String,
        customName: String? = nil,
        version: String = "",
        description: String? = nil,
        logoURL: String? = nil,
        types: [String] = [],
        catalogs: [AddonCatalogSnapshot] = [],
        providesStreams: Bool = false,
        configurationRequired: Bool = false,
        isEnabled: Bool = true,
        isProtected: Bool = false
    ) {
        self.baseURL = baseURL
        self.manifestID = manifestID
        self.name = name
        self.customName = customName
        self.version = version
        self.description = description
        self.logoURL = logoURL
        self.types = types
        self.catalogs = catalogs
        self.providesStreams = providesStreams
        self.configurationRequired = configurationRequired
        self.isEnabled = isEnabled
        self.isProtected = isProtected
    }

    /// Takes the app's decoded manifest type (`AddonManifest` is module-internal).
    init(
        manifest: AddonManifest,
        baseURL: String,
        customName: String? = nil,
        isEnabled: Bool = true,
        isProtected: Bool = false
    ) {
        self.init(
            baseURL: baseURL,
            manifestID: manifest.id,
            name: manifest.name,
            customName: customName,
            version: manifest.version ?? "",
            description: manifest.description,
            logoURL: manifest.logoURL,
            types: manifest.types,
            catalogs: manifest.catalogs.map(AddonCatalogSnapshot.init(catalog:)),
            providesStreams: manifest.providesStreams,
            isEnabled: isEnabled,
            isProtected: isProtected
        )
    }

    /// Returns a copy with a different enabled flag.
    public func with(isEnabled enabled: Bool) -> AddonSnapshot {
        AddonSnapshot(
            baseURL: baseURL,
            manifestID: manifestID,
            name: name,
            customName: customName,
            version: version,
            description: description,
            logoURL: logoURL,
            types: types,
            catalogs: catalogs,
            providesStreams: providesStreams,
            configurationRequired: configurationRequired,
            isEnabled: enabled,
            isProtected: isProtected
        )
    }
}
