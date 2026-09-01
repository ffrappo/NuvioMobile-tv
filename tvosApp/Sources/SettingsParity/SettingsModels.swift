import Foundation

/// Home layout options ported from `HomeLayout.kt`.
public enum NuvioHomeLayout: String, CaseIterable, Hashable, Sendable {
    case modern = "MODERN"
    case classic = "CLASSIC"
    case grid = "GRID"

    /// `HomeLayout.displayName`.
    public var displayName: String {
        switch self {
        case .modern: return "Modern View"
        case .classic: return "Classic View"
        case .grid: return "Grid View"
        }
    }

    /// Short label used by `LayoutSettingsScreen.kt` (`layout_modern/classic/grid`).
    public var shortName: String {
        switch self {
        case .modern: return "Modern"
        case .classic: return "Classic"
        case .grid: return "Grid"
        }
    }
}

/// Color themes ported from `AppTheme.kt` (`AppTheme.displayName`).
public enum NuvioAppTheme: String, CaseIterable, Hashable, Sendable {
    case gold = "GOLD"
    case jade = "JADE"
    case roseGold = "ROSE_GOLD"
    case arcticBlue = "ARCTIC_BLUE"
    case graphite = "GRAPHITE"
    case crimson = "CRIMSON"
    case ocean = "OCEAN"
    case violet = "VIOLET"
    case emerald = "EMERALD"
    case amber = "AMBER"
    case rose = "ROSE"
    case white = "WHITE"

    public var displayName: String {
        switch self {
        case .gold: return "Gold"
        case .jade: return "Jade"
        case .roseGold: return "Rose Gold"
        case .arcticBlue: return "Arctic Blue"
        case .graphite: return "Graphite"
        case .crimson: return "Crimson"
        case .ocean: return "Ocean"
        case .violet: return "Violet"
        case .emerald: return "Emerald"
        case .amber: return "Amber"
        case .rose: return "Rose"
        case .white: return "White"
        }
    }
}

/// Top-level settings sections owned by this module. Mirrors the subset of the
/// Android `SettingsCategory` rail (`SettingsScreen.kt`) covered by this port:
/// Layout, Playback, Network (Android Advanced/`NetworkSettingsScreen.kt`),
/// Integrations, Diagnostics (`DiagnosticsCard.kt`), About.
public enum NuvioSettingsCategory: String, CaseIterable, Hashable, Sendable {
    case layout
    case playback
    case network
    case integrations
    case diagnostics
    case about

    public var title: String {
        switch self {
        case .layout: return "Layout"
        case .playback: return "Playback"
        case .network: return "Network"
        case .integrations: return "Integrations"
        case .diagnostics: return "Diagnostics"
        case .about: return "About"
        }
    }

    public var subtitle: String {
        switch self {
        case .layout: return "Home layout, hero, and theme"
        case .playback: return "Player, audio, subtitles, autoplay, and buffering"
        case .network: return "Connection, speed tests, and performance"
        case .integrations: return "Debrid, TMDB, MDBList, and Anime Skip"
        case .diagnostics: return "Last playback diagnostics and reporting"
        case .about: return "Version, updates, and legal"
        }
    }

    /// SF Symbol standing in for the Android rail icon.
    public var systemImage: String {
        switch self {
        case .layout: return "rectangle.3.group"
        case .playback: return "play.circle"
        case .network: return "wifi"
        case .integrations: return "link"
        case .diagnostics: return "stethoscope"
        case .about: return "info.circle"
        }
    }
}

/// Typed value of a setting. `action` rows carry no value; they only emit a change.
public enum NuvioSettingValue: Equatable, Sendable {
    case toggle(Bool)
    case option(String)
    case number(Double)
    case text(String)
    case action
}

/// One selectable option, mirroring `SettingsPickerOption<T>` in `SettingsDesignSystem.kt`.
public struct NuvioSettingOption: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?

    public init(id: String, title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

/// Slider geometry, mirroring `SliderSettingsItem` min/max/step.
public struct NuvioSliderSpec: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double
    public let step: Double

    public init(minimum: Double, maximum: Double, step: Double) {
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
    }

    public func clamped(_ value: Double) -> Double {
        let stepped = ((value - minimum) / step).rounded() * step + minimum
        return Swift.min(Swift.max(stepped, minimum), maximum)
    }
}

/// The control a setting row renders.
public enum NuvioSettingKind: Equatable, Sendable {
    case toggle
    case optionPicker([NuvioSettingOption])
    case segmented([NuvioSettingOption])
    case slider(NuvioSliderSpec)
    /// Row that pushes a destination or opens an external picker.
    case navigation
    /// Read-only value row.
    case info
    /// Button row that performs an action.
    case action
}

/// A single typed setting: value, display metadata, and change identity (`id`).
/// Change callbacks are dispatched by `id` through `NuvioSettingsChange`, keeping
/// models pure and `Equatable`.
public struct NuvioSetting: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let systemImage: String?
    public let kind: NuvioSettingKind
    public let value: NuvioSettingValue
    /// Pre-formatted display value (`valueText` in the Android rows).
    public let valueText: String?
    public let isEnabled: Bool

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        kind: NuvioSettingKind,
        value: NuvioSettingValue,
        valueText: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.kind = kind
        self.value = value
        self.valueText = valueText
        self.isEnabled = isEnabled
    }
}

/// A group card of settings, mirroring `SettingsGroupCard` content blocks.
public struct NuvioSettingsSection: Equatable, Sendable, Identifiable {
    public let id: String
    public let category: NuvioSettingsCategory
    public let title: String
    public let subtitle: String?
    public let settings: [NuvioSetting]

    public init(
        id: String,
        category: NuvioSettingsCategory,
        title: String,
        subtitle: String? = nil,
        settings: [NuvioSetting]
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.settings = settings
    }
}

/// A change emitted by a settings control. The integration layer applies it to
/// its own store (this module never touches persistence) and rebuilds state.
public struct NuvioSettingsChange: Equatable, Sendable {
    public let settingID: String
    public let value: NuvioSettingValue

    public init(settingID: String, value: NuvioSettingValue) {
        self.settingID = settingID
        self.value = value
    }
}
