import SwiftUI

/// Generic renderer for a `NuvioSettingsSection`: one `SettingsSectionCard`
/// with a row per setting, dispatched by kind.
public struct SettingsSectionListView: View {
    private let section: NuvioSettingsSection
    private let onChange: (NuvioSettingsChange) -> Void

    public init(section: NuvioSettingsSection, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.section = section
        self.onChange = onChange
    }

    public var body: some View {
        SettingsSectionCard(title: section.title, subtitle: section.subtitle) {
            ForEach(section.settings) { setting in
                SettingsSettingRow(setting: setting, onChange: onChange)
            }
        }
    }
}

/// Renders a single `NuvioSetting` with the control matching its kind.
public struct SettingsSettingRow: View {
    private let setting: NuvioSetting
    private let onChange: (NuvioSettingsChange) -> Void

    public init(setting: NuvioSetting, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.setting = setting
        self.onChange = onChange
    }

    public var body: some View {
        switch setting.kind {
        case .toggle:
            SettingsToggleRow(setting: setting, onChange: onChange)
        case .slider:
            SettingsSliderRow(setting: setting, onChange: onChange)
        case .optionPicker, .navigation:
            if optionCount > 8 {
                SettingsOptionPickerRow(setting: setting, onChange: onChange)
            } else {
                SettingsActionRowView(setting: setting) { change in
                    if case .optionPicker(let options) = setting.kind,
                       let current = optionID,
                       let index = options.firstIndex(where: { $0.id == current }) {
                        // Cycle to the next option on activation, like the
                        // Android value stepper.
                        let next = options[(index + 1) % options.count]
                        onChange(NuvioSettingsChange(settingID: setting.id, value: .option(next.id)))
                    } else {
                        onChange(change)
                    }
                }
            }
        case .segmented:
            SettingsSegmentedRow(setting: setting, onChange: onChange)
        case .info, .action:
            SettingsActionRowView(setting: setting, onChange: onChange)
        }
    }

    private var optionCount: Int {
        if case .optionPicker(let options) = setting.kind { return options.count }
        return 0
    }

    private var optionID: String? {
        if case .option(let id) = setting.value { return id }
        return nil
    }
}

/// Settings root: category rail on the leading edge (rail width 260, item
/// height 56 from `Sizes.Settings`) and the selected category's sections.
public struct SettingsRootView: View {
    private let state: NuvioSettingsState
    private let diagnostics: NuvioPlaybackDiagnostics
    private let onChange: (NuvioSettingsChange) -> Void
    private let onSelectCategory: ((NuvioSettingsCategory) -> Void)?

    @State private var selectedCategory: NuvioSettingsCategory = .layout
    @FocusState private var focusedCategory: NuvioSettingsCategory?

    public init(
        state: NuvioSettingsState,
        diagnostics: NuvioPlaybackDiagnostics = NuvioPlaybackDiagnostics(),
        onChange: @escaping (NuvioSettingsChange) -> Void,
        onSelectCategory: ((NuvioSettingsCategory) -> Void)? = nil
    ) {
        self.state = state
        self.diagnostics = diagnostics
        self.onChange = onChange
        self.onSelectCategory = onSelectCategory
    }

    public var body: some View {
        HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xxs) {
                ForEach(NuvioSettingsCategory.allCases, id: \.self) { category in
                    SettingsRailButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        onSelectCategory?(category)
                    }
                    .focused($focusedCategory, equals: category)
                }
            }
            .frame(width: NuvioDesignTokens.Sizes.Settings.railWidth, alignment: .leading)
            ScrollView {
                VStack(alignment: .leading, spacing: SettingsDesignMetrics.sectionSpacing) {
                    categoryHeader
                    switch selectedCategory {
                    case .layout:
                        LayoutSettingsView(state: state, onChange: onChange)
                    case .playback:
                        PlaybackSettingsView(state: state, onChange: onChange)
                    case .network:
                        NetworkSettingsView(state: state, onChange: onChange)
                    case .integrations:
                        IntegrationsSettingsView(state: state, onChange: onChange)
                    case .diagnostics:
                        DiagnosticsSettingsView(state: state, diagnostics: diagnostics, onChange: onChange)
                    case .about:
                        AboutSettingsView(state: state, onChange: onChange)
                    }
                }
                .padding(.vertical, NuvioDesignTokens.Spacing.Screen.vertical)
            }
        }
        .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.horizontal)
        .defaultFocus($focusedCategory, .layout)
    }

    private var categoryHeader: some View {
        SettingsDetailHeader(
            title: selectedCategory.title,
            subtitle: selectedCategory.subtitle
        )
    }
}

/// `SettingsRailButton`: pill-shaped rail entry with icon, title, and selected
/// indicator.
struct SettingsRailButton: View {
    let category: NuvioSettingsCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvioDesignTokens.Spacing.md) {
                Image(systemName: category.systemImage)
                    .font(.system(size: NuvioDesignTokens.Sizes.Icons.md))
                    .foregroundStyle(isSelected ? NuvioDesignTokens.Colors.primaryText : NuvioDesignTokens.Colors.secondaryText)
                    .frame(width: NuvioDesignTokens.Sizes.Icons.xl)
                Text(category.title)
                    .font(NuvioTypography.cardTitle)
                    .foregroundStyle(isSelected ? NuvioDesignTokens.Colors.primaryText : NuvioDesignTokens.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, SettingsDesignMetrics.rowHorizontalPadding)
            .frame(height: NuvioDesignTokens.Sizes.Settings.railItemHeight)
            .background(
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
                    .fill(isSelected ? NuvioDesignTokens.Colors.elevatedSecondary : .clear)
            )
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.md))
        .accessibilityLabel(Text(category.title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Layout screen: the three layout cards with previews, layout-specific
/// toggles, and the theme picker.
public struct LayoutSettingsView: View {
    private let state: NuvioSettingsState
    private let onChange: (NuvioSettingsChange) -> Void

    public init(state: NuvioSettingsState, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.state = state
        self.onChange = onChange
    }

    public var body: some View {
        SettingsWorkspaceContainer {
            VStack(alignment: .leading, spacing: SettingsDesignMetrics.sectionSpacing) {
                ForEach(NuvioSettingsTree.sections(in: .layout, state: state)) { section in
                    if section.id == "layout.home" {
                        layoutSection(section)
                    } else {
                        SettingsSectionListView(section: section, onChange: onChange)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func layoutSection(_ section: NuvioSettingsSection) -> some View {
        SettingsSectionCard(title: section.title, subtitle: section.subtitle) {
            HStack(spacing: NuvioDesignTokens.Spacing.md) {
                ForEach(NuvioSettingsTree.layoutOptions) { option in
                    if let layout = NuvioHomeLayout(rawValue: option.id) {
                        SettingsLayoutCard(
                            layout: layout,
                            isSelected: state.homeLayout == layout,
                            animated: state.homeLayout == layout
                        ) {
                            onChange(NuvioSettingsChange(
                                settingID: "layout.homeLayout",
                                value: .option(layout.rawValue)
                            ))
                        }
                    }
                }
            }
            ForEach(section.settings.filter { $0.id != "layout.homeLayout" }) { setting in
                SettingsSettingRow(setting: setting, onChange: onChange)
            }
        }
    }
}

/// `LayoutCard`: 112-point preview, check mark, and label.
struct SettingsLayoutCard: View {
    let layout: NuvioHomeLayout
    let isSelected: Bool
    let animated: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .center, spacing: NuvioDesignTokens.Spacing.sm - 2) {
                NuvioLayoutPreviewView(layout: layout, animated: animated)
                    .frame(height: 112)
                HStack(spacing: NuvioDesignTokens.Spacing.xs) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm, weight: .semibold))
                            .foregroundStyle(NuvioDesignTokens.Colors.brand)
                    }
                    Text(layout.shortName)
                        .font(NuvioTypography.compactTitle)
                        .foregroundStyle(
                            isSelected
                                ? NuvioDesignTokens.Colors.primaryText
                                : NuvioDesignTokens.Colors.secondaryText
                        )
                }
            }
            .padding(NuvioDesignTokens.Spacing.sm + 2)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignMetrics.cardRadius, style: .continuous)
                    .fill(NuvioDesignTokens.Colors.elevatedSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsDesignMetrics.cardRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? NuvioDesignTokens.Colors.brand : .clear,
                        lineWidth: NuvioDesignTokens.Strokes.hairline
                    )
            )
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: SettingsDesignMetrics.cardRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(layout.displayName))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Playback screen: General, Audio, Subtitles, Autoplay, and Buffer & Network.
public struct PlaybackSettingsView: View {
    private let state: NuvioSettingsState
    private let onChange: (NuvioSettingsChange) -> Void

    public init(state: NuvioSettingsState, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.state = state
        self.onChange = onChange
    }

    public var body: some View {
        SettingsWorkspaceContainer {
            VStack(alignment: .leading, spacing: SettingsDesignMetrics.sectionSpacing) {
                ForEach(NuvioSettingsTree.playbackSections(state)) { section in
                    SettingsSectionListView(section: section, onChange: onChange)
                }
            }
        }
    }
}

/// Integrations screen: placeholder navigation rows for the integration hub
/// sections from `SettingsScreen.kt`.
public struct IntegrationsSettingsView: View {
    private let state: NuvioSettingsState
    private let onChange: (NuvioSettingsChange) -> Void

    public init(state: NuvioSettingsState, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.state = state
        self.onChange = onChange
    }

    public var body: some View {
        SettingsWorkspaceContainer {
            VStack(alignment: .leading, spacing: SettingsDesignMetrics.sectionSpacing) {
                ForEach(NuvioSettingsTree.sections(in: .integrations, state: state)) { section in
                    SettingsSectionListView(section: section, onChange: onChange)
                }
            }
        }
    }
}
