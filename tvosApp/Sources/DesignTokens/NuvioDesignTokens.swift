import CoreGraphics
import SwiftUI

/// Native tvOS values ported from the Android TV design-token sources.
public enum NuvioDesignTokens {
    public enum Colors {
        public static let canvasBlackHex: UInt32 = 0x000000
        public static let primaryTextHex: UInt32 = 0xFFFFFF
        public static let canvasHex: UInt32 = 0x0D0D0D
        public static let neutral925Hex: UInt32 = 0x111111
        public static let elevatedHex: UInt32 = 0x1A1A1A
        public static let neutral875Hex: UInt32 = 0x1E1E1E
        public static let neutral850Hex: UInt32 = 0x222222
        public static let elevatedSecondaryHex: UInt32 = 0x242424
        public static let neutral800Hex: UInt32 = 0x2D2D2D
        public static let neutral750Hex: UInt32 = 0x333333
        public static let neutral700Hex: UInt32 = 0x4D4D4D
        public static let neutral650Hex: UInt32 = 0x6F6F6F
        public static let neutral600Hex: UInt32 = 0x808080
        public static let neutral500Hex: UInt32 = 0x9E9E9E
        public static let secondaryTextHex: UInt32 = 0xB3B3B3
        public static let neutral200Hex: UInt32 = 0xE0E0E0
        public static let neutral100Hex: UInt32 = 0xF5F5F5
        public static let brandHex: UInt32 = 0x1E88E5
        public static let brandFocusHex: UInt32 = 0x42A5F5
        public static let ratingHex: UInt32 = 0xFFD700
        public static let errorHex: UInt32 = 0xCF6679
        public static let warningHex: UInt32 = 0xFFB74D
        public static let successHex: UInt32 = 0x4CAF50
        public static let infoHex: UInt32 = 0x29B6F6
        public static let torrentHex: UInt32 = 0x7E57C2
        public static let premiumHex: UInt32 = 0xFFD54F
        public static let traktHex: UInt32 = 0xED1C24
        public static let tmdbHex: UInt32 = 0x01B4E4
        public static let imdbHex: UInt32 = 0xF5C518
        public static let mdblistHex: UInt32 = 0x7DD3FC

        public static let canvasBlack = Color(hexRGB: canvasBlackHex)
        public static let primaryText = Color(hexRGB: primaryTextHex)
        public static let canvas = Color(hexRGB: canvasHex)
        public static let neutral925 = Color(hexRGB: neutral925Hex)
        public static let elevated = Color(hexRGB: elevatedHex)
        public static let neutral875 = Color(hexRGB: neutral875Hex)
        public static let neutral850 = Color(hexRGB: neutral850Hex)
        public static let elevatedSecondary = Color(hexRGB: elevatedSecondaryHex)
        public static let neutral800 = Color(hexRGB: neutral800Hex)
        public static let neutral750 = Color(hexRGB: neutral750Hex)
        public static let neutral700 = Color(hexRGB: neutral700Hex)
        public static let neutral650 = Color(hexRGB: neutral650Hex)
        public static let neutral600 = Color(hexRGB: neutral600Hex)
        public static let neutral500 = Color(hexRGB: neutral500Hex)
        public static let secondaryText = Color(hexRGB: secondaryTextHex)
        public static let neutral200 = Color(hexRGB: neutral200Hex)
        public static let neutral100 = Color(hexRGB: neutral100Hex)
        public static let brand = Color(hexRGB: brandHex)
        public static let brandFocus = Color(hexRGB: brandFocusHex)
        public static let rating = Color(hexRGB: ratingHex)
        public static let error = Color(hexRGB: errorHex)
        public static let warning = Color(hexRGB: warningHex)
        public static let success = Color(hexRGB: successHex)
        public static let info = Color(hexRGB: infoHex)
        public static let torrent = Color(hexRGB: torrentHex)
        public static let premium = Color(hexRGB: premiumHex)
        public static let trakt = Color(hexRGB: traktHex)
        public static let tmdb = Color(hexRGB: tmdbHex)
        public static let imdb = Color(hexRGB: imdbHex)
        public static let mdblist = Color(hexRGB: mdblistHex)
        public static let defaultFocus = primaryText
    }

    public enum Spacing {
        public static let none: CGFloat = 0
        public static let hairline: CGFloat = 1
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 48
        public static let huge: CGFloat = 56

        public enum Screen {
            public static let horizontal: CGFloat = 80
            public static let vertical: CGFloat = 48
            public static let compactHorizontal: CGFloat = 64
            public static let compactVertical: CGFloat = 36
            public static let overscanHorizontal: CGFloat = 80
            public static let overscanVertical: CGFloat = 48
        }

        public enum Rail {
            public static let horizontalPadding: CGFloat = 80
            public static let verticalPadding: CGFloat = 10
            public static let rowGap: CGFloat = 40
            public static let itemGap: CGFloat = 22
            public static let headerBottom: CGFloat = 18
            public static let tailPadding: CGFloat = 200
        }

        public enum Card {
            public static let outer: CGFloat = 12
            public static let inner: CGFloat = 16
            public static let gap: CGFloat = 12
            public static let compactGap: CGFloat = 8
        }

        public enum Dialog {
            public static let outer: CGFloat = 32
            public static let inner: CGFloat = 24
            public static let gap: CGFloat = 16
            public static let compactGap: CGFloat = 12
        }

        public enum SidePanel {
            public static let outer: CGFloat = 36
            public static let inner: CGFloat = 20
            public static let gap: CGFloat = 16
            public static let compactGap: CGFloat = 10
        }

        public enum Player {
            public static let outer: CGFloat = 52
            public static let inner: CGFloat = 16
            public static let gap: CGFloat = 14
            public static let compactGap: CGFloat = 8
        }

        public enum Settings {
            public static let outer: CGFloat = 32
            public static let inner: CGFloat = 20
            public static let gap: CGFloat = 16
            public static let compactGap: CGFloat = 12
        }
    }

    public enum Sizes {
        public enum Icons {
            public static let xs: CGFloat = 14
            public static let sm: CGFloat = 18
            public static let md: CGFloat = 22
            public static let lg: CGFloat = 28
            public static let xl: CGFloat = 36
        }

        public enum Buttons {
            public static let compactHeight: CGFloat = 40
            public static let defaultHeight: CGFloat = 52
            public static let largeHeight: CGFloat = 64
            public static let minimumWidth: CGFloat = 96
        }

        public enum Sidebar {
            public static let hiddenWidth: CGFloat = 0
            public static let compactWidth: CGFloat = 72
            public static let closedWidth: CGFloat = 184
            public static let expandedWidth: CGFloat = 262
            public static let expandedItemWidth: CGFloat = 148
            public static let railItemHeight: CGFloat = 52
            public static let leadingVisual: CGFloat = 34
        }

        public enum Cards {
            public static let poster = CGSize(width: 180, height: 270)
            public static let compactPoster = CGSize(width: 160, height: 240)
            public static let backdrop = CGSize(width: 360, height: 203)
            public static let episodeThumbnail = CGSize(width: 360, height: 203)
            public static let continueWatching = CGSize(width: 360, height: 203)
        }

        public enum Avatars {
            public static let sm: CGFloat = 34
            public static let md: CGFloat = 48
            public static let lg: CGFloat = 82
            public static let xl: CGFloat = 112
            public static let profile: CGFloat = 126
            public static let compactProfile: CGFloat = 104
        }

        public enum Player {
            public static let control: CGFloat = 44
            public static let compactControl: CGFloat = 40
            public static let timelineHeight: CGFloat = 4
            public static let sidePanelWidth: CGFloat = 360
            public static let railWidth: CGFloat = 280
        }

        public enum Settings {
            public static let railWidth: CGFloat = 260
            public static let railItemHeight: CGFloat = 56
            public static let workspaceMinimumWidth: CGFloat = 720
            public static let rowMinimumHeight: CGFloat = 64
        }

        public static let logo = CGSize(width: 190, height: 44)
        public static let menuItemHeight: CGFloat = 48
    }

    public enum Shapes {
        public static let none: CGFloat = 0
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 16
        public static let xxl: CGFloat = 20
        public static let panel: CGFloat = 28
        public static let full: CGFloat = 999

        public static let posterRadius: CGFloat = 12
        public static let backdropRadius: CGFloat = 16
        public static let collectionRadius: CGFloat = 16
        public static let episodeRadius: CGFloat = 16
        public static let sidePanelRadius: CGFloat = 20
        public static let settingsContainerRadius: CGFloat = 28
        public static let settingsSecondaryCardRadius: CGFloat = 18
        public static let sidebarRadius: CGFloat = 30
        public static let skeletonRadius: CGFloat = 10
    }

    public enum Media {
        public static let posterAspectRatio: CGFloat = 2.0 / 3.0
        public static let backdropAspectRatio: CGFloat = 16.0 / 9.0
        public static let heroAspectRatio: CGFloat = 16.0 / 9.0
        public static let logoAspectRatio: CGFloat = 190.0 / 44.0
        public static let thumbnailAspectRatio: CGFloat = 16.0 / 9.0
        public static let posterFallbackIconFraction: CGFloat = 0.28
        public static let backdropGradientStops: [CGFloat] = [0, 0.55, 1]
        public static let playerOverlayGradientStops: [CGFloat] = [0, 0.65, 1]
    }

    public enum Layout {
        public static let safeHorizontal: CGFloat = 80
        public static let safeVertical: CGFloat = 48
        public static let compactSafeHorizontal: CGFloat = 64
        public static let compactSafeVertical: CGFloat = 36
        public static let sidebarContentOffset: CGFloat = 0
        /// Apple TV's native sidebar already reserves its own interaction
        /// space. Foreground content uses the standard 80-point TV margin.
        public static let nativeSidebarForegroundInset: CGFloat = 80
        public static let rowAnchor: CGFloat = 0.42
        public static let detailsHeroWidthFraction: CGFloat = 0.62
        public static let detailsHeroHeightFraction: CGFloat = 0.72
    }

    public enum Blur {
        public static let soft: CGFloat = 12
        public static let panel: CGFloat = 26
        public static let strong: CGFloat = 40
    }

    public enum Strokes {
        public static let none: CGFloat = 0
        public static let hairline: CGFloat = 1
        public static let thin: CGFloat = 1.5
        public static let medium: CGFloat = 2
        public static let focus: CGFloat = 2
        public static let heavy: CGFloat = 3
        public static let progress: CGFloat = 4
        public static let divider: CGFloat = 1
    }

    public enum Elevations {
        public static let none: CGFloat = 0
        public static let card: CGFloat = 2
        public static let focused: CGFloat = 8
        public static let menu: CGFloat = 8
        public static let dialog: CGFloat = 12
        public static let overlay: CGFloat = 16
    }

    public enum Effects {
        public static let scrimLightOpacity = 0.28
        public static let scrimMediumOpacity = 0.52
        public static let scrimStrongOpacity = 0.78
        public static let glowSoftOpacity = 0.18
        public static let glowStrongOpacity = 0.38
        public static let imageOverlayOpacity = 0.62
        public static let disabledOpacity = 0.42
        public static let shimmerLowOpacity = 0.08
        public static let shimmerHighOpacity = 0.18
    }

    public enum Focus {
        public static let ringWidth: CGFloat = 2
        public static let scale: CGFloat = 1.02
        public static let subtleScale: CGFloat = 1.01
        public static let pressedScale: CGFloat = 0.98
        public static let reducedMotionScale: CGFloat = 1
        public static let scrollViewportTarget: CGFloat = 0.42
    }

    public enum Components {
        public static let posterContentPadding: CGFloat = 8
        public static let backdropContentPadding: CGFloat = 16
        public static let episodeContentPadding: CGFloat = 16
        public static let cardFocusedBorderWidth: CGFloat = 2
        public static let cardFocusedScale: CGFloat = 1.02

        public static let sidebarLegacyCollapsedWidth: CGFloat = 72
        public static let sidebarLegacyExpandedWidth: CGFloat = 196
        public static let sidebarContentGap: CGFloat = 14

        public static let dialogMaximumWidth: CGFloat = 720
        public static let dialogContentPadding: CGFloat = 24
        public static let dialogActionSpacing: CGFloat = 12
        public static let sidePanelMaximumWidth: CGFloat = 420
        public static let sidePanelContentPadding: CGFloat = 20

        public static let settingsWorkspacePadding: CGFloat = 20
        public static let settingsRowGap: CGFloat = 16
        public static let playerOverlayHorizontalPadding: CGFloat = 52
        public static let playerOverlayVerticalPadding: CGFloat = 36

        public static let chipHeight: CGFloat = 32
        public static let badgeHeight: CGFloat = 20
    }
}

private extension Color {
    init(hexRGB: UInt32) {
        self.init(
            .sRGB,
            red: Double((hexRGB >> 16) & 0xFF) / 255,
            green: Double((hexRGB >> 8) & 0xFF) / 255,
            blue: Double(hexRGB & 0xFF) / 255,
            opacity: 1
        )
    }
}
