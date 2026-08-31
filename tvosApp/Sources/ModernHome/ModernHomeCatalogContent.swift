import SwiftUI

struct ModernHomeCatalogContent: View {
    let presentation: ModernHomePresentation
    let continueWatching: [ContinueWatchingCard]
    let upcoming: [ContinueWatchingCard]
    let collections: [TVCollection]
    let message: String?
    let isOffline: Bool
    let onSelect: (MetaSummary) -> Void
    let onOpenCatalog: (HomeCatalogSection) -> Void
    let onOpenCollection: (TVCollection) -> Void
    let onPrefetchCatalog: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var hero: HeroPresentation
    @StateObject private var focusModel = RailFocusModel()
    @State private var catalogFocusOwnsHero = false

    init(
        presentation: ModernHomePresentation,
        continueWatching: [ContinueWatchingCard],
        upcoming: [ContinueWatchingCard],
        collections: [TVCollection],
        message: String?,
        isOffline: Bool,
        onSelect: @escaping (MetaSummary) -> Void,
        onOpenCatalog: @escaping (HomeCatalogSection) -> Void,
        onOpenCollection: @escaping (TVCollection) -> Void,
        onPrefetchCatalog: @escaping (String) -> Void = { _ in }
    ) {
        self.presentation = presentation
        self.continueWatching = continueWatching
        self.upcoming = upcoming
        self.collections = collections
        self.message = message
        self.isOffline = isOffline
        self.onSelect = onSelect
        self.onOpenCatalog = onOpenCatalog
        self.onOpenCollection = onOpenCollection
        self.onPrefetchCatalog = onPrefetchCatalog
        _hero = StateObject(wrappedValue: HeroPresentation(pages: presentation.heroes))
    }

    var body: some View {
        GeometryReader { proxy in
            let rowsHeight = proxy.size.height * 0.52
            let rowsTop = proxy.size.height - rowsHeight
            let heroHeight = rowsTop + Self.heroRailOverlap
            // Android parity: the hero text block bottom sits one lg gap above
            // the rows top, measured from the full screen in ModernHomeContent.kt
            // (padding bottom = rowsViewportHeight + spacing.lg), which inside the
            // hero frame equals the rail overlap plus lg.
            let foregroundBottomInset = Self.heroRailOverlap + NuvioDesignTokens.Spacing.lg
            ZStack(alignment: .topLeading) {
                heroScene(foregroundBottomInset: foregroundBottomInset)
                    .frame(height: heroHeight)
                rows.frame(height: rowsHeight).offset(y: rowsTop)
                if let message {
                    statusBanner(message).padding(.top, 30)
                }
            }
        }
        .background(NuvioDesignTokens.Colors.canvasBlack)
        .onChange(of: presentation.heroes) { _, pages in
            hero.replacePages(pages)
        }
        .onAppear { resolveMotionAndFocus() }
        .onChange(of: reduceMotion) { _, _ in resolveMotionAndFocus() }
        .onChange(of: catalogFocusOwnsHero) { _, _ in resolveMotionAndFocus() }
    }

    /// Android parity: the hero frame extends this far below the rows top
    /// (rowTitleHeight + 14dp in ModernHomeContent.kt).
    static let heroRailOverlap: CGFloat = 56

    private func heroScene(foregroundBottomInset: CGFloat) -> some View {
        HeroSceneView(
            presentation: hero,
            actions: [
                HeroAction(id: "details", title: "Open Details", systemImage: "info.circle") {
                    selectedHero in
                    guard let summary = presentation.summary(for: selectedHero) else { return }
                    onSelect(summary)
                },
            ],
            foregroundBottomInset: foregroundBottomInset
        )
    }

    private var rows: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.Rail.rowGap) {
                personalRows
                ForEach(presentation.catalogRows) { row in
                    ModernRailRow(
                        section: row,
                        focusModel: focusModel,
                        artworkProvider: artwork,
                        onSelect: select,
                        onFocus: focus,
                        onOpen: {
                            guard let section = presentation.sectionsByID[row.id] else { return }
                            onOpenCatalog(section)
                        },
                        onPrefetch: onPrefetchCatalog
                    )
                }
            }
            .padding(.bottom, 100)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var personalRows: some View {
        if !continueWatching.isEmpty {
            personalTitle("Continue Watching")
            ProgressRail(items: continueWatching, onSelect: selectProgress)
        }
        if !upcoming.isEmpty {
            personalTitle("Upcoming")
            ProgressRail(items: upcoming, onSelect: selectProgress)
        }
        ForEach(collections) { collection in
            CatalogCollectionRail(collection: collection) {
                onOpenCollection(collection)
            }
        }
    }

    private func personalTitle(_ title: String) -> some View {
        Text(title)
            .nuvioTextStyle(.sectionTitle)
            .padding(.leading, NuvioDesignTokens.Layout.nativeSidebarForegroundInset)
            .padding(.trailing, NuvioDesignTokens.Layout.safeHorizontal)
    }

    private func selectProgress(_ item: ContinueWatchingCard) {
        onSelect(item.summary.routedTo(
            videoID: item.videoID,
            season: item.season,
            episode: item.episode
        ))
    }

    private func select(_ item: RailItem) {
        guard let summary = presentation.summary(for: item) else { return }
        onSelect(summary)
    }

    private func focus(_ item: RailItem) {
        catalogFocusOwnsHero = true
        // Android parity: the hero previews the focused rail item directly,
        // including items outside the bounded rotating page set.
        hero.displayOverride(presentation.heroPage(for: item))
    }

    private func resolveMotionAndFocus() {
        hero.setReduceMotion(reduceMotion)
        hero.setActionFocused(catalogFocusOwnsHero)
    }

    private func statusBanner(_ message: String) -> some View {
        Label(message.tvSafe, systemImage: isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
            .nuvioTextStyle(.button)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .nuvioAdaptiveSurface(Capsule(), material: .ultraThinMaterial)
            .padding(.leading, NuvioDesignTokens.Layout.nativeSidebarForegroundInset)
            .padding(.trailing, NuvioDesignTokens.Layout.safeHorizontal)
    }

    private func artwork(
        _ source: PosterArtworkSource,
        pixelSize: CGSize,
        cornerRadius: CGFloat
    ) -> AnyView {
        switch source {
        case .url(let url):
            return AnyView(NuvioArtworkView(
                url: url,
                mode: pixelSize.width > 200 ? .backdrop : .poster,
                pixelSize: pixelSize,
                cornerRadius: cornerRadius
            ))
        case .loading:
            return AnyView(NuvioShimmerShape(size: pixelSize, cornerRadius: cornerRadius))
        case .placeholder(let systemName):
            return AnyView(NuvioArtworkView(
                url: nil,
                mode: pixelSize.width > 200 ? .backdrop : .poster,
                pixelSize: pixelSize,
                cornerRadius: cornerRadius,
                placeholderSystemImage: systemName
            ))
        }
    }
}
