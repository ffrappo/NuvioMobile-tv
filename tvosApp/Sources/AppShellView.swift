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
    @EnvironmentObject private var integrationStore: IntegrationStore
    @State private var selection: AppSection = .home
    @State private var path: [MetaSummary] = []
    @FocusState private var focusedSection: AppSection?

    var body: some View {
        NavigationStack(path: $path) {
            HStack(spacing: 0) {
                sidebar
                    .focusSection()
                content
                    .focusSection()
            }
            .background(NuvioTheme.background.ignoresSafeArea())
            .navigationDestination(for: MetaSummary.self) { summary in
                DetailsView(summary: summary)
            }
        }
        .task(id: authStore.signedInEmail) {
            if authStore.session != nil {
                async let addons: Void = addonStore.syncFromAccount(auth: authStore)
                async let integrations: Void = integrationStore.syncFromAccount(auth: authStore)
                _ = await (addons, integrations)
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
                        .foregroundStyle(focusedSection == section ? .black : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(sidebarColor(for: section))
                        )
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
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch selection {
            case .home:
                CatalogView(onSelect: showDetails)
            case .search:
                SearchView(onSelect: showDetails)
            case .library:
                LibraryView(onSelect: showDetails)
            case .addons:
                AddonsView()
            case .settings:
                SettingsView()
            }
        }
        .id(selection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func showDetails(_ summary: MetaSummary) {
        path.append(summary)
    }

    private func sidebarColor(for section: AppSection) -> Color {
        if focusedSection == section { return .white }
        if selection == section { return NuvioTheme.accent.opacity(0.65) }
        return .clear
    }
}

