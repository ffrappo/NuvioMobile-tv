import SwiftUI

/// Native SwiftUI port of the Android `AddonManagerScreen` list composition:
/// header, add-addon entry card, installed section, and one card per addon
/// with enable toggle, reorder controls, protected-row treatment and
/// credential badge. Presentation-only: the integrator supplies the entries
/// and wires the callbacks into its store.
public struct AddonManagerView: View {
    let entries: [AddonListEntry]
    var isReadOnly = false
    /// Essential mode hides reorder controls, as in Android.
    var showsReorder = true
    let onAddAddon: () -> Void
    let onToggleEnabled: (String, Bool) -> Void
    let onMoveUp: (String) -> Void
    let onMoveDown: (String) -> Void
    let onRemove: (String) -> Void
    let onSelectAddon: (String) -> Void
    let onOpenCatalogOrder: (() -> Void)?

    @State private var pendingRemoval: AddonListEntry?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        entries: [AddonListEntry],
        isReadOnly: Bool = false,
        showsReorder: Bool = true,
        onAddAddon: @escaping () -> Void,
        onToggleEnabled: @escaping (String, Bool) -> Void,
        onMoveUp: @escaping (String) -> Void,
        onMoveDown: @escaping (String) -> Void,
        onRemove: @escaping (String) -> Void,
        onSelectAddon: @escaping (String) -> Void = { _ in },
        onOpenCatalogOrder: (() -> Void)? = nil
    ) {
        self.entries = entries
        self.isReadOnly = isReadOnly
        self.showsReorder = showsReorder
        self.onAddAddon = onAddAddon
        self.onToggleEnabled = onToggleEnabled
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onRemove = onRemove
        self.onSelectAddon = onSelectAddon
        self.onOpenCatalogOrder = onOpenCatalogOrder
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.lg) {
                NuvioPageHeader(
                    title: "Addons",
                    subtitle: "Manage the services that provide catalogs, metadata, and streams"
                )
                if isReadOnly {
                    readOnlyNotice
                } else {
                    addAddonRow
                }
                installedSection
                if let onOpenCatalogOrder {
                    NuvioButton(
                        title: "Catalog Order",
                        symbol: "list.number",
                        action: onOpenCatalogOrder
                    )
                    .frame(width: 360)
                    .padding(.top, NuvioDesignTokens.Spacing.xl)
                }
            }
            .padding(NuvioDesignTokens.Spacing.Screen.horizontal)
            .padding(.vertical, NuvioDesignTokens.Spacing.Screen.vertical)
        }
        .confirmationDialog(
            "Remove \(pendingRemoval?.displayName ?? "addon")?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let entry = pendingRemoval {
                    onRemove(entry.id)
                }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("Its catalogs and streams will stop appearing on this Apple TV.")
        }
    }

    /// Android read-only card (`addon_readonly_notice`).
    private var readOnlyNotice: some View {
        Text("This profile shares the primary profile's addons. Changes are managed by the profile owner.")
            .nuvioTextStyle(.body)
            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            .padding(NuvioDesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(red: 0.1, green: 0.23, blue: 0.36),
                in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
            )
    }

    /// Install entry card. Android shows an inline URL field; tvOS routes to
    /// the dedicated add flow the integrator owns.
    private var addAddonRow: some View {
        Button(action: onAddAddon) {
            HStack(spacing: NuvioDesignTokens.Spacing.lg) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: NuvioDesignTokens.Sizes.Icons.lg))
                    .foregroundStyle(NuvioDesignTokens.Colors.brand)
                VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xxs) {
                    Text("Install addon")
                        .nuvioTextStyle(.cardTitle)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    Text("Add an addon from its manifest URL")
                        .nuvioTextStyle(.compactBody)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm))
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
            .padding(NuvioDesignTokens.Spacing.xl)
            .background(
                NuvioDesignTokens.Colors.elevated,
                in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.lg, style: .continuous)
            )
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.lg))
        .accessibilityLabel("Install addon")
    }

    @ViewBuilder
    private var installedSection: some View {
        Text("Installed addons")
            .nuvioTextStyle(.sectionTitle)
            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
        if entries.isEmpty {
            Text("No addons installed yet. Install one to bring catalogs and streams to Nuvio.")
                .nuvioTextStyle(.body)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
        } else {
            ForEach(entries) { entry in
                AddonManagerRowView(
                    entry: entry,
                    canMoveUp: showsReorder && !isReadOnly && entryIndex(entry) > 0,
                    canMoveDown: showsReorder && !isReadOnly && entryIndex(entry) < entries.count - 1,
                    showsControls: !isReadOnly,
                    showsReorder: showsReorder,
                    onToggleEnabled: { onToggleEnabled(entry.id, $0) },
                    onMoveUp: { onMoveUp(entry.id) },
                    onMoveDown: { onMoveDown(entry.id) },
                    onRemove: { pendingRemoval = entry },
                    onSelect: { onSelectAddon(entry.id) }
                )
            }
        }
    }

    private func entryIndex(_ entry: AddonListEntry) -> Int {
        entries.firstIndex { $0.id == entry.id } ?? 0
    }
}

/// One installed-addon card, matching the Android `AddonCard` composition:
/// logo, name, version, types/catalog count, disabled badge, credential
/// badge, enable toggle, reorder arrows and remove.
struct AddonManagerRowView: View {
    let entry: AddonListEntry
    let canMoveUp: Bool
    let canMoveDown: Bool
    let showsControls: Bool
    let showsReorder: Bool
    let onToggleEnabled: (Bool) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logoSize = CGSize(width: 56, height: 56)

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.lg) {
            Button(action: onSelect) {
                NuvioArtworkView(
                    urlString: entry.logoURL,
                    mode: .poster,
                    pixelSize: logoSize,
                    cornerRadius: NuvioDesignTokens.Shapes.sm,
                    placeholderSystemImage: "puzzlepiece.extension"
                )
            }
            .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
            .accessibilityLabel("Open \(entry.displayName)")

            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                    Text(entry.displayName)
                        .nuvioTextStyle(.cardTitle)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                        .lineLimit(1)
                    if entry.isProtected {
                        Image(systemName: "lock.fill")
                            .font(.system(size: NuvioDesignTokens.Sizes.Icons.xs))
                            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                            .accessibilityLabel("Protected addon")
                    }
                }
                metadataRow
                Text(entry.catalogSummary)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
            }
            Spacer()
            if showsControls {
                controls
            }
        }
        .padding(NuvioDesignTokens.Spacing.xl)
        .background(
            NuvioDesignTokens.Colors.elevated,
            in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.lg, style: .continuous)
        )
        .opacity(entry.isEnabled ? 1 : NuvioDesignTokens.Effects.disabledOpacity)
        .animation(
            NuvioMotion.animation(for: .quick, reduceMotion: reduceMotion),
            value: entry.isEnabled
        )
    }

    private var metadataRow: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.sm) {
            if let version = entry.versionLabel {
                Text(version)
            }
            if !entry.isEnabled {
                Text("Disabled")
            }
            if entry.credentialBadge.displayText != nil {
                AddonCredentialBadgeView(badge: entry.credentialBadge)
            }
        }
        .nuvioTextStyle(.compactBody)
        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
    }

    private var controls: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.sm) {
            Toggle("", isOn: Binding(
                get: { entry.isEnabled },
                set: onToggleEnabled
            ))
            .labelsHidden()
            .disabled(!entry.canToggleEnabled)
            .accessibilityLabel(entry.isEnabled ? "Disable addon" : "Enable addon")
            if showsReorder {
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
                .disabled(!canMoveUp)
                .accessibilityLabel("Move \(entry.displayName) up")
                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
                .disabled(!canMoveDown)
                .accessibilityLabel("Move \(entry.displayName) down")
            }
            if entry.canRemove {
                Button(action: onRemove) {
                    Text("Remove")
                        .nuvioTextStyle(.button)
                        .padding(.horizontal, NuvioDesignTokens.Spacing.md)
                        .frame(height: 44)
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.sm))
                .accessibilityLabel("Remove \(entry.displayName)")
            }
        }
    }
}

/// Credential chip: "Configured" (info) or "Setup required" (warning).
struct AddonCredentialBadgeView: View {
    let badge: AddonCredentialBadge

    private var tint: Color {
        switch badge {
        case .configured: NuvioDesignTokens.Colors.info
        case .setupRequired: NuvioDesignTokens.Colors.warning
        case .none: NuvioDesignTokens.Colors.primaryText
        }
    }

    var body: some View {
        Label(badge.displayText ?? "", systemImage: badge.symbolName ?? "")
            .labelStyle(.titleAndIcon)
            .nuvioTextStyle(.badge)
            .foregroundStyle(tint)
            .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
            .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
            .background(
                tint.opacity(NuvioDesignTokens.Effects.glowSoftOpacity),
                in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xxs)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xxs)
                    .strokeBorder(NuvioDesignTokens.Colors.neutral700)
            )
            .accessibilityElement(children: .combine)
    }
}
