import SwiftUI

/// Single-addon page: manifest facts (logo, name, version, types,
/// description, base URL), credential badge, catalog list with types, and
/// install/remove actions with protected handling. The composition follows
/// the Android addon-card grammar; the Android repository has no dedicated
/// addon detail route (see the parity report).
public struct AddonDetailView: View {
    let detail: AddonDetailModel
    let onInstall: () -> Void
    let onRemove: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logoSize = CGSize(width: 88, height: 88)

    public init(
        detail: AddonDetailModel,
        onInstall: @escaping () -> Void = {},
        onRemove: @escaping () -> Void = {}
    ) {
        self.detail = detail
        self.onInstall = onInstall
        self.onRemove = onRemove
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xl) {
                header
                actions
                if let protectedNote = detail.protectedNote {
                    Text(protectedNote)
                        .nuvioTextStyle(.compactBody)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
                catalogsSection
            }
            .padding(NuvioDesignTokens.Spacing.Screen.horizontal)
            .padding(.vertical, NuvioDesignTokens.Spacing.Screen.vertical)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.xl) {
            NuvioArtworkView(
                urlString: detail.logoURL,
                mode: .poster,
                pixelSize: logoSize,
                cornerRadius: NuvioDesignTokens.Shapes.md,
                placeholderSystemImage: "puzzlepiece.extension"
            )
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
                HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                    Text(detail.displayName)
                        .nuvioTextStyle(.headline)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    if detail.isProtected {
                        Image(systemName: "lock.fill")
                            .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm))
                            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                            .accessibilityLabel("Protected addon")
                    }
                }
                HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                    if let version = detail.versionLabel { Text(version) }
                    if !detail.typesLabel.isEmpty { Text(detail.typesLabel) }
                    if detail.providesStreams {
                        Label("Streams", systemImage: "play.circle")
                    }
                    if detail.credentialBadge.displayText != nil {
                        AddonCredentialBadgeView(badge: detail.credentialBadge)
                    }
                }
                .nuvioTextStyle(.compactBody)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                if let description = detail.description, !description.isEmpty {
                    Text(description)
                        .nuvioTextStyle(.body)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                        .lineLimit(4)
                }
                Text(detail.baseURL)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
                    .lineLimit(1)
                Text(detail.catalogSummary)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
            }
            Spacer()
        }
        .padding(NuvioDesignTokens.Spacing.xl)
        .background(
            NuvioDesignTokens.Colors.elevated,
            in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.lg, style: .continuous)
        )
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            if detail.showsInstallAction {
                Button(action: onInstall) {
                    Label("Install", systemImage: "plus")
                        .nuvioTextStyle(.button)
                        .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
                        .frame(height: 48)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
                .accessibilityLabel("Install \(detail.displayName)")
            }
            if detail.showsRemoveAction {
                Button(action: onRemove) {
                    Label("Remove", systemImage: "trash")
                        .nuvioTextStyle(.button)
                        .foregroundStyle(NuvioDesignTokens.Colors.error)
                        .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
                        .frame(height: 48)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
                .accessibilityLabel("Remove \(detail.displayName)")
            }
        }
    }

    private var catalogsSection: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            Text("Catalogs")
                .nuvioTextStyle(.sectionTitle)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            if detail.catalogs.isEmpty {
                Text("This addon provides no catalogs.")
                    .nuvioTextStyle(.body)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            } else {
                ForEach(detail.catalogs) { catalog in
                    AddonDetailCatalogRow(catalog: catalog)
                }
            }
        }
    }
}

/// One catalog row on the detail page: name, type chip and role caption.
struct AddonDetailCatalogRow: View {
    let catalog: AddonDetailCatalog

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            Text(catalog.name)
                .nuvioTextStyle(.cardTitle)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                .lineLimit(1)
            Text(catalog.typeLabel)
                .nuvioTextStyle(.badge)
                .foregroundStyle(NuvioDesignTokens.Colors.brand)
                .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
                .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
                .background(
                    NuvioDesignTokens.Colors.brand.opacity(NuvioDesignTokens.Effects.glowSoftOpacity),
                    in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xxs)
                )
            Spacer()
            Text(catalog.caption)
                .nuvioTextStyle(.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
        }
        .padding(NuvioDesignTokens.Spacing.lg)
        .background(
            NuvioDesignTokens.Colors.elevated,
            in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
