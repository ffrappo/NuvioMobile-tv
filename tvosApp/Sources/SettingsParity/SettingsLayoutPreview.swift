import SwiftUI

/// One rounded rectangle in a layout preview schematic, in unit space
/// (0...1 relative to the preview box). Geometry ported from
/// `LayoutPreviewAnimation.kt` draw functions.
public struct NuvioLayoutPreviewRect: Equatable, Sendable, Identifiable {
    public enum Role: Equatable, Sendable {
        case hero
        case primaryCard
        case secondaryCard
    }

    public let id: String
    public let frame: CGRect
    /// Corner radius as a fraction of the preview height.
    public let cornerRadiusFraction: CGFloat
    public let role: Role

    public init(id: String, frame: CGRect, cornerRadiusFraction: CGFloat, role: Role) {
        self.id = id
        self.frame = frame
        self.cornerRadiusFraction = cornerRadiusFraction
        self.role = role
    }
}

/// Static preview geometry per home layout. Values mirror the Android draw
/// functions exactly (fractions of the preview width/height).
public enum NuvioLayoutPreviewGeometry {
    /// Modern: hero occupies 62% of the height, then a wide card row at 0.73.
    public static func modernRects() -> [NuvioLayoutPreviewRect] {
        let horizontalPadding: CGFloat = 0.05
        let topPadding: CGFloat = 0.06
        let heroHeight: CGFloat = 0.62
        let cardHeight: CGFloat = 0.24
        let cardWidth = cardHeight * 1.45
        let gap: CGFloat = 0.03
        let step = cardWidth + gap
        let rowTop: CGFloat = topPadding + heroHeight + 0.05

        var rects = [NuvioLayoutPreviewRect(
            id: "modern.hero",
            frame: CGRect(x: horizontalPadding, y: topPadding, width: 1 - horizontalPadding * 2, height: heroHeight),
            cornerRadiusFraction: 0.05,
            role: .hero
        )]
        let cardsToFill = Int(1 / step) + 6
        var visibleIndex = 0
        for i in 0...cardsToFill {
            let x = horizontalPadding + CGFloat(i) * step
            guard x + cardWidth > 0, x < 1 else { continue }
            // Android tints every third card stronger (i % 3 == 1).
            let role: NuvioLayoutPreviewRect.Role = (i % 3 == 1) ? .primaryCard : .secondaryCard
            rects.append(NuvioLayoutPreviewRect(
                id: "modern.card.\(visibleIndex)",
                frame: CGRect(x: x, y: rowTop, width: cardWidth, height: cardHeight),
                cornerRadiusFraction: 0.03,
                role: role
            ))
            visibleIndex += 1
        }
        return rects
    }

    /// Classic: three rows, the middle one emphasized.
    public static func classicRects() -> [NuvioLayoutPreviewRect] {
        let rowCount = 3
        let rowSpacing: CGFloat = 0.04
        let rowHeight = (1 - rowSpacing * CGFloat(rowCount + 1)) / CGFloat(rowCount)
        let cardWidth: CGFloat = 1 / 5.5
        let cardHeight = rowHeight * 0.85
        let gap: CGFloat = 1 / 40
        let step = cardWidth + gap

        var rects: [NuvioLayoutPreviewRect] = []
        for rowIndex in 0..<rowCount {
            let rowY = rowSpacing + CGFloat(rowIndex) * (rowHeight + rowSpacing)
            let cardTop = rowY + (rowHeight - cardHeight) / 2
            for i in 0..<7 {
                let cardX = gap * 2 + CGFloat(i) * step
                guard cardX < 1 else { break }
                rects.append(NuvioLayoutPreviewRect(
                    id: "classic.\(rowIndex).\(i)",
                    frame: CGRect(x: cardX, y: cardTop, width: cardWidth, height: cardHeight),
                    cornerRadiusFraction: 0.02,
                    role: rowIndex == 1 ? .primaryCard : .secondaryCard
                ))
            }
        }
        return rects
    }

    /// Grid: five columns of portrait cards.
    public static func gridRects() -> [NuvioLayoutPreviewRect] {
        let columns = 5
        let cardGap: CGFloat = 0.025
        let cardWidth = (1 - cardGap * CGFloat(columns + 1)) / CGFloat(columns)
        let cardHeight = cardWidth * 1.4
        let rowStep = cardHeight + cardGap

        var rects: [NuvioLayoutPreviewRect] = []
        var row = 0
        while cardGap + CGFloat(row) * rowStep < 1 {
            let cardY = cardGap + CGFloat(row) * rowStep
            // Rows cycle two strong, one dim (row % 3 < 2).
            let role: NuvioLayoutPreviewRect.Role = (row % 3 < 2) ? .primaryCard : .secondaryCard
            for col in 0..<columns {
                let cardX = cardGap + CGFloat(col) * (cardWidth + cardGap)
                rects.append(NuvioLayoutPreviewRect(
                    id: "grid.\(row).\(col)",
                    frame: CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight),
                    cornerRadiusFraction: 0.015,
                    role: role
                ))
            }
            row += 1
        }
        return rects
    }

    public static func rects(for layout: NuvioHomeLayout) -> [NuvioLayoutPreviewRect] {
        switch layout {
        case .modern: return modernRects()
        case .classic: return classicRects()
        case .grid: return gridRects()
        }
    }

    /// Scrolling distance for one full animation cycle (a whole number of card
    /// periods) so the loop lands on a pixel-identical frame.
    public static func scrollPeriod(for layout: NuvioHomeLayout) -> CGFloat {
        switch layout {
        case .modern:
            let cardHeight: CGFloat = 0.24
            let cardWidth = cardHeight * 1.45
            return (cardWidth + 0.03) * 3
        case .classic:
            let cardWidth: CGFloat = 1 / 5.5
            return (cardWidth + 1 / 40) * 2
        case .grid:
            let cardGap: CGFloat = 0.025
            let cardWidth = (1 - cardGap * 6) / 5
            let cardHeight = cardWidth * 1.4
            return (cardHeight + cardGap) * 3
        }
    }
}

/// Canvas rendering of a layout schematic. Animation pauses when Reduce Motion
/// is enabled, matching the `animated` parameter gating in
/// `LayoutPreviewAnimation.kt`.
public struct NuvioLayoutPreviewView: View {
    public let layout: NuvioHomeLayout
    public let animated: Bool
    public let accentColor: Color

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        layout: NuvioHomeLayout,
        animated: Bool = true,
        accentColor: Color = NuvioDesignTokens.Colors.brand
    ) {
        self.layout = layout
        self.animated = animated
        self.accentColor = accentColor
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !shouldAnimate)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let phase = shouldAnimate
                    ? CGFloat(elapsed.truncatingRemainder(dividingBy: 1))
                    : 0
                draw(in: &context, size: size, phase: phase)
            }
        }
        .background(NuvioDesignTokens.Colors.canvas)
        .clipShape(RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.sm, style: .continuous))
        .accessibilityLabel(Text("\(layout.displayName) preview"))
    }

    private var shouldAnimate: Bool {
        animated && !reduceMotion
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, phase: CGFloat) {
        let rects = NuvioLayoutPreviewGeometry.rects(for: layout)
        let period = NuvioLayoutPreviewGeometry.scrollPeriod(for: layout)
        let offset = phase * period * size.width

        for rect in rects {
            var frame = CGRect(
                x: rect.frame.minX * size.width,
                y: rect.frame.minY * size.height,
                width: rect.frame.width * size.width,
                height: rect.frame.height * size.height
            )
            // Only the scrolling band moves; the modern hero stays put.
            if rect.role != .hero {
                frame.origin.x -= offset
                // Wrap cards that scrolled off the left edge back to the right.
                if frame.maxX < 0 {
                    frame.origin.x += (period + rect.frame.width) * size.width
                }
                guard frame.minX < size.width else { continue }
            }
            let radius = rect.cornerRadiusFraction * size.height
            let alpha: Double
            switch (layout, rect.role) {
            case (_, .hero): alpha = 0.38
            case (.modern, .primaryCard): alpha = 0.46
            case (.modern, .secondaryCard): alpha = 0.28
            case (.classic, .primaryCard): alpha = 0.6
            case (.classic, .secondaryCard): alpha = 0.3
            case (.grid, .primaryCard): alpha = 0.5
            case (.grid, .secondaryCard): alpha = 0.3
            }
            context.fill(
                Path(roundedRect: frame, cornerRadius: radius),
                with: .color(accentColor.opacity(alpha))
            )
        }
    }
}
