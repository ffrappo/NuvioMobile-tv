import SwiftUI

/// Follow-layout folder tile matching Android `FolderCard`
/// (`CollectionRowSection.kt`): tile geometry per `tileShape`, cover art with
/// emoji and initials fallbacks, bottom title overlay gated by `hideTitle`,
/// and the Nuvio focus ring on native focus.
public struct CollectionFolderTile: View {
    public let folder: CollectionFolderDraft
    public var isSelected = false
    public let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        folder: CollectionFolderDraft,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.folder = folder
        self.isSelected = isSelected
        self.action = action
    }

    private var tileSize: CGSize { folder.tileShape.tileSize() }

    private var cornerRadius: CGFloat {
        NuvioDesignTokens.Shapes.posterRadius
    }

    private var artworkMode: NuvioArtworkMode {
        folder.tileShape == .landscape ? .backdrop : .poster
    }

    public var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                coverSurface
                if !folder.hideTitle && !folder.title.isEmpty {
                    titleOverlay
                }
            }
            .frame(width: tileSize.width, height: tileSize.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(selectionBorder)
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(folder.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(folder.hideTitle ? "Opens this folder" : "")
    }

    @ViewBuilder
    private var coverSurface: some View {
        let hasCover = folder.coverImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ZStack {
            if hasCover {
                NuvioArtworkView(
                    urlString: folder.coverImageUrl,
                    mode: artworkMode,
                    pixelSize: tileSize,
                    cornerRadius: cornerRadius
                )
            } else if let emoji = folder.coverEmoji, !emoji.isEmpty {
                // Android renders the folder emoji at 48 sp on a card surface.
                NuvioDesignTokens.Colors.elevated
                Text(emoji)
                    .font(.system(size: 48))
                    .minimumScaleFactor(0.5)
            } else {
                NuvioDesignTokens.Colors.elevated
                Text(folder.fallbackInitials)
                    .font(NuvioTypography.headline)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(width: tileSize.width, height: tileSize.height)
    }

    /// Android: bottom-centered labelMedium white title, 8 dp padding.
    private var titleOverlay: some View {
        Text(folder.title)
            .font(.caption)
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
            .padding(.vertical, NuvioDesignTokens.Spacing.xs)
            .shadow(color: .black.opacity(0.6), radius: NuvioDesignTokens.Blur.soft / 4)
            .padding(.bottom, NuvioDesignTokens.Spacing.sm)
    }

    @ViewBuilder
    private var selectionBorder: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    NuvioDesignTokens.Colors.brand,
                    lineWidth: NuvioDesignTokens.Focus.ringWidth
                )
                .allowsHitTesting(false)
        }
    }
}

/// Horizontal folder rail matching Android `CollectionRowSection`:
/// headline title, 48 dp edge padding, 16 dp gap, folder-shaped tiles.
public struct CollectionFolderRail: View {
    public let title: String?
    public let folders: [CollectionFolderDraft]
    public let onSelect: (CollectionFolderDraft) -> Void

    public init(
        title: String? = nil,
        folders: [CollectionFolderDraft],
        onSelect: @escaping (CollectionFolderDraft) -> Void
    ) {
        self.title = title
        self.folders = folders
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(NuvioTypography.headline)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(1)
                    .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(
                    alignment: .top,
                    spacing: NuvioDesignTokens.Spacing.lg
                ) {
                    ForEach(folders) { folder in
                        CollectionFolderTile(folder: folder) { onSelect(folder) }
                    }
                }
                .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
                .padding(.vertical, NuvioDesignTokens.Spacing.Rail.verticalPadding)
            }
        }
        .focusSection()
    }
}

/// Folder picker grid used when choosing a folder (Android tabbed-grid and
/// folder-detail selection surfaces): adaptive columns of folder tiles with
/// a selection ring on the chosen folder.
public struct CollectionFolderPickerGrid: View {
    public let folders: [CollectionFolderDraft]
    public let selectedFolderID: String?
    public let onSelect: (CollectionFolderDraft) -> Void

    public init(
        folders: [CollectionFolderDraft],
        selectedFolderID: String?,
        onSelect: @escaping (CollectionFolderDraft) -> Void
    ) {
        self.folders = folders
        self.selectedFolderID = selectedFolderID
        self.onSelect = onSelect
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 140, maximum: 280),
                spacing: NuvioDesignTokens.Spacing.Rail.itemGap
            )
        ]
    }

    public var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: NuvioDesignTokens.Spacing.Rail.rowGap) {
            ForEach(folders) { folder in
                CollectionFolderTile(
                    folder: folder,
                    isSelected: folder.id == selectedFolderID
                ) {
                    onSelect(folder)
                }
            }
        }
        .focusSection()
    }
}
