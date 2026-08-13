import SwiftUI

struct LibraryView: View {
    let onSelect: (MetaSummary) -> Void

    @EnvironmentObject private var library: LibraryStore
    @FocusState private var focusedID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                NuvioPageHeader(
                    title: "Library",
                    subtitle: "Titles saved to your active profile"
                )

                if library.items.isEmpty {
                    NuvioUnavailableView(
                        title: "Your Library Is Empty",
                        symbol: "heart",
                        message: "Open any title and add it to your library."
                    )
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 236, maximum: 270), spacing: 28)],
                        spacing: 34
                    ) {
                        ForEach(library.items) { item in
                            MediaPosterButton(item: item, onSelect: onSelect)
                                .focused($focusedID, equals: "\(item.type):\(item.id)")
                        }
                    }
                    .padding(.vertical, 18)
                    .focusSection()
                }
            }
            .padding(48)
        }
        .navigationTitle("Library")
        .defaultFocus($focusedID, library.items.first.map { "\($0.type):\($0.id)" })
    }
}
