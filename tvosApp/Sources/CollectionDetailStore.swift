import Foundation

@MainActor
final class CollectionDetailStore: ObservableObject {
    @Published private(set) var selectedFolderID: String?
    @Published private(set) var sourceListings: [CatalogListing] = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    private let repository: CatalogRepository
    private var requestID = UUID()

    init(repository: CatalogRepository = .shared) {
        self.repository = repository
    }

    func select(
        folder: TVCollectionFolder?,
        descriptors: [CatalogDescriptor]
    ) async {
        requestID = UUID()
        let currentRequest = requestID
        selectedFolderID = folder?.id
        sourceListings = []
        message = nil
        guard folder != nil else {
            message = "This collection has no folders"
            return
        }
        guard !descriptors.isEmpty else {
            message = "This folder has no available addon sources"
            return
        }
        isLoading = true
        defer { if requestID == currentRequest { isLoading = false } }
        let batches = AsyncBatcher.batches(descriptors, limit: 3) { [repository] descriptor in
            do {
                let page = try await repository.firstPage(of: descriptor)
                return CatalogListing(descriptor: descriptor, items: page.items, nextSkip: page.nextSkip)
            } catch {
                return CatalogListing(descriptor: descriptor, items: [], nextSkip: nil)
            }
        }
        for await batch in batches {
            guard !Task.isCancelled, requestID == currentRequest else { return }
            sourceListings.append(contentsOf: batch.map(\.value).filter { !$0.items.isEmpty })
        }
        if sourceListings.isEmpty { message = "This folder has no available titles" }
    }

    func selectFolderID(_ id: String) {
        selectedFolderID = id
    }
}
