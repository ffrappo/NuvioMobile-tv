import SwiftUI

// MARK: - Hex parsing (pure, testable)

public enum ProfileColorParsing {
    /// Parses "#RRGGBB" (or "RRGGBB") into 0...1 components. Mirrors the
    /// Android `parseProfileColor` fallback to the Ocean blue.
    public static func components(hex: String) -> (red: Double, green: Double, blue: Double)? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 3 || value.count == 6,
              let parsed = UInt32(value, radix: 16)
        else { return nil }
        if value.count == 3 {
            let r = Double((parsed >> 8) & 0xF) / 15
            let g = Double((parsed >> 4) & 0xF) / 15
            let b = Double(parsed & 0xF) / 15
            return (r, g, b)
        }
        let r = Double((parsed >> 16) & 0xFF) / 255
        let g = Double((parsed >> 8) & 0xFF) / 255
        let b = Double(parsed & 0xFF) / 255
        return (r, g, b)
    }

    public static func color(hex: String, fallback: String = ProfileAvatarPalette.defaultHex) -> Color {
        guard let c = components(hex: hex) ?? components(hex: fallback) else {
            return Color(red: 0.118, green: 0.533, blue: 0.898)
        }
        return Color(red: c.red, green: c.green, blue: c.blue)
    }
}

// MARK: - Avatar circle

/// Mirrors Android `ProfileAvatarCircle`: solid avatar color with the
/// profile's initial, or the avatar image when one is set.
public struct ProfileAvatarCircleView: View {
    public let name: String
    public let colorHex: String
    public let size: CGFloat
    public let avatarURL: String?

    public init(name: String, colorHex: String, size: CGFloat, avatarURL: String?) {
        self.name = name
        self.colorHex = colorHex
        self.size = size
        self.avatarURL = avatarURL
    }

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map(String.init) ?? "?"
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(ProfileColorParsing.color(hex: colorHex))
            if let url = avatarURL, let imageURL = URL(string: url) {
                NuvioArtworkView(
                    url: imageURL,
                    mode: .poster,
                    pixelSize: CGSize(width: size * 2, height: size * 2),
                    cornerRadius: size / 2,
                    fadeDuration: NuvioMotion.crossFadeTransition
                )
                .clipShape(Circle())
            } else {
                Text(initial)
                    .font(.system(size: size * 0.38, weight: .bold, design: .default))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}

// MARK: - Card badges

/// Amber star badge the Android grid pins on the primary profile
/// (`0xFFFFB300`, white ★, background-colored rim).
struct ProfilePrimaryBadgeView: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(ProfileColorParsing.color(hex: ProfileAvatarPalette.primaryBadgeHex))
            .overlay(
                Text("\u{2605}")
                    .font(.system(size: diameter * 0.54, weight: .bold))
                    .foregroundStyle(.white)
            )
            .overlay(Circle().strokeBorder(NuvioDesignTokens.Colors.canvas, lineWidth: NuvioDesignTokens.Spacing.xxs))
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}

/// Lock indicator for PIN-protected profiles. The Android grid routes
/// locked profiles straight to the PIN overlay without a card glyph; the
/// brief explicitly asks for a lock indicator, so it is added here.
struct ProfileLockBadgeView: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.66))
            .overlay(
                Image(systemName: "lock.fill")
                    .font(.system(size: diameter * 0.4, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            )
            .overlay(
                Circle().strokeBorder(
                    NuvioDesignTokens.Colors.secondaryText.opacity(0.55),
                    lineWidth: NuvioDesignTokens.Strokes.hairline
                )
            )
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}
