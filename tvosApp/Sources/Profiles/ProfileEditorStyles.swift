import SwiftUI

// MARK: - Editor buttons

/// Android `OverlayButton(isPrimary = true)`: filled brand button.
struct EditorPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isFocused ? NuvioDesignTokens.Colors.brandFocus : NuvioDesignTokens.Colors.brand)
            )
            .scaleEffect(isFocused && !reduceMotion ? NuvioDesignTokens.Focus.scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Android `OverlayButton(isPrimary = false)`: card background button.
struct EditorSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isFocused ? NuvioDesignTokens.Colors.neutral750 : NuvioDesignTokens.Colors.neutral875)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        NuvioDesignTokens.Colors.neutral700,
                        lineWidth: NuvioDesignTokens.Strokes.hairline
                    )
            )
            .scaleEffect(isFocused && !reduceMotion ? NuvioDesignTokens.Focus.scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Android delete button container color `0xFF4A2323`.
struct EditorDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.29, green: 0.137, blue: 0.137))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: NuvioDesignTokens.Strokes.hairline)
            )
            .scaleEffect(isFocused && !reduceMotion ? NuvioDesignTokens.Focus.scale : 1)
    }
}

/// Avatar color swatch: brand-colored ring while focused.
struct SwatchButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused && !reduceMotion ? 1.1 : 1)
            .overlay(
                Circle()
                    .strokeBorder(
                        isFocused ? NuvioDesignTokens.Colors.defaultFocus : .clear,
                        lineWidth: NuvioDesignTokens.Strokes.focus
                    )
                    .padding(-NuvioDesignTokens.Spacing.xs)
                    .allowsHitTesting(false)
            )
    }
}

/// Flat pill (background options, tab-like choices).
struct FlatFocusButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused && !reduceMotion ? NuvioDesignTokens.Focus.scale : 1)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ? NuvioDesignTokens.Colors.defaultFocus : .clear,
                        lineWidth: NuvioDesignTokens.Strokes.focus
                    )
                    .allowsHitTesting(false)
            )
    }
}
