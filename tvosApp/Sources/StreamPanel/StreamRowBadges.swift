import SwiftUI

/// The badge chip row under a stream title, matching Android
/// `StreamBadgeChips`: small pill chips, file-size chip included,
/// marquee-free, focus-independent.
struct StreamRowBadgeRow: View {
    let badges: [StreamPanelBadge]

    var body: some View {
        if !badges.isEmpty {
            HStack(spacing: NuvioDesignTokens.Spacing.xs) {
                ForEach(badges) { badge in
                    StreamPanelBadgeChip(badge: badge)
                }
            }
            .lineLimit(1)
        }
    }
}

struct StreamPanelBadgeChip: View {
    let badge: StreamPanelBadge

    private var tint: Color {
        switch badge.kind {
        case .hdr: NuvioDesignTokens.Colors.premium
        case .seeds: NuvioDesignTokens.Colors.success
        case .quality: NuvioDesignTokens.Colors.brand
        default: NuvioDesignTokens.Colors.primaryText
        }
    }

    var body: some View {
        Text(badge.text.tvSafe)
            .nuvioTextStyle(.badge)
            .foregroundStyle(tint)
            .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
            .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
            .background(
                tint.opacity(NuvioDesignTokens.Effects.glowSoftOpacity),
                in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xxs)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xxs)
                    .strokeBorder(NuvioDesignTokens.Colors.neutral700)
            )
            .accessibilityLabel(badge.text.tvSafe)
    }
}

/// "Playing" indicator pill shown next to the current stream title,
/// mirroring the Android `sources_playing` pill.
struct StreamPlayingPill: View {
    var body: some View {
        Text("Playing")
            .nuvioTextStyle(.badge)
            .foregroundStyle(NuvioDesignTokens.Colors.brand)
            .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
            .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
            .background(
                NuvioDesignTokens.Colors.brand.opacity(0.2),
                in: Capsule()
            )
            .accessibilityLabel("Currently playing")
    }
}

/// Trailing addon identity column: logo above addon name, mirroring the
/// Android `StreamItem` trailing column.
struct StreamAddonIdentity: View {
    let addonName: String
    let addonLogoURL: String?

    private let logoSize = CGSize(width: 44, height: 44)

    var body: some View {
        VStack(spacing: NuvioDesignTokens.Spacing.xs) {
            NuvioArtworkView(
                urlString: addonLogoURL,
                mode: .poster,
                pixelSize: logoSize,
                cornerRadius: NuvioDesignTokens.Shapes.sm,
                statePresentation: .transparent,
                placeholderSystemImage: "puzzlepiece.extension"
            )
            Text(addonName.tvSafe)
                .nuvioTextStyle(.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .frame(width: 96)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(addonName.tvSafe)
    }
}
