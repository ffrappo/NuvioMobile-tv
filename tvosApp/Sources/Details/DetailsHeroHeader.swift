import SwiftUI

/// Button model supplied by the integrator for the hero action row
/// (Play / Trailer / Add-to-library).
public struct DetailsHeroActionModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String?
    public let isPrimary: Bool

    public init(id: String, title: String, systemImage: String? = nil, isPrimary: Bool = false) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isPrimary = isPrimary
    }
}

/// Detail hero content with logo/title fallback, Android `HeroTitleContent`
/// meta rows, and an integration-supplied action row. The parent provides a
/// bounded hero height while the screen-level backdrop remains full bleed.
public struct DetailsHeroHeaderView: View {
    public let model: DetailsHeroModel
    public let actions: [DetailsHeroActionModel]
    public let onAction: (DetailsHeroActionModel) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        model: DetailsHeroModel,
        actions: [DetailsHeroActionModel] = [],
        onAction: @escaping (DetailsHeroActionModel) -> Void = { _ in }
    ) {
        self.model = model
        self.actions = actions
        self.onAction = onAction
    }

    public var body: some View {
        content
            .accessibilityElement(children: .contain)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            title
            primaryMetaRow
            if model.hasSecondaryMeta {
                secondaryMetaRow
            }
            if let overview = model.overview {
                Text(overview)
                    .nuvioTextStyle(.body)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText.opacity(0.9))
                    .lineLimit(4)
            }
            actionRow
        }
        .padding(.horizontal, NuvioDesignTokens.Layout.safeHorizontal)
        .padding(.vertical, NuvioDesignTokens.Layout.safeVertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    @ViewBuilder
    private var title: some View {
        if let logo = model.logoURLString {
            NuvioArtworkView(
                urlString: logo,
                mode: .titleLogo,
                pixelSize: CGSize(width: 420, height: 112),
                cornerRadius: 0,
                fadeDuration: NuvioMotion.contentTransition,
                statePresentation: .transparent,
                failureSystemImage: "textformat"
            )
            .frame(maxWidth: 420, alignment: .leading)
            .accessibilityLabel(model.title)
        } else {
            Text(model.title)
                .nuvioTextStyle(.display)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                .lineLimit(2)
        }
    }

    private var primaryMetaRow: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.sm) {
            let leading = model.primaryLeadingTexts
            let trailing = model.primaryTrailingTexts
            if !leading.isEmpty {
                Text(leading.joined(separator: " • "))
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
            if !leading.isEmpty && !trailing.isEmpty {
                metaDivider
            }
            ForEach(trailing, id: \.self) { text in
                Text(text)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            }
            if let imdb = model.imdbRatingText {
                if !leading.isEmpty || !trailing.isEmpty {
                    metaDivider
                }
                Label("IMDb \(imdb)", systemImage: "star.fill")
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .labelStyle(TitleAndIconLabelStyle())
                    .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
                    .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
                    .background(
                        NuvioDesignTokens.Colors.elevated.opacity(0.82),
                        in: Capsule()
                    )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var secondaryMetaRow: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.sm) {
            if let highlight = model.secondaryHighlightText {
                Text(highlight)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(1)
            }
            if let age = model.ageRatingText {
                metaBadge(age)
            }
            if let status = model.statusBadgeText {
                metaBadge(status, tint: NuvioDesignTokens.Colors.primaryText)
            }
            if let language = model.languageText {
                if model.secondaryHighlightText != nil ||
                    model.ageRatingText != nil || model.statusBadgeText != nil {
                    metaDivider
                }
                Text(language)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func metaBadge(
        _ text: String,
        tint: Color = NuvioDesignTokens.Colors.secondaryText
    ) -> some View {
        Text(text)
            .nuvioTextStyle(.metadata)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, NuvioDesignTokens.Spacing.sm)
            .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
            .overlay(
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xs, style: .continuous)
                    .strokeBorder(tint.opacity(0.55), lineWidth: NuvioDesignTokens.Strokes.hairline)
            )
    }

    private var metaDivider: some View {
        Text("•")
            .nuvioTextStyle(.metadata)
            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText.opacity(0.6))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var actionRow: some View {
        if !actions.isEmpty {
            HStack(spacing: NuvioDesignTokens.Spacing.md) {
                ForEach(actions) { action in
                    DetailsHeroActionButton(
                        action: action,
                        onSelect: { onAction(action) }
                    )
                }
            }
            .focusSection()
        }
    }
}

private struct DetailsHeroActionButton: View {
    let action: DetailsHeroActionModel
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Group {
                if let systemImage = action.systemImage {
                    Label(action.title, systemImage: systemImage)
                } else {
                    Text(action.title)
                }
            }
            .nuvioTextStyle(.button)
            .lineLimit(1)
            .padding(.horizontal, NuvioDesignTokens.Spacing.xl)
            .frame(
                minWidth: NuvioDesignTokens.Sizes.Buttons.minimumWidth,
                minHeight: NuvioDesignTokens.Sizes.Buttons.defaultHeight
            )
        }
        .buttonStyle(DetailsHeroActionButtonStyle(isPrimary: action.isPrimary))
        .accessibilityHint("Activates \(action.title)")
    }
}

private struct DetailsHeroActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(backgroundColor, in: Capsule())
            .overlay(
                Capsule().stroke(
                    isFocused
                        ? NuvioDesignTokens.Colors.defaultFocus
                        : NuvioDesignTokens.Colors.secondaryText.opacity(0.7),
                    lineWidth: isFocused
                        ? NuvioDesignTokens.Focus.ringWidth
                        : NuvioDesignTokens.Strokes.hairline
                )
            )
            .scaleEffect(scale(configuration))
            .animation(
                NuvioMotion.animation(for: .focus, reduceMotion: reduceMotion),
                value: isFocused
            )
            .animation(
                NuvioMotion.animation(for: .quick, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }

    private var foreground: Color {
        if isPrimary { return NuvioDesignTokens.Colors.canvasBlack }
        return isFocused
            ? NuvioDesignTokens.Colors.canvasBlack
            : NuvioDesignTokens.Colors.primaryText
    }

    private var backgroundColor: Color {
        if isPrimary || isFocused {
            return NuvioDesignTokens.Colors.primaryText
        }
        return NuvioDesignTokens.Colors.elevated.opacity(0.88)
    }

    private func scale(_ configuration: Configuration) -> CGFloat {
        guard !reduceMotion else { return NuvioDesignTokens.Focus.reducedMotionScale }
        if configuration.isPressed { return NuvioDesignTokens.Focus.pressedScale }
        return isFocused ? NuvioDesignTokens.Focus.scale : 1
    }
}
