import Foundation
import SwiftUI

// MARK: - Collection push (Android CollectionSyncService.pushToRemote)

extension NuvioAccountService {
    /// `sync_push_collections`: replaces the profile's collections with the
    /// given list, serializing to the same camelCase shape the pull decodes.
    func pushCollections(
        _ collections: [TVCollection],
        profileID: Int,
        accessToken: String
    ) async throws {
        try await requestVoid(
            path: "/rest/v1/rpc/sync_push_collections",
            jsonBody: [
                "p_profile_id": profileID,
                "p_collections_json": collections.map(Self.collectionJSON),
                "p_origin_client_id": TVSyncClientIdentity.current(),
            ],
            accessToken: accessToken
        )
    }

    private static func collectionJSON(_ collection: TVCollection) -> [String: Any] {
        var json: [String: Any] = [
            "id": collection.id,
            "title": collection.title,
            "pinToTop": collection.pinToTop,
            "folders": collection.folders.map(folderJSON),
        ]
        if let backdrop = collection.backdropImageUrl {
            json["backdropImageUrl"] = backdrop
        }
        return json
    }

    private static func folderJSON(_ folder: TVCollectionFolder) -> [String: Any] {
        var json: [String: Any] = [
            "id": folder.id,
            "title": folder.title,
            "tileShape": folder.tileShape,
            "hideTitle": folder.hideTitle,
            "sources": folder.sources.map(sourceJSON),
        ]
        if let cover = folder.coverImageUrl {
            json["coverImageUrl"] = cover
        }
        return json
    }

    private static func sourceJSON(_ source: TVCollectionSource) -> [String: Any] {
        var json: [String: Any] = ["provider": source.provider]
        json["addonId"] = source.addonId as Any?
        json["type"] = source.type as Any?
        json["catalogId"] = source.catalogId as Any?
        json["genre"] = source.genre as Any?
        json["title"] = source.title as Any?
        json["tmdbSourceType"] = source.tmdbSourceType as Any?
        json["tmdbId"] = source.tmdbId as Any?
        json["traktListId"] = source.traktListId as Any?
        json["mediaType"] = source.mediaType as Any?
        json["sortBy"] = source.sortBy as Any?
        json["sortHow"] = source.sortHow as Any?
        return json
    }
}

// MARK: - Editor hosting

/// Hosts the parity collection editor against `CollectionStore`: saving
/// maps the editor state onto `TVCollection` and pushes the list.
struct CollectionEditingSheet: View {
    @EnvironmentObject private var collectionStore: CollectionStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var profiles: TVProfileStore
    @EnvironmentObject private var addons: AddonStore
    @Environment(\.dismiss) private var dismiss

    let existing: TVCollection?
    @State private var state = CollectionEditorState()

    var body: some View {
        NavigationStack {
            CollectionEditorView(
                state: state,
                onSave: { edited in save(edited) },
                onCancel: { dismiss() },
                onImportSource: { _, _ in }
            )
            .navigationTitle(existing?.title ?? "New Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear(perform: buildState)
    }

    private func buildState() {
        state = CollectionEditorState(
            collection: existing,
            folderItems: [:],
            protectedFolderIDs: [],
            sourceOptions: Self.sourceOptions(addons: addons.addons)
        )
    }

    /// One option per addon catalog, like the Android catalog picker.
    private static func sourceOptions(addons: [AddonEndpoint]) -> [CollectionSourceOption] {
        addons.compactMap { addon -> CollectionSourceOption? in
            guard let manifest = addon.manifest else { return nil }
            return CollectionSourceOption(
                id: addon.baseURL,
                kind: .addon,
                title: addon.name,
                subtitle: "\(manifest.catalogs.count) catalogs",
                coverImageUrl: manifest.logoURL,
                source: CollectionSourceDraft(
                    provider: "addon",
                    addonId: manifest.id,
                    type: manifest.catalogs.first?.type,
                    catalogId: manifest.catalogs.first?.id
                )
            )
        }
    }

    private func save(_ edited: CollectionEditorState) {
        let folders = edited.folders.map { draft in
            TVCollectionFolder(
                id: draft.id,
                title: draft.title,
                coverImageUrl: draft.coverImageUrl,
                tileShape: draft.tileShape.rawValue,
                hideTitle: draft.hideTitle,
                sources: draft.sources.map { draft in
                    TVCollectionSource(
                        provider: draft.provider,
                        addonId: draft.addonId,
                        type: draft.type,
                        catalogId: draft.catalogId,
                        genre: draft.genre,
                        title: draft.title,
                        tmdbSourceType: draft.tmdbSourceType,
                        tmdbId: draft.tmdbId,
                        traktListId: draft.traktListId,
                        mediaType: draft.mediaType,
                        sortBy: draft.sortBy,
                        sortHow: draft.sortHow
                    )
                }
            )
        }
        let collection = TVCollection(
            id: edited.collectionID,
            title: edited.title,
            backdropImageUrl: edited.backdropImageUrl,
            pinToTop: edited.pinToTop,
            folders: folders
        )
        var list = collectionStore.collections
        if let index = list.firstIndex(where: { $0.id == collection.id }) {
            list[index] = collection
        } else {
            list.append(collection)
        }
        Task { @MainActor in
            await collectionStore.save(list, auth: auth, profileID: profiles.activeProfileID)
            dismiss()
        }
    }
}
