import SwiftUI

/// Option picker row: shows the current value and presents the full option
/// list when activated (`SettingsSingleChoiceDialog`).
public struct SettingsOptionPickerRow: View {
    private let setting: NuvioSetting
    private let onChange: (NuvioSettingsChange) -> Void
    @State private var isPresented = false

    public init(setting: NuvioSetting, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.setting = setting
        self.onChange = onChange
    }

    public var body: some View {
        SettingsActionRowView(setting: setting) { _ in
            isPresented = true
        }
        .sheet(isPresented: $isPresented) {
            SettingsOptionPickerSheet(setting: setting) { option in
                isPresented = false
                onChange(NuvioSettingsChange(settingID: setting.id, value: .option(option.id)))
            }
        }
    }
}

/// `SettingsSingleChoiceDialog` equivalent rendered as a sheet list.
struct SettingsOptionPickerSheet: View {
    let setting: NuvioSetting
    let onSelect: (NuvioSettingOption) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                SettingsDetailHeader(title: setting.title, subtitle: setting.subtitle)
                if case .optionPicker(let options) = setting.kind {
                    ForEach(options) { option in
                        SettingsOptionRow(option: option, isSelected: option.id == selectedID) {
                            onSelect(option)
                        }
                    }
                }
            }
            .padding(SettingsDesignMetrics.cardPadding)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .background(NuvioDesignTokens.Colors.canvas)
        .background(BackgroundDismissal(onDismiss: { dismiss() }))
    }

    private var selectedID: String {
        if case .option(let id) = setting.value { return id }
        return ""
    }
}

struct SettingsOptionRow: View {
    let option: NuvioSettingOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: NuvioDesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xxs) {
                    Text(option.title)
                        .font(NuvioTypography.cardTitle)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(NuvioTypography.compactBody)
                            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(NuvioDesignTokens.Colors.brand)
                }
            }
            .padding(SettingsDesignMetrics.cardPadding)
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: SettingsDesignMetrics.cardRadius))
    }
}

/// Allows tapping outside the sheet to dismiss it, like the Android dialog
/// scrim.
struct BackgroundDismissal: View {
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.black.opacity(0.01)
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .ignoresSafeArea()
            .frame(width: 3000, height: 3000)
            .accessibilityHidden(true)
    }
}

/// Native-focus track control: focused once, remote left/right adjusts the
/// value by one step. Reduce Motion keeps the knob snap instant.
struct SettingsSliderControl: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let isEnabled: Bool
    let onValueChange: (Double) -> Void

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((value - range.lowerBound) / span)
    }

    var body: some View {
        GeometryReader { proxy in
            let trackHeight: CGFloat = 8
            let knobSize: CGFloat = isFocused ? 26 : 20
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NuvioDesignTokens.Colors.neutral800)
                    .frame(height: trackHeight)
                Capsule()
                    .fill(isFocused ? NuvioDesignTokens.Colors.brandFocus : NuvioDesignTokens.Colors.brand)
                    .frame(width: max(trackHeight, proxy.size.width * fraction), height: trackHeight)
                Circle()
                    .fill(NuvioDesignTokens.Colors.primaryText)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: proxy.size.width * fraction - knobSize / 2)
                    .frame(maxHeight: .infinity)
                    .animation(
                        reduceMotion ? nil : NuvioMotion.animation(
                            for: .focus, reduceMotion: reduceMotion
                        ),
                        value: value
                    )
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 40)
        .focusable(isEnabled)
        .focused($isFocused)
        .onMoveCommand { direction in
            switch direction {
            case .left: stepValue(-1)
            case .right: stepValue(1)
            default: break
            }
        }
        .nuvioFocusStyle(cornerRadius: NuvioDesignTokens.Shapes.sm, focusedScale: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text("\(Int(value))"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: stepValue(1)
            case .decrement: stepValue(-1)
            @unknown default: break
            }
        }
    }

    private func stepValue(_ direction: Int) {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return }
        let stepped = value + Double(direction) * step
        let clamped = Swift.min(Swift.max(stepped, range.lowerBound), range.upperBound)
        guard clamped != value else { return }
        onValueChange(clamped)
    }
}
