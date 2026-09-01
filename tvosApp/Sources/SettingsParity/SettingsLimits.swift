import Foundation

/// Limits and clamps ported from `PlayerSettingsDataStore.kt`, `BufferSettings`,
/// and `MemoryBudget.kt`. Pure functions so tests can drive edge cases.
public enum NuvioSettingsLimits {
    // Still watching
    public static let minStillWatchingThreshold = 2
    public static let maxStillWatchingThreshold = 6

    // Post-play movie threshold
    public static let minPostPlayMovieThresholdPercent = 80
    public static let maxPostPlayMovieThresholdPercent = 100

    // Stream autoplay timeout
    public static let streamAutoPlayTimeoutUnlimited = Int.max
    public static let streamAutoPlayTimeoutValues: [Int] =
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, streamAutoPlayTimeoutUnlimited]

    // Next-episode thresholds (slider doubles half steps: 194...200 over 2)
    public static let nextEpisodeThresholdPercentRange = 97.0...100.0
    public static let nextEpisodeThresholdMinutesRange = 0.0...3.5
    public static let nextEpisodeThresholdStep = 0.5

    // Buffers (seconds)
    public static let minBufferSeconds = 5
    public static let maxBufferSecondsStandard = 120
    public static let maxBufferSecondsPerformance = 1200
    public static let bufferDurationStepStandard = 5
    public static let bufferDurationStepPerformance = 10
    public static let bufferForPlaybackRange = 1...60
    public static let bufferAfterRebufferRange = 1...120
    public static let backBufferRange = 0...120
    public static let backBufferStep = 5

    // Target buffer memory budget (MemoryBudget.kt)
    public static let minBufferMb = 25
    public static let maxBufferMb = 4096
    public static let bufferStepMb = 25
    public static let largeTargetBufferMaxMb = 2048
    public static let defaultTargetBufferSizeMb = 150
    public static let minConnections = 2
    public static let maxConnections = 4
    public static let maxConnectionsPerformance = 16
    public static let minChunkMb = 8
    public static let maxChunkMb = 128

    // VOD disk cache
    public static let minVodCacheSizeMb = 100
    public static let maxVodCacheSizeMb = 65_536
    public static let vodCacheStepMb = 50
    public static let vodCacheFreeSpaceReserveMb = 2048

    // Subtitle style
    public static let subtitleSizeRange = 50...200
    public static let subtitleSizeStep = 10
    public static let subtitleVerticalOffsetRange = -20...50

    // Parallel chunk sizes (kb) from PlaybackBufferNetworkSettings.kt
    public static let parallelChunkSizeOptionsKb: [(kb: Int, label: String)] = [
        (256, "256 KB"), (512, "512 KB"), (1024, "1 MB"), (2048, "2 MB"),
        (4096, "4 MB"), (8192, "8 MB"), (16384, "16 MB"), (24576, "24 MB"),
        (32768, "32 MB"), (49152, "48 MB"), (65536, "64 MB"),
        (98304, "96 MB"), (131072, "128 MB"),
    ]

    // Reuse-last-link cache durations (hours)
    public static let reuseLastLinkCacheHourOptions: [Int] = [1, 2, 3, 6, 12, 24, 48, 72, 168]

    /// `applyLegacyTimeoutSentinelMigration`: 11 is a legacy unlimited sentinel;
    /// values outside the list snap to the nearest bounded option.
    public static func normalizedAutoPlayTimeout(_ raw: Int) -> Int {
        if raw == 11 { return streamAutoPlayTimeoutUnlimited }
        if streamAutoPlayTimeoutValues.contains(raw) { return raw }
        let bounded = streamAutoPlayTimeoutValues.filter { $0 != streamAutoPlayTimeoutUnlimited }
        return bounded.min { abs($0 - raw) < abs($1 - raw) } ?? 0
    }

    /// `isBoundedTimeout`
    public static func isBoundedTimeout(_ seconds: Int) -> Bool {
        seconds > 0 && seconds != streamAutoPlayTimeoutUnlimited
    }

    /// `formatReuseCacheDuration`
    public static func reuseCacheDurationText(hours: Int) -> String {
        if hours < 24 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        if hours % 24 == 0 {
            let days = hours / 24
            return days == 1 ? "1 day" : "\(days) days"
        }
        return "\(hours / 24) d \(hours % 24) h"
    }

    /// `MemoryBudget.maxChunkMb`: leftover budget per concurrent chunk buffer.
    public static func maxChunkMb(bufferMb: Int, connections: Int, maxHeapMb: Int) -> Int {
        let budget = NuvioMemoryBudget.budgetMb(maxHeapMb: maxHeapMb)
        let perBuffer = (budget - bufferMb) / (connections + 2)
        let tierMax = NuvioMemoryBudget.isLowRamTier(maxHeapMb: maxHeapMb) ? 16 : maxChunkMb
        return Swift.min(Swift.max(perBuffer, minChunkMb), tierMax)
    }

    /// `MemoryBudget.maxBufferMb`: budget minus parallel overhead, snapped to steps.
    public static func maxBufferMb(parallelOverheadMb: Int, maxHeapMb: Int) -> Int {
        let budget = NuvioMemoryBudget.budgetMb(maxHeapMb: maxHeapMb)
        let stepped = (budget - parallelOverheadMb) / bufferStepMb * bufferStepMb
        return Swift.min(Swift.max(stepped, minBufferMb), maxBufferMb)
    }

    /// `MemoryBudget.parallelOverheadMb`
    public static func parallelOverheadMb(connections: Int, chunkSizeMb: Int) -> Int {
        (connections + 2) * chunkSizeMb
    }

    /// Chunk options filtered by the current tier cap (`chunkSizes.filter { it.first <= maxChunkSizeMb * 1024 }`).
    public static func chunkSizeOptions(maxChunkMb: Int) -> [NuvioSettingOption] {
        let capKb = maxChunkMb * 1024
        return parallelChunkSizeOptionsKb
            .filter { $0.kb <= capKb }
            .map { NuvioSettingOption(id: String($0.kb), title: $0.label) }
    }

    /// Manual VOD cache maximum for a given free disk space
    /// (`resolveManualVodCacheMaxMb`).
    public static func maxManualVodCacheMb(freeDiskBytes: Int64) -> Int {
        let freeDiskMb = Swift.max(freeDiskBytes, 0) / (1024 * 1024)
        let dynamicMaxMb: Int64
        if freeDiskMb > Int64(vodCacheFreeSpaceReserveMb) {
            dynamicMaxMb = freeDiskMb - Int64(vodCacheFreeSpaceReserveMb)
        } else {
            dynamicMaxMb = (freeDiskMb * 8) / 10
        }
        let bounded = min(
            Int64(maxVodCacheSizeMb),
            Swift.max(dynamicMaxMb, Int64(minVodCacheSizeMb))
        )
        return Int(bounded)
    }

    /// Display duration for the timeout slider (`autoplay_timeout_instant/unlimited`).
    public static func autoPlayTimeoutText(_ seconds: Int) -> String {
        switch seconds {
        case 0: return "Instant"
        case streamAutoPlayTimeoutUnlimited: return "Unlimited"
        default: return "\(seconds)s"
        }
    }

    /// `formatHalfStepValue`: whole values show as integers, half steps as `.5`.
    public static func halfStepText(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

/// Heap-tiered memory budget, ported from `MemoryBudget.kt`.
public enum NuvioMemoryBudget {
    public static let lowHeapRatio = 0.65
    public static let highHeapRatio = 0.85
    public static let highHeapThresholdMb = 512
    public static let lowHeapReserveMb = 210
    public static let defaultTargetBufferSizeMb = NuvioSettingsLimits.defaultTargetBufferSizeMb

    public static func isLowRamTier(maxHeapMb: Int) -> Bool {
        maxHeapMb < highHeapThresholdMb
    }

    /// Pre-cap ratio budget (`rawBudgetMb`).
    public static func rawBudgetMb(maxHeapMb: Int) -> Int {
        Int(Double(maxHeapMb) * (isLowRamTier(maxHeapMb: maxHeapMb) ? lowHeapRatio : highHeapRatio))
    }

    /// `budgetMb`: low-RAM tiers reserve UI/decoder headroom before the buffer.
    public static func budgetMb(maxHeapMb: Int) -> Int {
        let raw = rawBudgetMb(maxHeapMb: maxHeapMb)
        guard isLowRamTier(maxHeapMb: maxHeapMb) else { return raw }
        let capped = min(raw, maxHeapMb - lowHeapReserveMb)
        return Swift.max(capped, NuvioSettingsLimits.minBufferMb)
    }

    /// DV7 conversion headroom: a third of the raw budget on low-RAM, half on high-RAM.
    public static func conversionBudgetMb(maxHeapMb: Int) -> Int {
        let raw = rawBudgetMb(maxHeapMb: maxHeapMb)
        let slice = isLowRamTier(maxHeapMb: maxHeapMb) ? raw / 3 : raw / 2
        return Swift.min(Swift.max(slice, NuvioSettingsLimits.minBufferMb), budgetMb(maxHeapMb: maxHeapMb))
    }

    /// `effectiveBufferMb`: zero means "use the default".
    public static func effectiveBufferMb(storedMb: Int) -> Int {
        storedMb > 0 ? storedMb : defaultTargetBufferSizeMb
    }

    /// `maxBufferMbWithOverride`: slider max for the target buffer.
    public static func maxBufferMbWithOverride(
        parallelOverheadMb: Int,
        allowLargeTargetBuffer: Bool,
        maxHeapMb: Int
    ) -> Int {
        let safeMax = NuvioSettingsLimits.maxBufferMb(
            parallelOverheadMb: parallelOverheadMb,
            maxHeapMb: maxHeapMb
        )
        if allowLargeTargetBuffer {
            return Swift.min(Swift.max(NuvioSettingsLimits.largeTargetBufferMaxMb, safeMax), NuvioSettingsLimits.maxBufferMb)
        }
        return safeMax
    }
}
