import Foundation

/// Builds the typed settings tree from `NuvioSettingsState`, mirroring the
/// Android section files. Sections are pure data: the integration layer reads
/// them for display and dispatches changes by setting id.
public enum NuvioSettingsTree {
    /// The three layout cards in `LayoutSettingsScreen.kt` order:
    /// Modern, Grid, Classic.
    public static let layoutOptions: [NuvioSettingOption] = [
        NuvioSettingOption(id: NuvioHomeLayout.modern.rawValue, title: "Modern View"),
        NuvioSettingOption(id: NuvioHomeLayout.grid.rawValue, title: "Grid View"),
        NuvioSettingOption(id: NuvioHomeLayout.classic.rawValue, title: "Classic View"),
    ]

    public static let themeOptions: [NuvioSettingOption] =
        NuvioAppTheme.allCases.map { NuvioSettingOption(id: $0.rawValue, title: $0.displayName) }

    /// `AVAILABLE_SUBTITLE_LANGUAGES` from PlayerSettingsDataStore.kt, also used
    /// for the audio language pickers.
    static let availableLanguages: [NuvioSettingOption] = SettingsLanguageCatalog.availableLanguages

    static func languageTitle(for code: String?) -> String {
        guard let code, !code.isEmpty else { return "Not set" }
        if code == "device" || code == "system" { return "System default" }
        return availableLanguages.first { $0.id == code }?.title
            ?? SubtitleLanguageCatalog.languageCodeToName(code)
    }

    /// All sections across every category.
    public static func sections(for state: NuvioSettingsState) -> [NuvioSettingsSection] {
        NuvioSettingsCategory.allCases.flatMap { sections(in: $0, state: state) }
    }

    public static func sections(
        in category: NuvioSettingsCategory,
        state: NuvioSettingsState
    ) -> [NuvioSettingsSection] {
        switch category {
        case .layout: layoutSections(state)
        case .playback: playbackSections(state)
        case .network: networkSections(state)
        case .integrations: integrationSections()
        case .diagnostics: diagnosticsSections(state)
        case .about: aboutSections(state)
        }
    }

    // MARK: - Layout (LayoutSettingsScreen.kt)

    static func layoutSections(_ state: NuvioSettingsState) -> [NuvioSettingsSection] {
        var homeSettings: [NuvioSetting] = [
            NuvioSetting(
                id: "layout.homeLayout",
                title: "Home layout",
                subtitle: "Choose how your home screen is organized",
                systemImage: "rectangle.3.group",
                kind: .optionPicker(layoutOptions),
                value: .option(state.homeLayout.rawValue),
                valueText: state.homeLayout.displayName
            ),
        ]
        if state.homeLayout == .modern {
            homeSettings.append(NuvioSetting(
                id: "layout.modernLandscapePosters",
                title: "Landscape posters",
                subtitle: "Use wide backdrops instead of posters on Modern Home",
                systemImage: "rectangle",
                kind: .toggle,
                value: .toggle(state.modernLandscapePostersEnabled)
            ))
            homeSettings.append(NuvioSetting(
                id: "layout.modernHeroFullScreenBackdrop",
                title: "Full-screen hero backdrop",
                subtitle: "Extend the hero backdrop behind the whole screen",
                systemImage: "rectangle.expand.vertical",
                kind: .toggle,
                value: .toggle(state.modernHeroFullScreenBackdropEnabled)
            ))
        }
        if state.homeLayout == .classic {
            homeSettings.append(NuvioSetting(
                id: "layout.classicFocusGradient",
                title: "Classic focus gradient",
                subtitle: "Gradient highlight for focused cards in Classic View",
                systemImage: "square.on.square.dashed",
                kind: .toggle,
                value: .toggle(state.classicFocusGradientEnabled)
            ))
        }
        return [
            NuvioSettingsSection(
                id: "layout.home",
                category: .layout,
                title: "Home",
                subtitle: "Layout and hero presentation",
                settings: homeSettings
            ),
            NuvioSettingsSection(
                id: "layout.theme",
                category: .layout,
                title: "Theme",
                subtitle: "Nuvio color theme",
                settings: [
                    NuvioSetting(
                        id: "layout.theme",
                        title: "Color theme",
                        subtitle: "Applies to focus rings, accents, and highlights",
                        systemImage: "paintpalette",
                        kind: .optionPicker(themeOptions),
                        value: .option(state.theme.rawValue),
                        valueText: state.theme.displayName
                    ),
                ]
            ),
        ]
    }

    // MARK: - Integrations (SettingsScreen.kt integration hub)

    static func integrationSections() -> [NuvioSettingsSection] {
        [
            NuvioSettingsSection(
                id: "integrations.hub",
                category: .integrations,
                title: "Integrations",
                subtitle: "Connected services and providers",
                settings: [
                    NuvioSetting(
                        id: "integrations.hub",
                        title: "Integration hub",
                        subtitle: "Browse every available integration",
                        systemImage: "square.grid.2x2",
                        kind: .navigation,
                        value: .action
                    ),
                    NuvioSetting(
                        id: "integrations.debrid",
                        title: "Debrid",
                        subtitle: "Premiumize, Real-Debrid, and AllDebrid accounts",
                        systemImage: "bolt",
                        kind: .navigation,
                        value: .action
                    ),
                    NuvioSetting(
                        id: "integrations.tmdb",
                        title: "TMDB",
                        subtitle: "Metadata, ratings, and watchlists",
                        systemImage: "film",
                        kind: .navigation,
                        value: .action
                    ),
                    NuvioSetting(
                        id: "integrations.mdblist",
                        title: "MDBList",
                        subtitle: "Lists and recommendations",
                        systemImage: "list.bullet.rectangle",
                        kind: .navigation,
                        value: .action
                    ),
                    NuvioSetting(
                        id: "integrations.animeSkip",
                        title: "Anime Skip",
                        subtitle: "Skip timestamps for anime openings and endings",
                        systemImage: "clock.arrow.circlepath",
                        kind: .navigation,
                        value: .action
                    ),
                ]
            ),
        ]
    }


    // MARK: - Diagnostics (NetworkSettingsScreen.kt diagnostics group)

    static func diagnosticsSections(_ state: NuvioSettingsState) -> [NuvioSettingsSection] {
        [
            NuvioSettingsSection(
                id: "diagnostics.reports",
                category: .diagnostics,
                title: "Reports",
                subtitle: "Crash and playback issue reporting",
                settings: [
                    NuvioSetting(
                        id: "diagnostics.sentryReports",
                        title: "Anonymous crash reports",
                        subtitle: "Send crash diagnostics to the Nuvio team",
                        systemImage: "ant.circle",
                        kind: .toggle,
                        value: .toggle(state.sentryReportsEnabled)
                    ),
                    NuvioSetting(
                        id: "diagnostics.playbackIssueReports",
                        title: "Playback issue reports",
                        subtitle: "Include playback details when a stream fails",
                        systemImage: "waveform.path.ecg",
                        kind: .toggle,
                        value: .toggle(state.playbackIssueReportsEnabled)
                    ),
                    NuvioSetting(
                        id: "diagnostics.playerStatsHud",
                        title: "Player stats HUD",
                        subtitle: "Show decode and drop counters during playback",
                        systemImage: "chart.bar",
                        kind: .toggle,
                        value: .toggle(state.playerStatsHudEnabled)
                    ),
                ]
            ),
        ]
    }

    // MARK: - About (AboutScreen.kt + UpdateChannelSettings.kt)

    static func aboutSections(_ state: NuvioSettingsState) -> [NuvioSettingsSection] {
        [
            NuvioSettingsSection(
                id: "about.app",
                category: .about,
                title: "About",
                subtitle: "Nuvio for Apple TV",
                settings: [
                    NuvioSetting(
                        id: "about.version",
                        title: "Version",
                        systemImage: "number",
                        kind: .info,
                        value: .text(state.appVersion),
                        valueText: state.appVersion
                    ),
                    NuvioSetting(
                        id: "about.updateChannel",
                        title: "Update channel",
                        subtitle: "Stable or beta releases",
                        systemImage: "arrow.triangle.2.circlepath",
                        kind: .optionPicker([
                            NuvioSettingOption(id: "STABLE", title: "Stable", subtitle: "Public releases"),
                            NuvioSettingOption(id: "BETA", title: "Beta", subtitle: "Early access releases"),
                        ]),
                        value: .option(state.updateChannel.rawValue),
                        valueText: state.updateChannel == .stable ? "Stable" : "Beta"
                    ),
                    NuvioSetting(
                        id: "about.updateBanner",
                        title: "Show update banner",
                        subtitle: "Notify when a new version is available",
                        systemImage: "megaphone",
                        kind: .toggle,
                        value: .toggle(state.updateBannerEnabled)
                    ),
                    NuvioSetting(
                        id: "about.checkUpdates",
                        title: "Check for updates",
                        subtitle: "Look for a newer Nuvio release now",
                        systemImage: "arrow.down.app",
                        kind: .action,
                        value: .action
                    ),
                    NuvioSetting(
                        id: "about.privacyPolicy",
                        title: "Privacy policy",
                        subtitle: "nuvio.tv/privacy-policy",
                        systemImage: "hand.raised",
                        kind: .action,
                        value: .action
                    ),
                    NuvioSetting(
                        id: "about.supportersContributors",
                        title: "Support Nuvio",
                        subtitle: "Supporters and contributors",
                        systemImage: "heart",
                        kind: .navigation,
                        value: .action
                    ),
                    NuvioSetting(
                        id: "about.licensesAttributions",
                        title: "Licenses and attributions",
                        subtitle: "Open source software used by Nuvio",
                        systemImage: "doc.text",
                        kind: .navigation,
                        value: .action
                    ),
                ]
            ),
        ]
    }
}
