import SwiftUI

public struct HeroAction: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String?
    public let perform: (HeroItem) -> Void

    public init(
        id: String,
        title: String,
        systemImage: String? = nil,
        perform: @escaping (HeroItem) -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.perform = perform
    }
}

public struct HeroSceneView: View {
    @ObservedObject public var presentation: HeroPresentation
    public let actions: [HeroAction]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @FocusState private var focusedActionID: String?

    public init(presentation: HeroPresentation, actions: [HeroAction] = []) {
        self.presentation = presentation
        self.actions = Array(actions.prefix(2))
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                NuvioDesignTokens.Colors.canvasBlack
                if let item = presentation.currentPage {
                    heroPage(item, in: proxy.size)
                        .id(item.id)
                        .transition(.opacity)
                }
            }
            .animation(
                NuvioMotion.animation(
                    for: .hero,
                    reduceMotion: reduceMotion,
                    substitute: .crossFade
                ),
                value: presentation.currentIndex
            )
        }
        .background(NuvioDesignTokens.Colors.canvasBlack)
        .ignoresSafeArea()
        .onAppear {
            presentation.setReduceMotion(reduceMotion)
            presentation.startAutoAdvance()
        }
        .onDisappear {
            presentation.stopAutoAdvance()
            presentation.setActionFocused(false)
        }
        .onChange(of: reduceMotion) { _, enabled in
            presentation.setReduceMotion(enabled)
        }
        .onChange(of: focusedActionID) { _, focusedID in
            presentation.setActionFocused(focusedID != nil)
        }
    }

    private func heroPage(_ item: HeroItem, in size: CGSize) -> some View {
        ZStack {
            NuvioArtworkView(
                urlString: item.backdropURL,
                mode: .backdrop,
                pixelSize: size,
                cornerRadius: 0,
                fadeDuration: NuvioMotion.overlayTransition
            )
            directionalGradients
            content(item, in: size)
            pageIndicator
        }
        .accessibilityElement(children: .contain)
    }

    private var directionalGradients: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: NuvioDesignTokens.Colors.canvas, location: 0),
                    .init(color: NuvioDesignTokens.Colors.canvas.opacity(0.86), location: 0.22),
                    .init(color: NuvioDesignTokens.Colors.canvas.opacity(0.56), location: 0.46),
                    .init(color: NuvioDesignTokens.Colors.canvas.opacity(0.16), location: 0.76),
                    .init(color: .clear, location: 1),
                ],
                startPoint: layoutDirection == .rightToLeft ? .trailing : .leading,
                endPoint: UnitPoint(
                    x: layoutDirection == .rightToLeft ? 0.55 : 0.45,
                    y: 0.5
                )
            )
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: NuvioDesignTokens.Colors.canvas.opacity(0.25), location: 0.40),
                    .init(color: NuvioDesignTokens.Colors.canvas.opacity(0.65), location: 0.75),
                    .init(color: NuvioDesignTokens.Colors.canvas, location: 1),
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.82),
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func content(_ item: HeroItem, in size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
            Spacer(minLength: 0)
            title(item)
            if !item.genres.isEmpty {
                Text(item.genres.prefix(2).joined(separator: " • "))
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
            metadata(item)
            if let overview = item.overview?.trimmingCharacters(in: .whitespacesAndNewlines),
               !overview.isEmpty {
                Text(overview)
                    .nuvioTextStyle(.body)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(4)
            }
            actionButtons(item)
        }
        .frame(maxWidth: min(size.width * 0.42, 760), alignment: .leading)
        .padding(.horizontal, NuvioDesignTokens.Layout.safeHorizontal)
        .padding(.vertical, NuvioDesignTokens.Layout.safeVertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    @ViewBuilder
    private func title(_ item: HeroItem) -> some View {
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
            fallbackTitle(item.title)
        }
    }

    private func fallbackTitle(_ value: String) -> some View {
        Text(value)
            .nuvioTextStyle(.display)
            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            .lineLimit(2)
    }

    @ViewBuilder
    private func metadata(_ item: HeroItem) -> some View {
        let badges = item.canonicalBadges
        if !badges.isEmpty {
            HStack(spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    Text(badge)
                        .nuvioTextStyle(.metadata)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            NuvioDesignTokens.Colors.elevated.opacity(0.82),
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(.white.opacity(0.42), lineWidth: 1))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(badges.joined(separator: ", "))
        }
    }

    @ViewBuilder
    private func actionButtons(_ item: HeroItem) -> some View {
        if !actions.isEmpty {
            HStack(spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                ForEach(actions) { action in
                    Button { action.perform(item) } label: {
                        if let systemImage = action.systemImage {
                            Label(action.title, systemImage: systemImage)
                        } else {
                            Text(action.title)
                        }
                    }
                    .nuvioTextStyle(.button)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .frame(
                        minWidth: NuvioDesignTokens.Sizes.Buttons.minimumWidth,
                        minHeight: NuvioDesignTokens.Sizes.Buttons.defaultHeight
                    )
                    .buttonStyle(HeroCapsuleButtonStyle())
                    .focused($focusedActionID, equals: action.id)
                    .accessibilityHint("Activates \(action.title)")
                }
            }
            .focusSection()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<presentation.pageIndicator.count, id: \.self) { index in
                let active = presentation.pageIndicator.isActive(index)
                Capsule()
                    .fill(active ? Color.white : Color.white.opacity(0.30))
                    .frame(width: active ? 24 : 12, height: active ? 6 : 4)
            }
        }
        .animation(
            NuvioMotion.animation(for: .focus, reduceMotion: reduceMotion),
            value: presentation.currentIndex
        )
        .padding(.bottom, NuvioDesignTokens.Layout.safeVertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pageIndicatorLabel)
    }

    private var pageIndicatorLabel: String {
        let indicator = presentation.pageIndicator
        guard indicator.count > 0 else { return "No featured pages" }
        return "Page \(indicator.activeIndex + 1) of \(indicator.count)"
    }
}

private struct HeroCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .background(
                isFocused ? Color.white : NuvioDesignTokens.Colors.elevated.opacity(0.88),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    isFocused ? Color.white : NuvioDesignTokens.Colors.secondaryText,
                    lineWidth: isFocused ? NuvioDesignTokens.Focus.ringWidth : 1
                )
            )
            .scaleEffect(scale(configuration))
            .animation(
                NuvioMotion.animation(for: .focus, reduceMotion: reduceMotion),
                value: isFocused
            )
            .animation(
                NuvioMotion.animation(for: .focus, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }

    private func scale(_ configuration: Configuration) -> CGFloat {
        guard !reduceMotion else { return NuvioDesignTokens.Focus.reducedMotionScale }
        if configuration.isPressed { return NuvioDesignTokens.Focus.pressedScale }
        return isFocused ? NuvioDesignTokens.Focus.scale : 1
    }
}
