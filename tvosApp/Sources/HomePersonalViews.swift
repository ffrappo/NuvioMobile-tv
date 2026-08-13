import SwiftUI
import UIKit

struct ProgressRail: View {
    let items: [ContinueWatchingCard]
    let onSelect: (ContinueWatchingCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 26) {
                    ForEach(items) { item in
                        ProgressButton(item: item) { onSelect(item) }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 26)
            }
        }
    }
}

private struct ProgressButton: View {
    let item: ContinueWatchingCard
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: action) {
                ZStack(alignment: .bottomLeading) {
                    RemoteArtwork(
                        urlString: item.episodeThumbnail ?? item.summary.background ?? item.summary.poster,
                        systemPlaceholder: "play.rectangle.fill"
                    )
                    .frame(width: 370, height: 208)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if !item.isUpcoming {
                        ProgressCardProgressBar(progress: item.progress)
                    }
                }
            }
            .buttonStyle(.card)
            ProgressCardText(item: item)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens details")
    }

    private var accessibilityLabel: String {
        var parts = [item.summary.name]
        if let season = item.season, let episode = item.episode {
            parts.append("Season \(season), episode \(episode)")
        }
        if !item.isUpcoming { parts.append("\(Int(item.progress * 100)) percent watched") }
        return parts.joined(separator: ", ")
    }
}

struct ProgressCardText: View {
    let item: ContinueWatchingCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.summary.name.tvSafe)
                .font(.headline)
                .lineLimit(1)
                .frame(width: 370, alignment: .leading)
            Text(metadata.tvSafe)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var metadata: String {
        if let season = item.season, let episode = item.episode {
            let code = "S\(season) E\(episode)"
            return item.episodeTitle.map { "\(code)  \($0)" } ?? code
        }
        return item.isUpcoming ? "Upcoming" : "Continue watching"
    }
}

struct ProgressCardProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.52))
                Capsule()
                    .fill(Color.white.opacity(0.90))
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 7)
        .padding(12)
    }
}

struct FolderButton: View {
    let folder: TVCollectionFolder
    let count: Int?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: action) {
                RemoteArtwork(urlString: folder.coverImageUrl, systemPlaceholder: "folder.fill")
                    .frame(width: 250, height: folder.tileShape.lowercased() == "landscape" ? 150 : 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.card)
            if !folder.hideTitle {
                Text(folder.title.tvSafe)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(width: 250, alignment: .leading)
            }
            if let count {
                Text("\(count) titles").font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(folder.title.tvSafe)
        .accessibilityHint("Shows this collection")
    }
}

struct RemoteArtwork: View {
    let urlString: String?
    let systemPlaceholder: String
    @State private var loaded: UIImage?
    @Environment(\.nuvioTheme) private var theme

    var body: some View {
        ZStack {
            if let loaded {
                Image(uiImage: loaded)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    theme.panel
                    Image(systemName: systemPlaceholder)
                        .font(.system(size: 54))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .task(id: urlString) { await loadIfNeeded() }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard loaded == nil,
              let urlString, let url = URL(string: urlString) else { return }
        loaded = await ArtworkLoader.shared.image(for: url)
    }
}

struct ErrorPanel: View {
    let message: String
    let retry: () -> Void
    @FocusState private var retryFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 54))
                .foregroundStyle(.orange)
            Text(message.tvSafe).font(.title3).multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .focused($retryFocused)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .defaultFocus($retryFocused, true)
    }
}
