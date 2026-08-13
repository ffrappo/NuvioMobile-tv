import SwiftUI

struct NuvioThemePalette {
    let background: Color
    let panel: Color
    let elevatedPanel: Color
    let secondaryText: Color
    let separator: Color
    let accent: Color

    static let standard = NuvioThemePalette(
        background: Color(red: 0.035, green: 0.035, blue: 0.045),
        panel: Color.white.opacity(0.075),
        elevatedPanel: Color.white.opacity(0.16),
        secondaryText: Color.white.opacity(0.68),
        separator: Color.white.opacity(0.16),
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

    func body(content: Content) -> some View {
        let palette = NuvioThemePalette.resolved(
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
