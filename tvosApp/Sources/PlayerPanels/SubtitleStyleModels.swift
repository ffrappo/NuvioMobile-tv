import Foundation

/// Subtitle appearance options, port of Android `SubtitleStyleSettings`
/// (`PlayerSettingsDataStore.kt`) with the DataStore clamp ranges.
struct SubtitleStyleOptions: Equatable {
    // MARK: Ranges and steps (DataStore setters + overlay steppers)

    /// `setSubtitleSize` clamps to 50...200; the overlay steps by 10.
    static let sizeRange: ClosedRange<Int> = 50...200
    static let sizeStep = 10
    /// Android data-class default (120). The DataStore read fallback is 100;
    /// the reset event restores the data-class defaults, so 120 wins here.
    static let defaultSize = 120

    /// `setSubtitleVerticalOffset` clamps to -20...50; steps by 5.
    static let verticalOffsetRange: ClosedRange<Int> = -20...50
    static let verticalOffsetStep = 5
    static let defaultVerticalOffset = 5

    /// `setSubtitleOutlineWidth` clamps to 1...5.
    static let outlineWidthRange: ClosedRange<Int> = 1...5
    static let defaultOutlineWidth = 2

    /// Text opacity stepper steps by 10 percent (overlay `StepperRow`).
    static let opacityStepPercent = 10

    /// Background opacity stepper steps by 10 percent.
    static let backgroundOpacityStepPercent = 10

    // MARK: Fields (SubtitleStyleSettings)

    var preferredLanguage = "en"
    var isPreferredLanguageSystemDefault = true
    var secondaryPreferredLanguage: String? = nil
    var useForcedSubtitles = false
    var showOnlyPreferredLanguages = false
    /// SDH filter state: strips sound descriptions from caption text.
    var stripSdh = false
    var sizePercent = SubtitleStyleOptions.defaultSize
    var verticalOffset = SubtitleStyleOptions.defaultVerticalOffset
    var bold = false
    /// ARGB packed color, matching the Android Int color storage.
    var textColorARGB: UInt32 = 0xFF_FF_FF_FF
    var backgroundColorARGB: UInt32 = 0x00_00_00_00
    var outlineEnabled = true
    var outlineColorARGB: UInt32 = 0xFF_00_00_00
    var outlineWidth = SubtitleStyleOptions.defaultOutlineWidth

    init() {}

    /// Text color palette offered by the Android overlay and style panel.
    static let textColorPalette: [UInt32] = [
        0xFF_FF_FF_FF, 0xFF_D9_D9_D9, 0xFF_FF_D7_00,
        0xFF_00_E5_FF, 0xFF_FF_5C_5C, 0xFF_00_FF_88,
    ]
    /// Outline color palette offered by the Android overlay and style panel.
    static let outlineColorPalette: [UInt32] = [
        0xFF_00_00_00, 0xFF_FF_FF_FF, 0xFF_00_E5_FF, 0xFF_FF_5C_5C,
    ]

    // MARK: Clamping and stepper math

    /// Applies every DataStore clamp (used both after loading persisted
    /// values and after each stepper interaction).
    func clamped() -> SubtitleStyleOptions {
        var value = self
        value.sizePercent = value.sizePercent.clamped(to: SubtitleStyleOptions.sizeRange)
        value.verticalOffset = value.verticalOffset.clamped(to: SubtitleStyleOptions.verticalOffsetRange)
        value.outlineWidth = value.outlineWidth.clamped(to: SubtitleStyleOptions.outlineWidthRange)
        return value
    }

    /// `OnSetSubtitleSize(size ± 10)`.
    func adjustingSize(by step: Int) -> SubtitleStyleOptions {
        var value = self
        value.sizePercent = (sizePercent + step).clamped(to: SubtitleStyleOptions.sizeRange)
        return value
    }

    /// `OnSetSubtitleVerticalOffset(offset ± 5)`.
    func adjustingVerticalOffset(by step: Int) -> SubtitleStyleOptions {
        var value = self
        value.verticalOffset = (verticalOffset + step)
            .clamped(to: SubtitleStyleOptions.verticalOffsetRange)
        return value
    }

    /// Text opacity stepper: keeps the RGB channels of the current text color
    /// and moves its alpha in 10% increments (overlay text-opacity row).
    func adjustingTextOpacity(byPercentStep step: Int) -> SubtitleStyleOptions {
        var value = self
        let currentPercent = Int(round(Double(textAlpha255) / 255 * 100))
        let nextPercent = (currentPercent + step).clamped(to: 0...100)
        value.textColorARGB = (UInt32(nextPercent) * 255 / 100) << 24 | (textColorARGB & 0x00_FF_FF_FF)
        return value
    }

    /// Text color chip selection: keeps the current alpha, replaces RGB
    /// (both the overlay rail and `SubtitleStyleSidePanel` do this).
    func settingTextColor(_ colorARGB: UInt32) -> SubtitleStyleOptions {
        var value = self
        value.textColorARGB = (textColorARGB & 0xFF_00_00_00) | (colorARGB & 0x00_FF_FF_FF)
        return value
    }

    /// Background style stepper: black background with an alpha in 10% steps
    /// (0% = transparent, the Android default).
    func settingBackgroundOpacity(percent: Int) -> SubtitleStyleOptions {
        var value = self
        let clampedPercent = percent.clamped(to: 0...100)
        value.backgroundColorARGB = (UInt32(clampedPercent) * 255 / 100) << 24
        return value
    }

    var backgroundOpacityPercent: Int { Int(backgroundAlpha255) * 100 / 255 }
    var textAlpha255: UInt32 { (textColorARGB >> 24) & 0xFF }
    var backgroundAlpha255: UInt32 { (backgroundColorARGB >> 24) & 0xFF }
    var textOpacityPercent: Int { Int(textAlpha255) * 100 / 255 }

    /// `OnSetSubtitleBold(!bold)`.
    func togglingBold() -> SubtitleStyleOptions {
        var value = self
        value.bold.toggle()
        return value
    }

    /// `OnSetSubtitleOutlineEnabled(!outlineEnabled)`.
    func togglingOutline() -> SubtitleStyleOptions {
        var value = self
        value.outlineEnabled.toggle()
        return value
    }

    /// Outline color chip selection enables the outline first when it is off,
    /// matching the Android overlay's `ColorChipRow` behavior.
    func settingOutlineColor(_ colorARGB: UInt32) -> SubtitleStyleOptions {
        var value = self
        value.outlineEnabled = true
        value.outlineColorARGB = colorARGB
        return value
    }

    func settingOutlineWidth(_ width: Int) -> SubtitleStyleOptions {
        var value = self
        value.outlineWidth = width.clamped(to: SubtitleStyleOptions.outlineWidthRange)
        return value
    }

    /// `OnResetSubtitleDefaults`: restores the style fields to the Android
    /// data-class defaults. Language preferences are deliberately kept, the
    /// same way the Android reset event only writes the style fields.
    func resettingStyleDefaults() -> SubtitleStyleOptions {
        var value = self
        value.sizePercent = SubtitleStyleOptions.defaultSize
        value.textColorARGB = 0xFF_FF_FF_FF
        value.bold = false
        value.outlineEnabled = true
        value.outlineColorARGB = 0xFF_00_00_00
        value.outlineWidth = SubtitleStyleOptions.defaultOutlineWidth
        value.verticalOffset = SubtitleStyleOptions.defaultVerticalOffset
        value.backgroundColorARGB = 0x00_00_00_00
        return value
    }
}

/// The Android DataStore preference keys that persist the subtitle style
/// (`PlayerSettingsDataStore.kt`). The raw values are part of the parity
/// contract: a future tvOS settings store must use the same strings.
enum SubtitleStylePersistenceKey: String, CaseIterable {
    case preferredLanguage = "subtitle_preferred_language"
    case secondaryLanguage = "subtitle_secondary_language"
    case useForcedSubtitles = "subtitle_use_forced_subtitles"
    case showOnlyPreferredLanguages = "subtitle_show_only_preferred_languages"
    case stripSdh = "subtitle_strip_sdh"
    case size = "subtitle_size"
    case verticalOffset = "subtitle_vertical_offset"
    case bold = "subtitle_bold"
    case textColor = "subtitle_text_color"
    case backgroundColor = "subtitle_background_color"
    case outlineEnabled = "subtitle_outline_enabled"
    case outlineColor = "subtitle_outline_color"
    case outlineWidth = "subtitle_outline_width"
}

/// Persistence model for `SubtitleStyleOptions` mirroring the Android
/// DataStore read/write semantics: missing keys fall back to defaults and
/// every numeric value is clamped on load.
enum SubtitleStylePersistence {
    /// Serializes the style into the flat key/value form the Android
    /// DataStore writes.
    static func persistedValues(of options: SubtitleStyleOptions) -> [String: Any] {
        var values: [String: Any] = [
            SubtitleStylePersistenceKey.preferredLanguage.rawValue: options.preferredLanguage,
            SubtitleStylePersistenceKey.useForcedSubtitles.rawValue: options.useForcedSubtitles,
            SubtitleStylePersistenceKey.showOnlyPreferredLanguages.rawValue: options.showOnlyPreferredLanguages,
            SubtitleStylePersistenceKey.stripSdh.rawValue: options.stripSdh,
            SubtitleStylePersistenceKey.size.rawValue: options.sizePercent,
            SubtitleStylePersistenceKey.verticalOffset.rawValue: options.verticalOffset,
            SubtitleStylePersistenceKey.bold.rawValue: options.bold,
            SubtitleStylePersistenceKey.textColor.rawValue: Int(truncatingIfNeeded: options.textColorARGB),
            SubtitleStylePersistenceKey.backgroundColor.rawValue: Int(truncatingIfNeeded: options.backgroundColorARGB),
            SubtitleStylePersistenceKey.outlineEnabled.rawValue: options.outlineEnabled,
            SubtitleStylePersistenceKey.outlineColor.rawValue: Int(truncatingIfNeeded: options.outlineColorARGB),
            SubtitleStylePersistenceKey.outlineWidth.rawValue: options.outlineWidth,
        ]
        if let secondary = options.secondaryPreferredLanguage {
            values[SubtitleStylePersistenceKey.secondaryLanguage.rawValue] = secondary
        }
        return values
    }

    /// Reads a style from persisted values, applying defaults for missing
    /// keys and clamping numeric ranges like the Android loaders do.
    static func load(from values: [String: Any]) -> SubtitleStyleOptions {
        var options = SubtitleStyleOptions()
        if let preferred = values[SubtitleStylePersistenceKey.preferredLanguage.rawValue] as? String {
            options.preferredLanguage = preferred
        }
        options.secondaryPreferredLanguage =
            values[SubtitleStylePersistenceKey.secondaryLanguage.rawValue] as? String
        options.useForcedSubtitles =
            values[SubtitleStylePersistenceKey.useForcedSubtitles.rawValue] as? Bool ?? false
        options.showOnlyPreferredLanguages =
            values[SubtitleStylePersistenceKey.showOnlyPreferredLanguages.rawValue] as? Bool ?? false
        options.stripSdh = values[SubtitleStylePersistenceKey.stripSdh.rawValue] as? Bool ?? false
        options.sizePercent = values[SubtitleStylePersistenceKey.size.rawValue] as? Int
            ?? SubtitleStyleOptions.defaultSize
        options.verticalOffset = values[SubtitleStylePersistenceKey.verticalOffset.rawValue] as? Int
            ?? SubtitleStyleOptions.defaultVerticalOffset
        options.bold = values[SubtitleStylePersistenceKey.bold.rawValue] as? Bool ?? false
        if let color = values[SubtitleStylePersistenceKey.textColor.rawValue] as? Int {
            options.textColorARGB = UInt32(bitPattern: Int32(truncatingIfNeeded: color))
        }
        if let color = values[SubtitleStylePersistenceKey.backgroundColor.rawValue] as? Int {
            options.backgroundColorARGB = UInt32(bitPattern: Int32(truncatingIfNeeded: color))
        }
        options.outlineEnabled =
            values[SubtitleStylePersistenceKey.outlineEnabled.rawValue] as? Bool ?? true
        if let color = values[SubtitleStylePersistenceKey.outlineColor.rawValue] as? Int {
            options.outlineColorARGB = UInt32(bitPattern: Int32(truncatingIfNeeded: color))
        }
        options.outlineWidth = values[SubtitleStylePersistenceKey.outlineWidth.rawValue] as? Int
            ?? SubtitleStyleOptions.defaultOutlineWidth
        return options.clamped()
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
