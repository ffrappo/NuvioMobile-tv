import SwiftUI

/// All overlay interactions as callbacks, mirroring the Android overlay's
/// `onPlay`/`onOpenDetails`/`onPlayTrailer`/`onTrailerEnded`/
/// `onPreviousRecommendation`/`onNextRecommendation` plus the replay and
/// return-to-player entries from the integration brief.
public struct PostPlayOverlayActions {
    public var onPlay: (PostPlayRecommendation) -> Void
    public var onOpenDetails: (PostPlayRecommendation) -> Void
    public var onPlayTrailer: () -> Void
    public var onReplay: () -> Void
    public var onReturnToPlayer: () -> Void
    public var onPreviousRecommendation: () -> Void
    public var onNextRecommendation: () -> Void

    public init(
        onPlay: @escaping (PostPlayRecommendation) -> Void,
        onOpenDetails: @escaping (PostPlayRecommendation) -> Void,
        onPlayTrailer: @escaping () -> Void,
        onReplay: @escaping () -> Void,
        onReturnToPlayer: @escaping () -> Void,
        onPreviousRecommendation: @escaping () -> Void,
        onNextRecommendation: @escaping () -> Void
    ) {
        self.onPlay = onPlay
        self.onOpenDetails = onOpenDetails
        self.onPlayTrailer = onPlayTrailer
        self.onReplay = onReplay
        self.onReturnToPlayer = onReturnToPlayer
        self.onPreviousRecommendation = onPreviousRecommendation
        self.onNextRecommendation = onNextRecommendation
    }
}

/// Post-play recommendation overlay matching the Android
/// `PostPlayRecommendationOverlay` composition: full-bleed backdrop with
/// scrims, bottom-leading summary card, countdown indicator, action row with
/// previous/next paging, and trailer entry. Presentation only: trailer
/// playback itself stays with the integrator.
public struct PostPlayOverlayView: View {
    let state: PostPlayRecommendationState
    let currentTitle: String
    let actions: PostPlayOverlayActions
    /// Whether the trailer entry point renders at all (integration feature
    /// gate, mirroring `AppFeaturePolicy.inAppTrailerPlaybackEnabled`).
    var trailerPlaybackEnabled: Bool = true

    private enum FocusID {
        case primary
        case previous
        case next
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedID: FocusID?

    public init(
        state: PostPlayRecommendationState,
        currentTitle: String,
        actions: PostPlayOverlayActions,
        trailerPlaybackEnabled: Bool = true
    ) {
        self.state = state
        self.currentTitle = currentTitle
        self.actions = actions
        self.trailerPlaybackEnabled = trailerPlaybackEnabled
    }

    public var body: some View {
        if let recommendation = state.recommendation {
            ZStack {
                backdrop(recommendation)
                scrims
                content(recommendation)
            }
            .opacity(state.isVisible ? 1 : 0)
            .animation(visibilityAnimation, value: state.isVisible)
            .task(id: state.isVisible) {
                guard state.isVisible else {
                    focusedID = nil
                    return
                }
                await requestPrimaryFocus()
            }
            .accessibilityHidden(!state.isVisible)
        }
    }

    // MARK: - Layers

    /// Full-bleed backdrop (poster fallback) with a crossfade when the
    /// recommendation pages, mirroring the backdrop `AnimatedContent`.
    private func backdrop(_ recommendation: PostPlayRecommendation) -> some View {
        GeometryReader { proxy in
            NuvioArtworkView(
                urlString: recommendation.backdrop ?? recommendation.poster,
                mode: .backdrop,
                pixelSize: proxy.size,
                cornerRadius: 0
            )
            .id(recommendation.id)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.02)))
        }
        .ignoresSafeArea()
        .animation(
            reduceMotion ? nil : NuvioMotion.animation(for: .content, reduceMotion: false),
            value: state.recommendation?.id
        )
    }

    /// Horizontal and vertical gradient scrims matching the Android brushes.
    private var scrims: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.88), location: 0),
                    .init(color: .black.opacity(0.16), location: 0.54),
                    .init(color: .black.opacity(0.22), location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.08), location: 0),
                    .init(color: .clear, location: 0.58),
                    .init(color: .black.opacity(0.82), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func content(_ recommendation: PostPlayRecommendation) -> some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xl) {
            PostPlayRecommendationCard(
                recommendation: recommendation,
                currentTitle: currentTitle,
                isTrailerPlaying: state.isTrailerPlaying
            )
            .frame(maxWidth: 900, alignment: .leading)
            actionRow(recommendation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(
            .leading,
            NuvioDesignTokens.Spacing.Screen.overscanHorizontal
                + NuvioDesignTokens.Components.playerOverlayHorizontalPadding
        )
        .padding(
            .bottom,
            NuvioDesignTokens.Spacing.Screen.overscanVertical
                + NuvioDesignTokens.Components.playerOverlayVerticalPadding
        )
        .padding(.trailing, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
    }

    // MARK: - Actions

    private func actionRow(_ recommendation: PostPlayRecommendation) -> some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            primaryButton(recommendation)
            trailerButton(recommendation)
            replayButton
            returnToPlayerButton
            if state.recommendationCount > 1 {
                navigationButtons
            }
        }
    }

    private func primaryButton(_ recommendation: PostPlayRecommendation) -> some View {
        let opensDetails = PostPlayRules.resolveContentKind(apiType: recommendation.contentType) == .series
        return PostPlayActionButton(
            title: opensDetails ? "Details" : "Play",
            systemImage: opensDetails ? "info.circle" : "play.fill",
            prominent: true
        ) {
            if opensDetails {
                actions.onOpenDetails(recommendation)
            } else {
                actions.onPlay(recommendation)
            }
        }
        .focused($focusedID, equals: .primary)
    }

    @ViewBuilder
    private func trailerButton(_ recommendation: PostPlayRecommendation) -> some View {
        if PostPlayRules.shouldShowTrailerAction(
            recommendation: recommendation,
            isTrailerPlaying: state.isTrailerPlaying,
            trailerPlaybackEnabled: trailerPlaybackEnabled
        ) {
            PostPlayActionButton(
                title: trailerButtonTitle,
                systemImage: "film.fill",
                prominent: false,
                trailing: {
                    if state.countdownSeconds != nil {
                        PostPlayCountdownIndicator(
                            seconds: state.countdownSeconds,
                            total: PostPlayTiming.trailerCountdownSeconds
                        )
                    } else if state.isLoadingTrailer {
                        ProgressView()
                    }
                }
            ) {
                actions.onPlayTrailer()
            }
        }
    }

    private var trailerButtonTitle: String {
        if let seconds = state.countdownSeconds {
            return "Trailer (\(seconds))"
        }
        return "Trailer"
    }

    private var replayButton: some View {
        PostPlayActionButton(
            title: "Replay",
            systemImage: "arrow.counterclockwise",
            prominent: false
        ) {
            actions.onReplay()
        }
    }

    @ViewBuilder
    private var returnToPlayerButton: some View {
        if state.canReturnToPlayer {
            PostPlayActionButton(
                title: "Back to player",
                systemImage: "rectangle.on.rectangle",
                prominent: false
            ) {
                actions.onReturnToPlayer()
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            PostPlayNavigationButton(
                systemImage: "chevron.left",
                accessibilityLabel: "Previous recommendation",
                enabled: state.canNavigatePrevious,
                focused: $focusedID,
                focusID: .previous
            ) {
                actions.onPreviousRecommendation()
            }
            PostPlayNavigationButton(
                systemImage: "chevron.right",
                accessibilityLabel: "Next recommendation",
                enabled: state.canNavigateNext,
                focused: $focusedID,
                focusID: .next
            ) {
                actions.onNextRecommendation()
            }
        }
    }

    /// Mirrors the Android focus hand-off: the primary action receives focus
    /// once the entrance transition completes.
    private func requestPrimaryFocus() async {
        if !reduceMotion {
            try? await Task.sleep(
                nanoseconds: UInt64(PostPlayTiming.transitionDuration * 1_000_000_000)
            )
        }
        guard !Task.isCancelled else { return }
        focusedID = .primary
    }

    private var visibilityAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(
            duration: state.isVisible
                ? PostPlayTiming.overlayFadeInDuration
                : PostPlayTiming.overlayFadeOutDuration
        )
    }
}

/// Pill action button mirroring `PostPlayRecommendationButton`.
struct PostPlayActionButton<Trailing: View>: View {
    let title: String
    let systemImage: String
    let prominent: Bool
    let trailing: Trailing
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) where Trailing == EmptyView {
        self.init(title: title, systemImage: systemImage, prominent: prominent, trailing: { EmptyView() }, action: action)
    }

    init(
        title: String,
        systemImage: String,
        prominent: Bool,
        @ViewBuilder trailing: () -> Trailing,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prominent = prominent
        self.trailing = trailing()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: NuvioDesignTokens.Sizes.Icons.sm))
                Text(title)
                    .font(NuvioTypography.button)
                    .lineLimit(1)
                trailing
            }
            .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
            .frame(minHeight: NuvioDesignTokens.Sizes.Buttons.defaultHeight)
            .foregroundStyle(
                prominent ? NuvioDesignTokens.Colors.canvasBlack : NuvioDesignTokens.Colors.primaryText
            )
            .background(
                prominent
                    ? AnyShapeStyle(NuvioDesignTokens.Colors.primaryText)
                    : AnyShapeStyle(NuvioDesignTokens.Colors.elevated)
            )
        }
        .buttonStyle(
            NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.full)
        )
        .accessibilityLabel(title)
    }
}

/// Circular previous/next paging control mirroring
/// `PostPlayRecommendationNavigationButton`.
struct PostPlayNavigationButton<FocusID: Hashable>: View {
    let systemImage: String
    let accessibilityLabel: String
    let enabled: Bool
    let focused: FocusState<FocusID?>.Binding
    let focusID: FocusID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: NuvioDesignTokens.Sizes.Icons.lg))
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                .frame(
                    width: NuvioDesignTokens.Sizes.Buttons.defaultHeight,
                    height: NuvioDesignTokens.Sizes.Buttons.defaultHeight
                )
                .background(Circle().fill(NuvioDesignTokens.Colors.elevated))
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : NuvioDesignTokens.Effects.disabledOpacity)
        .focused(focused, equals: focusID)
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.full))
        .accessibilityLabel(accessibilityLabel)
    }
}
