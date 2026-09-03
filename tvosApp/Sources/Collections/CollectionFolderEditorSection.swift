import SwiftUI

/// Per-folder editing section shown below the folder list while a folder is
/// being edited. Mirrors Android `FolderEditorContent`: rename field, tile
/// shape choice, hide-title switch, item management (remove / move to
/// another folder), imported source list, and the Trakt/TMDB source picker.
public struct CollectionFolderEditorSection: View {
    public let folder: CollectionFolderDraft
    public let otherFolders: [CollectionFolderDraft]
    public let isProtected: Bool
    public let sourcePicker: CollectionSourcePickerState
    public let onRename: (String) -> Void
    public let onTileShapeChange: (CollectionTileShape) -> Void
    public let onHideTitleChange: (Bool) -> Void
    public let onRemoveItem: (String) -> Void
    public let onMoveItem: (String, String) -> Void
    public let onRemoveSource: (Int) -> Void
    public let onSelectSourceOption: (String?) -> Void
    public let onImportSelectedSource: () -> Void
    public let onOpenItem: ((CollectionItemRef) -> Void)?

    @State private var draftTitle: String
    @FocusState private var titleFieldFocused: Bool

    public init(
        folder: CollectionFolderDraft,
        otherFolders: [CollectionFolderDraft],
        isProtected: Bool = false,
        sourcePicker: CollectionSourcePickerState = CollectionSourcePickerState(),
        onRename: @escaping (String) -> Void,
        onTileShapeChange: @escaping (CollectionTileShape) -> Void,
        onHideTitleChange: @escaping (Bool) -> Void,
        onRemoveItem: @escaping (String) -> Void,
        onMoveItem: @escaping (String, String) -> Void,
        onRemoveSource: @escaping (Int) -> Void,
        onSelectSourceOption: @escaping (String?) -> Void,
        onImportSelectedSource: @escaping () -> Void,
        onOpenItem: ((CollectionItemRef) -> Void)? = nil
    ) {
        self.folder = folder
        self.otherFolders = otherFolders
        self.isProtected = isProtected
        self.sourcePicker = sourcePicker
        self.onRename = onRename
        self.onTileShapeChange = onTileShapeChange
        self.onHideTitleChange = onHideTitleChange
        self.onRemoveItem = onRemoveItem
        self.onMoveItem = onMoveItem
        self.onRemoveSource = onRemoveSource
        self.onSelectSourceOption = onSelectSourceOption
        self.onImportSelectedSource = onImportSelectedSource
        self.onOpenItem = onOpenItem
        _draftTitle = State(initialValue: folder.title)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.lg) {
            folderHeader
            nameField
            tileShapePicker
            hideTitleToggle
            itemManagement
            sourceList
            sourcePickerSection
        }
        .padding(NuvioDesignTokens.Spacing.Card.inner)
        .background(
            RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
                .fill(NuvioDesignTokens.Colors.elevated)
        )
        .onChange(of: folder.title) { _, newTitle in
            if newTitle != draftTitle { draftTitle = newTitle }
        }
    }

    private var folderHeader: some View {
        HStack {
            Label("Edit Folder", systemImage: "folder.badge.gearshape")
                .font(NuvioTypography.cardTitle)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            Spacer()
            if isProtected {
                Text("Default folder")
                    .font(.caption)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            Text("Folder Name")
                .font(.caption)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            TextField(
                isProtected ? "Default folder name" : "Name",
                text: Binding(
                    get: { draftTitle },
                    set: { newValue in
                        draftTitle = String(newValue.prefix(CollectionEditorState.maximumNameLength))
                        onRename(draftTitle)
                    }
                )
            )
            .disabled(isProtected)
            .focused($titleFieldFocused)
        }
    }

    private var tileShapePicker: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            Text("Tile Shape")
                .font(.caption)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            Picker("Tile Shape", selection: Binding(
                get: { folder.tileShape },
                set: { onTileShapeChange($0) }
            )) {
                ForEach(CollectionTileShape.allCases, id: \.self) { shape in
                    Text(shape.displayName).tag(shape)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var hideTitleToggle: some View {
        Toggle(isOn: Binding(
            get: { folder.hideTitle },
            set: { onHideTitleChange($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hide folder title")
                Text("Show only cover art on the folder tile")
                    .font(.caption)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
        }
        .toggleStyle(.switch)
    }

    @ViewBuilder
    private var itemManagement: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            Text("Titles in this folder (\(folder.items.count))")
                .font(.caption)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            if folder.items.isEmpty {
                Text("No titles yet. Import a list or add titles from the library.")
                    .font(.caption)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            } else {
                ForEach(folder.items) { item in
                    itemRow(item)
                }
            }
        }
    }

    private func itemRow(_ item: CollectionItemRef) -> some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            Button {
                onOpenItem?(item)
            } label: {
                HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                    Image(systemName: item.type == "series" ? "tv" : "film")
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    Text(item.name)
                        .font(NuvioTypography.compactBody)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .disabled(onOpenItem == nil)
            Spacer()
            if !otherFolders.isEmpty {
                Menu {
                    ForEach(otherFolders) { destination in
                        Button(destination.title.isEmpty
                            ? CollectionEditorState.untitledFolderName
                            : destination.title
                        ) {
                            onMoveItem(item.key, destination.id)
                        }
                    }
                } label: {
                    Image(systemName: "folder.badge.arrow.up")
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
                .accessibilityLabel("Move \(item.name) to another folder")
            }
            Button {
                onRemoveItem(item.key)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(NuvioDesignTokens.Colors.error)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Remove \(item.name)")
        }
        .padding(.vertical, NuvioDesignTokens.Spacing.xs)
    }

    @ViewBuilder
    private var sourceList: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            Text("Sources (\(folder.sources.count))")
                .font(.caption)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            ForEach(Array(folder.sources.enumerated()), id: \.offset) { index, source in
                HStack {
                    Text(source.title ?? source.provider)
                        .font(NuvioTypography.compactBody)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Text(sourceDisplayName(source))
                        .font(.caption)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    Button {
                        onRemoveSource(index)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(NuvioDesignTokens.Colors.error)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Remove source \(source.title ?? "")")
                }
            }
        }
    }

    private func sourceDisplayName(_ source: CollectionSourceDraft) -> String {
        switch source.provider.lowercased() {
        case "tmdb": return "TMDB"
        case "trakt": return "Trakt"
        default: return "Addon"
        }
    }

    @ViewBuilder
    private var sourcePickerSection: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            Text("Import from")
                .font(.caption)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            Picker("Provider", selection: Binding(
                get: { sourcePicker.activeProvider ?? .tmdb },
                set: { onSelectProvider($0) }
            )) {
                ForEach(CollectionSourceProviderKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            providerOptions
            if let error = sourcePicker.importError, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(NuvioDesignTokens.Colors.error)
            }
        }
    }

    private var activeKind: CollectionSourceProviderKind {
        sourcePicker.activeProvider ?? .tmdb
    }

    private var providerOptions: some View {
        VStack(spacing: NuvioDesignTokens.Spacing.sm) {
            let options = sourcePicker.options(for: activeKind)
            if options.isEmpty {
                Text("No \(activeKind.displayName) lists available yet.")
                    .font(.caption)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            } else {
                ForEach(options) { option in
                    optionRow(option)
                }
            }
            Button {
                onImportSelectedSource()
            } label: {
                Label("Add Source", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(sourcePicker.selectedOptionID == nil)
        }
    }

    private func optionRow(_ option: CollectionSourceOption) -> some View {
        Button {
            onSelectSourceOption(option.id)
        } label: {
            HStack(spacing: NuvioDesignTokens.Spacing.md) {
                Circle()
                    .fill(brandColor(for: option.kind))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(NuvioTypography.compactBody)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                        .lineLimit(1)
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if sourcePicker.isSelected(option.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(NuvioDesignTokens.Colors.brand)
                }
            }
            .padding(NuvioDesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.sm, style: .continuous)
                    .fill(sourcePicker.isSelected(option.id)
                        ? NuvioDesignTokens.Colors.brand.opacity(0.18)
                        : NuvioDesignTokens.Colors.elevatedSecondary)
            )
        }
        .buttonStyle(.card)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(sourcePicker.isSelected(option.id) ? [.isSelected] : [])
    }

    private func brandColor(for kind: CollectionSourceProviderKind) -> Color {
        switch kind {
        case .addon: return NuvioDesignTokens.Colors.brand
        case .trakt: return NuvioDesignTokens.Colors.trakt
        case .tmdb: return NuvioDesignTokens.Colors.tmdb
        }
    }

    private func onSelectProvider(_ kind: CollectionSourceProviderKind) {
        if sourcePicker.activeProvider != kind {
            onSelectSourceOption(sourcePicker.options(for: kind).first?.id)
        }
    }
}
