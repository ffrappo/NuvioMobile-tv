import Combine
import SwiftUI
import UIKit

public enum NuvioArtworkMode: Sendable {
    case poster
    case backdrop
    case titleLogo

    public var defaultPixelSize: CGSize {
        switch self {
        case .poster: CGSize(width: 126, height: 189)
        case .backdrop: CGSize(width: 320, height: 180)
        case .titleLogo: CGSize(width: 190, height: 44)
        }
    }

    public var defaultCornerRadius: CGFloat {
        switch self {
        case .poster: 12
        case .backdrop: 16
        case .titleLogo: 0
        }
    }

    var defaultPlaceholderSystemImage: String {
        switch self {
        case .poster: "film"
        case .backdrop: "photo"
        case .titleLogo: "textformat"
        }
    }
}

public enum NuvioArtworkLoadPhase: Equatable, Sendable {
    case placeholder
    case loading
    case loaded
    case failure
}

public enum NuvioArtworkStatePresentation: Equatable, Sendable {
    case surface
    case transparent
}

@MainActor
final class NuvioArtworkViewModel: ObservableObject {
    @Published private(set) var phase: NuvioArtworkLoadPhase = .placeholder
    @Published private(set) var image: UIImage?

    private let loader: ArtworkLoader
    private var activeRequestID: UUID?

    init(loader: ArtworkLoader = .shared) {
        self.loader = loader
    }

    func load(url: URL?, pixelSize: CGSize) async {
        let requestID = UUID()
        activeRequestID = requestID
        image = nil
        guard let url else {
            phase = .placeholder
            return
        }

        phase = .loading
        let loadedImage = await loader.image(for: url, pixelSize: pixelSize)
        guard activeRequestID == requestID, !Task.isCancelled else { return }
        image = loadedImage
        phase = loadedImage == nil ? .failure : .loaded
    }
}

public struct NuvioArtworkView: View {
    public let url: URL?
    public let mode: NuvioArtworkMode
    public let pixelSize: CGSize
    public let cornerRadius: CGFloat
    public let fadeDuration: TimeInterval
    public let shimmerCycleDuration: TimeInterval
    public let statePresentation: NuvioArtworkStatePresentation

    private let placeholderColor: Color
    private let loadingHighlightColor: Color
    private let failureColor: Color
    private let symbolColor: Color
    private let placeholderSystemImage: String
    private let failureSystemImage: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model = NuvioArtworkViewModel()

    public init(
        url: URL?,
        mode: NuvioArtworkMode = .poster,
        pixelSize: CGSize? = nil,
        cornerRadius: CGFloat? = nil,
        fadeDuration: TimeInterval = 0.35,
        shimmerCycleDuration: TimeInterval = 1.2,
        statePresentation: NuvioArtworkStatePresentation = .surface,
        placeholderColor: Color = NuvioDesignTokens.Colors.elevated,
        loadingHighlightColor: Color = NuvioDesignTokens.Colors.elevatedSecondary,
        failureColor: Color = NuvioDesignTokens.Colors.canvas,
        symbolColor: Color = NuvioDesignTokens.Colors.secondaryText,
        placeholderSystemImage: String? = nil,
        failureSystemImage: String = "exclamationmark.triangle"
    ) {
        self.url = url
        self.mode = mode
        self.pixelSize = pixelSize ?? mode.defaultPixelSize
        self.cornerRadius = cornerRadius ?? mode.defaultCornerRadius
        self.fadeDuration = fadeDuration
        self.shimmerCycleDuration = shimmerCycleDuration
        self.statePresentation = statePresentation
        self.placeholderColor = placeholderColor
        self.loadingHighlightColor = loadingHighlightColor
        self.failureColor = failureColor
        self.symbolColor = symbolColor
        self.placeholderSystemImage = placeholderSystemImage
            ?? mode.defaultPlaceholderSystemImage
        self.failureSystemImage = failureSystemImage
    }

    public init(
        urlString: String?,
        mode: NuvioArtworkMode = .poster,
        pixelSize: CGSize? = nil,
        cornerRadius: CGFloat? = nil,
        fadeDuration: TimeInterval = 0.35,
        shimmerCycleDuration: TimeInterval = 1.2,
        statePresentation: NuvioArtworkStatePresentation = .surface,
        placeholderColor: Color = NuvioDesignTokens.Colors.elevated,
        loadingHighlightColor: Color = NuvioDesignTokens.Colors.elevatedSecondary,
        failureColor: Color = NuvioDesignTokens.Colors.canvas,
        symbolColor: Color = NuvioDesignTokens.Colors.secondaryText,
        placeholderSystemImage: String? = nil,
        failureSystemImage: String = "exclamationmark.triangle"
    ) {
        self.init(
            url: urlString.flatMap(URL.init(string:)),
            mode: mode,
            pixelSize: pixelSize,
            cornerRadius: cornerRadius,
            fadeDuration: fadeDuration,
            shimmerCycleDuration: shimmerCycleDuration,
            statePresentation: statePresentation,
            placeholderColor: placeholderColor,
            loadingHighlightColor: loadingHighlightColor,
            failureColor: failureColor,
            symbolColor: symbolColor,
            placeholderSystemImage: placeholderSystemImage,
            failureSystemImage: failureSystemImage
        )
    }

    public var body: some View {
        ZStack {
            switch model.phase {
            case .placeholder:
                stateSurface(color: placeholderColor, systemImage: placeholderSystemImage)
            case .loading:
                loadingSurface
            case .loaded:
                if let image = model.image {
                    loadedArtwork(image)
                        .frame(width: pixelSize.width, height: pixelSize.height)
                        .transition(.opacity)
                }
            case .failure:
                stateSurface(color: failureColor, systemImage: failureSystemImage)
                    .transition(.opacity)
            }
        }
        .frame(width: pixelSize.width, height: pixelSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipped()
        .animation(
            reduceMotion ? nil : .easeInOut(duration: max(fadeDuration, 0)),
            value: model.phase
        )
        .accessibilityHidden(true)
        .task(id: requestID) {
            await model.load(url: url, pixelSize: pixelSize)
        }
    }

    private var requestID: String {
        "\(url?.absoluteString ?? "placeholder")|\(pixelSize.width)x\(pixelSize.height)"
    }

    @ViewBuilder
    private var loadingSurface: some View {
        if statePresentation == .surface {
            stateSurface(color: placeholderColor, systemImage: placeholderSystemImage)
                .transition(.opacity)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func loadedArtwork(_ image: UIImage) -> some View {
        let artwork = Image(uiImage: image).resizable()
        switch mode {
        case .titleLogo:
            artwork.scaledToFit()
        case .poster, .backdrop:
            artwork.scaledToFill()
        }
    }

    @ViewBuilder
    private func stateSurface(color: Color, systemImage: String) -> some View {
        if statePresentation == .surface {
            ZStack {
                color
                Image(systemName: systemImage)
                    .font(.system(size: min(pixelSize.width, pixelSize.height) * 0.28))
                    .foregroundStyle(symbolColor)
            }
        } else {
            Color.clear
        }
    }
}
