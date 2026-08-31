import SwiftUI

/// Adds Nuvio focus visuals without changing focusability or remote routing.
public struct NuvioFocusStyleModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let ringColor: Color
    public let focusedScale: CGFloat

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        cornerRadius: CGFloat,
        ringColor: Color = NuvioDesignTokens.Colors.defaultFocus,
        focusedScale: CGFloat = NuvioDesignTokens.Focus.scale
    ) {
        self.cornerRadius = cornerRadius
        self.ringColor = ringColor
        self.focusedScale = focusedScale
    }

    public func body(content: Content) -> some View {
        content
            .overlay(focusRing)
            .scaleEffect(reduceMotion ? 1 : (isFocused ? focusedScale : 1))
            .shadow(
                color: ringColor.opacity(
                    isFocused ? NuvioDesignTokens.Effects.glowSoftOpacity : 0
                ),
                radius: NuvioDesignTokens.Blur.soft
            )
            .animation(focusAnimation, value: isFocused)
    }

    private var focusRing: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                isFocused ? ringColor : .clear,
                lineWidth: NuvioDesignTokens.Focus.ringWidth
            )
            .allowsHitTesting(false)
    }

    private var focusAnimation: Animation? {
        NuvioMotion.animation(
            for: .focus,
            reduceMotion: reduceMotion,
            substitute: .instant
        )
    }
}

/// A standard ButtonStyle, so the system focus engine retains interaction control.
public struct NuvioFocusButtonStyle: ButtonStyle {
    public let cornerRadius: CGFloat
    public let ringColor: Color

    public init(
        cornerRadius: CGFloat = NuvioDesignTokens.Shapes.posterRadius,
        ringColor: Color = NuvioDesignTokens.Colors.defaultFocus
    ) {
        self.cornerRadius = cornerRadius
        self.ringColor = ringColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        NuvioFocusButtonStyleBody(
            configuration: configuration,
            cornerRadius: cornerRadius,
            ringColor: ringColor
        )
    }
}

private struct NuvioFocusButtonStyleBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let ringColor: Color

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .overlay(focusRing)
            .scaleEffect(resolvedScale)
            .shadow(
                color: ringColor.opacity(
                    isFocused ? NuvioDesignTokens.Effects.glowSoftOpacity : 0
                ),
                radius: NuvioDesignTokens.Blur.soft
            )
            .animation(focusAnimation, value: isFocused)
            .animation(focusAnimation, value: configuration.isPressed)
    }

    private var resolvedScale: CGFloat {
        guard !reduceMotion else { return NuvioDesignTokens.Focus.reducedMotionScale }
        if configuration.isPressed { return NuvioDesignTokens.Focus.pressedScale }
        return isFocused ? NuvioDesignTokens.Focus.scale : 1
    }

    private var focusRing: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                isFocused ? ringColor : .clear,
                lineWidth: NuvioDesignTokens.Focus.ringWidth
            )
            .allowsHitTesting(false)
    }

    private var focusAnimation: Animation? {
        NuvioMotion.animation(
            for: .focus,
            reduceMotion: reduceMotion,
            substitute: .instant
        )
    }
}

public extension View {
    func nuvioFocusStyle(
        cornerRadius: CGFloat,
        ringColor: Color = NuvioDesignTokens.Colors.defaultFocus,
        focusedScale: CGFloat = NuvioDesignTokens.Focus.scale
    ) -> some View {
        modifier(
            NuvioFocusStyleModifier(
                cornerRadius: cornerRadius,
                ringColor: ringColor,
                focusedScale: focusedScale
            )
        )
    }
}
