import Foundation

/// Network category sections, mirroring `NetworkSettingsScreen.kt`.
public extension NuvioSettingsTree {
    // MARK: - Network (NetworkSettingsScreen.kt)

    static func networkSections(_ state: NuvioSettingsState) -> [NuvioSettingsSection] {
        let connectionText: String
        switch state.connectionType {
        case .wifi: connectionText = "Wi-Fi"
        case .ethernet: connectionText = "Ethernet"
        case .offline: connectionText = "Offline"
        }
        var connectionSettings: [NuvioSetting] = [
            NuvioSetting(
                id: "network.connectionStatus",
                title: "Connection",
                subtitle: "Active network interface",
                systemImage: state.connectionType == .offline ? "wifi.slash" : "wifi",
                kind: .info,
                value: .text(connectionText),
                valueText: connectionText
            ),
            NuvioSetting(
                id: "network.speedTest",
                title: "Speed test",
                subtitle: "Measure latency and download throughput",
                systemImage: "speedometer",
                kind: .action,
                value: .action,
                valueText: speedTestValueText(state.networkTestState)
            ),
        ]
        if state.latencyMs != nil || state.downloadMbps != nil {
            if let latency = state.latencyMs {
                connectionSettings.append(NuvioSetting(
                    id: "network.speedTestLatency",
                    title: "Latency",
                    systemImage: "timer",
                    kind: .info,
                    value: .text("\(latency) ms"),
                    valueText: "\(latency) ms"
                ))
            }
            if let download = state.downloadMbps {
                connectionSettings.append(NuvioSetting(
                    id: "network.speedTestDownload",
                    title: "Download",
                    systemImage: "arrow.down.circle",
                    kind: .info,
                    value: .text(String(format: "%.1f Mbps", download)),
                    valueText: String(format: "%.1f Mbps", download)
                ))
            }
        }
        connectionSettings.append(NuvioSetting(
            id: "network.streamSpeedTest",
            title: "Stream speed test",
            subtitle: "Measure throughput against Nuvio stream hosts",
            systemImage: "dot.radiowaves.left.and.right",
            kind: .action,
            value: .action,
            valueText: speedTestValueText(state.streamTestState)
        ))
        if let latency = state.streamLatencyMs {
            connectionSettings.append(NuvioSetting(
                id: "network.streamSpeedTestLatency",
                title: "Stream latency",
                systemImage: "timer",
                kind: .info,
                value: .text("\(latency) ms"),
                valueText: "\(latency) ms"
            ))
        }
        if let download = state.streamDownloadMbps {
            connectionSettings.append(NuvioSetting(
                id: "network.streamSpeedTestDownload",
                title: "Stream download",
                systemImage: "arrow.down.circle",
                kind: .info,
                value: .text(String(format: "%.1f Mbps", download)),
                valueText: String(format: "%.1f Mbps", download)
            ))
        }
        connectionSettings.append(NuvioSetting(
            id: "network.clearContinueWatchingCache",
            title: "Clear Continue Watching cache",
            subtitle: "Removes locally cached progress enrichment data",
            systemImage: "trash",
            kind: .action,
            value: .action
        ))
        return [
            NuvioSettingsSection(
                id: "network.connection",
                category: .network,
                title: "Connection",
                subtitle: "Status and speed tests",
                settings: connectionSettings
            ),
            NuvioSettingsSection(
                id: "network.performance",
                category: .network,
                title: "Performance",
                subtitle: "Navigation and startup behavior",
                settings: [
                    NuvioSetting(
                        id: "network.fastHorizontalNavigation",
                        title: "Fast horizontal navigation",
                        subtitle: "Move across rows without pausing on every card",
                        systemImage: "arrow.left.arrow.right",
                        kind: .toggle,
                        value: .toggle(state.fastHorizontalNavigationEnabled)
                    ),
                    NuvioSetting(
                        id: "network.nuvioFocusScroll",
                        title: "Nuvio focus scroll",
                        subtitle: "Scroll the focused row instead of the grid",
                        systemImage: "scroll",
                        kind: .toggle,
                        value: .toggle(state.nuvioFocusScrollEnabled)
                    ),
                    NuvioSetting(
                        id: "network.rememberLastProfile",
                        title: "Remember last profile",
                        subtitle: "Open the last used profile on launch",
                        systemImage: "person.crop.circle",
                        kind: .toggle,
                        value: .toggle(state.rememberLastProfileEnabled)
                    ),
                    NuvioSetting(
                        id: "network.confirmExit",
                        title: "Confirm exit",
                        subtitle: "Ask before leaving the app from the home screen",
                        systemImage: "exclamationmark.circle",
                        kind: .toggle,
                        value: .toggle(state.confirmExitEnabled)
                    ),
                ]
            ),
        ]
    }

    static func speedTestValueText(_ testState: NuvioNetworkTestState) -> String? {
        switch testState {
        case .idle: return nil
        case .testingLatency: return "Testing latency…"
        case .testingDownload: return "Testing download…"
        case .done: return "Done"
        case .error: return "Failed"
        }
    }
}
