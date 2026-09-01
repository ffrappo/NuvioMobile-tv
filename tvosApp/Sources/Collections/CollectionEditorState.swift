import Foundation

/// Presentation-only editor state for the Nuvio collection editor.
///
/// All mutations are synchronous and value-typed, so the integrator can keep
/// this in any SwiftUI `@State` and diff it against the saved baseline:
/// `isDirty` and `divergentEdits` are derived by comparing the working state
/// with the snapshot taken at load (or the last `markSaved()`).
public struct CollectionEditorState: Equatable, Sendable {
    /// Name-safe limits. Android does not cap collection or folder names; the
    /// task brief asks for a safe limit, so the editor enforces one.
    public static let maximumNameLength = 60

    /// Android `collection_editor_untitled_collection`.
    public static let untitledCollectionName = "Untitled Collection"
    /// Android `collection_editor_untitled_folder`.
    public static let untitledFolderName = "Untitled"

    public private(set) var collectionID: String
    public private(set) var isNew: Bool
    public private(set) var title: String
    public private(set) var backdropImageUrl: String?
    public private(set) var pinToTop: Bool
    public private(set) var folders: [CollectionFolderDraft]
    public let protectedFolderIDs: Set<String>
    public var sourcePicker: CollectionSourcePickerState
    var baseline: CollectionEditorBaseline

    // MARK: Initialization

    /// Builds editor state from a synced `TVCollection`, or a fresh
    /// collection when `collection` is nil. `folderItems` seeds the
    /// per-folder item lists that Android populates from folder sources.
    /// (Internal because `TVCollection` is module-internal.)
    init(
        collection: TVCollection? = nil,
        folderItems: [String: [CollectionItemRef]] = [:],
        protectedFolderIDs: Set<String> = [],
        sourceOptions: [CollectionSourceOption] = []
    ) {
        if let collection {
            let drafts = collection.folders.map { folder in
                CollectionFolderDraft(
                    id: folder.id,
                    title: folder.title,
                    coverImageUrl: folder.coverImageUrl,
                    tileShape: CollectionTileShape(raw: folder.tileShape),
                    hideTitle: folder.hideTitle,
                    items: folderItems[folder.id] ?? [],
                    sources: folder.sources.map(CollectionSourceDraft.init(source:))
                )
            }
            collectionID = collection.id
            isNew = false
            title = collection.title
            backdropImageUrl = collection.backdropImageUrl
            pinToTop = collection.pinToTop
            folders = drafts
        } else {
            collectionID = UUID().uuidString
            isNew = true
            title = ""
            backdropImageUrl = nil
            pinToTop = false
            folders = []
        }
        self.protectedFolderIDs = protectedFolderIDs
        sourcePicker = CollectionSourcePickerState(options: sourceOptions)
        baseline = CollectionEditorBaseline(
            title: title,
            backdropImageUrl: backdropImageUrl,
            pinToTop: pinToTop,
            folders: folders
        )
    }

    // MARK: Collection-level edits

    /// Android `setTitle`. Returns true when the value changed.
    @discardableResult
    public mutating func setTitle(_ newTitle: String) -> Bool {
        guard newTitle != title else { return false }
        title = newTitle
        return true
    }

    @discardableResult
    public mutating func setBackdropImageUrl(_ url: String?) -> Bool {
        let normalized = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != backdropImageUrl else { return false }
        backdropImageUrl = normalized
        return true
    }

    @discardableResult
    public mutating func setPinToTop(_ pinned: Bool) -> Bool {
        guard pinned != pinToTop else { return false }
        pinToTop = pinned
        return true
    }

    // MARK: Folder edits

    /// Android `addFolder`: appends an empty poster-shaped folder.
    /// Returns the new folder ID (nil only when the ID already exists).
    @discardableResult
    public mutating func addFolder(
        id: String = UUID().uuidString,
        title: String = "",
        tileShape: CollectionTileShape = .poster,
        coverImageUrl: String? = nil
    ) -> String? {
        guard !folders.contains(where: { $0.id == id }) else { return nil }
        folders.append(CollectionFolderDraft(
            id: id,
            title: title,
            coverImageUrl: coverImageUrl,
            tileShape: tileShape
        ))
        return id
    }

    /// Android `updateFolderTitle`. Refused for protected folders.
    @discardableResult
    public mutating func renameFolder(id: String, to newTitle: String) -> Bool {
        guard !protectedFolderIDs.contains(id),
              let index = folders.firstIndex(where: { $0.id == id }),
              folders[index].title != newTitle else { return false }
        folders[index].title = newTitle
        return true
    }

    /// Android `removeFolder`. Refused for protected folders.
    @discardableResult
    public mutating func removeFolder(id: String) -> Bool {
        guard !protectedFolderIDs.contains(id),
              let index = folders.firstIndex(where: { $0.id == id }) else { return false }
        folders.remove(at: index)
        return true
    }

    /// Android `moveFolderUp`: no-op at the top edge.
    public mutating func moveFolderUp(_ index: Int) {
        moveFolder(from: index, to: index - 1)
    }

    /// Android `moveFolderDown`: no-op at the bottom edge.
    public mutating func moveFolderDown(_ index: Int) {
        moveFolder(from: index, to: index + 1)
    }

    /// Moves the folder at `source` to `destination` when both indices are
    /// valid, matching Android's remove-at/insert-at behavior.
    public mutating func moveFolder(from source: Int, to destination: Int) {
        guard folders.indices.contains(source),
              folders.indices.contains(destination),
              source != destination else { return }
        let folder = folders.remove(at: source)
        folders.insert(folder, at: destination)
    }

    /// Android `updateFolderTileShape`.
    @discardableResult
    public mutating func setTileShape(_ shape: CollectionTileShape, folderID: String) -> Bool {
        guard let index = folders.firstIndex(where: { $0.id == folderID }),
              folders[index].tileShape != shape else { return false }
        folders[index].tileShape = shape
        return true
    }

    /// Android `updateFolderHideTitle`.
    @discardableResult
    public mutating func setHideTitle(_ hidden: Bool, folderID: String) -> Bool {
        guard let index = folders.firstIndex(where: { $0.id == folderID }),
              folders[index].hideTitle != hidden else { return false }
        folders[index].hideTitle = hidden
        return true
    }

    /// Android `updateFolderCoverImage`/`updateFolderCoverEmoji`.
    @discardableResult
    public mutating func setCoverImageUrl(_ url: String?, folderID: String) -> Bool {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return false }
        let trimmed = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = (trimmed?.isEmpty == true) ? nil : trimmed
        guard folders[index].coverImageUrl != normalized || folders[index].coverEmoji != nil else {
            return false
        }
        folders[index].coverImageUrl = normalized
        folders[index].coverEmoji = nil
        return true
    }

    // MARK: Folder items

    /// Adds an item to a folder; duplicates (same `type:id`) are ignored.
    @discardableResult
    public mutating func addItem(_ item: CollectionItemRef, toFolder folderID: String) -> Bool {
        guard let index = folders.firstIndex(where: { $0.id == folderID }),
              !folders[index].items.contains(where: { $0.key == item.key }) else { return false }
        folders[index].items.append(item)
        return true
    }

    @discardableResult
    public mutating func removeItem(itemKey: String, fromFolder folderID: String) -> Bool {
        guard let index = folders.firstIndex(where: { $0.id == folderID }),
              let itemIndex = folders[index].items.firstIndex(where: { $0.key == itemKey }) else {
            return false
        }
        folders[index].items.remove(at: itemIndex)
        return true
    }

    /// Moves an item between folders. Moving within the same folder is a
    /// no-op; missing folders or items fail without mutating.
    @discardableResult
    public mutating func moveItem(itemKey: String, fromFolder sourceID: String, toFolder destinationID: String) -> Bool {
        guard sourceID != destinationID,
              let sourceIndex = folders.firstIndex(where: { $0.id == sourceID }),
              let destinationIndex = folders.firstIndex(where: { $0.id == destinationID }),
              let itemIndex = folders[sourceIndex].items.firstIndex(where: { $0.key == itemKey }),
              !folders[destinationIndex].items.contains(where: { $0.key == itemKey }) else {
            return false
        }
        let item = folders[sourceIndex].items.remove(at: itemIndex)
        folders[destinationIndex].items.append(item)
        return true
    }

    // MARK: Source import

    /// Adds an imported provider source to a folder (Android
    /// `addTraktSourcesToFolder`/`addTmdbSourcesToFolder` duplicate guard),
    /// then records the picker selection.
    @discardableResult
    public mutating func importSource(_ option: CollectionSourceOption, intoFolder folderID: String) -> Bool {
        guard let index = folders.firstIndex(where: { $0.id == folderID }),
              !folders[index].sources.contains(where: { $0.fingerprint == option.source.fingerprint }) else {
            sourcePicker.select(option.id)
            return false
        }
        folders[index].sources.append(option.source)
        sourcePicker.select(option.id)
        sourcePicker.importError = nil
        return true
    }

    /// Removes an imported source from a folder by index.
    @discardableResult
    public mutating func removeSource(at sourceIndex: Int, fromFolder folderID: String) -> Bool {
        guard let index = folders.firstIndex(where: { $0.id == folderID }),
              folders[index].sources.indices.contains(sourceIndex) else { return false }
        folders[index].sources.remove(at: sourceIndex)
        return true
    }

    public func hasImported(_ option: CollectionSourceOption, folderID: String) -> Bool {
        folders.first(where: { $0.id == folderID })?.sources
            .contains(where: { $0.fingerprint == option.source.fingerprint }) ?? false
    }

    /// Android `saveFolderEdit`/`save` cleanup: blank names become the
    /// untitled defaults and blank URLs are dropped before persisting.
    public func sanitizedForSave() -> CollectionEditorState {
        var sanitized = self
        if sanitized.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sanitized.title = Self.untitledCollectionName
        }
        if let backdrop = sanitized.backdropImageUrl,
           backdrop.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sanitized.backdropImageUrl = nil
        }
        sanitized.folders = sanitized.folders.map { folder in
            var copy = folder
            if copy.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.title = Self.untitledFolderName
            }
            if let cover = copy.coverImageUrl,
               cover.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.coverImageUrl = nil
            }
            return copy
        }
        return sanitized
    }

}
private extension CollectionSourceDraft {
    init(source: TVCollectionSource) {
        self.init(
            provider: source.provider,
            addonId: source.addonId,
            type: source.type,
            catalogId: source.catalogId,
            genre: source.genre,
            title: source.title,
            tmdbSourceType: source.tmdbSourceType,
            tmdbId: source.tmdbId,
            traktListId: source.traktListId,
            mediaType: source.mediaType,
            sortBy: source.sortBy,
            sortHow: source.sortHow
        )
    }
}
