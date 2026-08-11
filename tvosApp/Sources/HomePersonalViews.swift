import SwiftUI

struct ProgressRail<FocusValue: Hashable>: View {
    let title: String
    let items: [ContinueWatchingCard]
    let focus: FocusState<FocusValue?>.Binding
    let focusValue: (ContinueWatchingCard) -> FocusValue
    let onSelect: (ContinueWatchingCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.weight(.semibold)).padding(.horizontal, 48)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 26) {
                    ForEach(items) { item in
                        let value = focusValue(item)
                        Button { onSelect(item) } label: {
                            ProgressCard(item: item, focused: focus.wrappedValue == value)
                        }
                        .buttonStyle(NuvioBareButtonStyle())
                        .focused(focus, equals: value)
                        .accessibilityLabel(accessibilityLabel(item))
                        .accessibilityHint("Opens details")
                    }
                }
                .padding(.horizontal, 48).padding(.vertical, 22)
            }
        }
    }

    private func accessibilityLabel(_ item: ContinueWatchingCard) -> String {
        var parts = [item.summary.name]
        if let season = item.season, let episode = item.episode { parts.append("Season \(season), episode \(episode)") }
        if !item.isUpcoming { parts.append("\(Int(item.progress * 100)) percent watched") }
        return parts.joined(separator: ", ")
    }
}

struct ProgressCard: View {
    let item: ContinueWatchingCard
    let focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                RemoteArtwork(
                    urlString: item.episodeThumbnail ?? item.summary.background ?? item.summary.poster,
                    systemPlaceholder: "play.rectangle.fill"
                )
                .frame(width: 370, height: 208)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                if !item.isUpcoming {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.black.opacity(0.52))
                            Capsule().fill(Color.white.opacity(0.78)).frame(width: proxy.size.width * item.progress)
                        }
                    }
                    .frame(height: 7).padding(12)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        focused ? Color.white.opacity(0.95) : Color.white.opacity(0.12),
                        lineWidth: focused ? 3 : 1
                    )
            )
            Text(item.summary.name.tvSafe).font(.headline).lineLimit(1).frame(width: 370, alignment: .leading)
            Text(metadata.tvSafe).font(.subheadline).foregroundStyle(NuvioTheme.secondaryText)
        }
        .scaleEffect(focused ? 1.06 : 1)
        .shadow(
            color: focused ? Color.white.opacity(0.25) : .black.opacity(0.4),
            radius: focused ? 16 : 8,
            y: focused ? 10 : 3
        )
        .animation(.easeOut(duration: 0.16), value: focused)
    }

    private var metadata: String {
        if let season = item.season, let episode = item.episode {
            let code = "S\(season) E\(episode)"
            return item.episodeTitle.map { "\(code)  \($0)" } ?? code
        }
        return item.isUpcoming ? "Upcoming" : "Continue watching"
    }
}

struct FolderCard: View {
    let folder: TVCollectionFolder
    let count: Int?
    let focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteArtwork(urlString: folder.coverImageUrl, systemPlaceholder: "folder.fill")
                .frame(width: 250, height: folder.tileShape.lowercased() == "landscape" ? 150 : 250)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            focused ? Color.white.opacity(0.95) : Color.white.opacity(0.12),
                            lineWidth: focused ? 3 : 1
                        )
                )
            if !folder.hideTitle {
                Text(folder.title.tvSafe).font(.headline).lineLimit(1).frame(width: 250, alignment: .leading)
            }
            if let count {
                Text("\(count) titles").font(.caption).foregroundStyle(NuvioTheme.secondaryText)
            }
        }
        .scaleEffect(focused ? 1.06 : 1)
        .shadow(
            color: focused ? Color.white.opacity(0.25) : .black.opacity(0.4),
            radius: focused ? 16 : 8,
            y: focused ? 10 : 3
        )
        .animation(.easeOut(duration: 0.16), value: focused)
    }
}

struct RemoteArtwork: View {
    let urlString: String?
    let systemPlaceholder: String

    var body: some View {
        AsyncImage(url: urlString.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .empty: ZStack { NuvioTheme.panel; ProgressView() }
            default: ZStack {
                NuvioTheme.panel
                Image(systemName: systemPlaceholder).font(.system(size: 54)).foregroundStyle(NuvioTheme.secondaryText)
            }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

struct ErrorPanel: View {
    let message: String
    let retry: () -> Void
    @FocusState private var retryFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 54)).foregroundStyle(.orange)
            Text(message.tvSafe).font(.title3).multilineTextAlignment(.center)
            Button("Try Again", action: retry).buttonStyle(.borderedProminent).focused($retryFocused)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .defaultFocus($retryFocused, true)
    }
}
