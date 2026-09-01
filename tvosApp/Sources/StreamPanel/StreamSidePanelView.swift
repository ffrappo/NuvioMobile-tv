import SwiftUI

/// Native SwiftUI port of the Android `StreamSourcesSidePanel`: a fixed-width
/// side panel surface with rounded leading corners, a header with the stream
/// count, a refresh + addon filter chip row, a sort option row, the sorted
/// stream list, and loading / partial-failure states.
///
/// The panel is presentation-only: the integrator supplies a
/// `StreamPanelSnapshot` from `StreamPanelPresentation.snapshot(for:)` and
/// wires the callbacks into its player flow.
struct StreamSidePanelView: View {
    let snapshot: StreamPanelSnapshot
    var contentInfo: String? = nil
    let onClose: () -> Void
    let onReload: () -> Void
    let onSelectAddon: (String?) -> Void
    let onSelectSort: (StreamSortOption) -> Void
    let onSelectStream: (StreamPanelRow) -> Void

    @FocusState private var focusedRowID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.lg) {
            header
            if let contentInfo {
                Text(contentInfo.tvSafe)
                    .nuvioTextStyle(.body)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
            if showsChipRow {
                chipRow
            }
            if snapshot.contentState == .content {
                sortRow
            }
            Divider().overlay(NuvioDesignTokens.Colors.neutral800)
            content
            failureFooters
        }
        .padding(NuvioDesignTokens.Components.sidePanelContentPadding)
        .frame(width: panelWidth)
        .frame(maxHeight: .infinity)
        .background(
            NuvioDesignTokens.Colors.elevated,
            in: UnevenRoundedRectangle(
                topLeadingRadius: NuvioDesignTokens.Shapes.sidePanelRadius,
                bottomLeadingRadius: NuvioDesignTokens.Shapes.sidePanelRadius,
                style: .continuous
            )
        )
        .defaultFocus($focusedRowID, snapshot.focusAnchorRowID)
        .focusSection()
    }

    /// Android uses a 520dp panel; the tvOS player side-panel token owns the
    /// native width.
    private var panelWidth: CGFloat {
        NuvioDesignTokens.Sizes.Player.sidePanelWidth
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            Text("Sources")
                .nuvioTextStyle(.sectionTitle)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            Text(snapshot.headerCountLabel.tvSafe)
                .nuvioTextStyle(.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .lineLimit(2)
            Spacer(minLength: NuvioDesignTokens.Spacing.sm)
            Button("Close", action: onClose)
                .nuvioTextStyle(.button)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                .padding(.horizontal, NuvioDesignTokens.Spacing.md)
                .frame(minHeight: NuvioDesignTokens.Components.chipHeight)
                .background(
                    NuvioDesignTokens.Colors.elevatedSecondary,
                    in: Capsule()
                )
                .buttonStyle(
                    NuvioFocusButtonStyle(
                        cornerRadius: NuvioDesignTokens.Components.chipHeight / 2
                    )
                )
                .accessibilityLabel("Close sources panel")
        }
    }

    // MARK: Chips

    /// Refresh chip (Android `RefreshFilterChip`) followed by the "All" and
    /// addon filter chips.
    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                Button(action: onReload) {
                    HStack(spacing: NuvioDesignTokens.Spacing.xs) {
                        if snapshot.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: NuvioDesignTokens.Sizes.Icons.xs))
                        }
                        Text("Reload")
                            .nuvioTextStyle(.button)
                            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    }
                    .padding(.horizontal, NuvioDesignTokens.Spacing.md)
                    .frame(minHeight: NuvioDesignTokens.Components.chipHeight)
                    .background(
                        NuvioDesignTokens.Colors.elevatedSecondary,
                        in: Capsule()
                    )
                }
                .buttonStyle(
                    NuvioFocusButtonStyle(
                        cornerRadius: NuvioDesignTokens.Components.chipHeight / 2
                    )
                )
                .accessibilityLabel("Reload sources")

                ForEach(snapshot.chips) { chip in
                    StreamAddonChipView(chip: chip) {
                        onSelectAddon(chip.name)
                    }
                }
            }
            .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
        }
        .scrollIndicators(.hidden)
        .focusSection()
    }

    /// Android hides the chip row until addons or chips exist; while loading
    /// the refresh chip alone remains useful.
    private var showsChipRow: Bool {
        snapshot.chips.count > 1 || snapshot.isLoading
    }

    private var sortRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NuvioDesignTokens.Spacing.xs) {
                Text("Sort")
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                ForEach(snapshot.sortOptions, id: \.self) { option in
                    StreamSortChipView(
                        option: option,
                        isSelected: option == snapshot.selectedSortOption
                    ) {
                        onSelectSort(option)
                    }
                }
            }
            .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
        }
        .scrollIndicators(.hidden)
        .focusSection()
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch snapshot.contentState {
        case .loading:
            loadingFooter
        case .failure(let messages):
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
                ForEach(messages, id: \.self) { message in
                    failureMessage(message)
                }
            }
        case .empty:
            emptyFooter
        case .content:
            streamList
        }
    }

    private var loadingFooter: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            ProgressView()
            Text("Checking enabled addons")
                .nuvioTextStyle(.body)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
    }

    private var emptyFooter: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            Text("No streams")
                .nuvioTextStyle(.body)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            Text("The enabled addons returned no streams for this title.")
                .nuvioTextStyle(.compactBody)
                .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var streamList: some View {
        ScrollView {
            LazyVStack(spacing: NuvioDesignTokens.Spacing.sm) {
                ForEach(snapshot.rows) { row in
                    StreamPanelRowView(row: row) {
                        onSelectStream(row)
                    }
                    .focused($focusedRowID, equals: row.id)
                }
            }
            .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
        }
        .scrollIndicators(.hidden)
        .focusSection()
    }

    /// Partial-failure footers: addons that failed keep their message below
    /// the list, mirroring the tvOS source list and the Android chip error
    /// status.
    @ViewBuilder
    private var failureFooters: some View {
        if snapshot.contentState == .content, !snapshot.failures.isEmpty {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
                ForEach(snapshot.failures, id: \.self) { message in
                    failureMessage(message)
                }
            }
            .transition(
                reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom))
            )
        }
    }

    private func failureMessage(_ message: String) -> some View {
        HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: NuvioDesignTokens.Sizes.Icons.xs))
                .foregroundStyle(NuvioDesignTokens.Colors.warning)
            Text(message.tvSafe)
                .nuvioTextStyle(.compactBody)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: NuvioDesignTokens.Spacing.none)
        }
        .accessibilityElement(children: .combine)
    }
}
