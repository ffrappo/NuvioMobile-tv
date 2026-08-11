import SwiftUI

struct AddonsView: View {
    @EnvironmentObject private var store: AddonStore
    @State private var manifestURL = ""
    @State private var statusMessage: String?
    @State private var isAdding = false
    @FocusState private var focus: AddonFocus?

    private enum AddonFocus: Hashable {
        case field
        case add
        case remove(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Addons")
                    .font(.largeTitle.weight(.bold))

                builtInCard
                addForm

                if store.addons.isEmpty {
                    Text("No stream addons are enabled. Add a Stremio manifest URL to get started.")
                        .font(.title3)
                        .foregroundStyle(NuvioTheme.secondaryText)
                        .padding(.vertical, 32)
                } else {
                    Text("Enabled Addons")
                        .font(.title2.weight(.semibold))
                    ForEach(store.addons) { addon in
                        addonCard(addon)
                    }
                }
            }
            .padding(48)
        }
        .defaultFocus($focus, .field)
    }

    private var builtInCard: some View {
        HStack(spacing: 22) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 7) {
                Text("Cinemeta")
                    .font(.title3.weight(.semibold))
                Text("Built in catalog and metadata provider. It is not used as a stream provider.")
                    .foregroundStyle(NuvioTheme.secondaryText)
            }
            Spacer()
            Text("Always On")
                .font(.callout.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.14), in: Capsule())
        }
        .padding(24)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 20))
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add a Manifest URL")
                .font(.title2.weight(.semibold))

            HStack(spacing: 18) {
                TextField("https://example.com/manifest.json", text: $manifestURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .field)
                    .onSubmit(add)

                Button(action: add) {
                    if isAdding {
                        ProgressView()
                    } else {
                        Label("Add", systemImage: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAdding)
                .focused($focus, equals: .add)
            }

            if let statusMessage {
                Text(statusMessage.tvSafe)
                    .font(.callout)
                    .foregroundStyle(statusMessage.hasPrefix("Added") ? .green : .orange)
            }
            if let syncMessage = store.syncMessage {
                Text(syncMessage.tvSafe)
                    .font(.callout)
                    .foregroundStyle(syncMessage.hasPrefix("Synced") ? .green : NuvioTheme.secondaryText)
            }
        }
    }

    private func addonCard(_ addon: AddonEndpoint) -> some View {
        HStack(spacing: 20) {
            Image(systemName: addon.providesStreams ? "play.rectangle.fill" : "puzzlepiece.extension.fill")
                .font(.system(size: 36))
            VStack(alignment: .leading, spacing: 6) {
                Text(addon.name.tvSafe)
                    .font(.title3.weight(.semibold))
                Text(addon.detail?.tvSafe ?? addon.baseURL.tvSafe)
                    .font(.callout)
                    .foregroundStyle(NuvioTheme.secondaryText)
                    .lineLimit(2)
                Text(addon.providesStreams ? "Stream resource available" : "No stream resource declared")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(addon.providesStreams ? .green : .orange)
            }
            Spacer()
            Button(role: .destructive) {
                Task { await store.remove(addon) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .focused($focus, equals: .remove(addon.id))
        }
        .padding(24)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 20))
    }

    private func add() {
        guard !manifestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Enter a manifest URL first."
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
            statusMessage = "Added the addon successfully."
            manifestURL = ""
        } catch {
            statusMessage = error.userMessage
        }
        isAdding = false
    }
}

