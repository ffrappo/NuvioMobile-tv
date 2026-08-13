import SwiftUI

struct MediaPosterButton: View {
    let item: MetaSummary
    let onSelect: (MetaSummary) -> Void

    var body: some View {
        Button { onSelect(item) } label: {
            VStack(alignment: .leading, spacing: 10) {
                RemoteArtwork(urlString: item.poster, systemPlaceholder: "film")
                    .aspectRatio(2 / 3, contentMode: .fit)
                Text(item.name.tvSafe)
                    .font(.headline)
                    .lineLimit(1)
                if let detail = item.releaseInfo?.trimmedNonEmpty ?? item.type.trimmedNonEmpty {
                    Text(detail.tvSafe)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.card)
        .accessibilityLabel(item.name.tvSafe)
        .accessibilityValue(item.releaseInfo?.tvSafe ?? item.type.capitalized)
        .accessibilityHint("Shows details")
    }
}

struct CatalogPlaceholderGrid: View {
    private let columns = [
        GridItem(.adaptive(minimum: 236, maximum: 270), spacing: 28),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 34) {
            ForEach(0..<12, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.quaternary)
                        .aspectRatio(2 / 3, contentMode: .fit)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(height: 24)
                }
                .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topLeading) {
            ProgressView("Loading catalog")
                .padding(20)
                .background(.regularMaterial, in: Capsule())
        }
    }
}
