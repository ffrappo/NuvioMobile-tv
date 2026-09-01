import Foundation

/// Mirrors the fields of Android `LastPlaybackDiagnostics` used by
/// `DiagnosticsCard.kt`. The integration layer copies values in from its player.
public struct NuvioPlaybackDiagnostics: Equatable, Sendable {
    public var timestampMs: Int64 = 0
    public var host: String = ""
    public var deviceName: String = ""
    public var hdrCapsKnown = false
    public var displayDv = false
    public var displayHdr10Plus = false
    public var displayHdr10 = false
    public var codecDv7Supported = false
    public var dv81DecoderName: String?
    public var bridgeReady = false
    public var bridgeVersion: String?
    public var bridgeReason: String?
    public var dv7ModeRequested: String = ""
    public var dv7ModeEffective: String = ""
    public var dv7AutoDecision: String = ""
    public var dvSourceProfile: String?
    public var dv7DoviSuccess = 0
    public var dv7DoviCalls = 0
    public var dv7DoviSignalRewrites = 0
    public var videoHdrType: String?
    public var bufferEngineEnabled = false
    public var parallelNetworkEnabled = false
    public var firstFrameMs = -1
    public var rebufferCount = 0
    public var rebufferTotalMs = 0
    public var result = ""

    public init() {}

    /// True when the last playback actually involved Dolby Vision content
    /// (`dvContentPlayed` in DiagnosticsCard.kt). The requested mode alone is
    /// not enough because AUTO is the default.
    public var dvContentPlayed: Bool {
        dvSourceProfile != nil
            || dv7DoviSuccess > 0
            || dv7DoviSignalRewrites > 0
            || (videoHdrType?.localizedCaseInsensitiveContains("Dolby Vision") == true)
    }

    /// True when DV conversion actually engaged for the last playback.
    public func dvEngaged(dvCurrentlyEnabled: Bool) -> Bool {
        dvCurrentlyEnabled
            && !dv7ModeRequested.isBlank
            && dv7ModeRequested != "OFF"
            && dvContentPlayed
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespaces).isEmpty }
}

/// Tone of a diagnostics row, mirroring the `valueColor` logic in
/// `DiagnosticsCard.kt`.
public enum NuvioDiagnosticTone: Equatable, Sendable {
    case normal
    case success
    case error
}

/// One `DiagnosticRow(label, value)` from `DiagnosticsCard.kt`.
public struct NuvioDiagnosticRow: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let value: String
    public let tone: NuvioDiagnosticTone

    public init(id: String, label: String, value: String, tone: NuvioDiagnosticTone = .normal) {
        self.id = id
        self.label = label
        self.value = value
        self.tone = tone
    }
}

/// One of the three dense diagnostics cards (input, decision, outcome).
public struct NuvioDiagnosticsCard: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let rows: [NuvioDiagnosticRow]

    public init(id: String, title: String, subtitle: String? = nil, rows: [NuvioDiagnosticRow]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.rows = rows
    }
}

/// Builds the diagnostics cards from `DiagnosticsCard.kt`: an empty-state card
/// when there is no data, otherwise the input / decision / outcome trio with
/// DV rows gated on real engagement.
public enum NuvioDiagnosticsBuilder {
    public static func cards(
        diagnostics: NuvioPlaybackDiagnostics,
        dvCurrentlyEnabled: Bool = true
    ) -> [NuvioDiagnosticsCard] {
        if diagnostics.timestampMs == 0 || diagnostics.host.trimmingCharacters(in: .whitespaces).isEmpty {
            return [
                NuvioDiagnosticsCard(
                    id: "diagnostics_empty",
                    title: "Last playback",
                    subtitle: nil,
                    rows: [
                        NuvioDiagnosticRow(
                            id: "diagnostics_empty.noData",
                            label: "No data",
                            value: "Play something to collect diagnostics"
                        ),
                    ]
                ),
            ]
        }

        let engaged = diagnostics.dvEngaged(dvCurrentlyEnabled: dvCurrentlyEnabled)
        func dv(_ value: String?) -> String {
            if engaged, let value, !value.trimmingCharacters(in: .whitespaces).isEmpty {
                return value
            }
            return "-"
        }

        let input = NuvioDiagnosticsCard(
            id: "diagnostics_input",
            title: "Source & hardware",
            subtitle: "Where the stream came from and how it was decoded",
            rows: [
                NuvioDiagnosticRow(id: "input.host", label: "Host", value: diagnostics.host),
                NuvioDiagnosticRow(
                    id: "input.when",
                    label: "When",
                    value: formatTimestamp(diagnostics.timestampMs)
                ),
                NuvioDiagnosticRow(
                    id: "input.device",
                    label: "Device",
                    value: diagnostics.deviceName
                ),
                NuvioDiagnosticRow(
                    id: "input.display",
                    label: "Display",
                    value: dv(displayCaps(diagnostics))
                ),
                NuvioDiagnosticRow(
                    id: "input.dv7Decoder",
                    label: "DV7 decoder",
                    value: dv(diagnostics.codecDv7Supported ? "Available" : "Not available")
                ),
                NuvioDiagnosticRow(
                    id: "input.dvDecoder",
                    label: "DV decoder",
                    value: dv(
                        diagnostics.dv81DecoderName
                            ?? (diagnostics.codecDv7Supported ? "Hidden by system" : "None")
                    )
                ),
                NuvioDiagnosticRow(
                    id: "input.dvBridge",
                    label: "DV bridge",
                    value: dv(diagnostics.bridgeReady ? "Ready" : "Not ready")
                ),
                NuvioDiagnosticRow(
                    id: "input.bridgeVersion",
                    label: "Bridge version",
                    value: dv(diagnostics.bridgeVersion)
                ),
                NuvioDiagnosticRow(
                    id: "input.bridgeReason",
                    label: "Bridge reason",
                    value: dv(diagnostics.bridgeReason)
                ),
            ]
        )

        var decisionRows: [NuvioDiagnosticRow] = [
            NuvioDiagnosticRow(
                id: "decision.dvModeRequested",
                label: "DV mode requested",
                value: dv(diagnostics.dv7ModeRequested)
            ),
        ]
        if engaged && diagnostics.dv7ModeRequested != diagnostics.dv7ModeEffective {
            decisionRows.append(NuvioDiagnosticRow(
                id: "decision.dvModeEffective",
                label: "DV mode effective",
                value: dv(diagnostics.dv7ModeEffective)
            ))
        }
        decisionRows.append(NuvioDiagnosticRow(
            id: "decision.autoDecision",
            label: "Auto decision",
            value: dv(diagnostics.dv7AutoDecision)
        ))
        decisionRows.append(NuvioDiagnosticRow(
            id: "decision.sourceProfile",
            label: "Source profile",
            value: dv(diagnostics.dvSourceProfile)
        ))
        if engaged && diagnostics.dv7DoviCalls > 0 {
            decisionRows.append(NuvioDiagnosticRow(
                id: "decision.conversions",
                label: "Conversions",
                value: "\(diagnostics.dv7DoviSuccess) of \(diagnostics.dv7DoviCalls)"
            ))
        }
        if engaged && diagnostics.dv7DoviSignalRewrites > 0 {
            decisionRows.append(NuvioDiagnosticRow(
                id: "decision.signalRewrites",
                label: "Signal rewrites",
                value: String(diagnostics.dv7DoviSignalRewrites)
            ))
        }
        decisionRows.append(NuvioDiagnosticRow(
            id: "decision.customBuffers",
            label: "Custom buffers",
            value: diagnostics.bufferEngineEnabled ? "On" : "Off"
        ))
        decisionRows.append(NuvioDiagnosticRow(
            id: "decision.customNetworkCache",
            label: "Custom network cache",
            value: diagnostics.parallelNetworkEnabled ? "On" : "Off"
        ))
        let decision = NuvioDiagnosticsCard(
            id: "diagnostics_decision",
            title: "Decision & settings",
            subtitle: "Configured and effective behavior",
            rows: decisionRows
        )

        let outcome = NuvioDiagnosticsCard(
            id: "diagnostics_outcome",
            title: "Outcome",
            subtitle: nil,
            rows: [
                NuvioDiagnosticRow(
                    id: "outcome.hdrFormat",
                    label: "HDR format (intended)",
                    value: nonBlank(diagnostics.videoHdrType) ?? "-"
                ),
                NuvioDiagnosticRow(
                    id: "outcome.firstFrame",
                    label: "First frame",
                    value: diagnostics.firstFrameMs >= 0
                        ? "\(diagnostics.firstFrameMs) ms"
                        : "Never rendered"
                ),
                NuvioDiagnosticRow(
                    id: "outcome.rebuffers",
                    label: "Rebuffers",
                    value: diagnostics.rebufferCount > 0
                        ? "\(diagnostics.rebufferCount) (\(diagnostics.rebufferTotalMs) ms)"
                        : "0"
                ),
                NuvioDiagnosticRow(
                    id: "outcome.result",
                    label: "Result",
                    value: diagnostics.result,
                    tone: resultTone(diagnostics.result)
                ),
            ]
        )
        return [input, decision, outcome]
    }

    /// `valueColor` in DiagnosticsCard.kt: errors red, "Played" green.
    public static func resultTone(_ result: String) -> NuvioDiagnosticTone {
        if result.localizedCaseInsensitiveContains("error") { return .error }
        if result == "Played" { return .success }
        return .normal
    }

    static func displayCaps(_ diagnostics: NuvioPlaybackDiagnostics) -> String? {
        guard diagnostics.hdrCapsKnown else { return "Unknown" }
        if diagnostics.displayDv { return "DV" }
        if diagnostics.displayHdr10Plus { return "HDR10+" }
        if diagnostics.displayHdr10 { return "HDR10" }
        return "SDR"
    }

    static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }

    /// `formatTimestamp` uses "yyyy-MM-dd HH:mm:ss".
    public static func formatTimestamp(_ ms: Int64) -> String {
        guard ms > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
