import Foundation

/// Catalog order presentation model, ported from the non-follow branch of
/// Android `CatalogOrderViewModel.buildOrderedCatalogItems` plus the custom
/// catalog titles (`LayoutPreferenceDataStore.customCatalogTitles`).
///
/// Follow-addons-order mode and collection interleaving from the Android
/// view model are out of scope for this module; the integrator feeds only the
/// addon catalogs it wants ordered.

// MARK: - Rename validation

public enum CatalogRenameError: Error, Equatable, Sendable {
    case tooLong(maxLength: Int)
    case invalidCharacters
}

/// Name-safe validation for custom catalog titles.
public enum CatalogNameValidator {
    public static let maxLength = 60

    /// Validates a raw rename input.
    /// - Returns: `.success(nil)` when the input is blank, meaning "reset to
    ///   the manifest catalog name" (Android ignores blank custom titles).
    public static func validate(_ raw: String) -> Result<String?, CatalogRenameError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .success(nil) }
        if trimmed.unicodeScalars.contains(where: { !$0.isPrintableASCIIOrCommon }) {
            return .failure(.invalidCharacters)
        }
        if trimmed.count > maxLength { return .failure(.tooLong(maxLength: maxLength)) }
        return .success(trimmed)
    }
}

private extension Unicode.Scalar {
    /// Accepts printable ASCII plus the common punctuation/whitespace range
    /// tvOS keyboards can produce; rejects control characters and newlines.
    var isPrintableASCIIOrCommon: Bool {
        value >= 32 && value != 127
    }
}

// MARK: - Items

/// One row of the catalog order list, mirroring Android `CatalogOrderItem`.
public struct CatalogOrderItem: Equatable, Sendable, Identifiable {
    public let key: String
    public let disableKey: String
    public let legacyDisableKey: String?
    public let catalogName: String
    public let addonName: String
    public let typeLabel: String
    public let isDisabled: Bool
    public let canMoveUp: Bool
    public let canMoveDown: Bool

    public var id: String { key }

    /// Android renders `"${catalogName} - ${typeLabel.capitalized}"`.
    public var displayTitle: String {
        let type = typeLabel.prefix(1).uppercased() + typeLabel.dropFirst()
        return "\(catalogName) - \(type)"
    }
}

// MARK: - Model

/// Reorderable catalog list with per-catalog enable state.
public struct CatalogOrderModel: Equatable, Sendable {
    public private(set) var items: [CatalogOrderItem]
    /// Current order of catalog keys (the persistence payload).
    public private(set) var orderKeys: [String]
    /// Disable keys for catalogs hidden from Home (the persistence payload).
    public private(set) var disabledKeys: Set<String>
    public private(set) var customTitles: [String: String]
    /// Manifest (default) order captured at init, used by `resetOrder()`.
    private let defaultOrderKeys: [String]
    /// Manifest catalog names by key, so cleared renames restore them.
    private var manifestCatalogNames: [String: String]

    public init(
        addons: [AddonSnapshot],
        savedOrderKeys: [String] = [],
        disabledKeys: Set<String> = [],
        customTitles: [String: String] = [:]
    ) {
        var defaultKeys: [String] = []
        var entries: [String: DefaultEntry] = [:]
        for addon in addons where addon.isEnabled {
            for catalog in addon.catalogs where !catalog.isSearchOnly {
                let key = AddonCatalogKeys.homeCatalogKey(
                    addonID: addon.manifestID,
                    type: catalog.type,
                    catalogID: catalog.id
                )
                let entry = DefaultEntry(
                    key: key,
                    disableKey: key,
                    legacyDisableKey: AddonCatalogKeys.legacyDisabledCatalogKey(
                        addonBaseURL: addon.baseURL,
                        type: catalog.type,
                        catalogID: catalog.id,
                        catalogName: catalog.name
                    ),
                    catalogName: catalog.name,
                    addonName: addon.customName.flatMap { $0.isEmpty ? nil : $0 } ?? addon.name,
                    typeLabel: catalog.type
                )
                guard entries[key] == nil else { continue }
                entries[key] = entry
                defaultKeys.append(key)
            }
        }

        // Android: saved order first (deduped, unknown keys dropped), then
        // any catalogs the saved order never mentioned, in manifest order.
        let savedValid = savedOrderKeys.filter { entries[$0] != nil }
        var seen = Set<String>()
        let ordered = savedValid.filter { seen.insert($0).inserted }
        let missing = defaultKeys.filter { !seen.contains($0) }
        orderKeys = ordered + missing
        defaultOrderKeys = defaultKeys
        manifestCatalogNames = entries.mapValues(\.catalogName)
        self.disabledKeys = disabledKeys
        self.customTitles = customTitles.filter { !$0.value.isEmpty }
        items = CatalogOrderModel.rebuild(
            orderKeys: orderKeys,
            entries: entries,
            disabledKeys: disabledKeys,
            customTitles: self.customTitles
        )
    }

    public func canMoveUp(_ key: String) -> Bool {
        orderKeys.firstIndex(of: key).map { $0 > 0 } ?? false
    }

    public func canMoveDown(_ key: String) -> Bool {
        orderKeys.firstIndex(of: key).map { $0 < orderKeys.count - 1 } ?? false
    }

    /// `CatalogOrderViewModel.moveCatalog(key, direction)`.
    @discardableResult
    public mutating func move(_ key: String, direction: Int) -> Bool {
        guard let index = orderKeys.firstIndex(of: key) else { return false }
        let target = index + direction
        guard orderKeys.indices.contains(target) else { return false }
        orderKeys.swapAt(index, target)
        rebuildItems()
        return true
    }

    @discardableResult
    public mutating func moveUp(_ key: String) -> Bool { move(key, direction: -1) }

    @discardableResult
    public mutating func moveDown(_ key: String) -> Bool { move(key, direction: 1) }

    /// `CatalogOrderViewModel.toggleCatalogEnabled(disableKey)`.
    public mutating func toggleDisabled(_ disableKey: String) {
        if disabledKeys.contains(disableKey) {
            disabledKeys.remove(disableKey)
        } else {
            disabledKeys.insert(disableKey)
        }
        rebuildItems()
    }

    /// Drops the saved order and returns every catalog to manifest order.
    public mutating func resetOrder() {
        guard defaultOrderKeys != orderKeys else { return }
        orderKeys = defaultOrderKeys
        rebuildItems()
    }

    /// Name-safe rename: stores the validated custom title or clears it when
    /// the input is blank. Returns the validation error, if any.
    @discardableResult
    public mutating func rename(_ key: String, rawTitle: String) -> CatalogRenameError? {
        switch CatalogNameValidator.validate(rawTitle) {
        case let .failure(error):
            return error
        case let .success(validated):
            if let validated {
                customTitles[key] = validated
            } else {
                customTitles.removeValue(forKey: key)
            }
            rebuildItems()
            return nil
        }
    }

    // MARK: - Internals

    private mutating func rebuildItems() {
        var entries: [String: DefaultEntry] = [:]
        for item in items {
            entries[item.key] = DefaultEntry(
                key: item.key,
                disableKey: item.disableKey,
                legacyDisableKey: item.legacyDisableKey,
                catalogName: manifestCatalogNames[item.key] ?? item.catalogName,
                addonName: item.addonName,
                typeLabel: item.typeLabel
            )
        }
        guard !entries.isEmpty else { return }
        items = CatalogOrderModel.rebuild(
            orderKeys: orderKeys,
            entries: entries,
            disabledKeys: disabledKeys,
            customTitles: customTitles
        )
    }

    private static func rebuild(
        orderKeys: [String],
        entries: [String: DefaultEntry],
        disabledKeys: Set<String>,
        customTitles: [String: String]
    ) -> [CatalogOrderItem] {
        orderKeys.enumerated().compactMap { index, key in
            guard let entry = entries[key] else { return nil }
            let name = customTitles[key] ?? entry.catalogName
            return CatalogOrderItem(
                key: entry.key,
                disableKey: entry.disableKey,
                legacyDisableKey: entry.legacyDisableKey,
                catalogName: name,
                addonName: entry.addonName,
                typeLabel: entry.typeLabel,
                isDisabled: disabledKeys.contains(entry.disableKey)
                    || entry.legacyDisableKey.map(disabledKeys.contains) == true,
                canMoveUp: index > 0,
                canMoveDown: index < orderKeys.count - 1
            )
        }
    }
}

/// Port of the private `CatalogOrderEntry` from the Android view model.
struct DefaultEntry {
    let key: String
    let disableKey: String
    let legacyDisableKey: String?
    let catalogName: String
    let addonName: String
    let typeLabel: String
}
