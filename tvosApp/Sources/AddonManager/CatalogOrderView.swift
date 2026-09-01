import SwiftUI

/// Native SwiftUI port of the Android `CatalogOrderScreen`: a header with
/// reset action, then one card per enabled-home catalog showing the ordered
/// title, addon attribution, hidden-on-Home state, move up/down buttons and a
/// per-catalog enable toggle. Presentation-only.
public struct CatalogOrderView: View {
    let items: [CatalogOrderItem]
    let onMoveUp: (String) -> Void
    let onMoveDown: (String) -> Void
    let onToggleDisabled: (String) -> Void
    let onResetOrder: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        items: [CatalogOrderItem],
        onMoveUp: @escaping (String) -> Void,
        onMoveDown: @escaping (String) -> Void,
        onToggleDisabled: @escaping (String) -> Void,
        onResetOrder: @escaping () -> Void
    ) {
        self.items = items
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onToggleDisabled = onToggleDisabled
        self.onResetOrder = onResetOrder
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.lg) {
                header
                if items.isEmpty {
                    Text("No catalogs to order yet. Install an addon with catalogs first.")
                        .nuvioTextStyle(.body)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                } else {
                    ForEach(items) { item in
                        CatalogOrderRowView(
                            item: item,
                            onMoveUp: { onMoveUp(item.key) },
                            onMoveDown: { onMoveDown(item.key) },
                            onToggle: { onToggleDisabled(item.disableKey) }
                        )
                    }
                }
            }
            .padding(NuvioDesignTokens.Spacing.Screen.horizontal)
            .padding(.vertical, NuvioDesignTokens.Spacing.Screen.vertical)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                    Text("Catalog order")
                        .nuvioTextStyle(.headline)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    Text("Choose the order catalogs appear on Home.")
                        .nuvioTextStyle(.compactBody)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
                Spacer()
                Button(action: onResetOrder) {
                    Label("Reset order", systemImage: "arrow.counterclockwise")
                        .nuvioTextStyle(.button)
                        .padding(.horizontal, NuvioDesignTokens.Spacing.md)
                        .frame(height: 44)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
                .accessibilityLabel("Reset catalog order to manifest order")
            }
        }
    }
}

/// One catalog card, matching the Android `CatalogOrderCard` composition:
/// `"catalog - Type"` title, addon name, hidden-on-Home line, up/down arrows
/// and an enable/disable action.
struct CatalogOrderRowView: View {
    let item: CatalogOrderItem
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                Text(item.displayTitle)
                    .nuvioTextStyle(.cardTitle)
                    .foregroundStyle(
                        item.isDisabled
                            ? NuvioDesignTokens.Colors.secondaryText
                            : NuvioDesignTokens.Colors.primaryText
                    )
                    .lineLimit(1)
                Text(item.addonName)
                    .nuvioTextStyle(.compactBody)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                if item.isDisabled {
                    Text("Hidden on Home")
                        .nuvioTextStyle(.compactBody)
                        .foregroundStyle(NuvioDesignTokens.Colors.error)
                }
            }
            Spacer()
            HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
                .disabled(!item.canMoveUp)
                .accessibilityLabel("Move \(item.displayTitle) up")
                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
                .disabled(!item.canMoveDown)
                .accessibilityLabel("Move \(item.displayTitle) down")
                Button(action: onToggle) {
                    Text(item.isDisabled ? "Enable" : "Disable")
                        .nuvioTextStyle(.button)
                        .foregroundStyle(
                            item.isDisabled
                                ? NuvioDesignTokens.Colors.success
                                : NuvioDesignTokens.Colors.secondaryText
                        )
                        .padding(.horizontal, NuvioDesignTokens.Spacing.md)
                        .frame(height: 44)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
                .accessibilityLabel(
                    item.isDisabled
                        ? "Show \(item.displayTitle) on Home"
                        : "Hide \(item.displayTitle) from Home"
                )
            }
        }
        .padding(NuvioDesignTokens.Spacing.xl)
        .background(
            NuvioDesignTokens.Colors.elevated,
            in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.lg, style: .continuous)
        )
    }
}
