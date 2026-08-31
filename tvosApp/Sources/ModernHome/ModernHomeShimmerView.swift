import SwiftUI

/// Android parity: the Modern Home loading state renders shimmering
/// placeholder geometry instead of a centered spinner.
struct ModernHomeShimmerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let rowsHeight = proxy.size.height * 0.52
            let rowsTop = proxy.size.height - rowsHeight
            ZStack(alignment: .topLeading) {
                heroSkeleton(width: proxy.size.width)
                    .frame(height: rowsTop)
                VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.Rail.rowGap) {
                    ForEach(0..<3, id: \.self) { _ in
                        railSkeleton
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, rowsTop + NuvioDesignTokens.Spacing.Rail.rowGap)
                .padding(.bottom, NuvioDesignTokens.Spacing.lg)
            }
        }
        .background(NuvioDesignTokens.Colors.canvasBlack.ignoresSafeArea())
        .accessibilityLabel("Loading your Home")
    }

    private func heroSkeleton(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            NuvioShimmerShape(
                size: CGSize(
                    width: min(width * 0.36, 560),
                    height: 56
                ),
                cornerRadius: 6
            )
            NuvioShimmerShape(size: CGSize(width: min(width * 0.30, 480), height: 20), cornerRadius: 4)
            NuvioShimmerShape(size: CGSize(width: min(width * 0.42, 700), height: 20), cornerRadius: 4)
            NuvioShimmerShape(size: CGSize(width: min(width * 0.24, 380), height: 20), cornerRadius: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, NuvioDesignTokens.Layout.nativeSidebarForegroundInset)
        .padding(.bottom, ModernHomeCatalogContent.heroRailOverlap + NuvioDesignTokens.Spacing.lg)
    }

    private var railSkeleton: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            NuvioShimmerShape(size: CGSize(width: 120, height: 28), cornerRadius: 4)
            HStack(spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                ForEach(0..<8, id: \.self) { _ in
                    NuvioShimmerShape(
                        size: CGSize(
                            width: ModernHomeRowTokens.posterWidth,
                            height: ModernHomeRowTokens.posterHeight
                        ),
                        cornerRadius: NuvioDesignTokens.Shapes.posterRadius
                    )
                }
            }
            .padding(.leading, ModernHomeRowTokens.homeForegroundLeadingMargin)
        }
    }
}
