import SwiftUI

struct DetailsBackdrop: View {
    let urlString: String?
    @Environment(\.nuvioTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            RemoteArtwork(urlString: urlString, systemPlaceholder: "film.fill")
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay {
                    ZStack {
                        Color.black.opacity(0.38)
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: theme.background.opacity(0.5), location: 0.58),
                                .init(color: theme.background.opacity(0.9), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
        }
        .ignoresSafeArea()
    }
}
