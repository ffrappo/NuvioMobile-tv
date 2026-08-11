import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case search
    case library
    case addons
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .library: return "Library"
        case .addons: return "Addons"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "heart.fill"
        case .addons: return "puzzlepiece.extension.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct AppShellView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var addonStore: AddonStore
    @State private var selection: AppSection = .home
    @State private var path: [MetaSummary] = []
    @State private var contentFocusRequest = 0
    @FocusState private var focusedSection: AppSection?

    var body: some View {
        NavigationStack(path: $path) {
            HStack(spacing: 0) {
                sidebar
                content
            }
            .background(NuvioTheme.background.ignoresSafeArea())
            .navigationDestination(for: MetaSummary.self) { summary in
                DetailsView(summary: summary)
            }
        }
        .task(id: authStore.signedInEmail) {
            if authStore.session != nil {
                await addonStore.syncFromAccount(auth: authStore)
            } else {
                await addonStore.refreshManifests()
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image("NuvioLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                Text("Nuvio")
                    .font(.title2.weight(.bold))
            }
            .padding(.bottom, 20)

            ForEach(AppSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Label(section.title, systemImage: section.symbol)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(sidebarColor(for: section))
                        )
                        .overlay(NuvioFocusBorder(focused: focusedSection == section, cornerRadius: 14))
                        .scaleEffect(focusedSection == section ? 1.04 : 1)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .focused($focusedSection, equals: section)
            }

            Spacer()

            Text("Native for Apple TV")
                .font(.caption)
                .foregroundStyle(NuvioTheme.secondaryText)
        }
        .padding(32)
        .frame(width: 310)
        .background(Color.black.opacity(0.38))
        .defaultFocus($focusedSection, .home)
        .onMoveCommand { direction in
            guard SidebarFocusRouter.shouldEnterContent(direction) else { return }
            contentFocusRequest += 1
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch selection {
            case .home:
                CatalogView(
                    entryFocusRequest: contentFocusRequest,
                    onReturnToSidebar: restoreSidebarFocus,
                    onSelect: showDetails
                )
            case .search:
                SearchView(entryFocusRequest: contentFocusRequest, onSelect: showDetails)
            case .library:
                LibraryView(
                    entryFocusRequest: contentFocusRequest,
                    onReturnToSidebar: restoreSidebarFocus,
                    onSelect: showDetails
                )
            case .addons:
                AddonsView(entryFocusRequest: contentFocusRequest)
            case .settings:
                SettingsView(entryFocusRequest: contentFocusRequest)
            }
        }
        .id(selection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func showDetails(_ summary: MetaSummary) {
        path.append(summary)
    }

    private func restoreSidebarFocus() {
        focusedSection = selection
    }

    private func sidebarColor(for section: AppSection) -> Color {
        if focusedSection == section { return NuvioTheme.panelFocused }
        if selection == section { return NuvioTheme.accent.opacity(0.65) }
        return .clear
    }
}

struct SidebarFocusRouter {
    static func shouldEnterContent(_ direction: MoveCommandDirection) -> Bool {
        direction == .right
    }
}

