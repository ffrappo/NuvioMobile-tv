import SwiftUI
import UIKit

/// Native rendering of ClassicFocusGradientBackdrop.kt: a linear gradient of
/// the focused item's prominent artwork color, painted right of 29% of the
/// width, visible only once the immersive hero backdrop has faded, with the
/// 140ms focus debounce and 256-entry color cache.
struct ClassicFocusGradientBackdrop: View {
    let artwork: ClassicFocusArtwork?
    let isVisible: Bool
    let updatesPaused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedColor: ClassicRGB?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            LinearGradient(
                stops: gradientStops,
                startPoint: UnitPoint(
                    x: ClassicFocusGradient.startUnit.x,
                    y: ClassicFocusGradient.startUnit.y
                ),
                endPoint: UnitPoint(
                    x: ClassicFocusGradient.endUnit.x,
                    y: ClassicFocusGradient.endUnit.y
                )
            )
            .mask(alignment: .leading) {
                GeometryReader { maskProxy in
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: maskProxy.size.width * ClassicFocusGradient.firstVisibleXFraction)
                        Rectangle()
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .opacity(isVisible && displayedColor != nil ? 1 : 0)
        .task(id: artwork) {
            await resolveColor()
        }
    }

    private var gradientStops: [Gradient.Stop] {
        let color = (displayedColor ?? ClassicFocusGradient.defaultFallback).color
        return ClassicFocusGradient.stops.map { stop in
            Gradient.Stop(color: color.opacity(stop.alpha), location: stop.location)
        }
    }

    @MainActor
    private func resolveColor() async {
        guard isVisible, !updatesPaused else { return }
        guard let artwork else {
            displayedColor = nil
            return
        }
        if let cached = ClassicFocusColorCache.color(for: artwork) {
            apply(cached, for: artwork)
            return
        }
        // Show the seed-derived fallback first, then refine with the sampled
        // artwork color, matching Android's cache-miss flow.
        apply(ClassicFocusGradient.seedColor(seed: artwork.seed), for: artwork)
        do {
            try await Task.sleep(
                for: .milliseconds(ClassicFocusGradient.debounceMilliseconds)
            )
        } catch {
            return
        }
        if let sampled = await sampleColor(for: artwork) {
            ClassicFocusColorCache.store(sampled, for: artwork)
            apply(sampled, for: artwork)
            return
        }
        do {
            try await Task.sleep(
                for: .milliseconds(ClassicFocusGradient.cacheRetryMilliseconds)
            )
        } catch {
            return
        }
        if let sampled = await sampleColor(for: artwork) {
            ClassicFocusColorCache.store(sampled, for: artwork)
            apply(sampled, for: artwork)
        }
    }

    @MainActor
    private func apply(_ color: ClassicRGB, for artwork: ClassicFocusArtwork) {
        guard self.artwork == artwork, !Task.isCancelled else { return }
        withAnimation(
            reduceMotion ? nil : .easeInOut(duration: NuvioMotion.overlayTransition)
        ) {
            displayedColor = color
        }
    }

    private func sampleColor(for artwork: ClassicFocusArtwork) async -> ClassicRGB? {
        guard let urlString = artwork.imageURL,
              let url = URL(string: urlString)
        else { return nil }
        let image = await ArtworkLoader.shared.image(for: url)
        guard let image else { return nil }
        return await Task.detached(priority: .userInitiated) {
            ClassicFocusColorSampler.prominentColor(in: image)?.stabilized
        }.value
    }
}

/// LRU-ish color cache bounded at ClassicFocusGradient.colorCacheLimit.
@MainActor
enum ClassicFocusColorCache {
    private static var order: [ClassicFocusArtwork] = []
    private static var colors: [ClassicFocusArtwork: ClassicRGB] = [:]

    static func color(for artwork: ClassicFocusArtwork) -> ClassicRGB? {
        colors[artwork]
    }

    static func store(_ color: ClassicRGB, for artwork: ClassicFocusArtwork) {
        if let index = order.firstIndex(of: artwork) {
            order.remove(at: index)
        }
        order.append(artwork)
        colors[artwork] = color
        if order.count > ClassicFocusGradient.colorCacheLimit {
            let evicted = order.removeFirst()
            colors[evicted] = nil
        }
    }

    static func removeAll() {
        order.removeAll()
        colors.removeAll()
    }
}

/// Port of sampledProminentColor: downsample to 72x72, step-sample a 14x14
/// grid, and average with HSV saturation/value weights.
enum ClassicFocusColorSampler {
    static let sampleSize = 72

    static func prominentColor(in image: UIImage) -> ClassicRGB? {
        guard let cgImage = image.cgImage else { return nil }
        let width = sampleSize
        let height = sampleSize
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context else { return nil }
        context.interpolationQuality = .low
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )

        let stepX = max(1, width / 14)
        let stepY = max(1, height / 14)
        var weightedRed = 0.0
        var weightedGreen = 0.0
        var weightedBlue = 0.0
        var totalWeight = 0.0

        for y in stride(from: 0, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX) {
                let offset = (y * width + x) * 4
                let alpha = Double(data[offset + 3]) / 255
                guard alpha >= 0.35 else { continue }
                let rgb = ClassicRGB(
                    red: Double(data[offset]) / 255,
                    green: Double(data[offset + 1]) / 255,
                    blue: Double(data[offset + 2]) / 255
                )
                let hsv = ClassicRGBMath.hsv(rgb)
                guard hsv.value >= 0.08 else { continue }
                let weight = alpha
                    * (0.35 + hsv.saturation * 1.65)
                    * (0.50 + hsv.value)
                weightedRed += rgb.red * weight
                weightedGreen += rgb.green * weight
                weightedBlue += rgb.blue * weight
                totalWeight += weight
            }
        }
        guard totalWeight > 0 else { return nil }
        return ClassicRGB(
            red: weightedRed / totalWeight,
            green: weightedGreen / totalWeight,
            blue: weightedBlue / totalWeight
        )
    }
}
