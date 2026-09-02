import Combine
import Foundation

/// Presentation-only post-play recommendation controller, mirroring
/// `PostPlayRecommendationController.kt`. The integrator supplies the addon
/// catalog query as an injected async closure; the controller owns the state
/// machine, the one-shot prefetch, the countdown, and cancellation.
@MainActor
public final class PostPlayController: ObservableObject {

    /// Integration-supplied recommendation fetch (addon catalog / more-like-this
    /// query). Thrown errors degrade to an empty result, mirroring the Android
    /// `catch (_: Exception) { emptyList() }` behavior.
    public typealias RecommendationFetch =
        @Sendable (_ identity: PostPlayPlaybackIdentity) async throws -> [PostPlayRecommendation]

    @Published public private(set) var state = PostPlayRecommendationState()

    /// Player interaction surfaces that gate the initial overlay appearance.
    public var blockers = PostPlayBlockerInputs()

    /// Whether the trailer may auto-play once the countdown finishes; paging
    /// recommendations disables it for the rest of the session, mirroring
    /// `autoPlayTrailerEnabled`.
    public var autoPlayTrailerEnabled: Bool

    private let fetchRecommendations: RecommendationFetch
    private let countdownTickInterval: TimeInterval
    private let transitionDuration: TimeInterval
    private let prefetchThreshold: Double
    private let initialAutoPlayTrailerEnabled: Bool

    private var identity: PostPlayPlaybackIdentity?
    private var recommendations: [PostPlayRecommendation] = []
    private var loadAttempted = false
    private var loadTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?

    public init(
        fetchRecommendations: @escaping RecommendationFetch,
        autoPlayTrailerEnabled: Bool = true,
        countdownTickInterval: TimeInterval = 1.0,
        transitionDuration: TimeInterval = PostPlayTiming.transitionDuration,
        prefetchThreshold: Double = PostPlayTiming.prefetchProgress
    ) {
        self.fetchRecommendations = fetchRecommendations
        self.initialAutoPlayTrailerEnabled = autoPlayTrailerEnabled
        self.autoPlayTrailerEnabled = autoPlayTrailerEnabled
        self.countdownTickInterval = countdownTickInterval
        self.transitionDuration = transitionDuration
        self.prefetchThreshold = prefetchThreshold
    }

    // MARK: - Lifecycle

    /// Starts a session with already-loaded recommendations (the integration
    /// resolved the candidates itself). A changed playback identity resets the
    /// previous session, mirroring the identity-change guard in `init`.
    public func begin(
        recommendations: [PostPlayRecommendation],
        identity newIdentity: PostPlayPlaybackIdentity
    ) {
        startSession(identity: newIdentity)
        let ordered = PostPlayRules.orderedCandidates(recommendations)
        // A non-empty preload completes loading; an empty one leaves the
        // prefetch path armed so progress can still trigger a fetch.
        loadAttempted = !ordered.isEmpty
        self.recommendations = ordered
        apply(.recommendationsLoaded(ordered))
    }

    /// Starts a session by fetching recommendations through the injected
    /// closure, publishing `isLoadingRecommendation` while in flight. Empty or
    /// failing fetches clear the loading flag without producing a
    /// recommendation.
    public func begin(identity newIdentity: PostPlayPlaybackIdentity) {
        startSession(identity: newIdentity)
        loadRecommendations()
    }

    /// One-shot prefetch trigger tied to playback progress
    /// (`handlePrefetch(progressFraction)`). Crosses at the configured
    /// threshold (`POST_PLAY_RECOMMENDATION_PREFETCH_PROGRESS` default 0.9;
    /// the parity settings store supplies the user's movie threshold).
    public func handlePrefetch(progressFraction: Double) {
        guard !loadAttempted,
              progressFraction >= prefetchThreshold
        else { return }
        loadRecommendations()
    }

    /// Playback reached its natural end: reveal the overlay using the stored
    /// blocker inputs, starting the post-end trailer countdown when the
    /// recommendation has a trailer and auto-play is still enabled.
    public func handleNaturalEnd() {
        guard let recommendation = state.recommendation else { return }
        let needsCountdown = recommendation.hasTrailer && autoPlayTrailerEnabled
        apply(
            .show(
                blockers: blockers,
                countdown: needsCountdown ? PostPlayTiming.trailerCountdownSeconds : nil
            )
        )
        if needsCountdown {
            startPostEndCountdown()
        }
    }

    /// Updates the position-derived trailer countdown while the overlay is
    /// visible and no trailer is playing (the live `evaluate` countdown path).
    public func handlePlaybackPosition(positionSeconds: Double, durationSeconds: Double) {
        guard state.isVisible, !state.isTrailerPlaying else { return }
        let countdown = PostPlayRules.countdownSeconds(
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds
        )
        apply(.countdownUpdated(countdown))
    }

    /// Mirrors `stop()`: clears the whole session.
    public func stop() {
        clearSession()
        identity = nil
    }

    // MARK: - Actions

    /// Mirrors `showPreviousRecommendation()`.
    public func showPreviousRecommendation() {
        selectRecommendation(offset: -1)
    }

    /// Mirrors `showNextRecommendation()`.
    public func showNextRecommendation() {
        selectRecommendation(offset: 1)
    }

    /// Mirrors `playTrailer()` / `startTrailer()`.
    public func playTrailer() {
        countdownTask?.cancel()
        countdownTask = nil
        apply(.trailerStarted)
    }

    /// Mirrors `onTrailerEnded()`.
    public func onTrailerEnded() {
        apply(.trailerStopped)
    }

    /// Mirrors `returnToPlayer()`: hides the overlay, cancels every in-flight
    /// job, then collapses to the locked-out state after the transition delay.
    public func returnToPlayer() {
        guard state.canReturnToPlayer else { return }
        loadTask?.cancel()
        loadTask = nil
        selectionTask?.cancel()
        selectionTask = nil
        countdownTask?.cancel()
        countdownTask = nil
        transitionTask?.cancel()
        transitionTask = nil
        recommendations = []
        apply(.returnToPlayer)
        transitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.transitionDuration ?? 0) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, self.state.hasReturnedToPlayer else { return }
                self.state = PostPlayRecommendationState(hasReturnedToPlayer: true)
            }
        }
    }

    /// Toggles the trailer enrichment indicator for the visible recommendation.
    public func setTrailerLoading(_ isLoading: Bool) {
        apply(.trailerLoadingChanged(isLoading))
    }

    // MARK: - Internals

    private func startSession(identity newIdentity: PostPlayPlaybackIdentity) {
        if let identity, identity != newIdentity {
            clearSession()
        } else {
            cancelTasks()
        }
        identity = newIdentity
    }

    private func clearSession() {
        cancelTasks()
        recommendations = []
        loadAttempted = false
        autoPlayTrailerEnabled = initialAutoPlayTrailerEnabled
        state = PostPlayRecommendationState()
    }

    private func cancelTasks() {
        loadTask?.cancel()
        loadTask = nil
        selectionTask?.cancel()
        selectionTask = nil
        countdownTask?.cancel()
        countdownTask = nil
        transitionTask?.cancel()
        transitionTask = nil
    }

    private func loadRecommendations() {
        guard !loadAttempted, let identity else { return }
        loadAttempted = true
        apply(.loadingRecommendationChanged(true))
        let fetch = fetchRecommendations
        let sessionIdentity = identity
        loadTask = Task { [weak self] in
            let loaded = (try? await fetch(sessionIdentity)) ?? []
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.recommendations = PostPlayRules.orderedCandidates(loaded)
                self.apply(.recommendationsLoaded(self.recommendations))
                self.loadTask = nil
            }
        }
    }

    private func selectRecommendation(offset: Int) {
        let before = state
        apply(offset < 0 ? .navigatePrevious : .navigateNext)
        guard state != before else { return }
        countdownTask?.cancel()
        countdownTask = nil
        autoPlayTrailerEnabled = false
        let target = state.recommendationIndex + offset
        selectionTask?.cancel()
        selectionTask = Task { [weak self] in
            // Async resolution boundary mirroring `awaitCandidateResolution`;
            // cancellation (rapid paging, return to player) drops the result.
            await Task.yield()
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard let resolved = self.recommendations[safe: target] else {
                    self.apply(.recommendationChangeFailed)
                    return
                }
                self.apply(.recommendationChanged(resolved, index: target))
                self.selectionTask = nil
            }
        }
    }

    private func startPostEndCountdown() {
        guard autoPlayTrailerEnabled,
              countdownTask == nil,
              !state.isTrailerPlaying,
              !state.hasAutoPlayedTrailer,
              state.recommendation?.hasTrailer == true
        else { return }
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.countdownTickInterval ?? 1) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                let finished = await MainActor.run { [weak self] () -> Bool in
                    guard let self else { return true }
                    if let seconds = self.state.countdownSeconds, seconds > 1 {
                        self.apply(.countdownTick)
                        return false
                    }
                    if self.autoPlayTrailerEnabled, self.state.recommendation?.hasTrailer == true {
                        self.playTrailer()
                    } else {
                        self.apply(.countdownUpdated(nil))
                    }
                    return true
                }
                if finished { return }
            }
        }
    }

    private func apply(_ action: PostPlayAction) {
        state = PostPlayReducer.reduce(state, action)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
