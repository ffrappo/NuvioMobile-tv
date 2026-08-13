import SwiftUI

struct DetailsBackdrop: View {
    let urlString: String?
    @Environment(\.nuvioTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            RemoteArtwork(urlString: urlString, systemPlaceholder: "film.fill")
                .frame(width: proxy.size.width, height: min(proxy.size.height * 0.86, 820))
                .overlay {
                    ZStack {
                        Color.black.opacity(0.45)
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: theme.background.opacity(0.58), location: 0.62),
                                .init(color: theme.background, location: 1)
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
