import SwiftUI

struct CatalogCollectionRail: View {
    let collection: TVCollection
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(collection.title.tvSafe).font(.title2.weight(.semibold))
                Spacer()
                Button("Open Collection", action: onOpen).buttonStyle(.bordered)
            }
            .padding(.horizontal, 48)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 26) {
                    ForEach(collection.folders.prefix(8)) { folder in
                        FolderButton(folder: folder, count: nil, action: onOpen)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 18)
            }
        }
        .focusSection()
    }
}
