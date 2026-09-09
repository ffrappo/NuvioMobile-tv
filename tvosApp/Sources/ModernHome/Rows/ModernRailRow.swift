import SwiftUI

public struct ModernRailRow: View {
    public let section: RailSection
    public let artworkProvider: PosterArtworkProvider
    public let onSelect: (RailItem) -> Void
    public let onFocus: (RailItem) -> Void
    public let onOpen: (() -> Void)?
    public let onPrefetch: (String) -> Void

    @StateObject private var prefetchTrigger: RailPrefetchTrigger
    @FocusState private var focusedItemID: String?

    public init(
        section: RailSection,
        artworkProvider: @escaping PosterArtworkProvider,
        onSelect: @escaping (RailItem) -> Void,
        onFocus: @escaping (RailItem) -> Void = { _ in },
        onOpen: (() -> Void)? = nil,
        onPrefetch: @escaping (String) -> Void = { _ in }
    ) {
        self.section = section
        self.artworkProvider = artworkProvider
        self.onSelect = onSelect
        self.onFocus = onFocus
        self.onOpen = onOpen
        self.onPrefetch = onPrefetch
        _prefetchTrigger = StateObject(
            wrappedValue: RailPrefetchTrigger {
                onPrefetch(section.id)
            }
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ModernHomeRowTokens.rowGap) {
            HStack(alignment: .firstTextBaseline, spacing: NuvioDesignTokens.Spacing.md) {
                Text(section.title)
                    .nuvioTextStyle(.sectionTitle)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if let onOpen {
                    Button("See All", action: onOpen)
                        .buttonStyle(.bordered)
                }
            }
            .padding(.leading, ModernHomeRowTokens.homeForegroundLeadingMargin)
            .padding(.trailing, ModernHomeRowTokens.screenHorizontalMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: ModernHomeRowTokens.itemGap) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        card(item, at: index)
                    }

                    if section.isLoading {
                        ProgressView()
                            .controlSize(.large)
                            .frame(
                                width: ModernHomeRowTokens.posterWidth,
                                height: ModernHomeRowTokens.posterHeight
                            )
                            .accessibilityLabel("Loading more \(section.title)")
                    }
                }
                .padding(.leading, ModernHomeRowTokens.homeForegroundLeadingMargin)
                .padding(.trailing, ModernHomeRowTokens.screenHorizontalMargin)
                .padding(.vertical, ModernHomeRowTokens.softBlur)
            }
            .scrollClipDisabled()
        }
        .focusSection()
        .onAppear {
            prefetchTrigger.updateAction { onPrefetch(section.id) }
        }
        .onChange(of: section.id) { _, newSectionID in
            prefetchTrigger.reset()
            prefetchTrigger.updateAction { onPrefetch(newSectionID) }
        }
        .onChange(of: focusedItemID) { _, newItemID in
            if let newItemID,
               let index = section.items.firstIndex(where: { $0.id == newItemID }) {
                observePrefetch(at: index)
            }
        }
    }

    private func card(_ item: RailItem, at index: Int) -> some View {
        PosterCardView(
            title: item.title,
            year: item.year,
            artwork: item.posterArtwork,
            status: item.status,
            showsLabel: true,
            isExpanded: false,
            expansion: nil,
            artworkProvider: artworkProvider,
            onSelect: { onSelect(item) }
        )
        .focused($focusedItemID, equals: item.id)
        .onAppear {
            observePrefetch(at: index)
        }
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
