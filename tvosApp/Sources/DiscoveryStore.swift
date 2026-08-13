import Foundation

@MainActor
final class DiscoveryStore: ObservableObject {
    @Published private(set) var descriptors: [CatalogDescriptor] = []
    @Published private(set) var items: [MetaSummary] = []
    @Published private(set) var selectedType: String?
    @Published private(set) var selectedCatalogID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var message: String?

    private let repository: CatalogRepository
    private var nextSkip: Int?
    private var requestID = UUID()
    private var duplicatePageCount = 0

    init(repository: CatalogRepository = .shared) {
        self.repository = repository
    }

    var availableTypes: [String] {
        descriptors.map(\.type).uniqued()
    }

    var availableCatalogs: [CatalogDescriptor] {
        guard let selectedType else { return descriptors }
        return descriptors.filter { $0.type == selectedType }
    }

    var selectedDescriptor: CatalogDescriptor? {
        availableCatalogs.first { $0.id == selectedCatalogID } ?? availableCatalogs.first
    }

    var canLoadMore: Bool { nextSkip != nil && !isLoadingMore }

    func configure(addons: [HomeAddon]) async {
        let next = CatalogDescriptors.browse(from: addons)
        descriptors = next
        let type = selectedType.flatMap { value in
            next.contains(where: { $0.type == value }) ? value : nil
        } ?? next.first?.type
        selectedType = type
        selectedCatalogID = availableCatalogs.first?.id
        await reload()
    }

    func selectType(_ type: String) async {
        guard type != selectedType else { return }
        selectedType = type
        selectedCatalogID = availableCatalogs.first?.id
        await reload()
    }

    func selectCatalog(_ id: String) async {
        guard id != selectedCatalogID else { return }
        selectedCatalogID = id
        await reload()
    }

    func reload() async {
        requestID = UUID()
        let currentRequest = requestID
        items = []
        nextSkip = nil
        duplicatePageCount = 0
        message = nil
        guard let descriptor = selectedDescriptor else {
            message = "Install an addon with browse catalogs to discover titles."
            return
        }
        isLoading = true
        defer { if requestID == currentRequest { isLoading = false } }
        do {
            let page = try await repository.firstPage(of: descriptor)
            guard !Task.isCancelled, requestID == currentRequest else { return }
            items = page.items
            nextSkip = page.nextSkip
            if items.isEmpty { message = "This catalog has no titles right now." }
        } catch is CancellationError {
            return
        } catch {
            guard requestID == currentRequest else { return }
            message = error.userMessage
        }
    }

    func loadMore() async {
        guard let descriptor = selectedDescriptor,
              let skip = nextSkip,
              !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let listing = CatalogListing(
                descriptor: descriptor,
                items: items,
                nextSkip: skip
            )
            guard let page = try await repository.nextPage(of: listing) else {
                nextSkip = nil
                return
            }
            try Task.checkCancellation()
            let existing = Set(items.map { "\($0.type):\($0.id)" })
            let additions = page.items.filter { !existing.contains("\($0.type):\($0.id)") }
            duplicatePageCount = additions.isEmpty ? duplicatePageCount + 1 : 0
            items.append(contentsOf: additions)
            nextSkip = duplicatePageCount >= 3 ? nil : page.nextSkip
        } catch is CancellationError {
            return
        } catch {
            message = error.userMessage
            nextSkip = nil
        }
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
