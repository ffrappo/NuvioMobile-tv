import SwiftUI

/// Cast rail with leading director/writer members, per Android
/// `CastSection.kt`: one horizontal rail (leading credits, divider, cast),
/// circular avatar cards with name and role labels underneath, plus credit
/// text rows for directors and writers.
public struct DetailsCastSectionView: View {
    public let model: DetailsCastSectionModel
    public let title: String
    public let onSelectMember: (DetailsCastMemberModel) -> Void

    /// Android CastSection parity values (itemWidth 150dp, cardSize 100dp).
    private let itemWidth: CGFloat = 150
    private let cardSize: CGFloat = 100

    public init(
        model: DetailsCastSectionModel,
        title: String = "Creator and Cast",
        onSelectMember: @escaping (DetailsCastMemberModel) -> Void = { _ in }
    ) {
        self.model = model
        self.title = title
        self.onSelectMember = onSelectMember
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            DetailsSectionHeaderView(title: title, symbol: "person.2")
            creditRows
            if !model.leadingMembers.isEmpty && !model.castMembers.isEmpty {
                roleDivider
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.sm) {
                    ForEach(model.leadingMembers) { member in
                        DetailsCastMemberCard(
                            member: member,
                            itemWidth: itemWidth,
                            cardSize: cardSize,
                            onSelect: { onSelectMember(member) }
                        )
                    }
                    ForEach(model.castMembers) { member in
                        DetailsCastMemberCard(
                            member: member,
                            itemWidth: itemWidth,
                            cardSize: cardSize,
                            onSelect: { onSelectMember(member) }
                        )
                    }
                }
                .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
                .padding(.vertical, NuvioDesignTokens.Spacing.Rail.verticalPadding)
            }
            .focusSection()
        }
        .padding(.top, NuvioDesignTokens.Spacing.lg)
    }

    @ViewBuilder
    private var creditRows: some View {
        let rows = creditLines
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                ForEach(rows, id: \.0) { label, names in
                    HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                        Text(label)
                            .nuvioTextStyle(.metadata)
                            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                        Text(names.joined(separator: ", "))
                            .nuvioTextStyle(.metadata)
                            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
                }
            }
        }
    }

    private var creditLines: [(String, [String])] {
        var lines: [(String, [String])] = []
        if !model.directorNames.isEmpty {
            lines.append(("Director", model.directorNames))
        }
        if !model.writerNames.isEmpty {
            lines.append(("Writer", model.writerNames))
        }
        return lines
    }

    private var roleDivider: some View {
        Rectangle()
            .fill(NuvioDesignTokens.Colors.neutral750)
            .frame(width: NuvioDesignTokens.Strokes.hairline, height: 72)
            .padding(.leading, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
            .accessibilityHidden(true)
    }
}

struct DetailsCastMemberCard: View {
    let member: DetailsCastMemberModel
    let itemWidth: CGFloat
    let cardSize: CGFloat
    let onSelect: () -> Void

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            Button(action: onSelect) {
                ZStack {
                    if let photoURL = member.photoURLString {
                        NuvioArtworkView(
                            urlString: photoURL,
                            mode: .poster,
                            pixelSize: CGSize(width: cardSize, height: cardSize),
                            cornerRadius: NuvioDesignTokens.Shapes.full
                        )
                    } else {
                        ZStack {
                            NuvioDesignTokens.Colors.elevated
                            Text(member.initials)
                                .nuvioTextStyle(.sectionTitle)
                                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                        }
                        .frame(width: cardSize, height: cardSize)
                        .clipShape(Circle())
                    }
                }
                .frame(width: cardSize, height: cardSize)
                .overlay(
                    Circle()
                        .strokeBorder(
                            isFocused ? NuvioDesignTokens.Colors.defaultFocus : .clear,
                            lineWidth: NuvioDesignTokens.Focus.ringWidth
                        )
                        .allowsHitTesting(false)
                )
            }
            .buttonStyle(DetailsPosterCardButtonStyle())
            .accessibilityLabel(member.name)
            .accessibilityHint(roleAccessibilityHint)

            Text(member.name)
                .nuvioTextStyle(.compactTitle)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .lineLimit(2)
            if let role = member.roleLabel {
                Text(role)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
                    .lineLimit(1)
            }
        }
        .frame(width: itemWidth, alignment: .leading)
        .animation(
            NuvioMotion.animation(for: .focus, reduceMotion: reduceMotion),
            value: isFocused
        )
    }

    private var roleAccessibilityHint: String {
        member.roleLabel.map { "Shows \($0) details" } ?? "Shows cast details"
    }
}
