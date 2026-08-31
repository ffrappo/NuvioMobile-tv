import Foundation
import SwiftUI

/// Modern Home aliases shared design tokens and keeps only two screen-specific values.
public enum ModernHomeRowTokens {
    public static let canvasBlack = NuvioDesignTokens.Colors.canvasBlack
    public static let canvasRaised = NuvioDesignTokens.Colors.canvas
    public static let elevated = NuvioDesignTokens.Colors.elevated
    public static let elevatedRaised = NuvioDesignTokens.Colors.elevatedSecondary
    public static let secondaryText = NuvioDesignTokens.Colors.secondaryText

    public static let posterWidth = NuvioDesignTokens.Sizes.Cards.poster.width
    public static let posterHeight = NuvioDesignTokens.Sizes.Cards.poster.height
    public static let posterCornerRadius = NuvioDesignTokens.Shapes.posterRadius
    public static let backdropWidth = NuvioDesignTokens.Sizes.Cards.backdrop.width
    public static let backdropHeight = NuvioDesignTokens.Sizes.Cards.backdrop.height
    public static let backdropCornerRadius = NuvioDesignTokens.Shapes.backdropRadius
    public static let episodeWidth = NuvioDesignTokens.Sizes.Cards.episodeThumbnail.width
    public static let episodeHeight = NuvioDesignTokens.Sizes.Cards.episodeThumbnail.height
    public static let sidePanelCornerRadius = NuvioDesignTokens.Shapes.sidePanelRadius
    public static let settingsContainerCornerRadius = NuvioDesignTokens.Shapes.settingsContainerRadius

    public static let screenHorizontalMargin = NuvioDesignTokens.Layout.safeHorizontal
    public static let screenVerticalMargin = NuvioDesignTokens.Layout.safeVertical
    // ModernHomeRows.kt uses 52dp for this specific rail instead of the 48dp base token.
    public static let railLeadingMargin: CGFloat = 52
    public static let homeForegroundLeadingMargin =
        NuvioDesignTokens.Layout.nativeSidebarForegroundInset
    public static let itemGap = NuvioDesignTokens.Spacing.Rail.itemGap
    public static let rowGap = NuvioDesignTokens.Spacing.Rail.rowGap
    public static let progressHeight: CGFloat = 3
    public static let focusRingWidth = NuvioDesignTokens.Focus.ringWidth

    public static let focusScale = NuvioDesignTokens.Focus.scale
    public static let pressedScale = NuvioDesignTokens.Focus.pressedScale
    public static let focusTransition = NuvioMotion.focusTransition
    public static let contentTransition = NuvioMotion.contentTransition
    public static let heroTransition = NuvioMotion.heroTransition
    public static let shimmerCycle = NuvioMotion.shimmerCycle
    public static let softBlur = NuvioDesignTokens.Blur.soft
    public static let panelBlur = NuvioDesignTokens.Blur.panel
    public static let strongBlur = NuvioDesignTokens.Blur.strong

    public static let display = TypographyMetric(style: .display)
    public static let compactDisplay = TypographyMetric(style: .compactDisplay)
    public static let headline = TypographyMetric(style: .headline)
    public static let sectionTitle = TypographyMetric(style: .sectionTitle)
    public static let body = TypographyMetric(style: .body)
    public static let cardTitle = TypographyMetric(style: .cardTitle)
    public static let compactBody = TypographyMetric(style: .compactBody)
    public static let metadata = TypographyMetric(style: .metadata)
}

public struct TypographyMetric: Equatable, Sendable {
    public let pointSize: CGFloat
    public let lineHeight: CGFloat

    public init(style: NuvioTypographyStyle) {
        pointSize = style.pointSize
        lineHeight = style.lineHeight
    }

    public var lineSpacing: CGFloat { max(0, lineHeight - pointSize) }
}

public enum PosterArtworkSource: Equatable, Sendable {
    case url(URL)
    case loading
    case placeholder(systemName: String)
}

public typealias PosterArtworkProvider = (
    _ source: PosterArtworkSource,
    _ pixelSize: CGSize,
    _ cornerRadius: CGFloat
) -> AnyView

public enum PosterBadge: Equatable, Sendable {
    case watched
    case inLibrary
    case unwatchedNew
}

public struct PosterCardStatus: Equatable, Sendable {
    public var isWatched: Bool
    public var isInLibrary: Bool
    public var isUnwatchedNew: Bool
    public var progressFraction: Double?

    public init(
        isWatched: Bool = false,
        isInLibrary: Bool = false,
        isUnwatchedNew: Bool = false,
        progressFraction: Double? = nil
    ) {
        self.isWatched = isWatched
        self.isInLibrary = isInLibrary
        self.isUnwatchedNew = isUnwatchedNew
        self.progressFraction = progressFraction
    }

    public var visibleBadges: [PosterBadge] {
        var badges: [PosterBadge] = []
        if isWatched { badges.append(.watched) }
        if isInLibrary { badges.append(.inLibrary) }
        if isUnwatchedNew && !isWatched { badges.append(.unwatchedNew) }
        return badges
    }

    public var showsProgress: Bool { progressFraction != nil }

    public var clampedProgress: Double {
        min(max(progressFraction ?? 0, 0), 1)
    }
}

public struct RailItem: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var year: String?
    public var overview: String?
    public var metadata: [String]
    public var posterArtwork: PosterArtworkSource
    public var backdropArtwork: PosterArtworkSource
    public var status: PosterCardStatus

    public init(
        id: String,
        title: String,
        year: String? = nil,
        overview: String? = nil,
        metadata: [String] = [],
        posterArtwork: PosterArtworkSource,
        backdropArtwork: PosterArtworkSource? = nil,
        status: PosterCardStatus = PosterCardStatus()
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.overview = overview
        self.metadata = metadata
        self.posterArtwork = posterArtwork
        self.backdropArtwork = backdropArtwork ?? posterArtwork
        self.status = status
    }
}

public struct RailSection: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var items: [RailItem]
    public var hasMore: Bool
    public var isLoading: Bool

    public init(
        id: String,
        title: String,
        items: [RailItem],
        hasMore: Bool = false,
        isLoading: Bool = false
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.hasMore = hasMore
        self.isLoading = isLoading
    }
}

public struct RailFocusID: Hashable, Sendable {
    public let sectionID: String
    public let itemID: String

    public init(sectionID: String, itemID: String) {
        self.sectionID = sectionID
        self.itemID = itemID
    }
}

public final class RailFocusModel: ObservableObject {
    @Published public private(set) var expandedItem: RailFocusID?

    public init(expandedItem: RailFocusID? = nil) {
        self.expandedItem = expandedItem
    }

    public func focus(_ item: RailFocusID) {
        guard expandedItem != item else { return }
        expandedItem = item
    }

    public func blur(_ item: RailFocusID) {
        guard expandedItem == item else { return }
        expandedItem = nil
    }

    public func collapseAll() {
        expandedItem = nil
    }

    public func isExpanded(_ item: RailFocusID) -> Bool {
        expandedItem == item
    }
}

public final class RailPrefetchTrigger: ObservableObject {
    public static let trailingThreshold = 4

    private var lastRequestedItemCount: Int?
    private var onPrefetch: () -> Void

    public init(onPrefetch: @escaping () -> Void) {
        self.onPrefetch = onPrefetch
    }

    public static func isNearTrailingEdge(
        index: Int,
        itemCount: Int,
        threshold: Int = trailingThreshold
    ) -> Bool {
        guard index >= 0, itemCount > 0, threshold > 0 else { return false }
        return index >= max(0, itemCount - threshold)
    }

    public func observe(
        index: Int,
        itemCount: Int,
        hasMore: Bool,
        isLoading: Bool
    ) {
        let isNearEnd = Self.isNearTrailingEdge(index: index, itemCount: itemCount)
        if !isNearEnd {
            lastRequestedItemCount = nil
            return
        }
        guard hasMore, !isLoading, lastRequestedItemCount != itemCount else { return }
        lastRequestedItemCount = itemCount
        onPrefetch()
    }

    public func updateAction(_ action: @escaping () -> Void) {
        onPrefetch = action
    }

    public func reset() {
        lastRequestedItemCount = nil
    }
}
