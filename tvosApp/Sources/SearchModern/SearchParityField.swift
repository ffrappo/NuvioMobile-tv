import SwiftUI

/// Native tvOS search field presentation: a `TextField` with a search icon,
/// focus-aware styling, and a D-pad-reachable clear button. Keyboard and
/// dictation remain system-owned — no custom keyboard handling.
struct SearchParityField: View {
    @Binding var query: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: NuvioDesignTokens.Sizes.Icons.lg))
                .foregroundStyle(
                    isFocused
                        ? NuvioDesignTokens.Colors.brandFocus
                        : NuvioDesignTokens.Colors.secondaryText
                )
            TextField("Search movies & series", text: $query)
                .nuvioTextStyle(.headline)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: NuvioDesignTokens.Sizes.Icons.md))
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.full))
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
        .padding(.vertical, NuvioDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
                .fill(NuvioDesignTokens.Colors.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
                .strokeBorder(
                    isFocused
                        ? NuvioDesignTokens.Colors.brandFocus
                        : NuvioDesignTokens.Colors.neutral700,
                    lineWidth: isFocused
                        ? NuvioDesignTokens.Focus.ringWidth
                        : NuvioDesignTokens.Strokes.hairline
                )
                .allowsHitTesting(false)
        )
        .scaleEffect(
            reduceMotion ? 1 : (isFocused ? NuvioDesignTokens.Focus.subtleScale : 1)
        )
        .animation(
            NuvioMotion.animation(for: .focus, reduceMotion: reduceMotion, substitute: .instant),
            value: isFocused
        )
        .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
    }
}
