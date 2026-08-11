import Foundation
import Libmpv

extension MPVPlayerController {
    func applyRequestHeaders(_ headers: [String: String]) {
        guard let mpv else { return }
        let clean = headers.compactMap { key, value -> String? in
            let name = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !content.isEmpty,
                  !name.contains("\n"), !name.contains("\r"),
                  !content.contains("\n"), !content.contains("\r") else { return nil }
            return "\(name): \(content)"
        }
        mpv_set_property_string(mpv, "http-header-fields", clean.joined(separator: ","))
    }
}
