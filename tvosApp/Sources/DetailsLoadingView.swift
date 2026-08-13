import SwiftUI

struct DetailsLoadingView: View {
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text("Loading details").font(.title3.weight(.semibold))
            }
            RoundedRectangle(cornerRadius: 18)
                .fill(.quaternary)
                .frame(height: 72)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 24) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.quaternary)
                            .frame(width: 320, height: 180)
                    }
                }
            }
            .scrollDisabled(true)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading details")
    }
}
