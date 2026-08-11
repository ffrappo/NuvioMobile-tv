import SwiftUI

@main
struct NuvioTVApp: App {
    @StateObject private var addonStore = AddonStore()
    @StateObject private var libraryStore = LibraryStore()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(addonStore)
                .environmentObject(libraryStore)
                .preferredColorScheme(.dark)
        }
    }
}

enum NuvioTheme {
    static let background = Color(red: 0.035, green: 0.035, blue: 0.045)
    static let panel = Color.white.opacity(0.075)
    static let panelFocused = Color.white.opacity(0.20)
    static let accent = Color(red: 0.56, green: 0.38, blue: 1.0)
    static let secondaryText = Color.white.opacity(0.68)
}

extension String {
    var tvSafe: String {
        replacingOccurrences(of: "\u{0026}", with: "and")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
    }
}
