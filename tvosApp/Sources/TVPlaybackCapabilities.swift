import Darwin
import Foundation

enum StreamPlaybackCompatibility: Equatable {
    case supported
    case unsupported(String)

    var issue: String? {
        guard case let .unsupported(reason) = self else { return nil }
        return reason
    }
}

struct TVPlaybackCapabilities: Equatable {
    let modelIdentifier: String

    static let current = TVPlaybackCapabilities(modelIdentifier: hardwareIdentifier)

    var isAppleTVHD: Bool {
        modelIdentifier == "AppleTV5,3"
    }

    func compatibility(for info: StreamDisplayInfo) -> StreamPlaybackCompatibility {
        guard isAppleTVHD else { return .supported }
        if info.quality == "4K" || info.hdr != nil {
            return .unsupported("Requires Apple TV 4K")
        }
        if info.codec == "AV1" || info.codec == "VP9" {
            return .unsupported("Requires newer Apple TV hardware")
        }
        return .supported
    }

    func ordered(_ sources: [StreamSource]) -> [StreamSource] {
        sources.enumerated().sorted { first, second in
            let firstRank = rank(first.element)
            let secondRank = rank(second.element)
            return firstRank == secondRank ? first.offset < second.offset : firstRank < secondRank
        }.map(\.element)
    }

    private func rank(_ source: StreamSource) -> Int {
        guard source.stream.directURL != nil else { return 2 }
        return compatibility(for: source.stream.displayInfo).issue == nil ? 0 : 1
    }

    private static var hardwareIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var length = 0
        guard sysctlbyname("hw.machine", nil, &length, nil, 0) == 0, length > 0 else {
            return "unknown"
        }
        var value = [CChar](repeating: 0, count: length)
        guard sysctlbyname("hw.machine", &value, &length, nil, 0) == 0 else {
            return "unknown"
        }
        return String(cString: value)
    }
}
