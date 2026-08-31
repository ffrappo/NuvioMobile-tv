import Combine
import Foundation

public struct HeroItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let titleLogoURL: String?
    public let backdropURL: String?
    public let overview: String?
    public let year: String?
    public let runtimeMinutes: Int?
    public let genres: [String]
    public let classification: String?
    public let badges: [String]

    public init(
        id: String,
        title: String,
        titleLogoURL: String? = nil,
        backdropURL: String? = nil,
        overview: String? = nil,
        year: String? = nil,
        runtimeMinutes: Int? = nil,
        genres: [String] = [],
        classification: String? = nil,
        badges: [String] = []
    ) {
        self.id = id
        self.title = title
        self.titleLogoURL = titleLogoURL
        self.backdropURL = backdropURL
        self.overview = overview
        self.year = year
        self.runtimeMinutes = runtimeMinutes
        self.genres = genres
        self.classification = classification
        self.badges = badges
    }

    public var formattedRuntime: String? {
        HeroFormatting.runtime(minutes: runtimeMinutes)
    }

    /// Brief-defined order used by integration callers: year, runtime,
    /// classification, then provider badges such as quality.
    public var canonicalBadges: [String] {
        HeroFormatting.canonicalBadges(
            year: year,
            runtimeMinutes: runtimeMinutes,
            classification: classification,
            badges: badges
        )
    }
}

public enum HeroFormatting {
    public static func runtime(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let minutes):
            return "\(minutes)m"
        case (let hours, 0):
            return "\(hours)h"
        case (let hours, let minutes):
            return "\(hours)h \(minutes)m"
        }
    }

    public static func canonicalBadges(
        year: String?,
        runtimeMinutes: Int?,
        classification: String?,
        badges: [String]
    ) -> [String] {
        let ordered = [
            normalized(year),
            runtime(minutes: runtimeMinutes),
            normalized(classification),
        ] + badges.map(normalized)

        var seen = Set<String>()
        return ordered.compactMap { value in
            guard let value else { return nil }
            let key = value.lowercased()
            return seen.insert(key).inserted ? value : nil
        }
    }

    private static func normalized(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }
}

public struct HeroPageIndicatorState: Equatable, Sendable {
    public let count: Int
    public let activeIndex: Int

    public init(pageCount: Int, currentIndex: Int) {
        count = max(0, pageCount)
        activeIndex = Self.normalizedIndex(currentIndex, pageCount: count)
    }

    public static func normalizedIndex(_ index: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        let remainder = index % pageCount
        return remainder >= 0 ? remainder : remainder + pageCount
    }

    public func isActive(_ index: Int) -> Bool {
        count > 0 && index == activeIndex
    }
}

public struct HeroRotationScheduler {
    public typealias Sleep = (Duration) async throws -> Void

    private let sleepOperation: Sleep

    public init(sleep: @escaping Sleep) {
        sleepOperation = sleep
    }

    public func sleep(for duration: Duration) async throws {
        try await sleepOperation(duration)
    }

    public static let continuous = HeroRotationScheduler { duration in
        try await ContinuousClock().sleep(for: duration)
    }
}

@MainActor
public final class HeroPresentation: ObservableObject {
    @Published public private(set) var pages: [HeroItem]
    @Published public private(set) var currentIndex: Int
    @Published public private(set) var overridePage: HeroItem?
    @Published public private(set) var isActionFocused = false
    @Published public private(set) var reduceMotionEnabled = false

    public let autoAdvanceInterval: Duration
    public let transitionDuration: TimeInterval

    private let scheduler: HeroRotationScheduler
    private var rotationTask: Task<Void, Never>?

    public init(
        pages: [HeroItem],
        currentIndex: Int = 0,
        autoAdvanceInterval: Duration = .seconds(10),
        transitionDuration: TimeInterval = 0.45,
        scheduler: HeroRotationScheduler = .continuous
    ) {
        self.pages = pages
        self.currentIndex = HeroPageIndicatorState.normalizedIndex(
            currentIndex,
            pageCount: pages.count
        )
        self.autoAdvanceInterval = autoAdvanceInterval
        self.transitionDuration = transitionDuration
        self.scheduler = scheduler
    }

    deinit {
        rotationTask?.cancel()
    }

    public var currentPage: HeroItem? {
        if let overridePage { return overridePage }
        return pages.indices.contains(currentIndex) ? pages[currentIndex] : nil
    }

    /// True while a focused rail item previews on the hero instead of the
    /// rotating pages. Android's Modern home drives the hero the same way,
    /// so the page indicator is hidden while an override is displayed.
    public var isDisplayingOverride: Bool {
        overridePage != nil
    }

    public var pageIndicator: HeroPageIndicatorState {
        HeroPageIndicatorState(pageCount: pages.count, currentIndex: currentIndex)
    }

    public var isAutoAdvancePaused: Bool {
        pages.count < 2 || overridePage != nil || isActionFocused || reduceMotionEnabled
    }

    public func startAutoAdvance() {
        guard rotationTask == nil else { return }
        rotationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await scheduler.sleep(for: autoAdvanceInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                handleAutoAdvanceTick()
            }
        }
    }

    public func stopAutoAdvance() {
        rotationTask?.cancel()
        rotationTask = nil
    }

    public func handleAutoAdvanceTick() {
        guard !isAutoAdvancePaused else { return }
        advance()
    }

    public func advance() {
        selectPage(at: currentIndex + 1)
    }

    public func retreat() {
        selectPage(at: currentIndex - 1)
    }

    public func selectPage(at index: Int) {
        currentIndex = HeroPageIndicatorState.normalizedIndex(
            index,
            pageCount: pages.count
        )
    }

    public func setActionFocused(_ focused: Bool) {
        isActionFocused = focused
    }

    /// Displays a focused rail item on the hero without adding it to the
    /// rotating page set. Pass nil to return to the rotating selection.
    public func displayOverride(_ item: HeroItem?) {
        overridePage = item
    }

    public func setReduceMotion(_ enabled: Bool) {
        reduceMotionEnabled = enabled
    }

    public func replacePages(_ newPages: [HeroItem]) {
        let selectedID = currentPage?.id
        pages = newPages
        if let selectedID,
           let retainedIndex = newPages.firstIndex(where: { $0.id == selectedID }) {
            currentIndex = retainedIndex
        } else {
            selectPage(at: currentIndex)
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
