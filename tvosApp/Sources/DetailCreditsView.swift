import SwiftUI

struct DetailCreditsView: View {
    let detail: MetaDetail

    private var rows: [(String, String)] {
        var values: [(String, String)] = []
        append("Director", detail.director, to: &values)
        append("Writer", detail.writer, to: &values)
        append("Cast", detail.cast, to: &values)
        if let country = detail.country?.trimmedNonEmpty { values.append(("Country", country)) }
        if let language = detail.language?.trimmedNonEmpty { values.append(("Language", language)) }
        return values
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                DetailSectionHeader(title: "Details", symbol: "info.circle")
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(rows, id: \.0) { title, value in
                        HStack(alignment: .top, spacing: 24) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 150, alignment: .leading)
                            Text(value.tvSafe)
                                .font(.headline)
                                .frame(maxWidth: 1_100, alignment: .leading)
                        }
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func append(
        _ title: String,
        _ values: [String],
        to rows: inout [(String, String)]
    ) {
        let value = values.filter { $0.trimmedNonEmpty != nil }.joined(separator: ", ")
        if !value.isEmpty { rows.append((title, value)) }
    }
}
