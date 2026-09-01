import Foundation

/// Bridges the parity settings tree to durable tvOS storage.
///
/// Every change is applied to the in-memory `NuvioSettingsState` (which
/// enforces the Android clamps via `apply`) and persisted under a
/// per-setting defaults key, so the tree survives relaunches. The home
/// layout selection additionally mirrors to the live layout key consumed by
/// `CatalogView`, making the layout picker the single source of truth on
/// both sides.
@MainActor
final class NuvioSettingsStore: ObservableObject {
    @Published private(set) var state = NuvioSettingsState()

    private let defaults: UserDefaults
    private let keyPrefix = "nuvio.tv.settings.v2."
    /// The key `CatalogView` reads for the live home layout switch.
    static let homeLayoutLiveKey = "nuvio.tv.home.layout.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        replayPersistedChanges()
    }

    /// Applies a change from any parity settings row.
    func handle(_ change: NuvioSettingsChange) {
        guard encode(change.value) != nil else { return }
        state.apply(change)
        persist(change)
        mirrorLiveKeys(change)
    }

    // MARK: - Persistence

    private func persist(_ change: NuvioSettingsChange) {
        guard let encoded = encode(change.value) else { return }
        defaults.set(encoded, forKey: keyPrefix + change.settingID)
    }

    private func replayPersistedChanges() {
        let dictionary = defaults.dictionaryRepresentation()
        let entries = dictionary
            .compactMap { key, value -> (String, String)? in
                guard key.hasPrefix(keyPrefix), let raw = value as? String else { return nil }
                return (String(key.dropFirst(keyPrefix.count)), raw)
            }
            .sorted { $0.0 < $1.0 }
        for (settingID, raw) in entries {
            guard let value = decode(raw) else { continue }
            state.apply(NuvioSettingsChange(settingID: settingID, value: value))
        }
    }

    /// Settings whose changes other live components read directly.
    private func mirrorLiveKeys(_ change: NuvioSettingsChange) {
        guard change.settingID == "layout.homeLayout",
              case .option(let raw) = change.value else { return }
        defaults.set(raw.lowercased(), forKey: Self.homeLayoutLiveKey)
    }

    // MARK: - Value encoding

    private func encode(_ value: NuvioSettingValue) -> String? {
        switch value {
        case .toggle(let on): return on ? "t:1" : "t:0"
        case .option(let id): return "o:\(id)"
        case .number(let number): return "n:\(number)"
        case .text(let text): return "s:\(text)"
        case .action: return nil
        }
    }

    private func decode(_ raw: String) -> NuvioSettingValue? {
        guard raw.count >= 2, raw.dropFirst(1).first == ":" else { return nil }
        let payload = String(raw.dropFirst(2))
        switch raw.prefix(1) {
        case "t" where payload == "1": return .toggle(true)
        case "t" where payload == "0": return .toggle(false)
        case "o": return .option(payload)
        case "n": return Double(payload).map { .number($0) }
        case "s": return .text(payload)
        default: return nil
        }
    }
}
