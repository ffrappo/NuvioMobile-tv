import SwiftUI

struct HomeHeroView: View {
    let item: MetaSummary
    let focused: Bool
    let onSelect: () -> Void

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
                        .padding(.horizontal, 22).padding(.vertical, 13)
                        .background(focused ? .white : NuvioTheme.panelFocused, in: Capsule())
                        .foregroundStyle(focused ? .black : .white)
                }
                .padding(.horizontal, 56).padding(.bottom, 48)
            }
        }
        .buttonStyle(NuvioBareButtonStyle())
        .accessibilityLabel("\(item.name), featured")
        .accessibilityHint("Opens details")
    }
}

struct CatalogRail<FocusValue: Hashable>: View {
    let title: String
    let subtitle: String?
    let items: [MetaSummary]
    let focus: FocusState<FocusValue?>.Binding
    let focusValue: (MetaSummary) -> FocusValue
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
                            let value = focusValue(item)
                            Button { onSelect(item) } label: {
                                PosterCard(item: item, isFocused: focus.wrappedValue == value)
                            }
                            .buttonStyle(NuvioBareButtonStyle())
                            .focused(focus, equals: value)
                            .accessibilityLabel(accessibilityLabel(item))
                            .accessibilityHint("Opens details")
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 22)
                }
            }
        }
    }

    private func accessibilityLabel(_ item: MetaSummary) -> String {
        [item.name, item.releaseInfo, item.type.capitalized].compactMap { $0 }.joined(separator: ", ")
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
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(isFocused ? 0.70 : 0.45),
                    radius: isFocused ? 22 : 10,
                    y: isFocused ? 12 : 4
                )
                .scaleEffect(isFocused ? 1.06 : 1)
            Text(item.name.tvSafe).font(.headline).lineLimit(1).frame(width: 220, alignment: .leading)
            Text(item.releaseInfo?.tvSafe ?? item.type.capitalized)
                .font(.subheadline).foregroundStyle(NuvioTheme.secondaryText)
        }
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}
