import SwiftUI

/// Native tvOS port of the Android `SubtitleStyleSidePanel.kt`: font size
/// steps, text color and opacity, background style, edge (outline) style,
/// and bottom position offset, with a live preview of the rendered subtitle.
struct SubtitleStylePanel: View {
    let style: SubtitleStyleOptions
    let onChange: (SubtitleStyleOptions) -> Void
    let onClose: () -> Void

    init(
        style: SubtitleStyleOptions,
        onChange: @escaping (SubtitleStyleOptions) -> Void,
        onClose: @escaping () -> Void = {}
    ) {
        self.style = style
        self.onChange = onChange
        self.onClose = onClose
    }

    private static let previewText = "The quick brown fox jumps over the lazy dog"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.12))
            ScrollView {
                VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.lg) {
                    preview
                    sizingSection
                    colorSection
                    backgroundSection
                    edgeSection
                    positionSection
                    resetSection
                }
                .padding(NuvioDesignTokens.Spacing.SidePanel.outer)
            }
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
            Text("Subtitle Appearance")
                .font(.title3.weight(.semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close appearance panel")
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

    // MARK: Live preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            SubtitlePanelSectionHeader(title: "Preview")
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        NuvioDesignTokens.Colors.neutral850,
                        NuvioDesignTokens.Colors.neutral800,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                Text(Self.previewText)
                    .font(
                        .system(
                            size: previewFontSize,
                            weight: style.bold ? .bold : .regular
                        )
                    )
                    .foregroundStyle(Color(nuvioARGB: style.textColorARGB))
                    .background(
                        style.backgroundAlpha255 > 0
                            ? Color.black.opacity(Double(style.backgroundAlpha255) / 255)
                            : nil
                    )
                    .shadow(
                        color: style.outlineEnabled
                            ? Color(nuvioARGB: style.outlineColorARGB)
                            : .clear,
                        radius: style.outlineEnabled ? CGFloat(style.outlineWidth) : 0
                    )
                    .padding(.horizontal, NuvioDesignTokens.Spacing.md)
                    .padding(
                        .bottom,
                        previewBottomPadding + NuvioDesignTokens.Spacing.lg
                    )
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .clipShape(
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.lg, style: .continuous)
            )
            .accessibilityLabel("Subtitle style preview")
        }
    }

    /// Maps the 50-200% size range onto the preview text point size.
    private var previewFontSize: CGFloat {
        12 + CGFloat(style.sizePercent - SubtitleStyleOptions.sizeRange.lowerBound) * 0.14
    }

    /// Maps the -20...50 offset range onto preview padding.
    private var previewBottomPadding: CGFloat {
        CGFloat(max(style.verticalOffset, 0)) * 0.6
    }

    // MARK: Sections

    private var sizingSection: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            SubtitlePanelSectionHeader(title: "Font Size")
            SubtitlePanelStepperRow(
                title: "Text Size",
                value: "\(style.sizePercent)%",
                decrementLabel: "Smaller subtitle text",
                incrementLabel: "Larger subtitle text",
                decrement: { onChange(style.adjustingSize(by: -SubtitleStyleOptions.sizeStep)) },
                increment: { onChange(style.adjustingSize(by: SubtitleStyleOptions.sizeStep)) }
            )
            SubtitlePanelToggleRow(
                title: "Bold",
                isOn: style.bold,
                action: { onChange(style.togglingBold()) }
            )
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            SubtitlePanelSectionHeader(title: "Text Color")
            SubtitlePanelColorChipRow(
                colors: SubtitleStyleOptions.textColorPalette,
                selectedRGB: style.textColorARGB.nuvioRGB
            ) { color in
                onChange(style.settingTextColor(color))
            }
            SubtitlePanelStepperRow(
                title: "Text Opacity",
                value: "\(style.textOpacityPercent)%",
                decrementLabel: "Decrease text opacity",
                incrementLabel: "Increase text opacity",
                decrement: {
                    onChange(
                        style.adjustingTextOpacity(
                            byPercentStep: -SubtitleStyleOptions.opacityStepPercent
                        )
                    )
                },
                increment: {
                    onChange(
                        style.adjustingTextOpacity(
                            byPercentStep: SubtitleStyleOptions.opacityStepPercent
                        )
                    )
                }
            )
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            SubtitlePanelSectionHeader(title: "Background")
            SubtitlePanelStepperRow(
                title: "Background Style",
                value: backgroundStyleLabel,
                decrementLabel: "More transparent subtitle background",
                incrementLabel: "More opaque subtitle background",
                decrement: {
                    onChange(
                        style.settingBackgroundOpacity(
                            percent: style.backgroundOpacityPercent
                                - SubtitleStyleOptions.backgroundOpacityStepPercent
                        )
                    )
                },
                increment: {
                    onChange(
                        style.settingBackgroundOpacity(
                            percent: style.backgroundOpacityPercent
                                + SubtitleStyleOptions.backgroundOpacityStepPercent
                        )
                    )
                }
            )
        }
    }

    private var backgroundStyleLabel: String {
        style.backgroundOpacityPercent == 0
            ? "None"
            : "\(style.backgroundOpacityPercent)%"
    }

    private var edgeSection: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            SubtitlePanelSectionHeader(title: "Edge Style")
            SubtitlePanelToggleRow(
                title: "Outline",
                isOn: style.outlineEnabled,
                action: { onChange(style.togglingOutline()) }
            )
            SubtitlePanelColorChipRow(
                colors: SubtitleStyleOptions.outlineColorPalette,
                selectedRGB: style.outlineColorARGB.nuvioRGB,
                enabled: style.outlineEnabled
            ) { color in
                // Selecting an outline color enables the outline (Android
                // overlay behavior).
                onChange(style.settingOutlineColor(color))
            }
            SubtitlePanelStepperRow(
                title: "Outline Width",
                value: "\(style.outlineWidth)",
                decrementLabel: "Thinner subtitle outline",
                incrementLabel: "Thicker subtitle outline",
                decrement: {
                    onChange(style.settingOutlineWidth(style.outlineWidth - 1))
                },
                increment: {
                    onChange(style.settingOutlineWidth(style.outlineWidth + 1))
                }
            )
        }
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            SubtitlePanelSectionHeader(title: "Position")
            SubtitlePanelStepperRow(
                title: "Bottom Offset",
                value: "\(style.verticalOffset)",
                decrementLabel: "Move subtitles lower",
                incrementLabel: "Move subtitles higher",
                decrement: {
                    onChange(
                        style.adjustingVerticalOffset(
                            by: -SubtitleStyleOptions.verticalOffsetStep
                        )
                    )
                },
                increment: {
                    onChange(
                        style.adjustingVerticalOffset(
                            by: SubtitleStyleOptions.verticalOffsetStep
                        )
                    )
                }
            )
        }
    }

    private var resetSection: some View {
        SubtitlePanelActionRow(title: "Reset to Defaults") {
            onChange(style.resettingStyleDefaults())
        }
    }
}
