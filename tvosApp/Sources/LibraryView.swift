import SwiftUI

/// Wave 2 integration: the Android-parity Library composition wired to the
/// existing LibraryStore and WatchProgressStore. Cloud mode stays a
/// placeholder surface until the account library sync ships.
struct LibraryView: View {
    let onSelect: (MetaSummary) -> Void

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var watchProgress: WatchProgressStore
    @State private var presentation = LibraryPresentation()

    var body: some View {
        LibraryParityView(presentation: $presentation, onSelect: onSelect)
            .onAppear { syncPresentation() }
            .onChange(of: library.items) { _, _ in syncPresentation() }
            .onChange(of: watchProgress.records) { _, _ in syncPresentation() }
    }

    /// Rebuilds the pure presentation inputs from the stores while keeping
    /// the user's active filter, sort, and query selections.
    private func syncPresentation() {
        presentation.items = library.items
        presentation.watchedKeys = Set(
            watchProgress.records
                .filter(\.isCompleted)
                .map { "\($0.contentType.lowercased()):\($0.contentID)" }
        )
    }
}
