import CoreText
import XCTest
@testable import NuvioTV

final class DesignTokenTests: XCTestCase {
    func testCanonicalColors() {
        XCTAssertEqual(NuvioDesignTokens.Colors.canvasBlackHex, 0x000000)
        XCTAssertEqual(NuvioDesignTokens.Colors.canvasHex, 0x0D0D0D)
        XCTAssertEqual(NuvioDesignTokens.Colors.elevatedHex, 0x1A1A1A)
        XCTAssertEqual(NuvioDesignTokens.Colors.elevatedSecondaryHex, 0x242424)
        XCTAssertEqual(NuvioDesignTokens.Colors.secondaryTextHex, 0xB3B3B3)
        XCTAssertEqual(NuvioDesignTokens.Colors.ratingHex, 0xFFD700)
        XCTAssertEqual(NuvioDesignTokens.Colors.imdbHex, 0xF5C518)
        XCTAssertEqual(NuvioDesignTokens.Colors.traktHex, 0xED1C24)
    }

    func testCanonicalMediaGeometryAndShapes() {
        XCTAssertEqual(NuvioDesignTokens.Sizes.Cards.poster.width, 126)
        XCTAssertEqual(NuvioDesignTokens.Sizes.Cards.poster.height, 189)
        XCTAssertEqual(NuvioDesignTokens.Shapes.posterRadius, 12)

        XCTAssertEqual(NuvioDesignTokens.Sizes.Cards.backdrop.width, 320)
        XCTAssertEqual(NuvioDesignTokens.Sizes.Cards.backdrop.height, 180)
        XCTAssertEqual(NuvioDesignTokens.Shapes.backdropRadius, 16)

        XCTAssertEqual(NuvioDesignTokens.Sizes.Cards.episodeThumbnail.width, 320)
        XCTAssertEqual(NuvioDesignTokens.Sizes.Cards.episodeThumbnail.height, 207)
        XCTAssertEqual(NuvioDesignTokens.Shapes.sidePanelRadius, 20)
        XCTAssertEqual(NuvioDesignTokens.Shapes.settingsContainerRadius, 28)
    }

    func testCanonicalSpacingFocusAndBlur() {
        XCTAssertEqual(NuvioDesignTokens.Spacing.Screen.horizontal, 48)
        XCTAssertEqual(NuvioDesignTokens.Spacing.Screen.vertical, 24)
        XCTAssertEqual(NuvioDesignTokens.Spacing.Rail.itemGap, 12)
        XCTAssertEqual(NuvioDesignTokens.Spacing.Rail.rowGap, 24)
        XCTAssertEqual(NuvioDesignTokens.Focus.ringWidth, 2)
        XCTAssertEqual(NuvioDesignTokens.Focus.scale, 1.02)
        XCTAssertEqual(NuvioDesignTokens.Focus.pressedScale, 0.98)
        XCTAssertEqual(NuvioDesignTokens.Blur.soft, 12)
        XCTAssertEqual(NuvioDesignTokens.Blur.panel, 26)
        XCTAssertEqual(NuvioDesignTokens.Blur.strong, 40)
    }

    func testCanonicalTypographyScale() {
        assertTypography(.display, points: 48, lineHeight: 56)
        assertTypography(.compactDisplay, points: 36, lineHeight: 44)
        assertTypography(.headline, points: 28, lineHeight: 36)
        assertTypography(.sectionTitle, points: 24, lineHeight: 32)
        assertTypography(.playerControl, points: 20, lineHeight: 28)
        assertTypography(.cardTitle, points: 16, lineHeight: 24)
        assertTypography(.body, points: 16, lineHeight: 24)
        assertTypography(.compactTitle, points: 14, lineHeight: 20)
        assertTypography(.compactBody, points: 14, lineHeight: 20)
        assertTypography(.button, points: 14, lineHeight: 20)
        assertTypography(.metadata, points: 12, lineHeight: 16)
        assertTypography(.badge, points: 10, lineHeight: 14)
    }

    func testBundledFontsLoadRegisterAndInterResolves() throws {
        _ = NuvioTypography.font(.display)

        for family in NuvioFontFamily.allCases {
            let url = try XCTUnwrap(NuvioFontRegistrar.fontURL(for: family))
            XCTAssertEqual(url.pathExtension, "ttf")
            XCTAssertFalse(try Data(contentsOf: url).isEmpty)
        }

        let registrations = NuvioFontRegistrar.registerBundledFonts()
        XCTAssertEqual(registrations.count, NuvioFontFamily.allCases.count)
        for result in registrations {
            XCTAssertTrue(
                result.succeeded,
                "\(result.family.rawValue): \(result.errorDescription ?? "unknown error")"
            )
        }
        XCTAssertEqual(NuvioFontRegistrar.resolvedFamilyName(for: .inter), "Inter")
    }

    func testCanonicalMotionDurationsAndReducedMotionVariants() {
        XCTAssertEqual(NuvioMotion.instant, 0, accuracy: 0.0001)
        XCTAssertEqual(NuvioMotion.quickTransition, 0.125, accuracy: 0.0001)
        XCTAssertEqual(NuvioMotion.focusTransition, 0.18, accuracy: 0.0001)
        XCTAssertEqual(NuvioMotion.contentTransition, 0.35, accuracy: 0.0001)
        XCTAssertEqual(NuvioMotion.overlayTransition, 0.4, accuracy: 0.0001)
        XCTAssertEqual(NuvioMotion.heroTransition, 0.45, accuracy: 0.0001)
        XCTAssertEqual(NuvioMotion.shimmerCycle, 1.2, accuracy: 0.0001)

        let expected: [NuvioMotionTransition: TimeInterval] = [
            .quick: 0.125,
            .focus: 0.18,
            .content: 0.35,
            .overlay: 0.4,
            .hero: 0.45,
            .shimmer: 1.2,
        ]
        for transition in NuvioMotionTransition.allCases {
            XCTAssertEqual(
                NuvioMotion.resolvedDuration(for: transition, reduceMotion: false),
                expected[transition]!,
                accuracy: 0.0001
            )
            XCTAssertEqual(
                NuvioMotion.resolvedDuration(
                    for: transition,
                    reduceMotion: true,
                    substitute: .instant
                ),
                0,
                accuracy: 0.0001
            )
            XCTAssertEqual(
                NuvioMotion.resolvedDuration(
                    for: transition,
                    reduceMotion: true,
                    substitute: .crossFade
                ),
                0.18,
                accuracy: 0.0001
            )
        }
    }

    func testCanonicalEasingCurves() {
        XCTAssertEqual(
            NuvioMotion.standardEasing,
            NuvioEasingCurve(x1: 0.4, y1: 0, x2: 0.2, y2: 1)
        )
        XCTAssertEqual(
            NuvioMotion.emphasizedEasing,
            NuvioEasingCurve(x1: 0.2, y1: 0, x2: 0, y2: 1)
        )
        XCTAssertEqual(
            NuvioMotion.decelerateEasing,
            NuvioEasingCurve(x1: 0, y1: 0, x2: 0.2, y2: 1)
        )
        XCTAssertEqual(
            NuvioMotion.accelerateEasing,
            NuvioEasingCurve(x1: 0.4, y1: 0, x2: 1, y2: 1)
        )
    }

    private func assertTypography(
        _ style: NuvioTypographyStyle,
        points: CGFloat,
        lineHeight: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(style.pointSize, points, file: file, line: line)
        XCTAssertEqual(style.lineHeight, lineHeight, file: file, line: line)
    }
}
