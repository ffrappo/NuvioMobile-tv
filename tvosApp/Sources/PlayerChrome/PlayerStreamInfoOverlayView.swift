import SwiftUI

/// One label/value readout cell in the stream info overlay (Android InfoItem).
struct PlayerStreamInfoItem: Equatable, Sendable {
    let label: String
    let value: String?

    init(_ label: String, _ value: String?) {
        self.label = label
        self.value = value
    }
}

/// One titled section of the technical readout (Android SectionLabel + row).
struct PlayerStreamInfoSection: Equatable, Sendable {
    let title: String
    let items: [PlayerStreamInfoItem]
}

/// Full-screen stream info overlay ported from Android StreamInfoOverlay.kt:
/// a bottom-leading technical readout in titled sections (SOURCE, FILE,
/// VIDEO, AUDIO, SUBTITLE) and an optional debug-HUD toggle at the bottom
/// end. Menu or a background tap dismisses.
struct PlayerStreamInfoOverlayView: View {
    let visible: Bool
    let data: PlayerStreamInfoData?
    var hudEnabled: Bool = false
    var hudButtonShown: Bool = false
    let onClose: () -> Void
    var onToggleHud: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if visible {
                ZStack {
                    PlayerOverlayStreamScrim()
                    if hudButtonShown {
                        StreamInfoHudButton(enabled: hudEnabled, onClick: onToggleHud)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: .bottomTrailing)
                            .padding(.horizontal, NuvioDesignTokens.Spacing.xxxl)
                            .padding(.vertical, 36)
                    }
                    if let data {
                        ScrollView {
                            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.lg) {
                                if data.addonName != nil || data.streamName != nil {
                                    StreamInfoSourceHeader(data: data)
                                }
                                ForEach(Array(PlayerStreamInfoOverlayView.sections(from: data).enumerated()),
                                        id: \.offset) { _, section in
                                    StreamInfoSectionView(section: section)
                                }
                            }
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomLeading)
                        .padding(.horizontal, NuvioDesignTokens.Spacing.xxxl)
                        .padding(.vertical, 36)
                    }
                }
                .onTapGesture { onClose() }
                .onExitCommand { onClose() }
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: visible)
    }

    /// Pure section builder mirroring the Android composition order and
    /// per-section presence rules (the SOURCE headline is rendered by
    /// StreamInfoSourceHeader, so only its Player Engine cell lands here).
    static func sections(from data: PlayerStreamInfoData) -> [PlayerStreamInfoSection] {
        var sections: [PlayerStreamInfoSection] = []

        if data.addonName != nil || data.streamName != nil {
            var items: [PlayerStreamInfoItem] = []
            if let engine = data.playerEngine {
                items.append(PlayerStreamInfoItem("Player Engine", engine))
            }
            if !items.isEmpty {
                sections.append(PlayerStreamInfoSection(title: "SOURCE", items: items))
            }
        }

        if data.filename != nil || data.fileSize != nil {
            sections.append(PlayerStreamInfoSection(title: "FILE", items: [
                PlayerStreamInfoItem("Filename", data.filename),
                PlayerStreamInfoItem("Size", data.fileSize.map(PlayerStreamInfoFormat.fileSize)),
            ]))
        }

        let hasVideo = data.videoCodec != nil || data.videoWidth != nil ||
            data.videoFrameRate != nil || data.videoBitrate != nil || data.fileBitrate != nil
        if hasVideo {
            let resolution: String?
            if let width = data.videoWidth, let height = data.videoHeight {
                resolution = PlayerStreamInfoFormat.resolution(width: width, height: height)
            } else {
                resolution = nil
            }
            // A container that declares no track bitrate leaves only the whole
            // file rate (audio + overhead included), labelled apart.
            let bitrate: PlayerStreamInfoItem
            if let videoBitrate = data.videoBitrate {
                bitrate = PlayerStreamInfoItem("Bitrate", PlayerStreamInfoFormat.bitrate(videoBitrate))
            } else {
                bitrate = PlayerStreamInfoItem("Bitrate (file)",
                                               data.fileBitrate.map(PlayerStreamInfoFormat.bitrate))
            }
            sections.append(PlayerStreamInfoSection(title: "VIDEO", items: [
                PlayerStreamInfoItem("Codec", data.videoCodec),
                PlayerStreamInfoItem("Resolution", resolution),
                PlayerStreamInfoItem("Frame Rate",
                                     data.videoFrameRate.map(PlayerStreamInfoFormat.frameRate)),
                bitrate,
            ]))
        }

        let hasAudio = data.audioCodec != nil || data.audioChannels != nil ||
            data.audioLanguage != nil || data.audioSampleRate != nil
        if hasAudio {
            sections.append(PlayerStreamInfoSection(title: "AUDIO", items: [
                PlayerStreamInfoItem("Codec", data.audioCodec),
                PlayerStreamInfoItem("Channels", data.audioChannels),
                PlayerStreamInfoItem("Sample Rate",
                                     data.audioSampleRate.map(PlayerStreamInfoFormat.sampleRate)),
                PlayerStreamInfoItem("Language",
                                     data.audioLanguage.map(PlayerStreamInfoFormat.languageName)),
            ]))
        }

        let hasSubtitle = data.subtitleName != nil || data.subtitleCodec != nil ||
            data.subtitleLanguage != nil
        if hasSubtitle {
            sections.append(PlayerStreamInfoSection(title: "SUBTITLE", items: [
                PlayerStreamInfoItem("Name", data.subtitleName),
                PlayerStreamInfoItem("Codec", data.subtitleCodec),
                PlayerStreamInfoItem("Language",
                                     data.subtitleLanguage.map(PlayerStreamInfoFormat.languageName)),
                PlayerStreamInfoItem("Source", data.subtitleSource),
            ]))
        }

        return sections
    }
}

/// Slightly flatter scrim than the pause overlay: Android reuses the scaffold
/// tint with a milder vertical gradient for the technical readout.
private struct PlayerOverlayStreamScrim: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
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

/// Android SOURCE section header: addon logo, addon name headline, stream
/// name and description with newlines flattened to " · ".
private struct StreamInfoSourceHeader: View {
    let data: PlayerStreamInfoData

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            Text("SOURCE")
                .nuvioTextStyle(.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.neutral600)
            HStack(alignment: .center, spacing: NuvioDesignTokens.Spacing.md) {
                if let logoURL = data.addonLogoURL {
                    StreamInfoAddonLogo(url: logoURL, name: data.addonName)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let addonName = data.addonName {
                        Text(addonName.tvSafe)
                            .nuvioTextStyle(.sectionTitle)
                            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                            .lineLimit(1)
                    }
                    if let streamName = data.streamName, streamName != data.addonName {
                        Text(streamName.replacingOccurrences(of: "\n", with: " · ").tvSafe)
                            .nuvioTextStyle(.body)
                            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            if let description = data.streamDescription, !description.isEmpty {
                Text(description.replacingOccurrences(of: "\n", with: " · ").tvSafe)
                    .nuvioTextStyle(.compactBody)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

private struct StreamInfoAddonLogo: View {
    let url: URL
    let name: String?

    @State private var loaded: UIImage?

    var body: some View {
        Group {
            if let loaded {
                Image(uiImage: loaded)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.sm,
                                                style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.sm, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
            }
        }
        .task(id: url) {
            loaded = await ArtworkLoader.shared.image(for: url)
        }
        .accessibilityLabel(name ?? "Addon")
    }
}

private struct StreamInfoSectionView: View {
    let section: PlayerStreamInfoSection

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            Text(section.title)
                .nuvioTextStyle(.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.neutral600)
            // Label/value cells laid out in a row with 36pt gutters, matching
            // the Android Arrangement.spacedBy(36.dp) readout rows.
            HStack(alignment: .top, spacing: 36) {
                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                    StreamInfoItemView(item: item)
                }
            }
        }
    }
}

private struct StreamInfoItemView: View {
    let item: PlayerStreamInfoItem

    var body: some View {
        if let value = item.value {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral600)
                Text(value.tvSafe)
                    .nuvioTextStyle(.cardTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(1)
            }
        }
    }
}

private struct StreamInfoHudButton: View {
    let enabled: Bool
    let onClick: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: NuvioDesignTokens.Spacing.xs) {
                Circle()
                    .fill(enabled
                          ? NuvioDesignTokens.Colors.brand
                          : Color.white.opacity(0.35))
                    .frame(width: 7, height: 7)
                Text("HUD")
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(Color.white.opacity(enabled ? 1 : 0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(hudBackground))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle debug HUD")
    }

    private var hudBackground: Color {
        if isFocused { return enabled ? .white : Color.white.opacity(0.4) }
        return Color.white.opacity(enabled ? 0.14 : 0.06)
    }
}
