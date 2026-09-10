import SwiftUI

// MARK: - Color helpers

extension Color {
    /// Color from an Android-packed ARGB integer (e.g. `0xFF00E5FF`).
    init(nuvioARGB argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}

extension UInt32 {
    /// The RGB channels of an ARGB color, for chip selection comparison.
    var nuvioRGB: UInt32 { self & 0x00_FF_FF_FF }
}

// MARK: - Focus-aware row style

/// Side-panel row button style matching the player selection panels: focused
/// rows invert to white with black text, unfocused rows sit on a translucent
/// surface with a hairline border.
struct SubtitlePanelRowStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .background(
                isFocused ? Color.white : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.lg, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.lg, style: .continuous)
                    .stroke(
                        isFocused ? Color.clear : Color.white.opacity(0.16),
                        lineWidth: NuvioDesignTokens.Strokes.hairline
                    )
            }
            .scaleEffect(
                configuration.isPressed ? NuvioDesignTokens.Focus.pressedScale : 1
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Smaller circular style used by stepper buttons inside panel rows.
/// Focused inverts to a solid white circle with a black glyph, matching the
/// row style so every focused control in a panel has full contrast.
struct SubtitlePanelStepButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .frame(width: 44, height: 44)
            .background(
                (isFocused ? Color.white : Color.white.opacity(0.14)),
                in: Circle()
            )
            .scaleEffect(
                reduceMotion ? 1 : (isFocused ? 1.06 : (configuration.isPressed ? NuvioDesignTokens.Focus.pressedScale : 1))
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isFocused)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Shared rows

/// Section header inside a player side panel.
struct SubtitlePanelSectionHeader: View {
    let title: String
    var badge: Int?

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.sm) {
            Text(title.tvSafe)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            if let badge, badge > 0 {
                Text("\(badge)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
                    .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
                    .background(NuvioDesignTokens.Colors.brand, in: Capsule())
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

/// A selectable track row: title, source chip, meta line, selected checkmark.
struct SubtitlePanelTrackRow: View {
    let title: String
    let sourceLabel: String
    let meta: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvioDesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                    HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                        Text(title.tvSafe).lineLimit(1)
                        Text(sourceLabel.tvSafe)
                            .font(.caption2)
                            .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
                            .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
                            .background(Color.white.opacity(0.1), in: Capsule())
                    }
                    if let meta, !meta.isEmpty {
                        Text(meta.tvSafe)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .accessibilityLabel("Selected")
                }
            }
            .font(.callout)
            .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
        .buttonStyle(SubtitlePanelRowStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Stepper row used by the delay, size, opacity, and offset controls: a
/// label, current value, and − / + buttons.
struct SubtitlePanelStepperRow: View {
    let title: String
    let value: String
    let decrementLabel: String
    let incrementLabel: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xxs) {
                Text(title.tvSafe)
                Text(value)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: decrement) {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(SubtitlePanelStepButtonStyle())
            .accessibilityLabel(decrementLabel)
            Button(action: increment) {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(SubtitlePanelStepButtonStyle())
            .accessibilityLabel(incrementLabel)
        }
        .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), \(value)")
    }
}

/// On/off toggle row (SDH filter, bold, outline).
struct SubtitlePanelToggleRow: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title.tvSafe)
                Spacer()
                Text(isOn ? "On" : "Off")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isOn ? Color.white : Color.secondary)
            }
            .font(.callout)
            .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
        .buttonStyle(SubtitlePanelRowStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(isOn ? "Currently on" : "Currently off")
    }
}

/// Circular color swatches with a selected ring, mirroring the Android
/// `ColorChipRow` / `SubtitleStyleColorChip`.
struct SubtitlePanelColorChipRow: View {
    let colors: [UInt32]
    let selectedRGB: UInt32
    var enabled = true
    let action: (UInt32) -> Void

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.sm) {
            ForEach(colors, id: \.self) { color in
                SubtitlePanelColorChip(
                    color: color,
                    isSelected: color.nuvioRGB == selectedRGB,
                    enabled: enabled
                ) {
                    action(color)
                }
            }
            Spacer()
        }
        .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
        .accessibilityElement(children: .contain)
    }
}

private struct SubtitlePanelColorChip: View {
    let color: UInt32
    let isSelected: Bool
    let enabled: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(nuvioARGB: color))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(
                            isLightColor(color) ? Color.black : Color.white
                        )
                }
            }
            .frame(width: 34, height: 34)
            .overlay {
                Circle().stroke(
                    (isFocused || isSelected) ? Color.white : Color.clear,
                    lineWidth: NuvioDesignTokens.Focus.ringWidth
                )
            }
            .scaleEffect(
                reduceMotion ? 1 : (isFocused ? 1.15 : 1)
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isFocused)
            .opacity(enabled ? 1 : NuvioDesignTokens.Effects.disabledOpacity)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(isSelected ? "Selected color" : "Color option")
    }

    private func isLightColor(_ argb: UInt32) -> Bool {
        let red = Double((argb >> 16) & 0xFF) / 255
        let green = Double((argb >> 8) & 0xFF) / 255
        let blue = Double(argb & 0xFF) / 255
        return (red + green + blue) / 3 > 0.5
    }
}

/// Full-width text action row (footer actions).
struct SubtitlePanelActionRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.tvSafe)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(SubtitlePanelRowStyle())
    }
}
