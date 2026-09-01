import SwiftUI

/// Profile card mirroring Android `ProfileCard`: 152pt column, 126pt avatar
/// container, focus scale 1.04 with the focus easing
/// cubic-bezier(0.22, 1, 0.36, 1) at 210ms, animated avatar growth
/// (96 → 102) inside a bordered outer circle (114 → 122), primary star
/// badge, name, and the meta slot.
struct ProfileGatewayCardView: View {
    let profile: GatewayProfile
    let width: CGFloat
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var focusProgress: Double { isFocused ? 1 : 0 }

    private var avatarSize: CGFloat { 96 + (102 - 96) * focusProgress }
    private var outerSize: CGFloat { 114 + (122 - 114) * focusProgress }
    private var ringWidth: CGFloat { 1 + (3 - 1) * focusProgress }

    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = profile.name
        if profile.isPrimary { label += ", primary profile" }
        if profile.lock.isLocked { label += ", PIN protected" }
        return label
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .strokeBorder(
                        NuvioDesignTokens.Colors.neutral600.opacity(0.75),
                        lineWidth: NuvioDesignTokens.Strokes.hairline
                    )
                    .frame(width: outerSize, height: outerSize)
                ProfileAvatarCircleView(
                    name: profile.name,
                    colorHex: profile.avatarColorHex,
                    size: avatarSize,
                    avatarURL: profile.avatarDisplayURL
                )
                if profile.isPrimary {
                    ProfilePrimaryBadgeView(diameter: 26)
                        .offset(x: 52, y: 50)
                } else if profile.lock.isLocked {
                    ProfileLockBadgeView(diameter: 26)
                        .offset(x: 52, y: 50)
                }
            }
            .frame(width: 126, height: 126)

            Text(profile.name)
                .font(.system(size: 17, weight: isFocused ? .semibold : .medium))
                .foregroundStyle(
                    isFocused
                        ? NuvioDesignTokens.Colors.primaryText
                        : NuvioDesignTokens.Colors.secondaryText
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.top, 12)

            // Meta slot keeps row heights aligned (Android MetaSlotHeight).
                .frame(height: 16, alignment: .top)
                .overlay(alignment: .top) {
                    if profile.isPrimary {
                        Text("PRIMARY")
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(0.8)
                            .foregroundStyle(
                                ProfileColorParsing.color(hex: ProfileAvatarPalette.primaryBadgeHex)
                            )
                    }
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: width)
    }
}

/// Add-profile card mirroring Android `AddProfileCard`: plus glyph inside the
/// bordered outer circle, ghost background that brightens on focus.
struct ProfileAddCardView: View {
    let width: CGFloat
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var focusProgress: Double { isFocused ? 1 : 0 }
    private var outerSize: CGFloat { 114 + (122 - 114) * focusProgress }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06 + 0.06 * focusProgress))
                        .frame(width: outerSize, height: outerSize)
                    Circle()
                        .strokeBorder(
                            NuvioDesignTokens.Colors.neutral600.opacity(0.5),
                            lineWidth: NuvioDesignTokens.Strokes.hairline
                        )
                        .frame(width: outerSize, height: outerSize)
                    Image(systemName: "plus")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(
                            isFocused ? Color.white : NuvioDesignTokens.Colors.secondaryText
                        )
                }
                .frame(width: 126, height: 126)

                Text("Add Profile")
                    .font(.system(size: 17, weight: isFocused ? .semibold : .medium))
                    .foregroundStyle(
                        isFocused
                            ? NuvioDesignTokens.Colors.primaryText
                            : NuvioDesignTokens.Colors.secondaryText
                    )
                    .lineLimit(1)
                    .padding(.top, 12)
                    .frame(height: 16, alignment: .top)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: width)
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add Profile")
    }
}

/// Focus treatment for the grid cards: 1.04 scale with the Android card
/// focus easing (cubic-bezier(0.22, 1, 0.36, 1), 210ms) plus a soft ring;
/// reduced motion keeps the ring and drops the scale.
struct CardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var isFocused

    private static let focusEasing = NuvioEasingCurve(x1: 0.22, y1: 1, x2: 0.36, y2: 1)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (isFocused ? 1.04 : 1))
            .overlay(
                Circle()
                    .strokeBorder(
                        isFocused
                            ? NuvioDesignTokens.Colors.defaultFocus.opacity(0.9)
                            : .clear,
                        lineWidth: NuvioDesignTokens.Strokes.focus
                    )
                    .frame(width: 128, height: 128)
                    .allowsHitTesting(false)
            )
            .shadow(
                color: Color.white.opacity(isFocused ? 0.18 : 0),
                radius: NuvioDesignTokens.Blur.soft
            )
            .animation(
                reduceMotion
                    ? nil
                    : Self.focusEasing.animation(duration: 0.21),
                value: isFocused
            )
    }
}
