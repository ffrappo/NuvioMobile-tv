import SwiftUI

struct AddonsView: View {
    @EnvironmentObject private var store: AddonStore
    @State private var manifestURL = ""
    @State private var statusMessage: String?
    @State private var statusIsSuccess = false
    @State private var isAdding = false
    @FocusState private var focus: AddonFocus?
    @State private var detailAddon: AddonEndpoint?

    private enum AddonFocus: Hashable { case field, add }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                NuvioPageHeader(
                    title: "Addons",
                    subtitle: "Manage the services that provide catalogs, metadata, and streams"
                )
                addForm
                enabledAddons
            }
            .padding(48)
        }
        .defaultFocus($focus, store.addons.isEmpty ? .field : nil)
    }

    private var addForm: some View {
        NuvioPanel {
            VStack(alignment: .leading, spacing: 16) {
                Label("Add from Manifest URL", systemImage: "link.badge.plus")
                    .font(.title2.weight(.semibold))
                Text("Paste a Stremio manifest link. Use an iPhone keyboard or Siri Remote dictation for faster entry.")
                    .foregroundStyle(.secondary)
                HStack(spacing: 18) {
                    TextField("https://example.com/manifest.json", text: $manifestURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .field)
                        .onSubmit(add)
                    Button(action: add) {
                        if isAdding { ProgressView() } else { Label("Add Addon", systemImage: "plus") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAdding || manifestURL.trimmedNonEmpty == nil)
                    .focused($focus, equals: .add)
                }
                if let statusMessage {
                    NuvioStatusMessage(
                        message: statusMessage,
                        symbol: statusIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        tint: statusIsSuccess ? .secondary : .orange
                    )
                }
            }
        }
    }

    /// The parity addon manager (Android `AddonManagerScreen.kt`): logo,
    /// version, catalog summary, credential badge, enable toggle, reorder,
    /// and removal with its own confirmation flow.
    @ViewBuilder
    private var enabledAddons: some View {
        AddonManagerView(
            entries: store.addons.map(addonListEntry),
            onAddAddon: { focus = .field },
            onToggleEnabled: { base, isEnabled in
                store.setEnabled(base, isEnabled)
            },
            onMoveUp: { base in store.move(base, offset: -1) },
            onMoveDown: { base in store.move(base, offset: 1) },
            onRemove: { base in
                if let addon = store.addons.first(where: { $0.baseURL == base }) {
                    Task { await store.remove(addon) }
                }
            },
            onSelectAddon: { base in
                detailAddon = store.addons.first { $0.baseURL == base }
            }
        )
        .sheet(item: $detailAddon) { addon in
            NavigationStack { addonDetailPage(addon) }
        }
        if let syncMessage = store.syncMessage {
            NuvioStatusMessage(message: syncMessage, symbol: "arrow.triangle.2.circlepath")
        }
    }

    private func addonDetailPage(_ addon: AddonEndpoint) -> some View {
        let manifest = addon.manifest
        let snapshot = AddonSnapshot(
            baseURL: addon.baseURL,
            manifestID: manifest?.id ?? "",
            name: addon.name,
            customName: nil,
            version: manifest?.version ?? "",
            description: addon.detail,
            logoURL: manifest?.logoURL,
            types: manifest?.types ?? [],
            catalogs: (manifest?.catalogs ?? []).map(AddonCatalogSnapshot.init),
            providesStreams: addon.providesStreams,
            configurationRequired: false,
            isEnabled: !store.disabledBases.contains(addon.baseURL),
            isProtected: false
        )
        return AddonDetailView(
            detail: AddonDetailModel(snapshot: snapshot, isInstalled: true),
            onInstall: {},
            onRemove: {
                detailAddon = nil
                Task { await store.remove(addon) }
            }
        )
    }

    private func addonListEntry(_ addon: AddonEndpoint) -> AddonListEntry {
        AddonListEntry(
            id: addon.baseURL,
            manifestID: addon.manifest?.id ?? "",
            name: addon.name,
            displayName: addon.name,
            version: addon.manifest?.version ?? "",
            types: addon.manifest?.types ?? [],
            isEnabled: !store.disabledBases.contains(addon.baseURL),
            isProtected: false,
            catalogCount: addon.manifest?.catalogs.count ?? 0,
            credentialBadge: AddonCredentialBadge(
                configurationRequired: false,
                baseURL: addon.baseURL
            ),
            logoURL: addon.manifest?.logoURL
        )
    }

    private func add() {
        guard manifestURL.trimmedNonEmpty != nil else {
            statusMessage = "Enter a manifest URL first."
            statusIsSuccess = false
            focus = .field
            return
        }
        Task { await addManifest() }
    }

    @MainActor
    private func addManifest() async {
        isAdding = true
        statusMessage = nil
        do {
            try await store.add(manifestURL: manifestURL)
            statusMessage = "Addon added successfully."
            statusIsSuccess = true
            manifestURL = ""
        } catch {
            statusMessage = error.userMessage
            statusIsSuccess = false
        }
        isAdding = false
    }
}
