import Foundation
import SwiftUI

/// Classic layout geometry ported from ClassicHomeContent.kt.
enum ClassicHomeScale {
    /// CLASSIC_CATALOG_POSTER_SCALE in ClassicHomeContent.kt.
    static let catalogPosterScale: CGFloat = 1.35
    /// CLASSIC_SECONDARY_ROW_POSTER_SCALE in ClassicHomeContent.kt.
    static let secondaryRowPosterScale: CGFloat = 1.2

    static let catalogPosterSize = CGSize(
        width: NuvioDesignTokens.Sizes.Cards.poster.width * catalogPosterScale,
        height: NuvioDesignTokens.Sizes.Cards.poster.height * catalogPosterScale
    )
    static let secondaryPosterSize = CGSize(
        width: NuvioDesignTokens.Sizes.Cards.poster.width * secondaryRowPosterScale,
        height: NuvioDesignTokens.Sizes.Cards.poster.height * secondaryRowPosterScale
    )

    /// HeroCarousel.kt renders the classic hero band at 400dp (not full page).
    static let heroBandHeight: CGFloat = 400
    /// CLASSIC_IMMERSIVE_FADE_DISTANCE in ClassicHomeContent.kt.
    static let immersiveFadeDistance: CGFloat = 180
    /// LazyColumn verticalArrangement spacing (NuvioTheme.spacing.xxl).
    static let rowSpacing: CGFloat = 32
}

/// The artwork the focused-item gradient backdrop derives its color from.
/// Mirrors the internal ClassicFocusArtwork of ClassicHomeContent.kt.
struct ClassicFocusArtwork: Hashable, Sendable {
    let imageURL: String?
    let seed: String

    init(imageURL: String?, seed: String) {
        self.imageURL = imageURL
        self.seed = seed
    }

    /// MetaPreview.toClassicFocusArtwork: backdrop chain when expand is on,
    /// poster chain otherwise.
    init(summary: MetaSummary, prefersBackdrop: Bool) {
        let url = prefersBackdrop
            ? (summary.background ?? summary.poster)
            : (summary.poster ?? summary.background)
        self.init(
            imageURL: url,
            seed: "\(summary.id)|\(summary.name)|\(summary.type)"
        )
    }

    /// ContinueWatchingItem.toClassicFocusArtwork for an in-progress entry.
    init(card: ContinueWatchingCard, prefersBackdrop: Bool) {
        let summary = card.summary
        let url = prefersBackdrop
            ? (card.episodeThumbnail ?? summary.background ?? summary.poster)
            : (summary.poster ?? card.episodeThumbnail ?? summary.background)
        self.init(
            imageURL: url,
            seed: "\(summary.id)|\(summary.name)|\(summary.type)"
        )
    }

    /// CollectionFolder.toClassicFocusArtwork. The tvos TVCollectionFolder
    /// model has no heroBackdropUrl field, so both chains use the cover image.
    init(folder: TVCollectionFolder, prefersBackdrop: Bool) {
        self.init(imageURL: folder.coverImageUrl, seed: "\(folder.id)|\(folder.title)")
    }
}

/// Pure sRGB color math ported from ClassicFocusGradientBackdrop.kt so the
/// seed-derived fallback color is deterministic and testable.
struct ClassicRGB: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// androidx compose Color.lerp interpolates channels in sRGB space.
    func blended(with other: ClassicRGB, fraction: Double) -> ClassicRGB {
        let t = min(max(fraction, 0), 1)
        return ClassicRGB(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }

    /// Rec. 709 relative luminance over linearized sRGB components,
    /// matching androidx Color.luminance().
    var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// stabilizeBackdropColor: keep the backdrop readable against the canvas.
    var stabilized: ClassicRGB {
        let opaque = ClassicRGB(red: red, green: green, blue: blue)
        if opaque.luminance < 0.16 {
            return opaque.blended(with: ClassicRGB(red: 1, green: 1, blue: 1), fraction: 0.34)
        }
        if opaque.luminance > 0.72 {
            return opaque.blended(with: ClassicRGB(red: 0, green: 0, blue: 0), fraction: 0.32)
        }
        return opaque
    }

    var color: Color {
        Color(
            .sRGB,
            red: red,
            green: green,
            blue: blue,
            opacity: 1
        )
    }
}

enum ClassicRGBMath {
    /// Java String.hashCode over UTF-16 code units with Int32 wrap-around.
    static func javaHashCode(_ string: String) -> Int32 {
        var hash: Int32 = 0
        for unit in string.utf16 {
            hash = hash &* 31 &+ Int32(bitPattern: UInt32(unit))
        }
        return hash
    }

    /// `((seed.hashCode().toLong() and 0xffffffffL) % 360L)` hue picker.
    static func hueDegrees(fromSeed seed: String) -> Double {
        let unsigned = UInt32(bitPattern: javaHashCode(seed))
        return Double(unsigned % 360)
    }

    /// Color.hsv(hue, saturation = 0.58, value = 0.82).
    static func rgb(hueDegrees hue: Double, saturation: Double, value: Double) -> ClassicRGB {
        let chroma = value * saturation
        let sector = (hue.truncatingRemainder(dividingBy: 360)) / 60
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double)
        switch sector {
        case ..<1: (r1, g1, b1) = (chroma, x, 0)
        case ..<2: (r1, g1, b1) = (x, chroma, 0)
        case ..<3: (r1, g1, b1) = (0, chroma, x)
        case ..<4: (r1, g1, b1) = (0, x, chroma)
        case ..<5: (r1, g1, b1) = (x, 0, chroma)
        default: (r1, g1, b1) = (chroma, 0, x)
        }
        let m = value - chroma
        return ClassicRGB(red: r1 + m, green: g1 + m, blue: b1 + m)
    }

    /// HSV components in 0...1 ranges for the sampling weights.
    static func hsv(_ rgb: ClassicRGB) -> (hue: Double, saturation: Double, value: Double) {
        let maximum = max(rgb.red, max(rgb.green, rgb.blue))
        let minimum = min(rgb.red, min(rgb.green, rgb.blue))
        let delta = maximum - minimum
        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maximum == rgb.red {
            hue = 60 * ((rgb.green - rgb.blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maximum == rgb.green {
            hue = 60 * ((rgb.blue - rgb.red) / delta + 2)
        } else {
            hue = 60 * ((rgb.red - rgb.green) / delta + 4)
        }
        let normalizedHue = hue < 0 ? hue + 360 : hue
        return (normalizedHue, maximum == 0 ? 0 : delta / maximum, maximum)
    }
}

/// Geometry and timing rules of ClassicFocusGradientBackdrop.kt.
enum ClassicFocusGradient {
    static let debounceMilliseconds: UInt64 = 140
    static let cacheRetryMilliseconds: UInt64 = 360
    static let colorCacheLimit = 256

    /// The gradient is painted only right of 29% of the width.
    static let firstVisibleXFraction: CGFloat = 0.29
    /// Brush start/end as fractions of the backdrop size.
    static let startUnit = (x: 0.12, y: 0.0)
    static let endUnit = (x: 1.0, y: 0.82)

    /// (location, alpha) color stops of the linear gradient.
    static let stops: [ClassicFocusGradientStop] = [
        ClassicFocusGradientStop(location: 0, alpha: 0),
        ClassicFocusGradientStop(location: 0.42, alpha: 0),
        ClassicFocusGradientStop(location: 0.66, alpha: 0.16),
        ClassicFocusGradientStop(location: 0.84, alpha: 0.30),
        ClassicFocusGradientStop(location: 1, alpha: 0.44),
    ]

    /// NuvioTheme FocusBackground of the default Crimson palette.
    static let defaultFallback = ClassicRGB(hex: 0x3D1A1A)

    /// catalogFocusBackdropVisible: the gradient only shows once the immersive
    /// hero backdrop has fully faded (firstVisibleItemIndex > 0 on Android).
    static func isBackdropVisible(immersiveAlpha: Double) -> Bool {
        immersiveAlpha <= 0
    }

    /// deriveSeedColor: hue from the seed hash, blended toward the fallback.
    static func seedColor(seed: String, fallback: ClassicRGB = defaultFallback) -> ClassicRGB {
        guard !seed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback.stabilized
        }
        let hue = ClassicRGBMath.hueDegrees(fromSeed: seed)
        let seeded = ClassicRGBMath.rgb(hueDegrees: hue, saturation: 0.58, value: 0.82)
        return fallback.blended(with: seeded, fraction: 0.58).stabilized
    }
}

struct ClassicFocusGradientStop: Equatable, Sendable {
    let location: CGFloat
    let alpha: Double

    init(location: CGFloat, alpha: Double) {
        self.location = location
        self.alpha = alpha
    }
}

/// Shared presentation-only mapping from HomeSnapshot to rail items, used by
/// both the Classic and Grid layouts so card content stays identical to the
/// Modern layout for the same snapshot.
enum HomeModeRailMapping {
    static func heroItemID(_ summary: MetaSummary) -> String {
        "\(summary.type):\(summary.id)"
    }

    static func railItemID(sectionID: String, summary: MetaSummary) -> String {
        "\(sectionID)|\(summary.type)|\(summary.id)"
    }

    static func heroItem(_ summary: MetaSummary) -> HeroItem {
        HeroItem(
            id: heroItemID(summary),
            title: summary.name,
            backdropURL: summary.background ?? summary.poster,
            overview: summary.description,
            year: summary.releaseInfo?.trimmedNonEmpty,
            genres: summary.genres,
            badges: [summary.type.capitalized]
        )
    }

    /// Classic and Grid use the dedicated hero slots only; the fallback
    /// synthesis across rail artwork is a Modern-only behavior.
    static func heroItems(_ snapshot: HomeSnapshot) -> [HeroItem] {
        snapshot.heroItems.map(heroItem)
    }

    static func artworkSource(_ value: String?) -> PosterArtworkSource {
        guard let value = value?.trimmedNonEmpty, let url = URL(string: value) else {
            return .placeholder(systemName: "film")
        }
        return .url(url)
    }

    static func isWatched(_ summary: MetaSummary, watchedKeys: Set<String>) -> Bool {
        watchedKeys.contains("\(summary.type.lowercased()):\(summary.id)")
    }

    struct MappedSections {
        var sections: [RailSection] = []
        var summariesByRailID: [String: MetaSummary] = [:]
        var summariesByHeroID: [String: MetaSummary] = [:]
    }

    static func map(snapshot: HomeSnapshot, preferences: HomePreferences) -> MappedSections {
        var mapped = MappedSections()
        for summary in snapshot.heroItems + snapshot.sections.flatMap(\.items) {
            mapped.summariesByHeroID[heroItemID(summary)] = summary
        }
        mapped.sections = snapshot.sections.map { section in
            let title = preferences.preference(for: section.id)?.customTitle.trimmedNonEmpty
                ?? section.title
            let items = section.items.map { summary -> RailItem in
                let railID = railItemID(sectionID: section.id, summary: summary)
                mapped.summariesByRailID[railID] = summary
                return RailItem(
                    id: railID,
                    title: summary.name,
                    year: summary.releaseInfo?.trimmedNonEmpty,
                    overview: summary.description?.trimmedNonEmpty,
                    metadata: [section.definition.addonName, summary.type.capitalized],
                    posterArtwork: artworkSource(summary.poster),
                    backdropArtwork: artworkSource(summary.background ?? summary.poster),
                    status: PosterCardStatus(
                        isWatched: isWatched(summary, watchedKeys: snapshot.watchedContentKeys)
                    )
                )
            }
            return RailSection(
                id: section.id,
                title: title,
                items: items,
                hasMore: section.nextSkip != nil,
                isLoading: snapshot.loadingSectionIDs.contains(section.id)
                    || (snapshot.isLoading && items.isEmpty)
            )
        }
        return mapped
    }
}

/// One row of the Classic layout LazyColumn, in vertical order.
enum ClassicHomeRow: Identifiable, Equatable {
    case continueWatching([ContinueWatchingCard])
    case upcoming([ContinueWatchingCard])
    case collection(TVCollection)
    case catalog(RailSection)

    var id: String {
        switch self {
        case .continueWatching: return "continue_watching"
        case .upcoming: return "upcoming_section"
        case .collection(let collection): return "collection_\(collection.id)"
        case .catalog(let section): return section.id
        }
    }
}

/// Presentation mapping for the Classic layout.
struct ClassicHomePresentation: Equatable {
    let heroes: [HeroItem]
    let rows: [ClassicHomeRow]
    let summariesByRailID: [String: MetaSummary]
    let summariesByHeroID: [String: MetaSummary]
    let sectionsByID: [String: HomeCatalogSection]

    static func build(
        snapshot: HomeSnapshot,
        preferences: HomePreferences
    ) -> ClassicHomePresentation {
        let mapped = HomeModeRailMapping.map(snapshot: snapshot, preferences: preferences)
        var rows: [ClassicHomeRow] = []
        if !snapshot.continueWatching.isEmpty {
            rows.append(.continueWatching(snapshot.continueWatching))
        }
        if !snapshot.upcoming.isEmpty {
            rows.append(.upcoming(snapshot.upcoming))
        }
        rows.append(contentsOf: snapshot.collections.map(ClassicHomeRow.collection))
        // Android classic renders homeRows in preference order; the tvos
        // snapshot keeps collections separate, so catalogs follow collections
        // in the order the sections were loaded.
        rows.append(
            contentsOf: mapped.sections
                .filter { !$0.items.isEmpty }
                .map(ClassicHomeRow.catalog)
        )
        return ClassicHomePresentation(
            heroes: HomeModeRailMapping.heroItems(snapshot),
            rows: rows,
            summariesByRailID: mapped.summariesByRailID,
            summariesByHeroID: mapped.summariesByHeroID,
            sectionsByID: Dictionary(
                uniqueKeysWithValues: snapshot.sections.map { ($0.id, $0) }
            )
        )
    }

    func summary(for item: RailItem) -> MetaSummary? {
        summariesByRailID[item.id]
    }

    func summary(for hero: HeroItem) -> MetaSummary? {
        summariesByHeroID[hero.id]
    }
}
