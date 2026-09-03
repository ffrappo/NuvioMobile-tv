import Foundation
import SwiftUI

/// Shared avatar catalog cache (`get_avatar_catalog`): resolves
/// `avatarID -> image URL` for gateway cards and feeds the editor's
/// avatar picker.
@MainActor
public final class ProfileAvatarCatalog: ObservableObject {
    public static let shared = ProfileAvatarCatalog()

    @Published private(set) var items: [AvatarCatalogRecord] = []
    private var loadTask: Task<Void, Never>?
    private let service = NuvioAccountService()

    /// One row the editor grid renders.
    public struct Choice: Identifiable, Equatable {
        public let id: String
        public let displayName: String
        public let imageURL: URL?
        public let bgColor: String?
    }

    public var choices: [Choice] {
        items.map { item in
            Choice(
                id: item.id,
                displayName: item.displayName,
                imageURL: NuvioAccountService.avatarImageURL(forStoragePath: item.storagePath),
                bgColor: item.bgColor
            )
        }
    }

    /// Loads once per session; failures leave the catalog empty (color
    /// circles remain the fallback, matching the pre-catalog behavior).
    func ensureLoaded(auth: AuthStore) {
        guard loadTask == nil, auth.session != nil else { return }
        loadTask = Task { [service] in
            guard let token = try? await auth.validAccessToken(),
                  let catalog = try? await service.avatarCatalog(accessToken: token) else { return }
            guard !Task.isCancelled else { return }
            items = catalog.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        }
    }

    /// `avatarUrl.takeIf { it.isNotBlank() }` wins over the catalog, like
    /// the Android card.
    public func displayURL(avatarID: String?, customURL: String?) -> URL? {
        if let custom = customURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty, let url = URL(string: custom) {
            return url
        }
        guard let avatarID,
              let item = items.first(where: { $0.id == avatarID }) else { return nil }
        return NuvioAccountService.avatarImageURL(forStoragePath: item.storagePath)
    }
}

/// The editor's avatar image grid (Android `AvatarPickerGrid`): one row of
/// catalog avatars with selection, above the color palette.
struct ProfileAvatarGrid: View {
    let choices: [ProfileAvatarCatalog.Choice]
    let selection: String?
    let onSelect: (String?) -> Void

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 128), spacing: 16)]

    var body: some View {
        if !choices.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose avatar")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(128))], spacing: 16) {
                        ForEach(choices) { choice in
                            avatarCell(choice)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func avatarCell(_ choice: ProfileAvatarCatalog.Choice) -> some View {
        Button {
            onSelect(choice.id == selection ? nil : choice.id)
        } label: {
            RemoteArtwork(
                urlString: choice.imageURL?.absoluteString,
                systemPlaceholder: "person.circle.fill"
            )
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                .overlay(Circle().stroke(
                    choice.id == selection ? Color.white : Color.clear,
                    lineWidth: 3
                ))
        }
        .buttonStyle(.card)
        .accessibilityLabel(choice.displayName)
        .accessibilityAddTraits(choice.id == selection ? .isSelected : [])
    }
}


/// The editor's full avatar section: the catalog image grid above the color
/// palette. Self-contained so the editor stays compact.
struct ProfileAvatarPickerSection: View {
    @Binding var avatarID: String?
    @Binding var colorHex: String
    let choices: [ProfileAvatarCatalog.Choice]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProfileAvatarGrid(choices: choices, selection: avatarID) { id in
                avatarID = id
            }
            VStack(spacing: 14) {
                sectionTitle("Choose avatar color")
                HStack(spacing: 14) {
                    ForEach(ProfileAvatarPalette.colors, id: \.self) { hex in
                        Button {
                            colorHex = hex
                        } label: {
                            Circle()
                                .fill(ProfileColorParsing.color(hex: hex))
                                .frame(width: 52, height: 52)
                                .overlay(Circle().strokeBorder(
                                    colorHex == hex
                                        ? NuvioDesignTokens.Colors.primaryText
                                        : NuvioDesignTokens.Colors.neutral600,
                                    lineWidth: colorHex == hex ? 3 : 1
                                ))
                        }
                        .buttonStyle(SwatchButtonStyle())
                        .accessibilityLabel("Avatar color \(hex)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
    }
}
