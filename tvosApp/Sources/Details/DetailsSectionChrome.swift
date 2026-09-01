import SwiftUI

/// Shared section chrome for the details screen: headers and the landscape
/// poster card used by similar / collection / trailer rails.
public struct DetailsSectionHeaderView: View {
    public let title: String
    public let symbol: String?

    public init(title: String, symbol: String? = nil) {
        self.title = title
        self.symbol = symbol
    }

    public var body: some View {
        Group {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
        }
        .nuvioTextStyle(.sectionTitle)
        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
        .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Landscape content card sized from the design tokens (260 x 146), matching
/// Android `GridContentCard` + `PosterCardStyle` used by the detail rails.
public struct DetailsPosterCard: View {
    public let title: String
    public let subtitle: String?
    public let artworkURLString: String?
    public let placeholderSymbol: String
    public let isWatched: Bool
    public let showsLabel: Bool
    public let playAffordance: Bool
    public let onSelect: () -> Void

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        subtitle: String? = nil,
        artworkURLString: String?,
        placeholderSymbol: String = "film",
        isWatched: Bool = false,
        showsLabel: Bool = true,
        playAffordance: Bool = false,
        onSelect: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.artworkURLString = artworkURLString
        self.placeholderSymbol = placeholderSymbol
        self.isWatched = isWatched
        self.showsLabel = showsLabel
        self.playAffordance = playAffordance
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                artwork
                if showsLabel {
                    VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xxs) {
                        Text(title)
                            .nuvioTextStyle(.cardTitle)
                            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                            .lineLimit(1)
                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .nuvioTextStyle(.metadata)
                                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, NuvioDesignTokens.Spacing.xxs)
                }
            }
        }
        .buttonStyle(DetailsPosterCardButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Shows details")
    }

    private var artwork: some View {
        ZStack {
            NuvioArtworkView(
                urlString: artworkURLString,
                mode: .backdrop,
                pixelSize: NuvioDesignTokens.Sizes.Cards.continueWatching,
                cornerRadius: NuvioDesignTokens.Shapes.posterRadius,
                placeholderSystemImage: placeholderSymbol
            )
            if playAffordance {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: NuvioDesignTokens.Sizes.Icons.xl))
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .shadow(color: .black.opacity(0.6), radius: NuvioDesignTokens.Blur.soft)
            }
            if isWatched {
                Image(systemName: "checkmark")
                    .nuvioTextStyle(.badge)
                    .foregroundStyle(NuvioDesignTokens.Colors.canvasBlack)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(NuvioDesignTokens.Colors.primaryText, in: Capsule())
                    .padding(NuvioDesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(
            width: NuvioDesignTokens.Sizes.Cards.continueWatching.width,
            height: NuvioDesignTokens.Sizes.Cards.continueWatching.height
        )
    }

    private var accessibilityValue: String {
        var values: [String] = []
        if let subtitle, !subtitle.isEmpty { values.append(subtitle) }
        if isWatched { values.append("Watched") }
        return values.joined(separator: ", ")
    }
}

struct DetailsPosterCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(
                    cornerRadius: NuvioDesignTokens.Shapes.posterRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isFocused ? NuvioDesignTokens.Colors.defaultFocus : .clear,
                    lineWidth: NuvioDesignTokens.Focus.ringWidth
                )
                .allowsHitTesting(false)
            )
            .scaleEffect(scale(configuration))
            .animation(
                NuvioMotion.animation(for: .focus, reduceMotion: reduceMotion),
                value: isFocused
            )
            .animation(
                NuvioMotion.animation(for: .quick, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }

    private func scale(_ configuration: Configuration) -> CGFloat {
        guard !reduceMotion else { return NuvioDesignTokens.Focus.reducedMotionScale }
        if configuration.isPressed { return NuvioDesignTokens.Focus.pressedScale }
        return isFocused ? NuvioDesignTokens.Focus.scale : 1
    }
}
