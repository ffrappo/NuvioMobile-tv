import SwiftUI

/// Network screen: connection status, speed tests, cache, and performance
/// toggles, mirroring `NetworkSettingsScreen.kt`.
public struct NetworkSettingsView: View {
    private let state: NuvioSettingsState
    private let onChange: (NuvioSettingsChange) -> Void

    public init(state: NuvioSettingsState, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.state = state
        self.onChange = onChange
    }

    public var body: some View {
        SettingsWorkspaceContainer {
            VStack(alignment: .leading, spacing: SettingsDesignMetrics.sectionSpacing) {
                ForEach(NuvioSettingsTree.sections(in: .network, state: state)) { section in
                    SettingsSectionListView(section: section, onChange: onChange)
                }
            }
        }
    }
}

/// Diagnostics screen: reporting toggles plus the three dense diagnostics
/// cards from `DiagnosticsCard.kt`.
public struct DiagnosticsSettingsView: View {
    private let state: NuvioSettingsState
    private let diagnostics: NuvioPlaybackDiagnostics
    private let onChange: (NuvioSettingsChange) -> Void

    public init(
        state: NuvioSettingsState,
        diagnostics: NuvioPlaybackDiagnostics,
        onChange: @escaping (NuvioSettingsChange) -> Void
    ) {
        self.state = state
        self.diagnostics = diagnostics
        self.onChange = onChange
    }

    public var body: some View {
        SettingsWorkspaceContainer {
            VStack(alignment: .leading, spacing: SettingsDesignMetrics.sectionSpacing) {
                ForEach(NuvioSettingsTree.sections(in: .diagnostics, state: state)) { section in
                    SettingsSectionListView(section: section, onChange: onChange)
                }
                ForEach(NuvioDiagnosticsBuilder.cards(diagnostics: diagnostics)) { card in
                    SettingsDiagnosticsCardView(card: card)
                }
            }
        }
    }
}

/// `DiagnosticsSectionCard`: read-only card of label/value rows; the card is
/// focusable so screen readers can traverse it in one D-pad stop.
struct SettingsDiagnosticsCardView: View {
    let card: NuvioDiagnosticsCard

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xxs) {
            Text(card.title.uppercased())
                .font(NuvioTypography.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.brand)
            if let subtitle = card.subtitle {
                Text(subtitle)
                    .font(NuvioTypography.compactBody)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
            ForEach(card.rows) { row in
                HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.sm) {
                    Text(row.label)
                        .font(NuvioTypography.compactBody)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                        .frame(width: 170, alignment: .leading)
                    Text(row.value)
                        .font(NuvioTypography.compactBody)
                        .foregroundStyle(color(for: row.tone))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, NuvioDesignTokens.Spacing.sm + 2)
        .padding(.vertical, NuvioDesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
                .fill(NuvioDesignTokens.Colors.elevatedSecondary)
        )
        .accessibilityElement(children: .combine)
    }

    private func color(for tone: NuvioDiagnosticTone) -> Color {
        switch tone {
        case .normal: return NuvioDesignTokens.Colors.primaryText
        case .success: return NuvioDesignTokens.Colors.success
        case .error: return NuvioDesignTokens.Colors.error
        }
    }
}

/// About screen: version, update channel, and legal rows, mirroring
/// `AboutScreen.kt` and `UpdateChannelSettings.kt`.
public struct AboutSettingsView: View {
    private let state: NuvioSettingsState
    private let onChange: (NuvioSettingsChange) -> Void

    public init(state: NuvioSettingsState, onChange: @escaping (NuvioSettingsChange) -> Void) {
        self.state = state
        self.onChange = onChange
    }

    public var body: some View {
        SettingsWorkspaceContainer {
            VStack(alignment: .leading, spacing: SettingsDesignMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xxs) {
                    Text("Nuvio")
                        .font(NuvioTypography.compactDisplay)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    Text("Made with ❤️ by the Nuvio community")
                        .font(NuvioTypography.metadata)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
                .padding(.bottom, NuvioDesignTokens.Spacing.xs)
                ForEach(NuvioSettingsTree.sections(in: .about, state: state)) { section in
                    SettingsSectionListView(section: section, onChange: onChange)
                }
            }
        }
    }
}
