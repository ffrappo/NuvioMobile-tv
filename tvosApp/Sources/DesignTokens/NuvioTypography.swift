import CoreText
import SwiftUI

public enum NuvioFontFamily: String, CaseIterable, Hashable, Sendable {
    case inter = "Inter"
    case dmSans = "DM Sans"
    case openSans = "Open Sans"

    public var bundleResourceName: String {
        switch self {
        case .inter: "inter_variable"
        case .dmSans: "dm_sans_variable"
        case .openSans: "opensans_variable"
        }
    }
}

public struct NuvioFontRegistration: Equatable, Sendable {
    public let family: NuvioFontFamily
    public let fileURL: URL?
    public let succeeded: Bool
    public let errorDescription: String?
}

/// Process-scoped font registration backed by a lazy, thread-safe static value.
public enum NuvioFontRegistrar {
    private static let registrationResults: [NuvioFontRegistration] = {
        NuvioFontFamily.allCases.map(register)
    }()

    @discardableResult
    public static func registerBundledFonts() -> [NuvioFontRegistration] {
        registrationResults
    }

    public static func fontURL(for family: NuvioFontFamily) -> URL? {
        Bundle.main.url(
            forResource: family.bundleResourceName,
            withExtension: "ttf",
            subdirectory: "Fonts"
        ) ?? Bundle.main.url(
            forResource: family.bundleResourceName,
            withExtension: "ttf"
        )
    }

    public static func resolvedFamilyName(for family: NuvioFontFamily) -> String {
        _ = registerBundledFonts()
        let font = CTFontCreateWithName(family.rawValue as CFString, 16, nil)
        return CTFontCopyFamilyName(font) as String
    }

    private static func register(_ family: NuvioFontFamily) -> NuvioFontRegistration {
        guard let url = fontURL(for: family) else {
            return NuvioFontRegistration(
                family: family,
                fileURL: nil,
                succeeded: false,
                errorDescription: "Missing bundled font: \(family.bundleResourceName).ttf"
            )
        }

        var unmanagedError: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(
            url as CFURL,
            .process,
            &unmanagedError
        )
        guard !registered, let error = unmanagedError?.takeRetainedValue() else {
            return NuvioFontRegistration(
                family: family,
                fileURL: url,
                succeeded: registered,
                errorDescription: registered ? nil : "CoreText registration failed"
            )
        }

        // CoreText reports 105 when another first resolver already registered it.
        let alreadyRegistered = CFErrorGetCode(error) == 105
        return NuvioFontRegistration(
            family: family,
            fileURL: url,
            succeeded: alreadyRegistered,
            errorDescription: alreadyRegistered ? nil : CFErrorCopyDescription(error) as String
        )
    }
}

public enum NuvioTypographyStyle: CaseIterable, Hashable, Sendable {
    case display
    case compactDisplay
    case headline
    case sectionTitle
    case playerControl
    case cardTitle
    case body
    case compactTitle
    case compactBody
    case button
    case metadata
    case badge

    public var pointSize: CGFloat {
        switch self {
        case .display: 52
        case .compactDisplay: 42
        case .headline: 34
        case .sectionTitle: 30
        case .playerControl: 28
        case .cardTitle: 22
        case .body: 24
        case .compactTitle, .compactBody, .button: 20
        case .metadata: 18
        case .badge: 15
        }
    }

    public var lineHeight: CGFloat {
        switch self {
        case .display: 62
        case .compactDisplay: 52
        case .headline: 44
        case .sectionTitle: 38
        case .playerControl: 36
        case .cardTitle: 28
        case .body: 32
        case .compactTitle, .compactBody, .button: 28
        case .metadata: 24
        case .badge: 20
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .display, .compactDisplay: .bold
        case .headline, .sectionTitle, .playerControl, .button, .badge: .semibold
        case .cardTitle, .compactTitle, .metadata: .medium
        case .body, .compactBody: .regular
        }
    }

    public var tracking: CGFloat {
        switch self {
        case .display: -0.5
        case .cardTitle: 0.15
        case .compactTitle, .button: 0.1
        case .body: 0.5
        case .compactBody: 0.25
        case .metadata: 0.5
        case .badge: 0.8
        default: 0
        }
    }
}

public struct NuvioTextStyle {
    public let font: Font
    public let pointSize: CGFloat
    public let lineHeight: CGFloat
    public let tracking: CGFloat

    public var lineSpacing: CGFloat { lineHeight - pointSize }
}

public enum NuvioTypography {
    public static func font(
        _ style: NuvioTypographyStyle,
        family: NuvioFontFamily = .inter
    ) -> Font {
        _ = NuvioFontRegistrar.registerBundledFonts()
        return .custom(family.rawValue, size: style.pointSize).weight(style.weight)
    }

    public static func textStyle(
        _ style: NuvioTypographyStyle,
        family: NuvioFontFamily = .inter
    ) -> NuvioTextStyle {
        NuvioTextStyle(
            font: font(style, family: family),
            pointSize: style.pointSize,
            lineHeight: style.lineHeight,
            tracking: style.tracking
        )
    }

    public static let display: Font = font(.display)
    public static let compactDisplay: Font = font(.compactDisplay)
    public static let headline: Font = font(.headline)
    public static let sectionTitle: Font = font(.sectionTitle)
    public static let playerControl: Font = font(.playerControl)
    public static let cardTitle: Font = font(.cardTitle)
    public static let body: Font = font(.body)
    public static let compactTitle: Font = font(.compactTitle)
    public static let compactBody: Font = font(.compactBody)
    public static let button: Font = font(.button)
    public static let metadata: Font = font(.metadata)
    public static let badge: Font = font(.badge)
}

public extension View {
    func nuvioTextStyle(
        _ style: NuvioTypographyStyle,
        family: NuvioFontFamily = .inter
    ) -> some View {
        let token = NuvioTypography.textStyle(style, family: family)
        return font(token.font)
            .tracking(token.tracking)
            .lineSpacing(token.lineSpacing)
    }
}
