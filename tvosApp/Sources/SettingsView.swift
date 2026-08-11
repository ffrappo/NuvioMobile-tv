import SwiftUI
import UIKit

struct SettingsView: View {
    @State private var cacheMessage: String?
    @FocusState private var clearFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))

                HStack(alignment: .top, spacing: 28) {
                    Image("NuvioLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nuvio for Apple TV")
                            .font(.title.weight(.bold))
                        infoRow("Version", value: appVersion)
                        infoRow("Device", value: UIDevice.current.model)
                        infoRow("System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                        infoRow("Architecture", value: architecture)
                    }
                }
                .padding(28)
                .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 16) {
                    Text("Network Cache")
                        .font(.title2.weight(.semibold))
                    Text("Clear cached artwork and addon responses. Your library and addon list stay saved.")
                        .foregroundStyle(NuvioTheme.secondaryText)
                    Button {
                        URLCache.shared.removeAllCachedResponses()
                        cacheMessage = "Cache cleared."
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .focused($clearFocused)

                    if let cacheMessage {
                        Text(cacheMessage)
                            .foregroundStyle(.green)
                    }
                }
                .padding(28)
                .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))

                Text("Playback uses the native Apple TV player for direct HTTP and HTTPS video URLs.")
                    .font(.callout)
                    .foregroundStyle(NuvioTheme.secondaryText)
            }
            .padding(48)
        }
        .defaultFocus($clearFocused, true)
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var architecture: String {
#if arch(arm64)
        return "arm64"
#elseif arch(x86_64)
        return "x86_64"
#else
        return "Unknown"
#endif
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(NuvioTheme.secondaryText)
            Text(value.tvSafe)
                .fontWeight(.semibold)
        }
    }
}

