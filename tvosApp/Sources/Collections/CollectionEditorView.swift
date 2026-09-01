import SwiftUI

/// Collection editor screen matching Android `CollectionEditorScreen`:
/// collection rename, folder list with move up/down affordances (no drag and
/// drop on tvOS), add-folder and delete-folder actions with confirmation
/// alerts, per-folder item management, and the Trakt/TMDB source picker with
/// an import callback. Presentation-only: all persistence stays with the
/// integrator through the callbacks.
public struct CollectionEditorView: View {
    @State private var state: CollectionEditorState
    @State private var editingFolderID: String?
    @State private var folderPendingDeletion: CollectionFolderDraft?

    private let onSave: (CollectionEditorState) -> Void
    private let onCancel: () -> Void
    private let onImportSource: (CollectionSourceOption, String) -> Void
    private let onOpenItem: ((CollectionItemRef, CollectionFolderDraft) -> Void)?
    private let newFolderTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        state: CollectionEditorState,
        onSave: @escaping (CollectionEditorState) -> Void,
        onCancel: @escaping () -> Void,
        onImportSource: @escaping (CollectionSourceOption, String) -> Void,
        onOpenItem: ((CollectionItemRef, CollectionFolderDraft) -> Void)? = nil
    ) {
        _state = State(initialValue: state)
        self.onSave = onSave
        self.onCancel = onCancel
        self.onImportSource = onImportSource
        self.onOpenItem = onOpenItem
        newFolderTitle = ""
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.lg) {
                header
                titleSection
                folderListSection
                addFolderButton
                folderEditor
            }
            .padding(.horizontal, NuvioDesignTokens.Layout.safeHorizontal)
            .padding(.top, NuvioDesignTokens.Spacing.xxxl)
            .padding(.bottom, NuvioDesignTokens.Spacing.xxxl)
        }
        .background(NuvioDesignTokens.Colors.canvasBlack.ignoresSafeArea())
        .alert(
            "Delete Folder?",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { folderPendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let folder = folderPendingDeletion {
                    if editingFolderID == folder.id { editingFolderID = nil }
                    state.removeFolder(id: folder.id)
                }
                folderPendingDeletion = nil
            }
        } message: {
            Text("This will permanently delete \"\(folderPendingDeletion?.title ?? "")\" and its contents.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            NuvioPageHeader(
                title: state.isNew ? "New Collection" : "Edit Collection",
                subtitle: state.isDirty ? "Unsaved changes" : nil
            )
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
            Button("Save") {
                onSave(state.sanitizedForSave())
            }
            .buttonStyle(.borderedProminent)
            .disabled(!state.canSave)
            .accessibilityLabel("Save collection")
        }
        .animation(
            NuvioMotion.animation(for: .content, reduceMotion: reduceMotion),
            value: state.isDirty
        )
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            Text("Row Title")
                .font(.caption)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            TextField(
                "Collection name",
                text: Binding(
                    get: { state.title },
                    set: { state.setTitle(String($0.prefix(CollectionEditorState.maximumNameLength))) }
                )
            )
        }
    }

    private var folderListSection: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            HStack {
                Text("Folders")
                    .font(NuvioTypography.cardTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                Spacer()
                Text("\(state.folders.count) folder\(state.folders.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
            if state.folders.isEmpty {
                Text("Add your first folder to start building this collection.")
                    .font(.caption)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            } else {
                ForEach(Array(state.folders.enumerated()), id: \.element.id) { index, folder in
                    folderRow(folder, index: index)
                }
            }
        }
    }

    private func folderRow(_ folder: CollectionFolderDraft, index: Int) -> some View {
        let isEditing = editingFolderID == folder.id
        let isProtected = state.protectedFolderIDs.contains(folder.id)
        return HStack(spacing: NuvioDesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.title.isEmpty ? CollectionEditorState.untitledFolderName : folder.title)
                    .font(NuvioTypography.compactTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(1)
                Text("\(folder.tileShape.displayName) - \(folder.sources.count) source\(folder.sources.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
            Spacer()
            Button {
                state.moveFolderUp(index)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.bordered)
            .disabled(index == 0)
            .accessibilityLabel("Move \(folder.title) up")
            Button {
                state.moveFolderDown(index)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.bordered)
            .disabled(index == state.folders.count - 1)
            .accessibilityLabel("Move \(folder.title) down")
            Button {
                withMotion {
                    editingFolderID = isEditing ? nil : folder.id
                }
            } label: {
                Image(systemName: isEditing ? "chevron.down.circle" : "square.and.pencil")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(isEditing ? "Close folder editor" : "Edit \(folder.title)")
            Button {
                folderPendingDeletion = folder
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(isProtected)
            .accessibilityLabel(isProtected
                ? "\(folder.title) is a protected default folder"
                : "Delete \(folder.title)")
        }
        .padding(NuvioDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
                .fill(isEditing
                    ? NuvioDesignTokens.Colors.elevatedSecondary
                    : NuvioDesignTokens.Colors.elevated)
        )
    }

    private var addFolderButton: some View {
        Button {
            if let id = state.addFolder(title: newFolderTitle) {
                editingFolderID = id
            }
        } label: {
            Label("Add Folder", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Add folder")
    }

    @ViewBuilder
    private var folderEditor: some View {
        if let folderID = editingFolderID,
           let folder = state.folders.first(where: { $0.id == folderID }) {
            CollectionFolderEditorSection(
                folder: folder,
                otherFolders: state.folders.filter { $0.id != folderID },
                isProtected: state.protectedFolderIDs.contains(folderID),
                sourcePicker: state.sourcePicker,
                onRename: { state.renameFolder(id: folderID, to: $0) },
                onTileShapeChange: { state.setTileShape($0, folderID: folderID) },
                onHideTitleChange: { state.setHideTitle($0, folderID: folderID) },
                onRemoveItem: { state.removeItem(itemKey: $0, fromFolder: folderID) },
                onMoveItem: { itemKey, destinationID in
                    state.moveItem(itemKey: itemKey, fromFolder: folderID, toFolder: destinationID)
                },
                onRemoveSource: { state.removeSource(at: $0, fromFolder: folderID) },
                onSelectSourceOption: { state.sourcePicker.select($0) },
                onImportSelectedSource: { importSelectedSource(into: folderID) },
                onOpenItem: onOpenItem.map { open in
                    { item in open(item, folder) }
                }
            )
        }
    }

    private func importSelectedSource(into folderID: String) {
        guard let option = state.sourcePicker.selectedOption() else { return }
        if state.importSource(option, intoFolder: folderID) {
            onImportSource(option, folderID)
        }
    }

    private func withMotion(_ body: () -> Void) {
        if reduceMotion {
            body()
        } else {
            withAnimation(
                NuvioMotion.animation(for: .content, reduceMotion: false)
            ) {
                body()
            }
        }
    }
}
