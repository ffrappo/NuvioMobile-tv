import Foundation

/// Buffer & Network section, mirroring `PlaybackBufferNetworkSettings.kt`.
public enum NuvioBufferTree {
    static func bufferNetworkSection(_ state: NuvioSettingsState) -> NuvioSettingsSection {
        var settings: [NuvioSetting] = [
            NuvioSetting(
                id: "playback.nuvioPerformanceMode",
                title: "Nuvio performance mode",
                subtitle: "Larger buffers backed by native memory",
                systemImage: "hare",
                kind: .toggle,
                value: .toggle(state.nuvioPerformanceModeEnabled)
            ),
            NuvioSetting(
                id: "playback.bufferEngine",
                title: "Custom buffers",
                subtitle: "Override the default buffering strategy",
                systemImage: "tuningfork",
                kind: .toggle,
                value: .toggle(state.bufferEngineEnabled)
            ),
        ]
        if state.bufferEngineEnabled {
            settings.append(contentsOf: bufferRows(state))
        }
        if state.bufferEngineEnabled || state.nuvioPerformanceModeEnabled {
            settings.append(contentsOf: vodCacheRows(state))
        }
        settings.append(NuvioSetting(
            id: "playback.parallelNetwork",
            title: "Custom network",
            subtitle: "Parallel and tunneled connections",
            systemImage: "hub",
            kind: .toggle,
            value: .toggle(state.parallelNetworkEnabled)
        ))
        if state.parallelNetworkEnabled {
            settings.append(NuvioSetting(
                id: "playback.http2",
                title: "HTTP/2",
                subtitle: "Multiplex requests over one connection",
                systemImage: "bolt.horizontal",
                kind: .toggle,
                value: .toggle(state.enableHttp2)
            ))
            settings.append(NuvioSetting(
                id: "playback.parallelConnections",
                title: "Parallel connections",
                subtitle: "Download stream chunks concurrently",
                systemImage: "arrow.triangle.branch",
                kind: .toggle,
                value: .toggle(state.useParallelConnections)
            ))
            if state.useParallelConnections {
                let maxCount = state.nuvioPerformanceModeEnabled
                    ? NuvioSettingsLimits.maxConnectionsPerformance
                    : NuvioSettingsLimits.maxConnections
                settings.append(NuvioSetting(
                    id: "playback.parallelConnectionCount",
                    title: "Connection count",
                    subtitle: "Concurrent chunk downloads",
                    systemImage: "number",
                    kind: .slider(NuvioSliderSpec(
                        minimum: Double(NuvioSettingsLimits.minConnections),
                        maximum: Double(maxCount),
                        step: 1
                    )),
                    value: .number(Double(state.parallelConnectionCount)),
                    valueText: String(state.parallelConnectionCount)
                ))
                let maxChunkMb = NuvioSettingsLimits.maxChunkMb(
                    bufferMb: NuvioMemoryBudget.effectiveBufferMb(storedMb: state.targetBufferSizeMb),
                    connections: state.parallelConnectionCount,
                    maxHeapMb: state.deviceMaxHeapMb
                )
                settings.append(NuvioSetting(
                    id: "playback.parallelChunkSizeKb",
                    title: "Chunk size",
                    subtitle: "Bytes fetched per connection request",
                    systemImage: "square.split.bottomrightquarter",
                    kind: .optionPicker(
                        NuvioSettingsLimits.chunkSizeOptions(maxChunkMb: maxChunkMb)
                    ),
                    value: .option(String(state.parallelChunkSizeKb)),
                    valueText: chunkSizeLabel(state.parallelChunkSizeKb)
                ))
            }
        }
        return NuvioSettingsSection(
            id: "playback.bufferNetwork",
            category: .playback,
            title: "Buffer & Network",
            subtitle: "Memory budget, disk cache, and connections",
            settings: settings
        )
    }

    static func bufferRows(_ state: NuvioSettingsState) -> [NuvioSetting] {
        let maxDuration = Double(
            state.nuvioPerformanceModeEnabled
                ? NuvioSettingsLimits.maxBufferSecondsPerformance
                : NuvioSettingsLimits.maxBufferSecondsStandard
        )
        let step = Double(
            state.nuvioPerformanceModeEnabled
                ? NuvioSettingsLimits.bufferDurationStepPerformance
                : NuvioSettingsLimits.bufferDurationStepStandard
        )
        let overhead = state.parallelNetworkEnabled && state.useParallelConnections
            ? NuvioSettingsLimits.parallelOverheadMb(
                connections: state.parallelConnectionCount,
                chunkSizeMb: (state.parallelChunkSizeKb + 1023) / 1024
            )
            : 0
        let maxTargetMb = NuvioMemoryBudget.maxBufferMbWithOverride(
            parallelOverheadMb: overhead,
            allowLargeTargetBuffer: state.allowLargeTargetBuffer,
            maxHeapMb: state.deviceMaxHeapMb
        )
        let targetMb = NuvioMemoryBudget.effectiveBufferMb(storedMb: state.targetBufferSizeMb)
        return [
            NuvioSetting(
                id: "playback.bufferMin",
                title: "Minimum buffer",
                subtitle: "Buffer maintained while playing",
                systemImage: "speedometer",
                kind: .slider(NuvioSliderSpec(
                    minimum: Double(NuvioSettingsLimits.minBufferSeconds),
                    maximum: maxDuration,
                    step: step
                )),
                value: .number(Double(state.minBufferSeconds)),
                valueText: "\(state.minBufferSeconds)s"
            ),
            NuvioSetting(
                id: "playback.bufferMax",
                title: "Maximum buffer",
                subtitle: "Buffer filled while paused or seeking",
                systemImage: "speedometer",
                kind: .slider(NuvioSliderSpec(
                    minimum: Double(NuvioSettingsLimits.minBufferSeconds),
                    maximum: maxDuration,
                    step: step
                )),
                value: .number(Double(state.maxBufferSeconds)),
                valueText: state.maxBufferSeconds == state.minBufferSeconds
                    ? "Same as minimum (\(state.maxBufferSeconds)s)"
                    : "\(state.maxBufferSeconds)s"
            ),
            NuvioSetting(
                id: "playback.bufferInitial",
                title: "Initial buffer",
                subtitle: "Buffer required before playback starts",
                systemImage: "play.fill",
                kind: .slider(NuvioSliderSpec(
                    minimum: Double(NuvioSettingsLimits.bufferForPlaybackRange.lowerBound),
                    maximum: Double(NuvioSettingsLimits.bufferForPlaybackRange.upperBound),
                    step: 1
                )),
                value: .number(Double(state.bufferForPlaybackSeconds)),
                valueText: "\(state.bufferForPlaybackSeconds)s"
            ),
            NuvioSetting(
                id: "playback.bufferAfterRebuffer",
                title: "Buffer after rebuffer",
                subtitle: "Buffer required before resuming playback",
                systemImage: "arrow.clockwise",
                kind: .slider(NuvioSliderSpec(
                    minimum: Double(NuvioSettingsLimits.bufferAfterRebufferRange.lowerBound),
                    maximum: Double(NuvioSettingsLimits.bufferAfterRebufferRange.upperBound),
                    step: 1
                )),
                value: .number(Double(state.bufferForPlaybackAfterRebufferSeconds)),
                valueText: "\(state.bufferForPlaybackAfterRebufferSeconds)s"
            ),
            NuvioSetting(
                id: "playback.bufferBack",
                title: "Back buffer",
                subtitle: "Seek-back window kept in memory",
                systemImage: "clock.arrow.circlepath",
                kind: .slider(NuvioSliderSpec(
                    minimum: Double(NuvioSettingsLimits.backBufferRange.lowerBound),
                    maximum: Double(NuvioSettingsLimits.backBufferRange.upperBound),
                    step: Double(NuvioSettingsLimits.backBufferStep)
                )),
                value: .number(Double(state.backBufferSeconds)),
                valueText: "\(state.backBufferSeconds)s"
            ),
            NuvioSetting(
                id: "playback.bufferBudgetManaged",
                title: "Managed buffer budget",
                subtitle: "Let the device memory budget cap the buffer",
                systemImage: "gauge.with.dots.needle.50percent",
                kind: .toggle,
                value: .toggle(state.bufferBudgetManaged)
            ),
            NuvioSetting(
                id: "playback.bufferTargetSizeMb",
                title: "Target buffer size",
                subtitle: "Memory reserved for the buffer",
                systemImage: "internaldrive",
                kind: .slider(NuvioSliderSpec(
                    minimum: Double(NuvioSettingsLimits.minBufferMb),
                    maximum: Double(maxTargetMb),
                    step: Double(NuvioSettingsLimits.bufferStepMb)
                )),
                value: .number(Double(targetMb)),
                valueText: "\(targetMb) MB",
                isEnabled: !state.bufferBudgetManaged
            ),
            NuvioSetting(
                id: "playback.bufferAllowLarge",
                title: "Allow large target buffer",
                subtitle: "Raise the slider cap to 2 GB",
                systemImage: "arrow.up.forward.circle",
                kind: .toggle,
                value: .toggle(state.allowLargeTargetBuffer),
                isEnabled: !state.bufferBudgetManaged
            ),
        ]
    }

    static func vodCacheRows(_ state: NuvioSettingsState) -> [NuvioSetting] {
        var rows: [NuvioSetting] = [
            NuvioSetting(
                id: "playback.vodCacheEnabled",
                title: "VOD disk cache",
                subtitle: "Cache streamed video on disk",
                systemImage: "externaldrive",
                kind: .toggle,
                value: .toggle(state.vodCacheEnabled)
            ),
        ]
        if state.vodCacheEnabled {
            rows.append(NuvioSetting(
                id: "playback.vodCacheAuto",
                title: "Automatic cache size",
                subtitle: "Size the cache from free disk space",
                systemImage: "wand.and.rays",
                kind: .toggle,
                value: .toggle(state.vodCacheSizeMode == .auto)
            ))
            if state.vodCacheSizeMode == .manual {
                rows.append(NuvioSetting(
                    id: "playback.vodCacheSizeMb",
                    title: "Cache size",
                    subtitle: "Manual disk cache size",
                    systemImage: "externaldrive.fill",
                    kind: .slider(NuvioSliderSpec(
                        minimum: Double(NuvioSettingsLimits.minVodCacheSizeMb),
                        maximum: Double(NuvioSettingsLimits.maxVodCacheSizeMb),
                        step: Double(NuvioSettingsLimits.vodCacheStepMb)
                    )),
                    value: .number(Double(state.vodCacheSizeMb)),
                    valueText: "\(state.vodCacheSizeMb) MB"
                ))
            }
        }
        return rows
    }

    static func chunkSizeLabel(_ kb: Int) -> String {
        NuvioSettingsLimits.parallelChunkSizeOptionsKb
            .first { $0.kb == kb }?.label ?? "\(kb / 1024) MB"
    }
}

public extension NuvioSettingsTree {
    /// Full playback category: General, Audio, Subtitles, Autoplay, and
    /// Buffer & Network.
    static func playbackSections(_ state: NuvioSettingsState) -> [NuvioSettingsSection] {
        NuvioPlaybackTree.playbackSections(state)
            + NuvioAutoPlayBufferTree.playbackSections(state)
    }
}

