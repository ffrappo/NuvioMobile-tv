import SwiftUI

/// One selectable stream row, mirroring the Android `StreamItem` card:
/// title (+ playing pill), description, badge chips, filename, and the
/// trailing addon identity column. Unplayable rows are dimmed and disabled.
struct StreamPanelRowView: View {
    let row: StreamPanelRow
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvioDesignTokens.Spacing.lg) {
                leadingColumn
                Spacer(minLength: NuvioDesignTokens.Spacing.none)
                StreamAddonIdentity(
                    addonName: row.addonName,
                    addonLogoURL: row.addonLogoURL
                )
            }
            .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
            .padding(.vertical, NuvioDesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                NuvioDesignTokens.Colors.elevatedSecondary,
                in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md)
            )
            .overlay(playingBorder)
            .opacity(row.isPlayable ? 1 : NuvioDesignTokens.Effects.disabledOpacity + 0.4)
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.md))
        .disabled(!row.isPlayable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(row.isPlayable ? "Stream this source" : "Unavailable source")
    }

    private var leadingColumn: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                Text(row.title.tvSafe)
                    .nuvioTextStyle(.cardTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(1)
                if row.isPlaying {
                    StreamPlayingPill()
                }
                if let issue = row.compatibilityIssue, !row.isPlaying {
                    Text(issue.tvSafe)
                        .nuvioTextStyle(.metadata)
                        .foregroundStyle(NuvioDesignTokens.Colors.warning)
                        .lineLimit(1)
                }
            }
            if let subtitle = row.subtitle {
                Text(subtitle.tvSafe)
                    .nuvioTextStyle(.compactBody)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(2)
            }
            StreamRowBadgeRow(badges: row.badges)
            if let filename = row.filename {
                Text(filename.tvSafe)
                    .font(.caption2.monospaced())
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
                    .lineLimit(1)
            }
        }
    }

    /// Android outlines the current stream with a translucent primary border.
    private var playingBorder: some View {
        RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md)
            .strokeBorder(
                row.isPlaying
                    ? NuvioDesignTokens.Colors.brand.opacity(0.65)
                    : .clear,
                lineWidth: NuvioDesignTokens.Strokes.thin
            )
            .allowsHitTesting(false)
    }

    private var accessibilityLabel: String {
        ([row.title] + (row.isPlaying ? ["Playing"] : [])).joined(separator: ", ")
    }

    private var accessibilityValue: String {
        var parts = [row.addonName]
        if let issue = row.compatibilityIssue {
            parts.append(issue)
        } else if row.isPlayable {
            parts.append("Ready")
        }
        parts.append(contentsOf: row.badges.map(\.text))
        return parts.joined(separator: ", ")
    }
}

/// Addon filter chip, mirroring Android `SourceStatusFilterChip`:
/// selected state, loading/error status, count.
struct StreamAddonChipView: View {
    let chip: StreamAddonFilterChip
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        switch chip.status {
        case .loading: NuvioDesignTokens.Colors.secondaryText
        case .failure: NuvioDesignTokens.Colors.error
        case .success: chip.isSelected
            ? NuvioDesignTokens.Colors.primaryText
            : NuvioDesignTokens.Colors.secondaryText
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvioDesignTokens.Spacing.xs) {
                if chip.status == .loading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(NuvioDesignTokens.Colors.secondaryText)
                }
                Text(chip.displayName.tvSafe)
                    .nuvioTextStyle(.button)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Text("\(chip.count)")
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(tint.opacity(0.8))
            }
            .padding(.horizontal, NuvioDesignTokens.Spacing.md)
            .frame(minHeight: NuvioDesignTokens.Components.chipHeight)
            .background(
                chip.isSelected
                    ? NuvioDesignTokens.Colors.brand.opacity(0.28)
                    : NuvioDesignTokens.Colors.elevatedSecondary,
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    chip.status == .failure
                        ? NuvioDesignTokens.Colors.error.opacity(0.7)
                        : (chip.isSelected
                            ? NuvioDesignTokens.Colors.brand
                            : NuvioDesignTokens.Colors.neutral700),
                    lineWidth: NuvioDesignTokens.Strokes.hairline
                )
            )
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Components.chipHeight / 2))
        .disabled(!chip.isSelectable)
        .opacity(chip.isSelectable ? 1 : NuvioDesignTokens.Effects.disabledOpacity + 0.3)
        .animation(
            reduceMotion ? nil : NuvioMotion.animation(for: .quick, reduceMotion: false),
            value: chip.isSelected
        )
        .accessibilityLabel("\(chip.displayName), \(chip.count) streams")
        .accessibilityAddTraits(chip.isSelected ? .isSelected : [])
    }
}

/// Compact sort option chip row entry.
struct StreamSortChipView: View {
    let option: StreamSortOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(option.displayName.tvSafe)
                .nuvioTextStyle(.metadata)
                .foregroundStyle(
                    isSelected
                        ? NuvioDesignTokens.Colors.primaryText
                        : NuvioDesignTokens.Colors.secondaryText
                )
                .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
                .frame(minHeight: NuvioDesignTokens.Components.chipHeight - 6)
                .background(
                    isSelected
                        ? NuvioDesignTokens.Colors.neutral700
                        : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Components.chipHeight / 2))
        .accessibilityLabel("Sort by \(option.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
