import Foundation

/// Android parity: `DiscoverGridAction` in `SearchDiscoverSection.kt`.
public enum DiscoverLoadAction: Equatable, Sendable {
    case none
    case showMore
    case loadMore
    case loading
}

/// Android parity: the `when` block at the bottom of `DiscoverSection`.
public enum DiscoverPhase: Equatable, Sendable {
    case loading
    case content
    /// `discover_empty_no_catalog_*`
    case emptyNoCatalog
    /// `discover_empty_no_content_*`
    case emptyNoContent

    public static let emptyNoCatalogTitle = "Select a catalog"
    public static let emptyNoCatalogSubtitle = "Choose a discover catalog to browse"
    public static let emptyNoContentTitle = "No content found"
    public static let emptyNoContentSubtitle = "Try a different genre or catalog"
}

public enum DiscoverStrings {
    public static let title = "Discover"
    public static let filterType = "Type"
    public static let filterCatalog = "Catalog"
    public static let filterGenre = "Genre"
    public static let selectCatalog = "Select"
    public static let genreDefault = "Default"
    public static let loadMore = "Load more"
    public static let loading = "Loading..."
    public static let showMore = "Show more"
}

/// One selectable option of a Discover filter (type, catalog, genre).
public struct DiscoverFilterOption: Identifiable, Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var id: String { value }
}

/// Section-model input for `DiscoverParityView`: the composition of Android
/// `SearchDiscoverSection.kt` (header, Type/Catalog/Genre filters, metadata
/// line, poster grid, load-more action) as pure data.
public struct DiscoverPresentation: Equatable, Sendable {
    public let title: String
    public let typeOptions: [DiscoverFilterOption]
    public let catalogOptions: [DiscoverFilterOption]
    public let genreOptions: [DiscoverFilterOption]
    public let selectedTypeValue: String?
    public let selectedCatalogValue: String?
    public let selectedGenreValue: String?
    /// `addonName • Type • Genre` metadata line under the filters.
    public let metadataLine: String
    public let items: [SearchPosterItem]
    public let action: DiscoverLoadAction
    public let phase: DiscoverPhase

    public init(
        title: String = DiscoverStrings.title,
        typeOptions: [DiscoverFilterOption],
        catalogOptions: [DiscoverFilterOption],
        genreOptions: [DiscoverFilterOption],
        selectedTypeValue: String?,
        selectedCatalogValue: String?,
        selectedGenreValue: String?,
        metadataLine: String,
        items: [SearchPosterItem],
        action: DiscoverLoadAction,
        phase: DiscoverPhase
    ) {
        self.title = title
        self.typeOptions = typeOptions
        self.catalogOptions = catalogOptions
        self.genreOptions = genreOptions
        self.selectedTypeValue = selectedTypeValue
        self.selectedCatalogValue = selectedCatalogValue
        self.selectedGenreValue = selectedGenreValue
        self.metadataLine = metadataLine
        self.items = items
        self.action = action
        self.phase = phase
    }

    /// Maps the existing `DiscoveryStore` state onto the parity composition.
    /// Internal because it consumes in-module `CatalogDescriptor`/
    /// `MetaSummary` values. `selectedType` mirrors the Android default
    /// `selectedDiscoverType = "movie"`.
    static func build(
        descriptors: [CatalogDescriptor],
        selectedType: String?,
        selectedCatalogID: String?,
        selectedGenre: String?,
        items: [MetaSummary],
        pendingItemsCount: Int = 0,
        canLoadMore: Bool,
        isLoadingMore: Bool,
        isInitialLoad: Bool,
        showTypeSuffix: Bool = true
    ) -> DiscoverPresentation {
        let availableTypes = descriptors.map(\.type).uniqued()
        let resolvedType = selectedType.flatMap { availableTypes.contains($0) ? $0 : nil }
            ?? availableTypes.first
            ?? "movie"
        let catalogsForType = descriptors.filter { $0.type == resolvedType }
        let selectedCatalog = catalogsForType.first(where: { $0.id == selectedCatalogID })
            ?? catalogsForType.first

        let typeOptions = availableTypes.map { type in
            DiscoverFilterOption(label: type.capitalized, value: type)
        }
        let catalogOptions = catalogsForType.map { catalog in
            DiscoverFilterOption(label: catalog.displayTitle, value: catalog.id)
        }
        var genreOptions = [DiscoverFilterOption(
            label: DiscoverStrings.genreDefault,
            value: "__default__"
        )]
        genreOptions.append(
            contentsOf: (selectedCatalog?.genres ?? []).map { genre in
                DiscoverFilterOption(label: genre, value: genre)
            }
        )

        // Android DiscoverSection metadata segments: addon, type suffix, genre.
        var segments: [String] = []
        if let addonName = selectedCatalog?.addonName.trimmedNonEmpty {
            segments.append(addonName)
        }
        if showTypeSuffix {
            let typeLabel = resolvedType.capitalized
            if !typeLabel.isEmpty { segments.append(typeLabel) }
        }
        if let genre = selectedGenre?.trimmedNonEmpty {
            segments.append(genre)
        }

        // Android DiscoverGrid action selection.
        let action: DiscoverLoadAction
        if pendingItemsCount > 0 {
            action = .showMore
        } else if isLoadingMore {
            action = .loading
        } else if canLoadMore {
            action = .loadMore
        } else {
            action = .none
        }

        // Android DiscoverSection state order: loading with no results,
        // results, no catalog, no content.
        let phase: DiscoverPhase
        if isInitialLoad && items.isEmpty {
            phase = .loading
        } else if items.isNotEmpty {
            phase = .content
        } else if selectedCatalog == nil {
            phase = .emptyNoCatalog
        } else {
            phase = .emptyNoContent
        }

        return DiscoverPresentation(
            typeOptions: typeOptions,
            catalogOptions: catalogOptions,
            genreOptions: genreOptions,
            selectedTypeValue: resolvedType,
            selectedCatalogValue: selectedCatalog?.id,
            selectedGenreValue: selectedGenre,
            metadataLine: segments.joined(separator: " • "),
            items: items.map(SearchPosterItem.init(summary:)),
            action: action,
            phase: phase
        )
    }
}

private extension Collection {
    var isNotEmpty: Bool { !isEmpty }
}
