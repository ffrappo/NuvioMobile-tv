import SwiftUI

public struct ModernRailRow: View {
    public let section: RailSection
    public let artworkProvider: PosterArtworkProvider
    public let onSelect: (RailItem) -> Void
    public let onPrefetch: (String) -> Void

    @ObservedObject private var focusModel: RailFocusModel
    @StateObject private var prefetchTrigger: RailPrefetchTrigger
    @FocusState private var focusedItemID: String?

    public init(
        section: RailSection,
        focusModel: RailFocusModel,
        artworkProvider: @escaping PosterArtworkProvider,
        onSelect: @escaping (RailItem) -> Void,
        onPrefetch: @escaping (String) -> Void = { _ in }
    ) {
        self.section = section
        self.focusModel = focusModel
        self.artworkProvider = artworkProvider
        self.onSelect = onSelect
        self.onPrefetch = onPrefetch
        _prefetchTrigger = StateObject(
            wrappedValue: RailPrefetchTrigger {
                onPrefetch(section.id)
            }
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ModernHomeRowTokens.rowGap) {
            Text(section.title)
                .nuvioTextStyle(.sectionTitle)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.leading, ModernHomeRowTokens.railLeadingMargin)
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
                .padding(.leading, ModernHomeRowTokens.railLeadingMargin)
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
        .onChange(of: focusedItemID) { oldItemID, newItemID in
            if let oldItemID {
                focusModel.blur(focusID(for: oldItemID))
            }
            if let newItemID,
               let index = section.items.firstIndex(where: { $0.id == newItemID }) {
                focusModel.focus(focusID(for: newItemID))
                observePrefetch(at: index)
            }
        }
        .onDisappear {
            if let focusedItemID {
                focusModel.blur(focusID(for: focusedItemID))
            }
        }
    }

    private func card(_ item: RailItem, at index: Int) -> some View {
        let id = focusID(for: item.id)
        return PosterCardView(
            title: item.title,
            year: item.year,
            artwork: item.posterArtwork,
            status: item.status,
            showsLabel: true,
            isExpanded: focusModel.isExpanded(id),
            expansion: PosterCardExpansion(
                backdropArtwork: item.backdropArtwork,
                overview: item.overview,
                metadata: item.metadata
            ),
            artworkProvider: artworkProvider,
            onSelect: { onSelect(item) }
        )
        .focused($focusedItemID, equals: item.id)
        .onAppear {
            observePrefetch(at: index)
        }
    }

    private func focusID(for itemID: String) -> RailFocusID {
        RailFocusID(sectionID: section.id, itemID: itemID)
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
