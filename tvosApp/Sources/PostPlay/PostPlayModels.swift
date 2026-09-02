import Foundation

/// Timing and sizing constants ported from `PostPlayRecommendationState.kt`
/// and `PostPlayRecommendationController.kt`.
public enum PostPlayTiming {
    /// `POST_PLAY_RECOMMENDATION_PREFETCH_PROGRESS = 0.9f`
    public static let prefetchProgress: Double = 0.9

    /// The user's post-play movie threshold from the parity settings store
    /// (`postPlayMovieThresholdPercent`, Android default 90), read at
    /// playback start; falls back to the Android default when unset.
    public static func userMovieThreshold(
        defaults: UserDefaults = .standard,
        key: String = "nuvio.tv.settings.v2.playback.postPlayMovieThreshold"
    ) -> Double {
        // NuvioSettingsStore persists numbers as "n:<value>" strings.
        let raw = defaults.string(forKey: key) ?? ""
        let percent = raw.hasPrefix("n:") ? Int(raw.dropFirst(2)) ?? 90 : 90
        return min(max(Double(percent), 0), 100) / 100
    }
    /// `POST_PLAY_RECOMMENDATION_PREFETCH_REMAINING_MS = 10 * 60_000L`
    public static let prefetchRemainingSeconds: Double = 10 * 60
    /// `POST_PLAY_RECOMMENDATION_TRAILER_COUNTDOWN_SECONDS = 5`
    public static let trailerCountdownSeconds = 5
    /// `POST_PLAY_RECOMMENDATION_TRANSITION_MS = 420`
    public static let transitionDuration: Double = 0.42
    /// `MAX_POST_PLAY_RECOMMENDATIONS = 4`
    public static let maximumRecommendations = 4
    /// Overlay fade-in duration used by the Android `AnimatedVisibility` (360ms tween).
    public static let overlayFadeInDuration: Double = 0.36
    /// Overlay fade-out duration used by the Android `AnimatedVisibility` (220ms tween).
    public static let overlayFadeOutDuration: Double = 0.22
}

/// Content kind resolved from addon API types, mirroring `ContentType` usage in
/// `PostPlayRecommendationState.kt`.
public enum PostPlayContentKind: String, Equatable, Sendable {
    case movie
    case series
}

/// Mirrors the Android `PostPlayRecommendation` immutable model.
public struct PostPlayRecommendation: Equatable, Identifiable, Sendable {
    public let id: String
    public let contentType: String
    public let title: String
    public let poster: String?
    public let backdrop: String?
    public let logo: String?
    public let description: String?
    public let releaseInfo: String?
    public let rating: Double?
    public let genres: [String]
    public let runtime: String?
    public let sourceAddonBaseURL: String?
    public let tmdbID: String?
    public let tmdbRating: Double?
    public let ageRating: String?
    public let status: String?
    public let country: String?
    public let language: String?
    public let contentLanguage: String?
    public let externalRatings: PostPlayExternalRatings?
    public let showsStandardRatings: Bool
    public let trailerVideoURL: String?
    public let trailerAudioURL: String?

    public init(
        id: String,
        contentType: String,
        title: String,
        poster: String? = nil,
        backdrop: String? = nil,
        logo: String? = nil,
        description: String? = nil,
        releaseInfo: String? = nil,
        rating: Double? = nil,
        genres: [String] = [],
        runtime: String? = nil,
        sourceAddonBaseURL: String? = nil,
        tmdbID: String? = nil,
        tmdbRating: Double? = nil,
        ageRating: String? = nil,
        status: String? = nil,
        country: String? = nil,
        language: String? = nil,
        contentLanguage: String? = nil,
        externalRatings: PostPlayExternalRatings? = nil,
        showsStandardRatings: Bool = true,
        trailerVideoURL: String? = nil,
        trailerAudioURL: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.title = title
        self.poster = poster
        self.backdrop = backdrop
        self.logo = logo
        self.description = description
        self.releaseInfo = releaseInfo
        self.rating = rating
        self.genres = genres
        self.runtime = runtime
        self.sourceAddonBaseURL = sourceAddonBaseURL
        self.tmdbID = tmdbID
        self.tmdbRating = tmdbRating
        self.ageRating = ageRating
        self.status = status
        self.country = country
        self.language = language
        self.contentLanguage = contentLanguage
        self.externalRatings = externalRatings
        self.showsStandardRatings = showsStandardRatings
        self.trailerVideoURL = trailerVideoURL
        self.trailerAudioURL = trailerAudioURL
    }

    /// `val hasTrailer: Boolean get() = !trailerVideoUrl.isNullOrBlank()`
    public var hasTrailer: Bool {
        !(trailerVideoURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Mirrors `MDBListRatings` as consumed by the Android post-play ratings row.
public struct PostPlayExternalRatings: Equatable, Sendable {
    public let trakt: Double?
    public let imdb: Double?
    public let tmdb: Double?
    public let letterboxd: Double?
    public let myAnimeList: Double?
    public let rottenTomatoes: Double?

    public init(
        trakt: Double? = nil,
        imdb: Double? = nil,
        tmdb: Double? = nil,
        letterboxd: Double? = nil,
        myAnimeList: Double? = nil,
        rottenTomatoes: Double? = nil
    ) {
        self.trakt = trakt
        self.imdb = imdb
        self.tmdb = tmdb
        self.letterboxd = letterboxd
        self.myAnimeList = myAnimeList
        self.rottenTomatoes = rottenTomatoes
    }

    public var isEmpty: Bool {
        trakt == nil && imdb == nil && tmdb == nil &&
            letterboxd == nil && myAnimeList == nil && rottenTomatoes == nil
    }
}

/// Identifies the currently playing item so a change (next episode, new stream)
/// resets the recommendation session, mirroring the controller's
/// `PlaybackIdentity`.
public struct PostPlayPlaybackIdentity: Equatable, Sendable {
    public let contentType: String?
    public let contentID: String?
    public let videoID: String?
    public let season: Int?
    public let episode: Int?

    public init(
        contentType: String?,
        contentID: String?,
        videoID: String? = nil,
        season: Int? = nil,
        episode: Int? = nil
    ) {
        self.contentType = contentType
        self.contentID = contentID
        self.videoID = videoID
        self.season = season
        self.episode = episode
    }
}

/// The player interaction surfaces that postpone the post-play overlay,
/// mirroring `PlayerUiState.blocksPostPlayRecommendation()`.
public struct PostPlayBlockerInputs: Equatable, Sendable {
    public var pendingPreviewSeek: Bool
    public var showsPauseOverlay: Bool
    public var showsStreamInfoOverlay: Bool
    public var showsEpisodesPanel: Bool
    public var showsSourcesPanel: Bool
    public var showsAudioOverlay: Bool
    public var showsSubtitleOverlay: Bool
    public var showsSubtitleStylePanel: Bool
    public var showsSubtitleDelayOverlay: Bool
    public var showsSubtitleTimingDialog: Bool
    public var showsSpeedDialog: Bool
    public var showsMoreDialog: Bool

    public init(
        pendingPreviewSeek: Bool = false,
        showsPauseOverlay: Bool = false,
        showsStreamInfoOverlay: Bool = false,
        showsEpisodesPanel: Bool = false,
        showsSourcesPanel: Bool = false,
        showsAudioOverlay: Bool = false,
        showsSubtitleOverlay: Bool = false,
        showsSubtitleStylePanel: Bool = false,
        showsSubtitleDelayOverlay: Bool = false,
        showsSubtitleTimingDialog: Bool = false,
        showsSpeedDialog: Bool = false,
        showsMoreDialog: Bool = false
    ) {
        self.pendingPreviewSeek = pendingPreviewSeek
        self.showsPauseOverlay = showsPauseOverlay
        self.showsStreamInfoOverlay = showsStreamInfoOverlay
        self.showsEpisodesPanel = showsEpisodesPanel
        self.showsSourcesPanel = showsSourcesPanel
        self.showsAudioOverlay = showsAudioOverlay
        self.showsSubtitleOverlay = showsSubtitleOverlay
        self.showsSubtitleStylePanel = showsSubtitleStylePanel
        self.showsSubtitleDelayOverlay = showsSubtitleDelayOverlay
        self.showsSubtitleTimingDialog = showsSubtitleTimingDialog
        self.showsSpeedDialog = showsSpeedDialog
        self.showsMoreDialog = showsMoreDialog
    }

    /// `blocksPostPlayRecommendation()`: any active player interaction surface
    /// blocks the overlay's initial appearance.
    public var isBlocked: Bool {
        pendingPreviewSeek ||
            showsPauseOverlay ||
            showsStreamInfoOverlay ||
            showsEpisodesPanel ||
            showsSourcesPanel ||
            showsAudioOverlay ||
            showsSubtitleOverlay ||
            showsSubtitleStylePanel ||
            showsSubtitleDelayOverlay ||
            showsSubtitleTimingDialog ||
            showsSpeedDialog ||
            showsMoreDialog
    }
}

/// Pure presentation state mirroring `PostPlayRecommendationUiState`.
public struct PostPlayRecommendationState: Equatable, Sendable {
    public var recommendation: PostPlayRecommendation?
    public var recommendationIndex: Int
    public var recommendationCount: Int
    public var isLoadingRecommendation: Bool
    public var isChangingRecommendation: Bool
    public var isLoadingTrailer: Bool
    public var isVisible: Bool
    public var hasReturnedToPlayer: Bool
    public var countdownSeconds: Int?
    public var isTrailerPlaying: Bool
    public var hasAutoPlayedTrailer: Bool

    public init(
        recommendation: PostPlayRecommendation? = nil,
        recommendationIndex: Int = 0,
        recommendationCount: Int = 0,
        isLoadingRecommendation: Bool = false,
        isChangingRecommendation: Bool = false,
        isLoadingTrailer: Bool = false,
        isVisible: Bool = false,
        hasReturnedToPlayer: Bool = false,
        countdownSeconds: Int? = nil,
        isTrailerPlaying: Bool = false,
        hasAutoPlayedTrailer: Bool = false
    ) {
        self.recommendation = recommendation
        self.recommendationIndex = recommendationIndex
        self.recommendationCount = recommendationCount
        self.isLoadingRecommendation = isLoadingRecommendation
        self.isChangingRecommendation = isChangingRecommendation
        self.isLoadingTrailer = isLoadingTrailer
        self.isVisible = isVisible
        self.hasReturnedToPlayer = hasReturnedToPlayer
        self.countdownSeconds = countdownSeconds
        self.isTrailerPlaying = isTrailerPlaying
        self.hasAutoPlayedTrailer = hasAutoPlayedTrailer
    }

    /// `canNavigatePrevious = !isChangingRecommendation && recommendationIndex > 0`
    public var canNavigatePrevious: Bool {
        !isChangingRecommendation && recommendationIndex > 0
    }

    /// `canNavigateNext = !isChangingRecommendation && recommendationIndex < recommendationCount - 1`
    public var canNavigateNext: Bool {
        !isChangingRecommendation && recommendationIndex < recommendationCount - 1
    }

    /// `canReturnToPlayer = isVisible && !isTrailerPlaying && !hasAutoPlayedTrailer`
    public var canReturnToPlayer: Bool {
        isVisible && !isTrailerPlaying && !hasAutoPlayedTrailer
    }

    /// `blocksNaturalCompletion = isVisible || (isLoadingRecommendation && !hasReturnedToPlayer)`
    public var blocksNaturalCompletion: Bool {
        isVisible || (isLoadingRecommendation && !hasReturnedToPlayer)
    }
}
