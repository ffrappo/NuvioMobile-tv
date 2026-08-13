import Foundation

struct CatalogDescriptor: Hashable, Identifiable, Sendable {
    let baseURL: String
    let addonID: String
    let addonName: String
    let type: String
    let catalogID: String
    let catalogName: String
    let genre: String?
    let supportsPagination: Bool

    var id: String {
        [baseURL, addonID, type, catalogID, genre ?? ""].joined(separator: "|")
    }

    var preferenceKey: String { "\(addonID):\(type):\(catalogID)" }
    var displayTitle: String { catalogName }
    var displaySubtitle: String { "\(addonName) · \(type.capitalized)" }
}

struct CatalogPage: Equatable, Hashable, Sendable {
    let items: [MetaSummary]
    let nextSkip: Int?
}

struct CatalogListing: Equatable, Hashable, Identifiable, Sendable {
    let descriptor: CatalogDescriptor
    var items: [MetaSummary]
    var nextSkip: Int?
    var isLoadingMore = false

    var id: String { descriptor.id }
    var metadataBaseURL: String { descriptor.baseURL }
    var displayTitle: String { descriptor.displayTitle }
    var displaySubtitle: String { descriptor.displaySubtitle }
    var canLoadMore: Bool { nextSkip != nil && !isLoadingMore }

    static func from(_ section: HomeCatalogSection) -> CatalogListing {
        CatalogListing(
            descriptor: CatalogDescriptor(
                baseURL: section.definition.addonBaseURL,
                addonID: section.definition.addonID,
                addonName: section.definition.addonName,
                type: section.definition.type,
                catalogID: section.definition.catalogID,
                catalogName: section.title,
                genre: nil,
                supportsPagination: section.definition.supportsPagination
            ),
            items: section.items,
            nextSkip: CatalogRepository.nextSkip(
                currentSkip: 0,
                supportsPagination: section.definition.supportsPagination,
                receivedCount: section.items.count
            )
        )
    }
}

enum CatalogDescriptors {
    static func browse(from addons: [HomeAddon]) -> [CatalogDescriptor] {
        let descriptors = addons.flatMap { addon in
            addon.manifest.catalogs.compactMap { catalog -> CatalogDescriptor? in
                let names = Set(catalog.extra.map(\.name))
                guard !names.contains("search") else { return nil }
                guard !catalog.extra.contains(where: {
                    $0.isRequired && $0.name != "genre" && $0.name != "skip"
                }) else { return nil }
                let genreExtra = catalog.extra.first { $0.name == "genre" && $0.isRequired }
                guard genreExtra == nil || genreExtra?.options.first != nil else { return nil }
                return descriptor(
                    addon: addon,
                    catalog: catalog,
                    genre: genreExtra?.options.first,
                    supportsPagination: names.contains("skip")
                )
            }
        }
        return descriptors.isEmpty ? fallback(paginates: true) : descriptors.uniqued(by: \.id)
    }

    static func search(from addons: [HomeAddon]) -> [CatalogDescriptor] {
        let descriptors = addons.flatMap { addon in
            addon.manifest.catalogs.compactMap { catalog -> CatalogDescriptor? in
                let names = Set(catalog.extra.map(\.name))
                guard names.contains("search") else { return nil }
                guard !catalog.extra.contains(where: {
                    $0.isRequired && $0.name != "search" && $0.name != "skip"
                }) else { return nil }
                return descriptor(
                    addon: addon,
                    catalog: catalog,
                    genre: nil,
                    supportsPagination: false
                )
            }
        }
        return descriptors.isEmpty ? fallback(paginates: false) : descriptors.uniqued(by: \.id)
    }

    private static func descriptor(
        addon: HomeAddon,
        catalog: AddonCatalog,
        genre: String?,
        supportsPagination: Bool
    ) -> CatalogDescriptor {
        CatalogDescriptor(
            baseURL: addon.baseURL,
            addonID: addon.manifest.id,
            addonName: addon.name,
            type: catalog.type,
            catalogID: catalog.id,
            catalogName: catalog.name,
            genre: genre,
            supportsPagination: supportsPagination
        )
    }

    private static func fallback(paginates: Bool) -> [CatalogDescriptor] {
        ["movie", "series"].map { type in
            CatalogDescriptor(
                baseURL: StremioService.cinemetaBaseURL.absoluteString,
                addonID: "com.linvo.cinemeta",
                addonName: "Cinemeta",
                type: type,
                catalogID: "top",
                catalogName: type == "movie" ? "Movies" : "Series",
                genre: nil,
                supportsPagination: paginates
            )
        }
    }
}

private extension Array {
    func uniqued<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Element] {
        var keys = Set<Key>()
        return filter { keys.insert($0[keyPath: keyPath]).inserted }
    }
}
