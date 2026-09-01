import SwiftUI

/// Native port of ClassicHomeContent.kt: a full-screen immersive hero
/// backdrop that fades out over the first 180pt of scroll, the focused-item
/// color gradient backdrop behind the catalog rows, and the classic-sized
/// rails (catalog posters at 1.35x, secondary rows at 1.2x).
struct ClassicHomeView: View {
    let presentation: ClassicHomePresentation
    let message: String?
    let isOffline: Bool
    let onSelect: (MetaSummary) -> Void
    let onOpenCatalog: (HomeCatalogSection) -> Void
    let onOpenCollection: (TVCollection) -> Void
    let onPrefetchCatalog: (String) -> Void

    @State private var activeHero: HeroItem?
    @State private var focusedArtwork: ClassicFocusArtwork?
    @State private var immersiveAlpha: CGFloat = 1
    @State private var isScrolling = false
    @State private var scrollActivityTick = 0

    init(
        presentation: ClassicHomePresentation,
        message: String? = nil,
        isOffline: Bool = false,
        onSelect: @escaping (MetaSummary) -> Void,
        onOpenCatalog: @escaping (HomeCatalogSection) -> Void,
        onOpenCollection: @escaping (TVCollection) -> Void,
        onPrefetchCatalog: @escaping (String) -> Void = { _ in }
    ) {
        self.presentation = presentation
        self.message = message
        self.isOffline = isOffline
        self.onSelect = onSelect
        self.onOpenCatalog = onOpenCatalog
        self.onOpenCollection = onOpenCollection
        self.onPrefetchCatalog = onPrefetchCatalog
    }

    var body: some View {
        ZStack(alignment: .top) {
            immersiveBackdrop
            ClassicFocusGradientBackdrop(
                artwork: focusedArtwork,
                isVisible: ClassicFocusGradient.isBackdropVisible(
                    immersiveAlpha: immersiveAlpha
                ),
                updatesPaused: isScrolling
            )
            column
            if let message {
                statusBanner(message)
            }
        }
        .background(NuvioDesignTokens.Colors.canvasBlack.ignoresSafeArea())
    }

    /// HeroCarouselBackdrop: the active hero's full-page backdrop, drawn
    /// while the immersive alpha is above zero and covered by the canvas
    /// background color as the first row scrolls away.
    @ViewBuilder
    private var immersiveBackdrop: some View {
        if let backdrop = activeHero?.backdropURL ?? presentation.heroes.first?.backdropURL {
            NuvioArtworkView(
                urlString: backdrop,
                mode: .backdrop,
                pixelSize: CGSize(width: 1920, height: 1080),
                cornerRadius: 0,
                fadeDuration: NuvioMotion.overlayTransition
            )
            .ignoresSafeArea()
            .opacity(immersiveAlpha)
            .animation(nil, value: immersiveAlpha)
            .accessibilityHidden(true)
        }
    }

    private var column: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ClassicHomeScale.rowSpacing) {
                if !presentation.heroes.isEmpty {
                    HomeModeHeroBand(
                        pages: presentation.heroes,
                        height: ClassicHomeScale.heroBandHeight,
                        showsBackdrop: false,
                        onSelect: { hero in
                            if let summary = presentation.summary(for: hero) {
                                onSelect(summary)
                            }
                        },
                        onActiveItemChanged: { activeHero = $0 }
                    )
                }
                ForEach(presentation.rows) { row in
                    rowView(row)
                }
            }
            .padding(
                .top,
                presentation.heroes.isEmpty ? NuvioDesignTokens.Spacing.xl : 0
            )
            .padding(.bottom, 100)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(0, geometry.contentOffset.y + geometry.contentInsets.top)
        } action: { _, offset in
            immersiveAlpha = 1 - min(
                max(offset / ClassicHomeScale.immersiveFadeDistance, 0),
                1
            )
            scrollActivityTick += 1
        }
        .task(id: scrollActivityTick) {
            isScrolling = true
            try? await Task.sleep(for: .milliseconds(240))
            if !Task.isCancelled { isScrolling = false }
        }
    }

    @ViewBuilder
    private func rowView(_ row: ClassicHomeRow) -> some View {
        switch row {
        case .continueWatching(let cards):
            sectionTitle("Continue Watching")
            ClassicProgressRail(items: cards, onSelect: selectProgress) {
                focusedArtwork = $0.map { ClassicFocusArtwork(card: $0, prefersBackdrop: true) }
            }
        case .upcoming(let cards):
            sectionTitle("Upcoming")
            ClassicProgressRail(items: cards, onSelect: selectProgress) { _ in }
        case .collection(let collection):
            CatalogCollectionRail(collection: collection) {
                onOpenCollection(collection)
            }
        case .catalog(let section):
            ClassicRailRow(
                section: section,
                posterSize: ClassicHomeScale.catalogPosterSize,
                onSelect: select,
                onFocus: { item in
                    focusedArtwork = item
                        .flatMap(presentation.summary(for:))
                        .map { ClassicFocusArtwork(summary: $0, prefersBackdrop: true) }
                },
                onOpen: {
                    if let section = presentation.sectionsByID[section.id] {
                        onOpenCatalog(section)
                    }
                },
                onPrefetch: onPrefetchCatalog
            )
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .nuvioTextStyle(.sectionTitle)
            .padding(.leading, NuvioDesignTokens.Layout.nativeSidebarForegroundInset)
            .padding(.trailing, NuvioDesignTokens.Layout.safeHorizontal)
    }

    private func selectProgress(_ item: ContinueWatchingCard) {
        onSelect(
            item.summary.routedTo(
                videoID: item.videoID,
                season: item.season,
                episode: item.episode
            )
        )
    }

    private func select(_ item: RailItem) {
        guard let summary = presentation.summary(for: item) else { return }
        onSelect(summary)
    }

    private func statusBanner(_ message: String) -> some View {
        Label(
            message.tvSafe,
            systemImage: isOffline ? "wifi.slash" : "exclamationmark.triangle.fill"
        )
        .nuvioTextStyle(.button)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .nuvioAdaptiveSurface(Capsule(), material: .ultraThinMaterial)
        .padding(.top, 30)
        .padding(.leading, NuvioDesignTokens.Layout.nativeSidebarForegroundInset)
        .padding(.trailing, NuvioDesignTokens.Layout.safeHorizontal)
    }
}

/// Classic catalog rail: 1.35x posters with a See All header action and
/// trailing-edge catalog prefetch.
struct ClassicRailRow: View {
    let section: RailSection
    let posterSize: CGSize
    let onSelect: (RailItem) -> Void
    let onFocus: (RailItem?) -> Void
    let onOpen: (() -> Void)?
    let onPrefetch: (String) -> Void

    @StateObject private var prefetchTrigger: RailPrefetchTrigger
    @FocusState private var focusedItemID: String?

    init(
        section: RailSection,
        posterSize: CGSize,
        onSelect: @escaping (RailItem) -> Void,
        onFocus: @escaping (RailItem?) -> Void,
        onOpen: (() -> Void)? = nil,
        onPrefetch: @escaping (String) -> Void
    ) {
        self.section = section
        self.posterSize = posterSize
        self.onSelect = onSelect
        self.onFocus = onFocus
        self.onOpen = onOpen
        self.onPrefetch = onPrefetch
        _prefetchTrigger = StateObject(
            wrappedValue: RailPrefetchTrigger { onPrefetch(section.id) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.Rail.rowGap) {
            HStack(alignment: .firstTextBaseline, spacing: NuvioDesignTokens.Spacing.md) {
                Text(section.title.tvSafe)
                    .nuvioTextStyle(.sectionTitle)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if let onOpen {
                    Button("See All", action: onOpen)
                        .buttonStyle(.bordered)
                }
            }
            .padding(.leading, NuvioDesignTokens.Layout.nativeSidebarForegroundInset)
            .padding(.trailing, NuvioDesignTokens.Layout.safeHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        HomeModePosterCard(item: item, size: posterSize) {
                            onSelect(item)
                        }
                        .focused($focusedItemID, equals: item.id)
                        .onAppear { observePrefetch(at: index) }
                    }
                }
                .padding(.leading, NuvioDesignTokens.Layout.nativeSidebarForegroundInset)
                .padding(.trailing, NuvioDesignTokens.Layout.safeHorizontal)
                .padding(.vertical, NuvioDesignTokens.Blur.soft)
            }
            .scrollClipDisabled()
        }
        .focusSection()
        .onChange(of: focusedItemID) { _, newID in
            if let newID,
               let item = section.items.first(where: { $0.id == newID }) {
                onFocus(item)
            }
        }
        .onDisappear { onFocus(nil) }
    }

    private func observePrefetch(at index: Int) {
        prefetchTrigger.observe(
            index: index,
            itemCount: section.items.count,
            hasMore: section.hasMore,
            isLoading: section.isLoading
        )
    }
}

/// Continue Watching / Upcoming rail with focus reporting so the gradient
/// backdrop can color from the focused episode.
struct ClassicProgressRail: View {
    let items: [ContinueWatchingCard]
    let onSelect: (ContinueWatchingCard) -> Void
    let onFocusChange: (ContinueWatchingCard?) -> Void

    @FocusState private var focusedID: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 26) {
                ForEach(items) { item in
                    ClassicProgressCard(item: item) { onSelect(item) }
                        .focused($focusedID, equals: item.id)
                }
            }
            .padding(.leading, NuvioDesignTokens.Layout.nativeSidebarForegroundInset)
            .padding(.trailing, NuvioDesignTokens.Layout.safeHorizontal)
            .padding(.vertical, 26)
        }
        .scrollClipDisabled()
        .onChange(of: focusedID) { _, newID in
            if let newID, let item = items.first(where: { $0.id == newID }) {
                onFocusChange(item)
            }
        }
        .onDisappear { onFocusChange(nil) }
    }
}

struct ClassicProgressCard: View {
    let item: ContinueWatchingCard
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: action) {
                ZStack(alignment: .bottomLeading) {
                    RemoteArtwork(
                        urlString: item.episodeThumbnail
                            ?? item.summary.background
                            ?? item.summary.poster,
                        systemPlaceholder: "play.rectangle.fill"
                    )
                    .frame(width: 370, height: 208)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    if !item.isUpcoming {
                        ProgressCardProgressBar(progress: item.progress)
                    }
                }
                .modifier(HomeModeFocusRing(cornerRadius: 16))
            }
            .buttonStyle(HomeModePosterButtonStyle())
            ProgressCardText(item: item)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.summary.name.tvSafe)
        .accessibilityHint("Opens details")
    }
}
