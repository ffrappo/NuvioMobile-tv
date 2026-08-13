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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 34)], spacing: 42) {
                        ForEach(library.items) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    onSelect(item)
                                } label: {
                                    RemoteArtwork(urlString: item.poster, systemPlaceholder: "film")
                                        .frame(width: 220, height: 320)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.card)
                                Text(item.name.tvSafe)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .frame(width: 220, alignment: .leading)
                                Text(item.releaseInfo?.tvSafe ?? item.type.capitalized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .focused($focusedID, equals: item.id)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(item.name.tvSafe)
                            .accessibilityHint("Opens details")
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
