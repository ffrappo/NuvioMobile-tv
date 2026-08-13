import SwiftUI

struct CatalogRail: View {
    let title: String
    let subtitle: String?
    let items: [MetaSummary]
    let onSelect: (MetaSummary) -> Void
    var onOpenCatalog: (() -> Void)?

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(title.tvSafe).font(.title2.weight(.semibold))
                    if let subtitle {
                        Text(subtitle.tvSafe).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let onOpenCatalog {
                        Button("See All", action: onOpenCatalog).buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 48)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 28) {
                        ForEach(items) { item in
                            MediaPosterButton(item: item, onSelect: onSelect)
                                .frame(width: 220)
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 26)
                }
            }
            .focusSection()
        }
    }
}
