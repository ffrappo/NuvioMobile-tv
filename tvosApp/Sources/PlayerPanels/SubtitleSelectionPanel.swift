import SwiftUI

/// Native tvOS port of the Android subtitle selection overlay
/// (`SubtitleSelectionOverlay.kt`), presented as a single side panel. The
/// Android overlay uses a language rail plus per-language option rail; this
/// panel keeps the same composition and labeling rules but lays tracks out in
/// "Off", built-in, and external sections (see the parity report).
struct SubtitleSelectionPanel: View {
    let embeddedTracks: [SubtitleEmbeddedTrack]
    let externalTracks: [SubtitleExternalTrack]
    var styleOptions = SubtitleStyleOptions()
    var delayMilliseconds = 0
    var installedAddonOrder: [String] = []
    var isLoadingExternalTracks = false

    let onSelectEmbedded: (SubtitleEmbeddedTrack) -> Void
    let onSelectExternal: (SubtitleExternalTrack) -> Void
    let onDisableSubtitles: () -> Void
    let onAdjustDelay: (Int) -> Void
    let onOpenTimingDialog: () -> Void
    let onToggleSdhFilter: (Bool) -> Void
    let onShowAppearance: () -> Void
    let onClose: () -> Void

    init(
        embeddedTracks: [SubtitleEmbeddedTrack],
        externalTracks: [SubtitleExternalTrack] = [],
        styleOptions: SubtitleStyleOptions = SubtitleStyleOptions(),
        delayMilliseconds: Int = 0,
        installedAddonOrder: [String] = [],
        isLoadingExternalTracks: Bool = false,
        onSelectEmbedded: @escaping (SubtitleEmbeddedTrack) -> Void,
        onSelectExternal: @escaping (SubtitleExternalTrack) -> Void = { _ in },
        onDisableSubtitles: @escaping () -> Void = {},
        onAdjustDelay: @escaping (Int) -> Void = { _ in },
        onOpenTimingDialog: @escaping () -> Void = {},
        onToggleSdhFilter: @escaping (Bool) -> Void = { _ in },
        onShowAppearance: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        self.embeddedTracks = embeddedTracks
        self.externalTracks = externalTracks
        self.styleOptions = styleOptions
        self.delayMilliseconds = delayMilliseconds
        self.installedAddonOrder = installedAddonOrder
        self.isLoadingExternalTracks = isLoadingExternalTracks
        self.onSelectEmbedded = onSelectEmbedded
        self.onSelectExternal = onSelectExternal
        self.onDisableSubtitles = onDisableSubtitles
        self.onAdjustDelay = onAdjustDelay
        self.onOpenTimingDialog = onOpenTimingDialog
        self.onToggleSdhFilter = onToggleSdhFilter
        self.onShowAppearance = onShowAppearance
        self.onClose = onClose
    }

    private var hasSelection: Bool {
        embeddedTracks.contains(where: \.isSelected) || externalTracks.contains(where: \.isSelected)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.12))
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: NuvioDesignTokens.Spacing.sm,
                    pinnedViews: []
                ) {
                    offSection
                    embeddedSection
                    externalSection
                    timingSection
                    sdhSection
                }
                .padding(NuvioDesignTokens.Spacing.SidePanel.outer)
            }
            Divider().overlay(Color.white.opacity(0.12))
            footer
        }
        .frame(width: panelWidth)
        .background(
            NuvioDesignTokens.Colors.neutral925.opacity(0.96),
            in: RoundedRectangle(
                cornerRadius: NuvioDesignTokens.Shapes.sidePanelRadius,
                style: .continuous
            )
        )
    }

    private var panelWidth: CGFloat {
        NuvioDesignTokens.Sizes.Player.sidePanelWidth
    }

    private var header: some View {
        HStack {
            Text("Subtitles")
                .font(.title3.weight(.semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close subtitles panel")
        }
        .padding(
            EdgeInsets(
                top: NuvioDesignTokens.Spacing.lg,
                leading: NuvioDesignTokens.Spacing.SidePanel.outer,
                bottom: NuvioDesignTokens.Spacing.md,
                trailing: NuvioDesignTokens.Spacing.SidePanel.outer
            )
        )
    }

    // MARK: Sections

    /// The "Off" entry, always first in the Android language rail.
    private var offSection: some View {
        SubtitlePanelTrackRow(
            title: "Off",
            sourceLabel: SubtitleLanguageCatalog.languageCodeToName("none"),
            meta: nil,
            isSelected: !hasSelection
        ) {
            onDisableSubtitles()
        }
    }

    private var embeddedSection: some View {
        Group {
            if !embeddedTracks.isEmpty {
                SubtitlePanelSectionHeader(title: "Built-in", badge: embeddedTracks.count)
                ForEach(embeddedTracks) { track in
                    SubtitlePanelTrackRow(
                        title: track.name,
                        sourceLabel: builtInSourceLabel(for: track),
                        meta: embeddedMeta(for: track),
                        isSelected: track.isSelected
                    ) {
                        onSelectEmbedded(track)
                    }
                }
            }
        }
    }

    private var externalSection: some View {
        Group {
            SubtitlePanelSectionHeader(title: "External", badge: externalTracks.count)
            if externalTracks.isEmpty && isLoadingExternalTracks {
                HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                    ProgressView()
                    Text("Loading subtitles from addons…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
            } else if externalTracks.isEmpty {
                Text("No addon subtitles for this stream")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
            } else {
                // Android orders external tracks by installed addon order.
                ForEach(orderedExternalTracks) { track in
                    SubtitlePanelTrackRow(
                        title: externalTitle(for: track),
                        sourceLabel: track.addonName,
                        meta: externalMeta(for: track),
                        isSelected: track.isSelected
                    ) {
                        onSelectExternal(track)
                    }
                }
            }
        }
    }

    private var timingSection: some View {
        Group {
            SubtitlePanelSectionHeader(title: "Timing")
            SubtitlePanelStepperRow(
                title: "Subtitle Delay",
                value: SubtitleTimingMath.delayMillisecondsLabel(delayMilliseconds),
                decrementLabel: "Delay subtitles 100 milliseconds earlier",
                incrementLabel: "Delay subtitles 100 milliseconds later",
                decrement: { onAdjustDelay(-SubtitleDelayRange.stepMilliseconds) },
                increment: { onAdjustDelay(SubtitleDelayRange.stepMilliseconds) }
            )
            if delayMilliseconds != 0 {
                SubtitlePanelActionRow(title: "Reset Delay") {
                    onAdjustDelay(-delayMilliseconds)
                }
            }
            SubtitlePanelActionRow(title: "Sync by Line…") {
                onOpenTimingDialog()
            }
        }
    }

    private var sdhSection: some View {
        Group {
            SubtitlePanelSectionHeader(title: "Captions")
            SubtitlePanelToggleRow(
                title: "Strip SDH Descriptions",
                isOn: styleOptions.stripSdh,
                action: { onToggleSdhFilter(!styleOptions.stripSdh) }
            )
        }
    }

    private var footer: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            Button(action: onShowAppearance) {
                Label("Appearance", systemImage: "textformat")
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(SubtitlePanelRowStyle())
            Button(action: onClose) {
                Text("Done")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(SubtitlePanelRowStyle())
        }
        .padding(NuvioDesignTokens.Spacing.SidePanel.inner)
    }

    // MARK: Row labeling (same rules as SubtitleSelectionComposer.optionItems)

    private var orderedExternalTracks: [SubtitleExternalTrack] {
        let orderIndex = Dictionary(
            installedAddonOrder.enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return externalTracks.enumerated()
            .sorted { lhs, rhs in
                let lhsOrder = orderIndex[lhs.element.addonName] ?? Int.max
                let rhsOrder = orderIndex[rhs.element.addonName] ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func builtInSourceLabel(for track: SubtitleEmbeddedTrack) -> String {
        SubtitleSelectionComposer.languageLabel(
            SubtitleSelectionComposer.languageKey(forTrack: track)
        )
    }

    private func embeddedMeta(for track: SubtitleEmbeddedTrack) -> String? {
        var parts: [String] = []
        if let language = track.language, !language.isEmpty {
            parts.append(SubtitleLanguageCatalog.languageCodeToName(language))
        }
        if let codec = track.codec, !codec.isEmpty { parts.append(codec) }
        if track.isForced { parts.append("Forced") }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func externalTitle(for track: SubtitleExternalTrack) -> String {
        SubtitleLanguageCatalog.languageCodeToName(
            SubtitleLanguageCatalog.normalizeLanguageCode(track.language)
        )
    }

    private func externalMeta(for track: SubtitleExternalTrack) -> String? {
        guard !track.externalID.isEmpty, track.externalID != track.language else { return nil }
        return track.externalID
    }
}
