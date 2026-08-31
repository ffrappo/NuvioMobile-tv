import SwiftUI

public struct PosterCardExpansion: Equatable, Sendable {
    public var backdropArtwork: PosterArtworkSource
    public var overview: String?
    public var metadata: [String]

    public init(
        backdropArtwork: PosterArtworkSource,
        overview: String? = nil,
        metadata: [String] = []
    ) {
        self.backdropArtwork = backdropArtwork
        self.overview = overview
        self.metadata = metadata
    }
}

public struct PosterCardView: View {
    public let title: String
    public let year: String?
    public let artwork: PosterArtworkSource
    public let status: PosterCardStatus
    public let showsLabel: Bool
    public let isExpanded: Bool
    public let expansion: PosterCardExpansion?
    public let artworkProvider: PosterArtworkProvider
    public let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        year: String? = nil,
        artwork: PosterArtworkSource,
        status: PosterCardStatus = PosterCardStatus(),
        showsLabel: Bool = true,
        isExpanded: Bool = false,
        expansion: PosterCardExpansion? = nil,
        artworkProvider: @escaping PosterArtworkProvider,
        onSelect: @escaping () -> Void
    ) {
        self.title = title
        self.year = year
        self.artwork = artwork
        self.status = status
        self.showsLabel = showsLabel
        self.isExpanded = isExpanded
        self.expansion = expansion
        self.artworkProvider = artworkProvider
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            Group {
                if isExpanded, let expansion {
                    expandedContent(expansion)
                        .transition(.opacity)
                } else {
                    collapsedContent
                        .transition(.opacity)
                }
            }
            .frame(
                width: isExpanded && expansion != nil
                    ? ModernHomeRowTokens.backdropWidth
                    : ModernHomeRowTokens.posterWidth,
                alignment: .topLeading
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: ModernHomeRowTokens.contentTransition),
                value: isExpanded
            )
        }
        .buttonStyle(PosterCardButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Shows details")
    }

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            artworkSurface(
                source: artwork,
                width: ModernHomeRowTokens.posterWidth,
                height: ModernHomeRowTokens.posterHeight,
                cornerRadius: ModernHomeRowTokens.posterCornerRadius
            )

            if showsLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .nuvioTextStyle(.cardTitle)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let year, !year.isEmpty {
                        Text(year)
                            .nuvioTextStyle(.metadata)
                            .foregroundStyle(ModernHomeRowTokens.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func expandedContent(_ expansion: PosterCardExpansion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                artworkSurface(
                    source: expansion.backdropArtwork,
                    width: ModernHomeRowTokens.backdropWidth,
                    height: ModernHomeRowTokens.backdropHeight,
                    cornerRadius: ModernHomeRowTokens.backdropCornerRadius
                )

                LinearGradient(
                    colors: [.clear, .black.opacity(0.82)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: ModernHomeRowTokens.backdropCornerRadius,
                        style: .continuous
                    )
                )

                Text(title)
                    .nuvioTextStyle(.cardTitle)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(12)
            }

            let metadata = expandedMetadata(expansion)
            if !metadata.isEmpty {
                Text(metadata.joined(separator: "  •  "))
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(ModernHomeRowTokens.secondaryText)
                    .lineLimit(1)
            }

            if let overview = expansion.overview, !overview.isEmpty {
                Text(overview)
                    .nuvioTextStyle(.compactBody)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
        }
    }

    private func expandedMetadata(_ expansion: PosterCardExpansion) -> [String] {
        var result = expansion.metadata.filter { !$0.isEmpty }
        if let year, !year.isEmpty, !result.contains(year) {
            result.append(year)
        }
        return result
    }

    private func artworkSurface(
        source: PosterArtworkSource,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            artworkProvider(source)
                .frame(width: width, height: height)
                .clipped()

            if !status.visibleBadges.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(status.visibleBadges.enumerated()), id: \.offset) { _, badge in
                        PosterBadgeView(badge: badge)
                    }
                }
                .padding(8)
            }
        }
        .frame(width: width, height: height)
        .background(ModernHomeRowTokens.elevated)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if status.showsProgress {
                PosterProgressBar(fraction: status.clampedProgress)
            }
        }
        .modifier(PosterFocusChrome(cornerRadius: cornerRadius))
    }

    private var accessibilityValue: String {
        var values = status.visibleBadges.map(\.accessibilityLabel)
        if status.showsProgress {
            values.append("\(Int((status.clampedProgress * 100).rounded())) percent watched")
        }
        return values.joined(separator: ", ")
    }
}

public struct PosterCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .animation(
                reduceMotion ? nil : .easeOut(duration: ModernHomeRowTokens.focusTransition),
                value: configuration.isPressed
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: ModernHomeRowTokens.focusTransition),
                value: isFocused
            )
    }

    private func scale(isPressed: Bool) -> CGFloat {
        if isPressed { return ModernHomeRowTokens.pressedScale }
        guard !reduceMotion else { return 1 }
        return isFocused ? ModernHomeRowTokens.focusScale : 1
    }
}

private struct PosterFocusChrome: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white, lineWidth: ModernHomeRowTokens.focusRingWidth)
                    .opacity(isFocused ? 1 : 0)
                    .shadow(
                        color: .white.opacity(isFocused ? 0.28 : 0),
                        radius: ModernHomeRowTokens.softBlur,
                        y: 2
                    )
            }
            .animation(
                reduceMotion ? nil : .easeOut(duration: ModernHomeRowTokens.focusTransition),
                value: isFocused
            )
    }
}

private struct PosterBadgeView: View {
    let badge: PosterBadge

    var body: some View {
        Group {
            switch badge {
            case .watched:
                Image(systemName: "checkmark")
            case .inLibrary:
                Image(systemName: "bookmark.fill")
            case .unwatchedNew:
                Text("NEW")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.black)
        .frame(minWidth: 20, minHeight: 20)
        .padding(.horizontal, badge == .unwatchedNew ? 3 : 0)
        .background(.white, in: Capsule())
        .accessibilityLabel(badge.accessibilityLabel)
    }
}

private struct PosterProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.white.opacity(0.28)
                Color.accentColor
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: ModernHomeRowTokens.progressHeight)
        .accessibilityHidden(true)
    }
}

private extension PosterBadge {
    var accessibilityLabel: String {
        switch self {
        case .watched: return "Watched"
        case .inLibrary: return "In library"
        case .unwatchedNew: return "New unwatched release"
        }
    }
}
