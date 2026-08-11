import SwiftUI

struct HomeHeroView: View {
    let item: MetaSummary
    let onSelect: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                RemoteArtwork(
                    urlString: item.background ?? item.poster,
                    systemPlaceholder: "film.stack.fill"
                )
                .frame(height: 520)
                .overlay(
                    LinearGradient(
                        colors: [.clear, NuvioTheme.background.opacity(0.25), NuvioTheme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.name.tvSafe)
                        .font(.system(size: 52, weight: .bold))
                        .lineLimit(2)
                    if let description = item.description?.trimmedNonEmpty {
                        Text(description.tvSafe)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(3)
                            .frame(maxWidth: 850, alignment: .leading)
                    }
                    Label("Open Details", systemImage: "play.fill")
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(focused ? .white : NuvioTheme.panelFocused, in: Capsule())
                        .foregroundStyle(focused ? .black : .white)
                }
                .padding(.horizontal, 56)
                .padding(.bottom, 48)
            }
        }
        .buttonStyle(.card)
        .focused($focused)
        .defaultFocus($focused, true)
        .accessibilityLabel("\(item.name), featured")
        .accessibilityHint("Opens details")
    }
}

struct CatalogRail: View {
    let title: String
    let subtitle: String?
    let items: [MetaSummary]
    let onSelect: (MetaSummary) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(title.tvSafe).font(.title2.weight(.semibold))
                    if let subtitle {
                        Text(subtitle.tvSafe).font(.callout).foregroundStyle(NuvioTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 48)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 28) {
                        ForEach(items) { item in
                            PosterButton(item: item) { onSelect(item) }
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 26)
                }
            }
        }
    }
}

private struct PosterButton: View {
    let item: MetaSummary
    let action: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            PosterCard(item: item, isFocused: focused)
        }
        .buttonStyle(.card)
        .focused($focused)
        .accessibilityLabel(
            [item.name, item.releaseInfo, item.type.capitalized]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
        .accessibilityHint("Opens details")
    }
}

struct PosterCard: View {
    let item: MetaSummary
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteArtwork(urlString: item.poster, systemPlaceholder: "film")
                .frame(width: 220, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(focusBorder)
                .shadow(
                    color: isFocused ? .white.opacity(0.28) : .black.opacity(0.45),
                    radius: isFocused ? 18 : 10,
                    y: isFocused ? 10 : 4
                )
            Text(item.name.tvSafe)
                .font(.headline)
                .lineLimit(1)
                .frame(width: 220, alignment: .leading)
            Text(item.releaseInfo?.tvSafe ?? item.type.capitalized)
                .font(.subheadline)
                .foregroundStyle(NuvioTheme.secondaryText)
        }
        .scaleEffect(isFocused ? 1.08 : 1)
        .animation(.easeOut(duration: 0.13), value: isFocused)
    }

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                isFocused ? Color.white.opacity(0.95) : Color.white.opacity(0.12),
                lineWidth: isFocused ? 3 : 1
            )
    }
}
