import SwiftUI

/// SwiftUI building blocks ported from `SettingsDesignSystem.kt`. All controls
/// are presentation-only: values flow in and changes flow out through the
/// change callback.
public enum SettingsDesignMetrics {
    /// `SettingsContainerRadius` = 28.
    public static let containerRadius = NuvioDesignTokens.Shapes.settingsContainerRadius
    /// `SettingsSecondaryCardRadius` = 18.
    public static let cardRadius = NuvioDesignTokens.Shapes.settingsSecondaryCardRadius
    /// `SettingsWorkspaceSurface` padding = 20.
    public static let cardPadding: CGFloat = 20
    /// `Sizes.Settings.rowMinimumHeight` = 64.
    public static let rowMinimumHeight = NuvioDesignTokens.Sizes.Settings.rowMinimumHeight
    /// Row inner padding from `SettingsToggleRow` (18 horizontal, 12 vertical).
    public static let rowHorizontalPadding: CGFloat = 18
    public static let rowVerticalPadding = NuvioDesignTokens.Spacing.md
    public static let sectionSpacing = NuvioDesignTokens.Components.settingsRowGap
    public static let titleSubtitleGap = NuvioDesignTokens.Spacing.xxs
    public static let iconTitleGap = NuvioDesignTokens.Spacing.md
}

/// `SettingsWorkspaceSurface`: the radius-28 elevated container every settings
/// group sits inside.
public struct SettingsWorkspaceContainer<Content: View>: View {
    @ViewBuilder private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SettingsDesignMetrics.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignMetrics.containerRadius, style: .continuous)
                    .fill(NuvioDesignTokens.Colors.elevated)
            )
    }
}

/// `SettingsDetailHeader`: section title and description above the workspace.
public struct SettingsDetailHeader: View {
    private let title: String
    private let subtitle: String?

    public init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            Text(title)
                .font(NuvioTypography.compactDisplay)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            if let subtitle {
                Text(subtitle)
                    .font(NuvioTypography.body)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
        }
        .padding(.leading, NuvioDesignTokens.Spacing.md)
        .padding(.bottom, NuvioDesignTokens.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

/// `SettingsGroupCard`: a nested card grouping rows inside the workspace.
public struct SettingsSectionCard<Content: View>: View {
    private let title: String?
    private let subtitle: String?
    @ViewBuilder private let content: Content

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            if let title {
                Text(title)
                    .font(NuvioTypography.compactTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            }
            if let subtitle {
                Text(subtitle)
                    .font(NuvioTypography.compactBody)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                content
            }
            .frame(maxWidth: .infinity)
            .padding(NuvioDesignTokens.Spacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignMetrics.cardRadius, style: .continuous)
                    .fill(NuvioDesignTokens.Colors.elevatedSecondary)
            )
        }
    }
}

/// Trailing value/control area shared by every row variant.
struct SettingsRowTrailing: View {
    let valueText: String?
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.sm) {
            if let valueText {
                Text(valueText)
                    .font(NuvioTypography.compactBody)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm, weight: .semibold))
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
            }
        }
    }
}

/// Shared leading content of a row: icon plus title/subtitle stack.
public struct SettingsRowLeading: View {
    private let icon: String?
    private let title: String
    private let subtitle: String?

    public init(icon: String?, title: String, subtitle: String?) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        HStack(alignment: .top, spacing: SettingsDesignMetrics.iconTitleGap) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: NuvioDesignTokens.Sizes.Icons.md))
                    .foregroundStyle(NuvioDesignTokens.Colors.brand)
                    .frame(width: NuvioDesignTokens.Sizes.Icons.xl)
            }
            VStack(alignment: .leading, spacing: SettingsDesignMetrics.titleSubtitleGap) {
                Text(title)
                    .font(NuvioTypography.cardTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(NuvioTypography.compactBody)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                        .lineLimit(2)
                }
            }
        }
    }
}

/// `SettingsToggleRow`: emits `.toggle` changes without owning state.
public struct SettingsToggleRow: View {
    private let setting: NuvioSetting
    private let onChange: (NuvioSettingsChange) -> Void

    public init(setting: NuvioSetting, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.setting = setting
        self.onChange = onChange
    }

    public var body: some View {
        let isOn = setting.value == .toggle(true)
        Button {
            onChange(NuvioSettingsChange(settingID: setting.id, value: .toggle(!isOn)))
        } label: {
            HStack(spacing: NuvioDesignTokens.Spacing.lg) {
                SettingsRowLeading(
                    icon: setting.systemImage,
                    title: setting.title,
                    subtitle: setting.subtitle
                )
                Spacer(minLength: NuvioDesignTokens.Spacing.md)
                Toggle("", isOn: .constant(isOn))
                    .labelsHidden()
                    .tint(NuvioDesignTokens.Colors.brand)
                    .disabled(true)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, SettingsDesignMetrics.rowHorizontalPadding)
            .padding(.vertical, SettingsDesignMetrics.rowVerticalPadding)
            .frame(minHeight: SettingsDesignMetrics.rowMinimumHeight)
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.md))
        .opacity(setting.isEnabled ? 1 : NuvioDesignTokens.Effects.disabledOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(setting.title))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
    }
}

/// Navigation/action row: `SettingsActionRow` with value and chevron.
public struct SettingsActionRowView: View {
    private let setting: NuvioSetting
    private let onChange: (NuvioSettingsChange) -> Void

    public init(setting: NuvioSetting, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.setting = setting
        self.onChange = onChange
    }

    public var body: some View {
        Button {
            onChange(NuvioSettingsChange(settingID: setting.id, value: setting.value))
        } label: {
            HStack(spacing: NuvioDesignTokens.Spacing.lg) {
                SettingsRowLeading(
                    icon: setting.systemImage,
                    title: setting.title,
                    subtitle: setting.subtitle
                )
                Spacer(minLength: NuvioDesignTokens.Spacing.md)
                SettingsRowTrailing(
                    valueText: setting.valueText,
                    showsChevron: setting.kind == .navigation
                )
            }
            .padding(.horizontal, SettingsDesignMetrics.rowHorizontalPadding)
            .padding(.vertical, SettingsDesignMetrics.rowVerticalPadding)
            .frame(minHeight: SettingsDesignMetrics.rowMinimumHeight)
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.md))
        .opacity(setting.isEnabled ? 1 : NuvioDesignTokens.Effects.disabledOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(setting.title))
        .accessibilityValue(Text(setting.valueText ?? ""))
    }
}

/// `SliderSettingsItem`: a custom tvOS stepper-track control. SwiftUI `Slider`
/// does not exist on tvOS, so the row is focusable and the Siri Remote's
/// left/right moves step the value; every step flows out through `onChange`.
public struct SettingsSliderRow: View {
    private let setting: NuvioSetting
    private let onChange: (NuvioSettingsChange) -> Void

    public init(setting: NuvioSetting, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.setting = setting
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.lg) {
            SettingsRowLeading(
                icon: setting.systemImage,
                title: setting.title,
                subtitle: setting.subtitle
            )
            SettingsSliderControl(
                value: numberValue(setting.value),
                range: sliderRange,
                step: sliderStep,
                isEnabled: setting.isEnabled
            ) { newValue in
                onChange(NuvioSettingsChange(settingID: setting.id, value: .number(newValue)))
            }
            .frame(width: 320)
            SettingsRowTrailing(valueText: setting.valueText, showsChevron: false)
                .frame(minWidth: 90, alignment: .trailing)
        }
        .padding(.horizontal, SettingsDesignMetrics.rowHorizontalPadding)
        .padding(.vertical, SettingsDesignMetrics.rowVerticalPadding)
        .frame(minHeight: SettingsDesignMetrics.rowMinimumHeight)
        .opacity(setting.isEnabled ? 1 : NuvioDesignTokens.Effects.disabledOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(setting.title))
        .accessibilityValue(Text(setting.valueText ?? ""))
    }

    private var spec: NuvioSliderSpec? {
        if case .slider(let spec) = setting.kind { return spec }
        return nil
    }

    private var sliderRange: ClosedRange<Double> {
        guard let spec else { return 0...1 }
        return spec.minimum...spec.maximum
    }

    private var sliderStep: Double {
        spec?.step ?? 1
    }

    private func numberValue(_ value: NuvioSettingValue) -> Double {
        if case .number(let n) = value { return n }
        return 0
    }
}

/// Segmented control for short option lists (`SettingsTopBarTab`-style pill).
public struct SettingsSegmentedRow: View {
    private let setting: NuvioSetting
    private let onChange: (NuvioSettingsChange) -> Void
    @State private var selection: String?

    public init(setting: NuvioSetting, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.setting = setting
        self.onChange = onChange
    }

    public var body: some View {
        if case .segmented(let options) = setting.kind {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
                SettingsRowLeading(
                    icon: setting.systemImage,
                    title: setting.title,
                    subtitle: setting.subtitle
                )
                Picker(setting.title, selection: Binding(
                    get: { selection ?? selectedID(options) },
                    set: { newValue in
                        selection = newValue
                        onChange(NuvioSettingsChange(settingID: setting.id, value: .option(newValue)))
                    }
                )) {
                    ForEach(options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 560)
                .onAppear { selection = selectedID(options) }
            }
            .padding(.horizontal, SettingsDesignMetrics.rowHorizontalPadding)
            .padding(.vertical, SettingsDesignMetrics.rowVerticalPadding)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(setting.title))
        }
    }

    private func selectedID(_ options: [NuvioSettingOption]) -> String {
        if case .option(let id) = setting.value { return id }
        return options.first?.id ?? ""
    }
}
