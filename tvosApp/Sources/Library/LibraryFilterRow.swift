import SwiftUI

/// One selectable choice in a filter row (tab, provider, filter, or sort).
struct LibraryFilterChoice: Equatable, Identifiable, Sendable {
    let id: String
    let label: String

    init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

/// A titled horizontal row of focusable capsule choices: type tabs, the
/// view-mode switcher, provider/watched filters, and the sort row. Native
/// focus only — each choice is a plain `Button` styled with the app's
/// `NuvioFocusButtonStyle`.
struct LibraryFilterRow: View {
    let title: String?
    let choices: [LibraryFilterChoice]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xxs) {
            if let title {
                Text(title.tvSafe)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                    ForEach(choices) { choice in
                        LibraryFilterCapsule(
                            label: choice.label,
                            isSelected: choice.id == selection
                        ) {
                            selection = choice.id
                        }
                    }
                }
                .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
            }
            .focusSection()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title ?? "Filters")
    }
}

/// A single capsule choice: selected state uses the brand fill (Android's
/// `FocusBackground`), otherwise the elevated card fill.
struct LibraryFilterCapsule: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(label.tvSafe)
                .nuvioTextStyle(.button)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
                .padding(.vertical, NuvioDesignTokens.Spacing.sm)
                .background(
                    Capsule().fill(
                        isSelected
                            ? NuvioDesignTokens.Colors.brand
                            : NuvioDesignTokens.Colors.elevated
                    )
                )
                .overlay(
                    Capsule().strokeBorder(
                        NuvioDesignTokens.Colors.neutral700,
                        lineWidth: NuvioDesignTokens.Strokes.hairline
                    )
                )
        }
        .buttonStyle(
            NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.full)
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(
            reduceMotion ? nil : .easeOut(duration: NuvioMotion.focusTransition),
            value: isSelected
        )
    }
}
