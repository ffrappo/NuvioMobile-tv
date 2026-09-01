import Foundation

/// Sort options for the source list, mirroring the Android
/// `DebridSortProfile` values exposed in `DebridSettingsScreen.kt`
/// (Original, Best quality, Largest, Smallest, Best audio, Language).
public enum StreamSortOption: String, CaseIterable, Sendable, Hashable {
    case original
    case bestQuality
    case largest
    case smallest
    case bestAudio
    case language

    public var displayName: String {
        switch self {
        case .original: "Original order"
        case .bestQuality: "Best quality first"
        case .largest: "Largest first"
        case .smallest: "Smallest first"
        case .bestAudio: "Best audio first"
        case .language: "Language first"
        }
    }
}

/// Addon chip status, mirroring Android `SourceChipStatus`.
public enum StreamAddonStatus: Sendable, Hashable {
    case loading
    case success
    case failure
}

/// One addon filter chip in the panel header row.
/// A `nil` name represents the "All" filter.
public struct StreamAddonFilterChip: Equatable, Sendable, Identifiable {
    public let name: String?
    public let count: Int
    public let status: StreamAddonStatus
    public let isSelected: Bool
    public let isSelectable: Bool

    public init(
        name: String?,
        count: Int,
        status: StreamAddonStatus = .success,
        isSelected: Bool,
        isSelectable: Bool = true
    ) {
        self.name = name
        self.count = count
        self.status = status
        self.isSelected = isSelected
        self.isSelectable = isSelectable
    }

    public var id: String { name ?? "__all__" }
    public var displayName: String { name ?? "All" }
}

/// Badge kinds shown on a stream row, in display order.
public enum StreamPanelBadgeKind: Sendable, Hashable, Comparable {
    case quality
    case size
    case seeds
    case codec
    case hdr
    case audio
    case language

    var order: Int {
        switch self {
        case .quality: 0
        case .size: 1
        case .seeds: 2
        case .codec: 3
        case .hdr: 4
        case .audio: 5
        case .language: 6
        }
    }

    public static func < (lhs: StreamPanelBadgeKind, rhs: StreamPanelBadgeKind) -> Bool {
        lhs.order < rhs.order
    }
}

/// A single badge chip model rendered on a stream row.
public struct StreamPanelBadge: Equatable, Sendable, Identifiable {
    public let kind: StreamPanelBadgeKind
    public let text: String

    public init(kind: StreamPanelBadgeKind, text: String) {
        self.kind = kind
        self.text = text
    }

    public var id: String { "\(kind):\(text)" }

    /// HDR/DV badges use the accent tint to stand out, as on Android.
    public var isProminent: Bool { kind == .hdr }
}

/// Reference to the stream that is currently playing, mirroring the
/// Android `currentStream*` matching inputs of `findCurrentStreamIndex`.
public struct StreamPlayingReference: Equatable, Sendable {
    public var url: String?
    public var addonName: String?
    public var streamName: String?

    public init(url: String? = nil, addonName: String? = nil, streamName: String? = nil) {
        self.url = url
        self.addonName = addonName
        self.streamName = streamName
    }
}

/// Playback capability filter inputs for the presentation.
struct StreamPanelPlaybackFilter: Equatable, Sendable {
    var capabilities: TVPlaybackCapabilities
    /// When true, rows the device cannot play are dropped instead of dimmed.
    var omitUnplayable: Bool

    init(
        capabilities: TVPlaybackCapabilities = .current,
        omitUnplayable: Bool = false
    ) {
        self.capabilities = capabilities
        self.omitUnplayable = omitUnplayable
    }
}

/// One filtered, sorted stream row ready for rendering.
struct StreamPanelRow: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let subtitle: String?
    public let badges: [StreamPanelBadge]
    public let addonName: String
    public let addonLogoURL: String?
    public let filename: String?
    public let isPlaying: Bool
    public let isPlayable: Bool
    public let compatibilityIssue: String?
    public let source: StreamSource

    public init(
        id: UUID,
        title: String,
        subtitle: String?,
        badges: [StreamPanelBadge],
        addonName: String,
        addonLogoURL: String?,
        filename: String?,
        isPlaying: Bool,
        isPlayable: Bool,
        compatibilityIssue: String?,
        source: StreamSource
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.badges = badges
        self.addonName = addonName
        self.addonLogoURL = addonLogoURL
        self.filename = filename
        self.isPlaying = isPlaying
        self.isPlayable = isPlayable
        self.compatibilityIssue = compatibilityIssue
        self.source = source
    }
}

/// Focus-restoration anchor: the index into `StreamPanelSnapshot.rows`
/// that should receive initial focus when the panel appears.
public struct StreamPanelFocusAnchor: Equatable, Sendable {
    public let rowIndex: Int?

    public init(rowIndex: Int?) {
        self.rowIndex = rowIndex
    }

    public var hasRows: Bool { rowIndex != nil }
}

/// Which body the panel should render.
public enum StreamPanelContentState: Equatable, Sendable {
    case loading
    case failure([String])
    case empty
    case content
}

/// Input model for `StreamPanelPresentation.snapshot`.
struct StreamPanelInput: Equatable, Sendable {
    var sources: [StreamSource]
    var failures: [String]
    var isLoading: Bool
    var selectedAddon: String?
    var sortOption: StreamSortOption
    var playing: StreamPlayingReference?
    var playbackFilter: StreamPanelPlaybackFilter
    var preferredLanguages: [String]
    /// Per-addon chip status for addons that are still loading or failed.
    var addonStatuses: [String: StreamAddonStatus]
    var showFileSizeBadges: Bool

    init(
        sources: [StreamSource],
        failures: [String] = [],
        isLoading: Bool = false,
        selectedAddon: String? = nil,
        sortOption: StreamSortOption = .original,
        playing: StreamPlayingReference? = nil,
        playbackFilter: StreamPanelPlaybackFilter = StreamPanelPlaybackFilter(),
        preferredLanguages: [String] = [],
        addonStatuses: [String: StreamAddonStatus] = [:],
        showFileSizeBadges: Bool = true
    ) {
        self.sources = sources
        self.failures = failures
        self.isLoading = isLoading
        self.selectedAddon = selectedAddon
        self.sortOption = sortOption
        self.playing = playing
        self.playbackFilter = playbackFilter
        self.preferredLanguages = preferredLanguages
        self.addonStatuses = addonStatuses
        self.showFileSizeBadges = showFileSizeBadges
    }
}

/// Fully derived, renderable state of the source selection panel.
struct StreamPanelSnapshot: Equatable, Sendable {
    public let rows: [StreamPanelRow]
    public let chips: [StreamAddonFilterChip]
    public let sortOptions: [StreamSortOption]
    public let selectedSortOption: StreamSortOption
    public let playingIndex: Int?
    public let focusAnchor: StreamPanelFocusAnchor
    public let totalStreamCount: Int
    public let playableCount: Int
    public let limitedCount: Int
    public let isLoading: Bool
    public let failures: [String]
    public let contentState: StreamPanelContentState
    public let headerCountLabel: String

    init(
        rows: [StreamPanelRow],
        chips: [StreamAddonFilterChip],
        sortOptions: [StreamSortOption],
        selectedSortOption: StreamSortOption,
        playingIndex: Int?,
        focusAnchor: StreamPanelFocusAnchor,
        totalStreamCount: Int,
        playableCount: Int,
        limitedCount: Int,
        isLoading: Bool,
        failures: [String],
        contentState: StreamPanelContentState,
        headerCountLabel: String
    ) {
        self.rows = rows
        self.chips = chips
        self.sortOptions = sortOptions
        self.selectedSortOption = selectedSortOption
        self.playingIndex = playingIndex
        self.focusAnchor = focusAnchor
        self.totalStreamCount = totalStreamCount
        self.playableCount = playableCount
        self.limitedCount = limitedCount
        self.isLoading = isLoading
        self.failures = failures
        self.contentState = contentState
        self.headerCountLabel = headerCountLabel
    }

    public var focusAnchorRowID: UUID? {
        guard let index = focusAnchor.rowIndex, rows.indices.contains(index) else { return nil }
        return rows[index].id
    }
}
