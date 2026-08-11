import SwiftUI
import UIKit

struct SettingsView: View {
    let entryFocusRequest: Int

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var addons: AddonStore
    @State private var cacheMessage: String?
    @State private var showLogout = false
    @FocusState private var focus: Action?

    private enum Action: Hashable { case clearCache, account, logout }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))
                appCard
                accountCard
                cacheCard
                Text("Playback uses the native Apple TV player for direct HTTP and HTTPS video URLs.")
                    .font(.callout)
                    .foregroundStyle(NuvioTheme.secondaryText)
            }
            .padding(48)
        }
        .defaultFocus($focus, .clearCache)
        .onChange(of: entryFocusRequest) { _, _ in
            focus = auth.signedInEmail == nil ? .account : .logout
        }
        .confirmationDialog("Sign out of Nuvio?", isPresented: $showLogout, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task {
                    addons.clearForLogout()
                    await auth.logout()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Account data and synchronized addons will be removed from this Apple TV.")
        }
    }

    private var appCard: some View {
        HStack(alignment: .top, spacing: 28) {
            Image("NuvioLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            VStack(alignment: .leading, spacing: 12) {
                Text("Nuvio for Apple TV").font(.title.weight(.bold))
                infoRow("Version", value: appVersion)
                infoRow("Device", value: UIDevice.current.model)
                infoRow("System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                infoRow("Architecture", value: architecture)
            }
        }
        .padding(28)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account").font(.title2.weight(.semibold))
            if let email = auth.signedInEmail {
                Label(email.tvSafe, systemImage: "person.crop.circle.badge.checkmark")
                    .font(.title3.weight(.semibold))
                Text(addons.syncMessage ?? "Your account addons are synchronized on this Apple TV.")
                    .foregroundStyle(NuvioTheme.secondaryText)
                NuvioButton(title: "Sign Out", symbol: "rectangle.portrait.and.arrow.right", focused: focus == .logout, destructive: true) {
                    showLogout = true
                }
                .frame(width: 280)
                .focused($focus, equals: .logout)
            } else {
                Text("Guest mode stores library and addons on this Apple TV.")
                    .foregroundStyle(NuvioTheme.secondaryText)
                NuvioButton(title: "Sign In", symbol: "person.crop.circle.badge.checkmark", focused: focus == .account, prominent: true) {
                    auth.showSignIn()
                }
                .frame(width: 280)
                .focused($focus, equals: .account)
            }
        }
        .padding(28)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))
    }

    private var cacheCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Cache").font(.title2.weight(.semibold))
            Text("Clear cached artwork and addon responses. Your library and addon list stay saved.")
                .foregroundStyle(NuvioTheme.secondaryText)
            NuvioButton(title: "Clear Cache", symbol: "trash", focused: focus == .clearCache) {
                URLCache.shared.removeAllCachedResponses()
                cacheMessage = "Cache cleared."
            }
            .frame(width: 280)
            .focused($focus, equals: .clearCache)
            if let cacheMessage { Text(cacheMessage).foregroundStyle(.green) }
        }
        .padding(28)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 22))
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
            Text(label).foregroundStyle(NuvioTheme.secondaryText)
            Text(value.tvSafe).fontWeight(.semibold)
        }
    }
}
