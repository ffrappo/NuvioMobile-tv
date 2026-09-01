import SwiftUI

/// The 400pt hero band shared by the Classic and Grid layouts, matching
/// HeroCarousel.kt: backdrop, bottom canvas gradient, title/logo, metadata,
/// page indicator, and ten-second rotation through HeroPresentation.
/// Classic passes `showsBackdrop: false` because the immersive backdrop is
/// drawn full-screen behind the scrolling column instead.
struct HomeModeHeroBand: View {
    let pages: [HeroItem]
    let height: CGFloat
    let showsBackdrop: Bool
    let onSelect: (HeroItem) -> Void
    let onActiveItemChanged: ((HeroItem) -> Void)?

    @StateObject private var presentation: HeroPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var heroFocused: Bool

    init(
        pages: [HeroItem],
        height: CGFloat,
        showsBackdrop: Bool,
        onSelect: @escaping (HeroItem) -> Void,
        onActiveItemChanged: ((HeroItem) -> Void)? = nil
    ) {
        self.pages = pages
        self.height = height
        self.showsBackdrop = showsBackdrop
        self.onSelect = onSelect
        self.onActiveItemChanged = onActiveItemChanged
        _presentation = StateObject(wrappedValue: HeroPresentation(pages: pages))
    }

    var body: some View {
        Button(action: selectCurrent) {
            ZStack(alignment: .bottomLeading) {
                if let item = presentation.currentPage {
                    ZStack(alignment: .bottomLeading) {
                        if showsBackdrop {
                            NuvioArtworkView(
                                urlString: item.backdropURL,
                                mode: .backdrop,
                                pixelSize: CGSize(width: 1920, height: height),
                                cornerRadius: 0,
                                fadeDuration: NuvioMotion.overlayTransition
                            )
                            .id(item.id)
                            .transition(.opacity)
                        }
                        bottomGradient
                        foreground(item)
                    }
                    .id(item.id)
                } else {
                    NuvioDesignTokens.Colors.canvas
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .overlay(alignment: .bottom) { pageIndicator }
        }
        .buttonStyle(HeroBandButtonStyle())
        .focused($heroFocused)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens details")
        .animation(
            reduceMotion ? nil : .easeInOut(duration: NuvioMotion.heroTransition),
            value: presentation.currentPage?.id
        )
        .onAppear {
            presentation.setReduceMotion(reduceMotion)
            presentation.startAutoAdvance()
            notifyActiveItem()
        }
        .onDisappear {
            presentation.stopAutoAdvance()
            presentation.setActionFocused(false)
        }
        .onChange(of: presentation.currentPage?.id) { _, _ in notifyActiveItem() }
        .onChange(of: pages) { _, newPages in
            presentation.replacePages(newPages)
            notifyActiveItem()
        }
        .onChange(of: reduceMotion) { _, enabled in
            presentation.setReduceMotion(enabled)
        }
        .onChange(of: heroFocused) { _, focused in
            presentation.setActionFocused(focused)
        }
    }

    private var bottomGradient: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: NuvioDesignTokens.Colors.canvas.opacity(0.45), location: 0.55),
                .init(color: NuvioDesignTokens.Colors.canvas.opacity(0.82), location: 0.8),
                .init(color: NuvioDesignTokens.Colors.canvas, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private func foreground(_ item: HeroItem) -> some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
            Spacer(minLength: 0)
            if let logo = item.titleLogoURL, !logo.isEmpty {
                NuvioArtworkView(
                    urlString: logo,
                    mode: .titleLogo,
                    pixelSize: CGSize(width: 420, height: 112),
                    fadeDuration: NuvioMotion.contentTransition,
                    statePresentation: .transparent
                )
                .accessibilityLabel(item.title)
            } else {
                Text(item.title.tvSafe)
                    .nuvioTextStyle(.compactDisplay)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            if !item.genres.isEmpty {
                Text(item.genres.prefix(2).joined(separator: " • ").tvSafe)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
            let badges = item.canonicalBadges
            if !badges.isEmpty {
                Text(badges.joined(separator: " • ").tvSafe)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(1)
            }
        }
        .padding(.leading, NuvioDesignTokens.Layout.nativeSidebarForegroundInset)
        .padding(.trailing, NuvioDesignTokens.Layout.safeHorizontal)
        .padding(.bottom, NuvioDesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    @ViewBuilder
    private var pageIndicator: some View {
        let state = presentation.pageIndicator
        if state.count > 1, !presentation.isDisplayingOverride {
            HStack(spacing: NuvioDesignTokens.Spacing.xxs) {
                ForEach(0..<state.count, id: \.self) { index in
                    Capsule()
                        .fill(
                            state.isActive(index)
                                ? Color.white
                                : Color.white.opacity(0.38)
                        )
                        .frame(
                            width: state.isActive(index) ? 18 : 6,
                            height: 6
                        )
                }
            }
            .padding(.bottom, NuvioDesignTokens.Spacing.lg)
            .accessibilityHidden(true)
        }
    }

    private func selectCurrent() {
        guard let item = presentation.currentPage else { return }
        onSelect(item)
    }

    private func notifyActiveItem() {
        guard let item = presentation.currentPage else { return }
        onActiveItemChanged?(item)
    }

    private var accessibilityLabel: String {
        var parts = [presentation.currentPage?.title ?? "Featured"]
        if presentation.pageIndicator.count > 1 {
            parts.append(
                "Page \(presentation.pageIndicator.activeIndex + 1) of \(presentation.pageIndicator.count)"
            )
        }
        return parts.joined(separator: ", ")
    }
}

/// Flat button chrome for the hero band: focus ring only, no scale, so the
/// band does not jump while rotating.
private struct HeroBandButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.sm, style: .continuous)
                        .stroke(
                            NuvioDesignTokens.Colors.primaryText,
                            lineWidth: NuvioDesignTokens.Focus.ringWidth
                        )
                        .opacity(0.7)
                }
            }
    }
}
