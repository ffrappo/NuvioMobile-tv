import CoreGraphics
import Foundation

// MARK: - Tile shape

/// Folder tile geometry ported from Android `PosterShape` and the `FolderCard`
/// composable in `CollectionRowSection.kt`.
public enum CollectionTileShape: String, CaseIterable, Codable, Hashable, Sendable {
    case poster
    case landscape
    case square

    /// Android `PosterShape.fromString`: unknown values fall back to poster.
    public init(raw: String?) {
        self = Self.from(raw)
    }

    public static func from(_ value: String?) -> CollectionTileShape {
        switch value?.lowercased() {
        case "landscape": return .landscape
        case "square": return .square
        default: return .poster
        }
    }

    /// Android poster-card base: 126 x 189 dp, matching
    /// `NuvioDesignTokens.Sizes.Cards.poster`.
    public static let defaultBaseSize = CGSize(width: 126, height: 189)

    /// Android `FolderCard` follow-layout geometry:
    /// poster -> base size; landscape -> (width * 16/9, width); square -> (width, width).
    public func tileSize(baseSize: CGSize = CollectionTileShape.defaultBaseSize) -> CGSize {
        switch self {
        case .poster:
            return CGSize(width: baseSize.width, height: baseSize.height)
        case .landscape:
            return CGSize(width: baseSize.width * 16.0 / 9.0, height: baseSize.width)
        case .square:
            return CGSize(width: baseSize.width, height: baseSize.width)
        }
    }

    /// Android `collections_editor_shape_*` labels.
    public var displayName: String {
        switch self {
        case .poster: return "Poster"
        case .landscape: return "Wide"
        case .square: return "Square"
        }
    }
}

// MARK: - Folder contents

/// One editable folder in the collection editor. Coding keys match the
/// synced `TVCollectionFolder` payload, so drafts survive a JSON round-trip
/// through the existing wire model.
public struct CollectionFolderDraft: Equatable, Hashable, Identifiable, Codable, Sendable {
    public let id: String
    public var title: String
    public var coverImageUrl: String?
    public var coverEmoji: String?
    public var tileShape: CollectionTileShape
    public var hideTitle: Bool
    public var items: [CollectionItemRef]
    public var sources: [CollectionSourceDraft]

    enum CodingKeys: String, CodingKey {
        case id, title, coverImageUrl, coverEmoji, tileShape, hideTitle, items, sources
    }

    public init(
        id: String = UUID().uuidString,
        title: String = "",
        coverImageUrl: String? = nil,
        coverEmoji: String? = nil,
        tileShape: CollectionTileShape = .poster,
        hideTitle: Bool = false,
        items: [CollectionItemRef] = [],
        sources: [CollectionSourceDraft] = []
    ) {
        self.id = id
        self.title = title
        self.coverImageUrl = coverImageUrl
        self.coverEmoji = coverEmoji
        self.tileShape = tileShape
        self.hideTitle = hideTitle
        self.items = items
        self.sources = sources
    }

    /// Fallback initials shown when no cover art exists (Android `FolderCard`).
    public var fallbackInitials: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return String(trimmed.prefix(2)).uppercased()
    }
}

/// A title placed inside a collection folder while editing.
public struct CollectionItemRef: Equatable, Hashable, Identifiable, Codable, Sendable {
    public let type: String
    public let id: String
    public let name: String
    public let poster: String?

    public init(type: String, id: String, name: String, poster: String? = nil) {
        self.type = type
        self.id = id
        self.name = name
        self.poster = poster
    }

    /// Mirrors the `"type:id"` key `CollectionStore` uses to de-duplicate items.
    public var key: String { "\(type):\(id)" }
}

/// Editable mirror of the synced `TVCollectionSource` payload. Coding keys
/// match the wire model so drafts round-trip through `TVCollection` decoding.
public struct CollectionSourceDraft: Equatable, Hashable, Codable, Sendable {
    public var provider: String
    public var addonId: String?
    public var type: String?
    public var catalogId: String?
    public var genre: String?
    public var title: String?
    public var tmdbSourceType: String?
    public var tmdbId: Int?
    public var traktListId: Int64?
    public var mediaType: String?
    public var sortBy: String?
    public var sortHow: String?

    public init(
        provider: String = "addon",
        addonId: String? = nil,
        type: String? = nil,
        catalogId: String? = nil,
        genre: String? = nil,
        title: String? = nil,
        tmdbSourceType: String? = nil,
        tmdbId: Int? = nil,
        traktListId: Int64? = nil,
        mediaType: String? = nil,
        sortBy: String? = nil,
        sortHow: String? = nil
    ) {
        self.provider = provider
        self.addonId = addonId
        self.type = type
        self.catalogId = catalogId
        self.genre = genre
        self.title = title
        self.tmdbSourceType = tmdbSourceType
        self.tmdbId = tmdbId
        self.traktListId = traktListId
        self.mediaType = mediaType
        self.sortBy = sortBy
        self.sortHow = sortHow
    }

    /// Stable identity used for duplicate detection and dirty tracking.
    public var fingerprint: String {
        [
            provider, addonId ?? "", type ?? "", catalogId ?? "",
            String(tmdbId ?? -1), String(traktListId ?? -1),
            mediaType ?? "", sortBy ?? "", sortHow ?? ""
        ].joined(separator: "|")
    }
}

// MARK: - Source providers

/// Remote list providers available inside the editor source picker.
public enum CollectionSourceProviderKind: String, CaseIterable, Codable, Hashable, Sendable {
    case addon
    case trakt
    case tmdb

    public var displayName: String {
        switch self {
        case .addon: return "Addon"
        case .trakt: return "Trakt"
        case .tmdb: return "TMDB"
        }
    }
}

/// One importable list (Trakt public list, TMDB list/company/network...).
public struct CollectionSourceOption: Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let kind: CollectionSourceProviderKind
    public let title: String
    public let subtitle: String?
    public let coverImageUrl: String?
    public let source: CollectionSourceDraft

    public init(
        id: String,
        kind: CollectionSourceProviderKind,
        title: String,
        subtitle: String? = nil,
        coverImageUrl: String? = nil,
        source: CollectionSourceDraft
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.coverImageUrl = coverImageUrl
        self.source = source
    }

    /// Ported from Android `CollectionEditorViewModel.tmdbPresets()`.
    public static let tmdbPresets: [CollectionSourceOption] = [
        preset("Marvel Studios", sourceType: "company", tmdbId: 420, mediaType: "movie"),
        preset("Walt Disney Pictures", sourceType: "company", tmdbId: 2, mediaType: "movie"),
        preset("Pixar", sourceType: "company", tmdbId: 3, mediaType: "movie"),
        preset("Lucasfilm", sourceType: "company", tmdbId: 1, mediaType: "movie"),
        preset("Warner Bros.", sourceType: "company", tmdbId: 174, mediaType: "movie"),
        preset("Netflix", sourceType: "network", tmdbId: 213, mediaType: "tv"),
        preset("HBO", sourceType: "network", tmdbId: 49, mediaType: "tv"),
        preset("Disney+", sourceType: "network", tmdbId: 2739, mediaType: "tv"),
        preset("Prime Video", sourceType: "network", tmdbId: 1024, mediaType: "tv"),
        preset("Hulu", sourceType: "network", tmdbId: 453, mediaType: "tv"),
        preset("Apple TV+", sourceType: "network", tmdbId: 2552, mediaType: "tv")
    ]

    private static func preset(
        _ title: String,
        sourceType: String,
        tmdbId: Int,
        mediaType: String
    ) -> CollectionSourceOption {
        CollectionSourceOption(
            id: "tmdb:\(sourceType):\(tmdbId):\(mediaType)",
            kind: .tmdb,
            title: title,
            subtitle: sourceType == "company" ? "Production company" : "Network",
            source: CollectionSourceDraft(
                provider: "tmdb",
                title: title,
                tmdbSourceType: sourceType,
                tmdbId: tmdbId,
                mediaType: mediaType,
                sortBy: "popularity.desc"
            )
        )
    }
}

/// Selection state for the Trakt/TMDB source picker section of the editor.
public struct CollectionSourcePickerState: Equatable, Sendable {
    public var options: [CollectionSourceOption]
    public var selectedOptionID: String?
    public var activeProvider: CollectionSourceProviderKind?
    public var importError: String?

    public init(
        options: [CollectionSourceOption] = [],
        selectedOptionID: String? = nil,
        activeProvider: CollectionSourceProviderKind? = nil,
        importError: String? = nil
    ) {
        self.options = options
        self.selectedOptionID = selectedOptionID
        self.activeProvider = activeProvider
        self.importError = importError
    }

    public var hasSelection: Bool { selectedOptionID != nil }

    public func isSelected(_ optionID: String) -> Bool {
        selectedOptionID == optionID
    }

    public func selectedOption() -> CollectionSourceOption? {
        options.first { $0.id == selectedOptionID }
    }

    public func options(for kind: CollectionSourceProviderKind) -> [CollectionSourceOption] {
        options.filter { $0.kind == kind }
    }

    public mutating func select(_ optionID: String?) {
        selectedOptionID = optionID
        if let optionID,
           let option = options.first(where: { $0.id == optionID }) {
            activeProvider = option.kind
        }
    }

    public mutating func setActiveProvider(_ kind: CollectionSourceProviderKind?) {
        activeProvider = kind
        if let kind, selectedOption()?.kind != kind {
            selectedOptionID = options(for: kind).first?.id
        }
    }

    public mutating func recordImportFailure(_ message: String?) {
        importError = message
    }
}

// MARK: - Edit tracking

/// The kinds of edits the editor can hold. Divergent kinds are derived by
/// diffing the working state against its save baseline, so reverting an edit
/// clears it again.
public enum CollectionEditKind: Hashable, Sendable {
    case renameCollection
    case backdropChanged
    case pinToTopChanged
    case renameFolder(String)
    case folderSettings(String)
    case addFolder(String)
    case removeFolder(String)
    case reorderFolders
    case addItem(folderID: String, itemKey: String)
    case removeItem(folderID: String, itemKey: String)
    case moveItem(itemKey: String, fromFolderID: String, toFolderID: String)
    case importSource(folderID: String, fingerprint: String)
    case removeSource(folderID: String, fingerprint: String)
}

// MARK: - Validation

/// Validation issues surfaced by `CollectionEditorState.validate()`.
public enum CollectionValidationIssue: Equatable, Sendable {
    case collectionTitleEmpty
    case collectionTitleTooLong(limit: Int)
    case collectionNeedsFolders
    case folderNameEmpty(folderID: String)
    case folderNameTooLong(folderID: String, limit: Int)

    public var isBlocking: Bool { true }
}
