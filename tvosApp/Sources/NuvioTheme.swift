import SwiftUI

struct NuvioThemePalette {
    var background: Color
    let panel: Color
    let elevatedPanel: Color
    let secondaryText: Color
    let separator: Color
    var accent: Color

    static let standard = NuvioThemePalette(
        background: Color(red: 0.035, green: 0.035, blue: 0.045),
        panel: Color.white.opacity(0.075),
        elevatedPanel: Color.white.opacity(0.16),
        secondaryText: Color.white.opacity(0.68),
        separator: Color.white.opacity(0.16),
        accent: Color(red: 0.20, green: 0.55, blue: 1.0)
    )

    /// The user-selected theme (`AppTheme` parity): accent from the Android
    /// `ThemeColors` palettes; backgrounds stay the dark neutral base with
    /// the theme's subtle tint where Android defines one.
    static func themed(
        _ theme: NuvioAppTheme,
        contrast: ColorSchemeContrast,
        reduceTransparency: Bool
    ) -> NuvioThemePalette {
        let accent = Self.accent(for: theme)
        if contrast == .increased {
            var palette = Self.increasedContrastBase
            palette.accent = Self.brightAccent(for: theme)
            return palette
        }
        if reduceTransparency {
            var palette = Self.opaqueBase
            palette.accent = accent
            return palette
        }
        var palette = NuvioThemePalette.standard
        palette.accent = accent
        if let background = Self.background(for: theme) {
            palette.background = background
        }
        return palette
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Android `ThemeColors`/`SupporterThemeColors` secondary values.
    private static func accent(for theme: NuvioAppTheme) -> Color {
        switch theme {
        case .white: return color(0xF5F5F5)
        case .gold: return color(0xE8A91C)
        case .jade: return color(0x22D37C)
        case .roseGold: return color(0xEC70A9)
        case .arcticBlue: return color(0x3185F5)
        case .graphite: return color(0xAAB2BE)
        case .crimson: return color(0xE53935)
        case .ocean: return color(0x1E88E5)
        case .violet: return color(0x8E24AA)
        case .emerald: return color(0x43A047)
        case .amber: return color(0xFB8C00)
        case .rose: return color(0xD81B60)
        }
    }

    /// Android focus-ring colors (the x300/lighter variants), used when
    /// Increase Contrast demands a brighter accent.
    private static func brightAccent(for theme: NuvioAppTheme) -> Color {
        switch theme {
        case .white: return .white
        case .gold: return color(0xFFD45C)
        case .jade: return color(0x7BF08D)
        case .roseGold: return color(0xFFB37A)
        case .arcticBlue: return color(0x4DE3FF)
        case .graphite: return color(0xF3F5F7)
        case .crimson: return color(0xFF5252)
        case .ocean: return color(0x42A5F5)
        case .violet: return color(0xAB47BC)
        case .emerald: return color(0x66BB6A)
        case .amber: return color(0xFFA726)
        case .rose: return color(0xEC407A)
        }
    }

    /// Android theme backgrounds that differ from the neutral base.
    private static func background(for theme: NuvioAppTheme) -> Color? {
        switch theme {
        case .ocean, .violet: return color(0x0D0D0F)
        case .amber: return color(0x0F0D0D)
        case .roseGold: return color(0x100C0F)
        case .arcticBlue: return color(0x0B0E14)
        case .graphite: return color(0x0C0D0F)
        default: return nil
        }
    }

    private static let increasedContrastBase = NuvioThemePalette(
        background: .black,
        panel: Color(red: 0.13, green: 0.13, blue: 0.15),
        elevatedPanel: Color(red: 0.25, green: 0.25, blue: 0.28),
        secondaryText: Color.white.opacity(0.92),
        separator: Color.white.opacity(0.72),
        accent: Color(red: 0.32, green: 0.68, blue: 1.0)
    )

    private static let opaqueBase = NuvioThemePalette(
        background: Color(red: 0.035, green: 0.035, blue: 0.045),
        panel: Color(red: 0.13, green: 0.13, blue: 0.15),
        elevatedPanel: Color(red: 0.21, green: 0.21, blue: 0.24),
        secondaryText: Color.white.opacity(0.82),
        separator: Color.white.opacity(0.38),
        accent: Color(red: 0.20, green: 0.55, blue: 1.0)
    )

    static func resolved(
        contrast: ColorSchemeContrast,
        reduceTransparency: Bool
    ) -> NuvioThemePalette {
        if contrast == .increased {
            return NuvioThemePalette(
                background: .black,
                panel: Color(red: 0.13, green: 0.13, blue: 0.15),
                elevatedPanel: Color(red: 0.25, green: 0.25, blue: 0.28),
                secondaryText: Color.white.opacity(0.92),
                separator: Color.white.opacity(0.72),
                accent: Color(red: 0.32, green: 0.68, blue: 1.0)
            )
        }
        if reduceTransparency {
            return NuvioThemePalette(
                background: Color(red: 0.035, green: 0.035, blue: 0.045),
                panel: Color(red: 0.13, green: 0.13, blue: 0.15),
                elevatedPanel: Color(red: 0.21, green: 0.21, blue: 0.24),
                secondaryText: Color.white.opacity(0.82),
                separator: Color.white.opacity(0.38),
                accent: Color(red: 0.20, green: 0.55, blue: 1.0)
            )
        }
        return .standard
    }
}

private struct NuvioThemeKey: EnvironmentKey {
    static let defaultValue = NuvioThemePalette.standard
}

extension EnvironmentValues {
    var nuvioTheme: NuvioThemePalette {
        get { self[NuvioThemeKey.self] }
        set { self[NuvioThemeKey.self] = newValue }
    }
}

private struct NuvioThemeEnvironmentModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    /// The parity theme picker's persisted value ("o:GOLD"); empty or
    /// unreadable values fall back to the Android default (WHITE).
    @AppStorage(NuvioThemeEnvironmentModifier.themeKey) private var persistedTheme = ""

    static let themeKey = "nuvio.tv.settings.v2.layout.theme"

    func body(content: Content) -> some View {
        let palette = NuvioThemePalette.themed(
            NuvioAppTheme(parsedSetting: persistedTheme) ?? .white,
            contrast: contrast,
            reduceTransparency: reduceTransparency
        )
        content
            .environment(\.nuvioTheme, palette)
            .tint(palette.accent)
    }
}

private struct NuvioAdaptiveSurfaceModifier<S: Shape>: ViewModifier {
    let shape: S
    let material: Material

    @Environment(\.nuvioTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            if contrast == .increased || reduceTransparency {
                shape.fill(theme.panel)
            } else {
                shape.fill(material)
            }
        }
    }
}

extension View {
    func nuvioThemeEnvironment() -> some View {
        modifier(NuvioThemeEnvironmentModifier())
    }

    func nuvioAdaptiveSurface<S: Shape>(
        _ shape: S,
        material: Material = .thinMaterial
    ) -> some View {
        modifier(NuvioAdaptiveSurfaceModifier(shape: shape, material: material))
    }
}
