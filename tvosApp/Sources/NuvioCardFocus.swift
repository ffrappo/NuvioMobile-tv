import SwiftUI

// Apple-TV-style focus for selectable cards. One clean surface per item: the
// focused element scales up, lifts off the background with a soft drop shadow,
// and brightens. This replaces the previous double grey box created by stacking
// the system `.buttonStyle(.card)` chrome on top of an explicit panel fill.
//
// Design references (Apple Human Interface Guidelines, current):
//  - "Focus and selection" (tvOS): the focused item stands out through elevation
//    to the foreground, illumination, a drop shadow, and a gentle scale; keep
//    layering simple and subtle, and be consistent across the app.
//  - "Images" > Parallax effect: depth and dynamism come from elevation,
//    illumination, and motion, not from nested containers.

/// Image-filled tiles (posters, thumbnails, folder covers). The artwork is the
/// focus surface, so no fill is added and there is no grey box. Apply to the
/// whole card stack so the title stays anchored to the artwork while it lifts.
private struct NuvioTileFocus: ViewModifier {
    let isFocused: Bool
    var scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? scale : 1.0)
            .shadow(
                color: .black.opacity(isFocused ? 0.5 : 0.0),
                radius: isFocused ? 18 : 0,
                y: 12
            )
            .animation(focusAnimation, value: isFocused)
    }

    private var focusAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72)
    }
}

/// Row and action cards (episode picker, stream sources). A single
/// focus-reactive surface replaces the previous nested boxes. `selected` tints
/// the surface with the accent ring instead of stacking a second fill, keeping
/// the selected state on the same visual layer as the focus state.
private struct NuvioSurfaceFocus: ViewModifier {
    let isFocused: Bool
    let selected: Bool
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fill: Color {
        if isFocused { return Color.white.opacity(0.22) }
        return selected ? Color.white.opacity(0.15) : NuvioTheme.panel
    }

    func body(content: Content) -> some View {
        content
            .background(
                fill,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(NuvioTheme.accent.opacity(0.9), lineWidth: 2)
                }
            }
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .shadow(
                color: .black.opacity(isFocused ? 0.45 : 0.0),
                radius: isFocused ? 16 : 0,
                y: 10
            )
            .animation(focusAnimation, value: isFocused)
    }

    private var focusAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72)
    }
}

extension View {
    /// Image-filled tile focus: scale + soft shadow on focus, no fill. Pair with
    /// a `FocusState` binding so the lift tracks keyboard and Siri Remote input.
    func nuvioTileFocus(_ isFocused: Bool, scale: CGFloat = 1.05) -> some View {
        modifier(NuvioTileFocus(isFocused: isFocused, scale: scale))
    }

    /// Row/action card focus: a single focus-reactive surface with optional
    /// selection accent. Use for cards that need their own background panel.
    func nuvioSurfaceFocus(
        _ isFocused: Bool,
        selected: Bool = false,
        cornerRadius: CGFloat = 18
    ) -> some View {
        modifier(
            NuvioSurfaceFocus(
                isFocused: isFocused,
                selected: selected,
                cornerRadius: cornerRadius
            )
        )
    }
}
