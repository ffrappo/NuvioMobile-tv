import Foundation
import TVServices

final class NuvioTopShelfProvider: TVTopShelfContentProvider {
    private let service = TopShelfCatalogService()

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        let sections = await service.sections()
        let collections = sections.compactMap(makeCollection)
        guard !collections.isEmpty else { return nil }
        return TVTopShelfSectionedContent(sections: collections)
    }

    private func makeCollection(
        _ section: TopShelfCatalogSection
    ) -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        let items = section.items.compactMap(makeItem)
        guard !items.isEmpty else { return nil }
        let collection = TVTopShelfItemCollection(items: items)
        collection.title = section.title
        return collection
    }

    private func makeItem(_ entry: TopShelfCatalogEntry) -> TVTopShelfSectionedItem? {
        guard let actionURL = NuvioTopShelfLink.detailsURL(
            type: entry.type,
            id: entry.id
        ) else { return nil }
        let item = TVTopShelfSectionedItem(identifier: "\(entry.type).\(entry.id)")
        item.title = entry.name
        item.imageShape = .poster
        if let poster = entry.poster.flatMap(URL.init(string:)) {
            item.setImageURL(poster, for: .screenScale1x)
            item.setImageURL(poster, for: .screenScale2x)
        }
        item.displayAction = TVTopShelfAction(url: actionURL)
        return item
    }
}
