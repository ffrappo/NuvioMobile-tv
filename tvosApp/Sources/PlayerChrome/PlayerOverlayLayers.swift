import SwiftUI

/// Cast member for the pause overlay, mirroring Android `MetaCastMember`.
struct PlayerCastMember: Identifiable, Hashable, Sendable {
    let name: String
    var character: String? = nil
    var photoURL: URL? = nil

    var id: String { character.map { "\(name) (\($0))" } ?? name }
}

/// Metadata payload for the pause overlay, mirroring the `PauseOverlay`
/// composable parameters from PauseOverlay.kt.
struct PlayerPauseOverlayContent: Equatable, Sendable {
    var title: String = ""
    var logoURL: URL? = nil
    var episodeTitle: String? = nil
    var season: Int? = nil
    var episode: Int? = nil
    var year: String? = nil
    var type: String? = nil
    var description: String? = nil
    var cast: [PlayerCastMember] = []
    var showClock: Bool = true
    /// The brief's "position indicator": a formatted playback position the
    /// integrator may supply (e.g. "12:34 / 1:29:59"). Android's pause
    /// overlay shows none; nil matches Android exactly.
    var positionText: String? = nil
}

/// Composition of the full-screen player overlay layers (pause overlay and
/// stream info overlay), driven by the resolved `PlayerChromeState`. The
/// integrator hosts this above the controls chrome and below any side panels.
struct PlayerOverlayLayers: View {
    let chrome: PlayerChromeState
    var pauseContent: PlayerPauseOverlayContent? = nil
    var streamInfo: PlayerStreamInfoData? = nil
    var hudEnabled: Bool = false
    var hudButtonShown: Bool = false
    let onDismissPauseOverlay: () -> Void
    let onDismissStreamInfoOverlay: () -> Void
    var onToggleHud: () -> Void = {}
    var onSelectCastMember: (PlayerCastMember) -> Void = { _ in }

    var body: some View {
        ZStack {
            if let pause = pauseContent {
                PlayerPauseOverlay(
                    visible: chrome.isPauseOverlayVisible,
                    content: pause,
                    onClose: onDismissPauseOverlay,
                    onSelectCastMember: onSelectCastMember
                )
            }
            PlayerStreamInfoOverlayView(
                visible: chrome.isStreamInfoOverlayVisible,
                data: streamInfo,
                hudEnabled: hudEnabled,
                hudButtonShown: hudButtonShown,
                onClose: onDismissStreamInfoOverlay,
                onToggleHud: onToggleHud
            )
        }
    }
}

/// Full-screen pause overlay ported from Android PauseOverlay.kt: bottom
/// metadata block ("You're watching", logo or title, year / season-episode,
/// episode title, description, cast rail) with a wall clock at the top end.
/// Background tap and the Menu button dismiss.
struct PlayerPauseOverlay: View {
    let visible: Bool
    let content: PlayerPauseOverlayContent
    let onClose: () -> Void
    var onSelectCastMember: (PlayerCastMember) -> Void = { _ in }

    @State private var selectedCastMember: PlayerCastMember?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if visible {
                ZStack(alignment: .bottomLeading) {
                    PlayerOverlayScrim()
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 0)
                        if let member = selectedCastMember {
                            PauseCastDetailView(member: member) {
                                selectedCastMember = nil
                            }
                        } else {
                            PauseMetadataView(content: content) { member in
                                selectedCastMember = member
                                onSelectCastMember(member)
                            }
                        }
                    }
                    .padding(.horizontal, NuvioDesignTokens.Spacing.huge)
                    .padding(.top, 40)
                    .padding(.bottom, 120)
                    if content.showClock {
                        PauseOverlayClock()
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: .topTrailing)
                            .padding(.trailing, NuvioDesignTokens.Spacing.huge)
                            .padding(.top, 40)
                    }
                }
                .onTapGesture { onClose() }
                .onExitCommand { onClose() }
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: visible)
        .onChange(of: visible) { _, shown in
            if !shown { selectedCastMember = nil }
        }
    }
}

/// Android PlayerOverlayScaffold backdrop: flat tint plus directional
/// gradients darkening the leading edge and the top.
private struct PlayerOverlayScrim: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
            LinearGradient(
                colors: [.black.opacity(0.88), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.6), location: 0),
                    .init(color: .black.opacity(0.4), location: 0.3),
                    .init(color: .black.opacity(0.2), location: 0.6),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

/// Android PauseOverlayClock: wall clock, refreshed on the minute boundary.
private struct PauseOverlayClock: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(context.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.95))
        }
    }
}

private struct PauseMetadataView: View {
    let content: PlayerPauseOverlayContent
    let onCastSelected: (PlayerCastMember) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("You're watching")
                .nuvioTextStyle(.body)
                .foregroundStyle(NuvioDesignTokens.Colors.neutral600)
                .padding(.bottom, NuvioDesignTokens.Spacing.md)
            if let logoURL = content.logoURL {
                PauseLogoView(url: logoURL, title: content.title)
            } else {
                titleText(content.title)
            }
            if let year = content.year, !year.isEmpty {
                Text(year + episodeLabel)
                    .nuvioTextStyle(.body)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .padding(.top, NuvioDesignTokens.Spacing.sm)
            }
            if let positionText = content.positionText, !positionText.isEmpty {
                Text(positionText)
                    .nuvioTextStyle(.body)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .padding(.top, NuvioDesignTokens.Spacing.sm)
            }
            if let episodeTitle = content.episodeTitle, !episodeTitle.isEmpty {
                Text(episodeTitle.tvSafe)
                    .nuvioTextStyle(.sectionTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(2)
                    .padding(.top, NuvioDesignTokens.Spacing.md)
            }
            if let description = content.description, !description.isEmpty {
                Text(description.tvSafe)
                    .nuvioTextStyle(.body)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .padding(.top, NuvioDesignTokens.Spacing.lg)
            }
            if !content.cast.isEmpty {
                castRail
            }
        }
    }

    private func titleText(_ title: String) -> some View {
        Text(title.tvSafe)
            .nuvioTextStyle(.headline)
            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            .lineLimit(2)
    }

    /// Android appends " • S%d E%d" when the content is a series episode.
    private var episodeLabel: String {
        guard let type = content.type?.lowercased(),
              type == "series" || type == "tv",
              let season = content.season,
              let episode = content.episode else { return "" }
        return " • S\(season) E\(episode)"
    }

    private var castRail: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            Text("Cast")
                .nuvioTextStyle(.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.neutral600)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(content.cast.prefix(8)) { member in
                        PauseCastChip(member: member) { onCastSelected(member) }
                    }
                }
            }
        }
        .padding(.top, 20)
    }
}

/// Title logo with graceful fallback to the plain title, mirroring the
/// Android logo load-failure path.
private struct PauseLogoView: View {
    let url: URL
    let title: String

    @State private var loaded: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let loaded, !failed {
                Image(uiImage: loaded)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 96, alignment: .bottomLeading)
            } else {
                Text(title.tvSafe)
                    .nuvioTextStyle(.headline)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(2)
            }
        }
        .task(id: url) {
            failed = false
            loaded = await ArtworkLoader.shared.image(for: url)
            if loaded == nil { failed = true }
        }
    }
}

private struct PauseCastChip: View {
    let member: PlayerCastMember
    let onSelect: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: onSelect) {
            Text(member.name.tvSafe)
                .nuvioTextStyle(.button)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
                        .fill(isFocused
                              ? Color.white.opacity(0.18)
                              : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(member.name)
    }
}

/// Android CastDetailView: back row, photo, name, "as character".
private struct PauseCastDetailView: View {
    let member: PlayerCastMember
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: NuvioDesignTokens.Spacing.md) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: NuvioDesignTokens.Sizes.Icons.xl))
                    Text("Back to details")
                        .nuvioTextStyle(.button)
                }
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 28)
            HStack(alignment: .top, spacing: 28) {
                if let photoURL = member.photoURL {
                    PauseCastPhoto(url: photoURL)
                }
                VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
                    Text(member.name.tvSafe)
                        .nuvioTextStyle(.headline)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                        .lineLimit(2)
                    if let character = member.character, !character.isEmpty {
                        Text("as \(character)")
                            .nuvioTextStyle(.body)
                            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                            .lineLimit(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct PauseCastPhoto: View {
    let url: URL

    @State private var loaded: UIImage?

    var body: some View {
        Group {
            if let loaded {
                Image(uiImage: loaded)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xl,
                                                style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xl, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 160, height: 240)
            }
        }
        .task(id: url) {
            loaded = await ArtworkLoader.shared.image(for: url)
        }
    }
}
