import Foundation

// Dirty tracking, validation, and sync serialization for
// `CollectionEditorState`, split out to keep files small.

extension CollectionEditorState {
    // MARK: Dirty tracking

    public var isDirty: Bool { !divergentEdits.isEmpty }

    public func hasDivergentEdit(_ kind: CollectionEditKind) -> Bool {
        divergentEdits.contains(kind)
    }

    /// Derived from a diff against the save baseline. Reverting an edit
    /// clears the kind again, so `isDirty` reflects real changes only.
    public var divergentEdits: Set<CollectionEditKind> {
        var edits: Set<CollectionEditKind> = []
        if title != baseline.title { edits.insert(.renameCollection) }
        if backdropImageUrl != baseline.backdropImageUrl { edits.insert(.backdropChanged) }
        if pinToTop != baseline.pinToTop { edits.insert(.pinToTopChanged) }

        let currentByID = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        let baselineByID = Dictionary(uniqueKeysWithValues: baseline.folders.map { ($0.id, $0) })
        let baselineItemOwners = itemOwners(by: baseline.folders)

        for folder in folders {
            guard let baselineFolder = baselineByID[folder.id] else {
                edits.insert(.addFolder(folder.id))
                continue
            }
            if folder.title != baselineFolder.title {
                edits.insert(.renameFolder(folder.id))
            }
            if folder.tileShape != baselineFolder.tileShape
                || folder.hideTitle != baselineFolder.hideTitle
                || folder.coverImageUrl != baselineFolder.coverImageUrl
                || folder.coverEmoji != baselineFolder.coverEmoji {
                edits.insert(.folderSettings(folder.id))
            }
            var baselineFingerprints = baselineFolder.sources.map(\.fingerprint)
            for fingerprint in folder.sources.map(\.fingerprint) {
                if let position = baselineFingerprints.firstIndex(of: fingerprint) {
                    baselineFingerprints.remove(at: position)
                } else {
                    edits.insert(.importSource(folderID: folder.id, fingerprint: fingerprint))
                }
            }
            for fingerprint in baselineFingerprints {
                edits.insert(.removeSource(folderID: folder.id, fingerprint: fingerprint))
            }
            let currentKeys = Set(folder.items.map(\.key))
            for item in baselineFolder.items where !currentKeys.contains(item.key) {
                if let newOwner = currentByID.values.first(where: { $0.items.contains(where: { $0.key == item.key }) }) {
                    edits.insert(.moveItem(itemKey: item.key, fromFolderID: folder.id, toFolderID: newOwner.id))
                } else {
                    edits.insert(.removeItem(folderID: folder.id, itemKey: item.key))
                }
            }
            for item in folder.items where baselineItemOwners[item.key] == nil
                && !baselineFolder.items.contains(where: { $0.key == item.key }) {
                edits.insert(.addItem(folderID: folder.id, itemKey: item.key))
            }
        }

        for folder in baseline.folders where currentByID[folder.id] == nil {
            edits.insert(.removeFolder(folder.id))
        }

        let sharedCurrent = folders.map(\.id).filter { baselineByID[$0] != nil }
        let sharedBaseline = baseline.folders.map(\.id).filter { currentByID[$0] != nil }
        if sharedCurrent != sharedBaseline {
            edits.insert(.reorderFolders)
        }

        return edits
    }

    private func itemOwners(by folders: [CollectionFolderDraft]) -> [String: String] {
        var owners: [String: String] = [:]
        for folder in folders {
            for item in folder.items { owners[item.key] = folder.id }
        }
        return owners
    }

    /// Resets the save baseline to the current state (after a successful save).
    public mutating func markSaved() {
        baseline = CollectionEditorBaseline(
            title: title,
            backdropImageUrl: backdropImageUrl,
            pinToTop: pinToTop,
            folders: folders
        )
    }

    // MARK: Validation

    /// Android save gating: a non-blank title plus at least one folder
    /// (`canSaveCollection` in `CollectionEditorScreen.kt`).
    public var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !folders.isEmpty
    }

    public func validate() -> [CollectionValidationIssue] {
        var issues: [CollectionValidationIssue] = []
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty { issues.append(.collectionTitleEmpty) }
        if title.count > Self.maximumNameLength {
            issues.append(.collectionTitleTooLong(limit: Self.maximumNameLength))
        }
        if folders.isEmpty { issues.append(.collectionNeedsFolders) }
        for folder in folders {
            if folder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.folderNameEmpty(folderID: folder.id))
            }
            if folder.title.count > Self.maximumNameLength {
                issues.append(.folderNameTooLong(folderID: folder.id, limit: Self.maximumNameLength))
            }
        }
        return issues
    }

    // MARK: Sync bridge

    /// Encodes the collection to the JSON shape the existing `TVCollection`
    /// wire model decodes, so the integrator can round-trip the saved draft:
    /// `JSONDecoder().decode(TVCollection.self, from: payload)`.
    public func encodedCollectionPayload() throws -> Data {
        let payload = SyncCollectionPayload(
            id: collectionID,
            title: title,
            backdropImageUrl: backdropImageUrl,
            pinToTop: pinToTop,
            folders: folders
        )
        return try JSONEncoder().encode(payload)
    }
}

struct CollectionEditorBaseline: Equatable, Sendable {
    let title: String
    let backdropImageUrl: String?
    let pinToTop: Bool
    let folders: [CollectionFolderDraft]
}

private struct SyncCollectionPayload: Encodable {
    let id: String
    let title: String
    let backdropImageUrl: String?
    let pinToTop: Bool
    let folders: [CollectionFolderDraft]
}
