import SwiftUI

/// Brand focus chrome shared by the Classic rails and Grid cells: 2pt ring
/// with a soft glow, matching the Nuvio focus token grammar.
struct HomeModeFocusRing: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        NuvioDesignTokens.Colors.primaryText,
                        lineWidth: NuvioDesignTokens.Focus.ringWidth
                    )
                    .opacity(isFocused ? 1 : 0)
                    .shadow(
                        color: .white.opacity(isFocused ? 0.28 : 0),
                        radius: NuvioDesignTokens.Blur.soft,
                        y: 2
                    )
            }
            .animation(
                reduceMotion ? nil : .easeOut(duration: NuvioMotion.focusTransition),
                value: isFocused
            )
    }
}

/// Poster cell used by the Classic rails and the Grid sections: artwork at
/// the requested size, focus ring, watched badge, and a title/year label.
struct HomeModePosterCard: View {
    let item: RailItem
    let width: CGFloat
    let height: CGFloat
    let showsLabel: Bool
    let action: () -> Void

    init(
        item: RailItem,
        size: CGSize,
        showsLabel: Bool = true,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.width = size.width
        self.height = size.height
        self.showsLabel = showsLabel
        self.action = action
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                ZStack(alignment: .topTrailing) {
                    NuvioArtworkView(
                        url: posterURL,
                        mode: .poster,
                        pixelSize: CGSize(width: width, height: height),
                        cornerRadius: NuvioDesignTokens.Shapes.posterRadius
                    )
                    .frame(width: width, height: height)
                    .background(NuvioDesignTokens.Colors.elevated)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: NuvioDesignTokens.Shapes.posterRadius,
                            style: .continuous
                        )
                    )
                    if item.status.isWatched {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(.white, in: Capsule())
                            .padding(NuvioDesignTokens.Spacing.xs)
                            .accessibilityLabel("Watched")
                    }
                }
                .modifier(
                    HomeModeFocusRing(cornerRadius: NuvioDesignTokens.Shapes.posterRadius)
                )

                if showsLabel {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title.tvSafe)
                            .nuvioTextStyle(.cardTitle)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let year = item.year, !year.isEmpty {
                            Text(year.tvSafe)
                                .nuvioTextStyle(.metadata)
                                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(width: width, alignment: .leading)
                }
            }
        }
        .buttonStyle(HomeModePosterButtonStyle())
        .accessibilityLabel(item.title.tvSafe)
        .accessibilityValue(item.status.isWatched ? "Watched" : "")
        .accessibilityHint("Shows details")
    }

    private var posterURL: URL? {
        if case .url(let url) = item.posterArtwork { return url }
        return nil
    }
}

struct HomeModePosterButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .animation(
                reduceMotion ? nil : .easeOut(duration: NuvioMotion.focusTransition),
                value: configuration.isPressed
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: NuvioMotion.focusTransition),
                value: isFocused
            )
    }

    private func scale(isPressed: Bool) -> CGFloat {
        if isPressed { return NuvioDesignTokens.Focus.pressedScale }
        guard !reduceMotion else { return 1 }
        return isFocused ? NuvioDesignTokens.Focus.scale : 1
    }
}
