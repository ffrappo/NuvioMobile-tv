import SwiftUI

public struct NuvioShimmerShape: View {
    public let size: CGSize
    public let cornerRadius: CGFloat
    public let cycleDuration: TimeInterval
    public let baseColor: Color
    public let highlightColor: Color
    public let highlightBandFraction: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        size: CGSize,
        cornerRadius: CGFloat,
        cycleDuration: TimeInterval = 1.2,
        baseColor: Color = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
        highlightColor: Color = Color(red: 36 / 255, green: 36 / 255, blue: 36 / 255),
        highlightBandFraction: CGFloat = 0.55
    ) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.cycleDuration = cycleDuration
        self.baseColor = baseColor
        self.highlightColor = highlightColor
        self.highlightBandFraction = highlightBandFraction
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let duration = max(cycleDuration, 0.01)
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: duration) / duration
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(baseColor)
                .overlay {
                    if !reduceMotion {
                        GeometryReader { proxy in
                            let bandWidth = proxy.size.width * max(highlightBandFraction, 0)
                            LinearGradient(
                                colors: [.clear, highlightColor, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: bandWidth)
                            .offset(x: -bandWidth + (proxy.size.width + bandWidth) * phase)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}

public struct NuvioPosterSkeleton: View {
    public let artworkSize: CGSize
    public let artworkRadius: CGFloat
    public let titleSize: CGSize
    public let metadataSize: CGSize
    public let textRadius: CGFloat
    public let spacing: CGFloat
    public let cycleDuration: TimeInterval
    public let baseColor: Color
    public let highlightColor: Color

    public init(
        artworkSize: CGSize = CGSize(width: 126, height: 189),
        artworkRadius: CGFloat = 12,
        titleSize: CGSize = CGSize(width: 126, height: 24),
        metadataSize: CGSize = CGSize(width: 126, height: 16),
        textRadius: CGFloat = 12,
        spacing: CGFloat = 12,
        cycleDuration: TimeInterval = 1.2,
        baseColor: Color = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
        highlightColor: Color = Color(red: 36 / 255, green: 36 / 255, blue: 36 / 255)
    ) {
        self.artworkSize = artworkSize
        self.artworkRadius = artworkRadius
        self.titleSize = titleSize
        self.metadataSize = metadataSize
        self.textRadius = textRadius
        self.spacing = spacing
        self.cycleDuration = cycleDuration
        self.baseColor = baseColor
        self.highlightColor = highlightColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            shimmer(size: artworkSize, radius: artworkRadius)
            shimmer(size: titleSize, radius: textRadius)
            shimmer(size: metadataSize, radius: textRadius)
        }
        .accessibilityHidden(true)
    }

    private func shimmer(size: CGSize, radius: CGFloat) -> some View {
        NuvioShimmerShape(
            size: size,
            cornerRadius: radius,
            cycleDuration: cycleDuration,
            baseColor: baseColor,
            highlightColor: highlightColor
        )
    }
}

public struct NuvioBackdropSkeleton: View {
    public let size: CGSize
    public let cornerRadius: CGFloat
    public let cycleDuration: TimeInterval
    public let baseColor: Color
    public let highlightColor: Color

    public init(
        size: CGSize = CGSize(width: 320, height: 180),
        cornerRadius: CGFloat = 16,
        cycleDuration: TimeInterval = 1.2,
        baseColor: Color = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
        highlightColor: Color = Color(red: 36 / 255, green: 36 / 255, blue: 36 / 255)
    ) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.cycleDuration = cycleDuration
        self.baseColor = baseColor
        self.highlightColor = highlightColor
    }

    public var body: some View {
        NuvioShimmerShape(
            size: size,
            cornerRadius: cornerRadius,
            cycleDuration: cycleDuration,
            baseColor: baseColor,
            highlightColor: highlightColor
        )
    }
}

public struct NuvioHeroSkeleton: View {
    public let size: CGSize
    public let cornerRadius: CGFloat
    public let headlineSize: CGSize
    public let bodySize: CGSize
    public let textRadius: CGFloat
    public let contentPadding: CGFloat
    public let lineSpacing: CGFloat
    public let cycleDuration: TimeInterval
    public let baseColor: Color
    public let highlightColor: Color

    public init(
        size: CGSize = CGSize(width: 320, height: 180),
        cornerRadius: CGFloat = 16,
        headlineSize: CGSize = CGSize(width: 126, height: 36),
        bodySize: CGSize = CGSize(width: 126, height: 24),
        textRadius: CGFloat = 12,
        contentPadding: CGFloat = 24,
        lineSpacing: CGFloat = 12,
        cycleDuration: TimeInterval = 1.2,
        baseColor: Color = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
        highlightColor: Color = Color(red: 36 / 255, green: 36 / 255, blue: 36 / 255)
    ) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.headlineSize = headlineSize
        self.bodySize = bodySize
        self.textRadius = textRadius
        self.contentPadding = contentPadding
        self.lineSpacing = lineSpacing
        self.cycleDuration = cycleDuration
        self.baseColor = baseColor
        self.highlightColor = highlightColor
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            shimmer(size: size, radius: cornerRadius)
            VStack(alignment: .leading, spacing: lineSpacing) {
                shimmer(size: headlineSize, radius: textRadius)
                shimmer(size: bodySize, radius: textRadius)
            }
            .padding(contentPadding)
        }
        .accessibilityHidden(true)
    }

    private func shimmer(size: CGSize, radius: CGFloat) -> some View {
        NuvioShimmerShape(
            size: size,
            cornerRadius: radius,
            cycleDuration: cycleDuration,
            baseColor: baseColor,
            highlightColor: highlightColor
        )
    }
}

public struct NuvioRailRowSkeleton: View {
    public let itemCount: Int
    public let itemSize: CGSize
    public let itemRadius: CGFloat
    public let titleSize: CGSize
    public let titleRadius: CGFloat
    public let itemGap: CGFloat
    public let rowGap: CGFloat
    public let cycleDuration: TimeInterval
    public let baseColor: Color
    public let highlightColor: Color

    public init(
        itemCount: Int = 6,
        itemSize: CGSize = CGSize(width: 126, height: 189),
        itemRadius: CGFloat = 12,
        titleSize: CGSize = CGSize(width: 320, height: 32),
        titleRadius: CGFloat = 12,
        itemGap: CGFloat = 12,
        rowGap: CGFloat = 24,
        cycleDuration: TimeInterval = 1.2,
        baseColor: Color = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
        highlightColor: Color = Color(red: 36 / 255, green: 36 / 255, blue: 36 / 255)
    ) {
        self.itemCount = itemCount
        self.itemSize = itemSize
        self.itemRadius = itemRadius
        self.titleSize = titleSize
        self.titleRadius = titleRadius
        self.itemGap = itemGap
        self.rowGap = rowGap
        self.cycleDuration = cycleDuration
        self.baseColor = baseColor
        self.highlightColor = highlightColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: rowGap) {
            shimmer(size: titleSize, radius: titleRadius)
            HStack(spacing: itemGap) {
                ForEach(0..<max(itemCount, 0), id: \.self) { _ in
                    shimmer(size: itemSize, radius: itemRadius)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func shimmer(size: CGSize, radius: CGFloat) -> some View {
        NuvioShimmerShape(
            size: size,
            cornerRadius: radius,
            cycleDuration: cycleDuration,
            baseColor: baseColor,
            highlightColor: highlightColor
        )
    }
}
