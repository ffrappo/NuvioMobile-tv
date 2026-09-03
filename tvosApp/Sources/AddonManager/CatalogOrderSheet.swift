import SwiftUI

/// The parity catalog order screen (Android `CatalogOrderScreen.kt`),
/// hosted from the Addons tab. The Android DataStore order/disable payloads
/// map onto `HomePreferencesStore`, which is both persisted locally and
/// synced with the account and already drives Home's section ordering.
struct CatalogOrderSheet: View {
    @EnvironmentObject private var addonStore: AddonStore
    @EnvironmentObject private var homePreferences: HomePreferencesStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var profiles: TVProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var model = CatalogOrderModel(addons: [])

    var body: some View {
        NavigationStack {
            CatalogOrderView(
                items: model.items,
                onMoveUp: { key in
                    if model.moveUp(key) { persist() }
                },
                onMoveDown: { key in
                    if model.moveDown(key) { persist() }
                },
                onToggleDisabled: { disableKey in
                    model.toggleDisabled(disableKey)
                    persist()
                },
                onResetOrder: {
                    model.resetOrder()
                    persist()
                }
            )
            .navigationTitle("Catalog Order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: rebuild)
    }

    /// Rebuilds the model from the current addons and saved preferences.
    private func rebuild() {
        let definitions = CatalogDescriptors.browse(from: addonStore.homeAddons)
        let preferences = homePreferences.value
        // Saved order: preference items sorted by order, mapped onto the
        // model's `addonID_type_catalogID` keys.
        let orderedDefinitionKeys = preferences.items
            .filter { !$0.key.hasPrefix("collection_") }
            .sorted { lhs, rhs in
                lhs.order == rhs.order ? lhs.key < rhs.key : lhs.order < rhs.order
            }
            .map(\.key)
        let savedOrderKeys = orderedDefinitionKeys.compactMap { definitionKey in
            Self.modelKey(forDefinitionKey: definitionKey, valid: definitions)
        }
        let disabledDefinitionKeys = Set(preferences.items.filter { !$0.enabled }.map(\.key))
        let disabledKeys = Set(disabledDefinitionKeys.compactMap { definitionKey in
            Self.modelKey(forDefinitionKey: definitionKey, valid: definitions)
        })
        model = CatalogOrderModel(
            addons: addonSnapshots,
            savedOrderKeys: savedOrderKeys,
            disabledKeys: disabledKeys
        )
    }

    /// Writes the model's order and disable state back into Home
    /// preferences using the store's `addonID:type:catalogID` keys, then
    /// schedules the account sync push.
    private func persist() {
        let definitionKeyByModelKey = modelKeyToDefinitionKey
        let orderKeys = model.orderKeys.compactMap { definitionKeyByModelKey[$0] }
        let disabledKeys = Set(model.disabledKeys.compactMap { definitionKeyByModelKey[$0] })
        homePreferences.applyCatalogOrder(orderKeys: orderKeys, disabledKeys: disabledKeys)
        homePreferences.schedulePush(auth: auth, profileID: profiles.activeProfileID)
    }

    /// `addonID_type_catalogID` (model) -> `addonID:type:catalogID` (the
    /// HomeCatalogDefinition key Home preferences persist and consume).
    private var modelKeyToDefinitionKey: [String: String] {
        var mapping: [String: String] = [:]
        for definition in CatalogDescriptors.browse(from: addonStore.homeAddons) {
            mapping[AddonCatalogKeys.homeCatalogKey(
                addonID: definition.addonID,
                type: definition.type,
                catalogID: definition.catalogID
            )] = [definition.addonID, definition.type, definition.catalogID].joined(separator: ":")
        }
        return mapping
    }

    static func modelKey(
        forDefinitionKey definitionKey: String,
        valid definitions: [CatalogDescriptor]
    ) -> String? {
        let parts = definitionKey.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return nil }
        let key = AddonCatalogKeys.homeCatalogKey(
            addonID: parts[0], type: parts[1], catalogID: parts[2]
        )
        return definitions.contains { descriptor in
            descriptor.addonID == parts[0] && descriptor.type == parts[1] && descriptor.catalogID == parts[2]
        } ? key : nil
    }

    private var addonSnapshots: [AddonSnapshot] {
        addonStore.addons.map { addon in
            AddonSnapshot(
                endpoint: addon,
                isEnabled: !addonStore.disabledBases.contains(addon.baseURL)
            )
        }
    }
}
