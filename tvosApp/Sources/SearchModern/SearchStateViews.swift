import SwiftUI

/// Android `EmptyScreenState` parity: symbol, title, subtitle, centered.
struct SearchEmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: NuvioDesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: NuvioDesignTokens.Sizes.Icons.xl))
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            Text(title)
                .nuvioTextStyle(.headline)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            Text(subtitle)
                .nuvioTextStyle(.body)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NuvioDesignTokens.Spacing.xxl)
        .accessibilityElement(children: .combine)
    }
}

/// Android `ErrorState` parity: message plus a Retry button.
struct SearchErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: NuvioDesignTokens.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: NuvioDesignTokens.Sizes.Icons.xl))
                .foregroundStyle(NuvioDesignTokens.Colors.error)
            Text(message)
                .nuvioTextStyle(.body)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                .multilineTextAlignment(.center)
            Button(SearchStrings.retry, action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NuvioDesignTokens.Spacing.xxl)
        .accessibilityElement(children: .contain)
    }
}

/// Recent searches: "Recent searches" header with a Clear history button and
/// capsule chips. Android stacks full-width buttons vertically; on tvOS the
/// parity mapping is a capsule chip row (the brief's required presentation).
struct RecentSearchesView: View {
    let searches: [String]
    let onSelect: (String) -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            HStack {
                Text(SearchStrings.recentTitle)
                    .nuvioTextStyle(.sectionTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                Spacer()
                Button(SearchStrings.recentClear, action: onClearAll)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: NuvioDesignTokens.Spacing.sm) {
                    ForEach(searches, id: \.self) { search in
                        RecentSearchChip(search: search) { onSelect(search) }
                    }
                }
                .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
                .padding(.vertical, NuvioDesignTokens.Spacing.sm)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

struct RecentSearchChip: View {
    let search: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvioDesignTokens.Spacing.xs) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm))
                Text(search)
                    .nuvioTextStyle(.compactBody)
                    .lineLimit(1)
            }
            .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
            .frame(minHeight: NuvioDesignTokens.Components.chipHeight)
        }
        .buttonStyle(
            NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.full)
        )
        .accessibilityLabel("Search for \(search)")
    }
}
