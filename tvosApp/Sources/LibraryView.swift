import SwiftUI

struct LibraryView: View {
    let onSelect: (MetaSummary) -> Void

    @EnvironmentObject private var library: LibraryStore
    @FocusState private var focusedID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Library")
                    .font(.largeTitle.weight(.bold))

                if library.items.isEmpty {
                    VStack(spacing: 18) {
                        Image(systemName: "heart")
                            .font(.system(size: 70))
                        Text("Your library is empty")
                            .font(.title2)
                        Text("Open any title and add it to your favorites.")
                            .foregroundStyle(NuvioTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 420)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 34)], spacing: 42) {
                        ForEach(library.items) { item in
                            Button {
                                onSelect(item)
                            } label: {
                                PosterCard(item: item, isFocused: focusedID == item.id)
                            }
                            .buttonStyle(.plain)
                            .focused($focusedID, equals: item.id)
                        }
                    }
                    .padding(.vertical, 18)
                }
            }
            .padding(48)
        }
        .defaultFocus($focusedID, library.items.first?.id)
    }
}

