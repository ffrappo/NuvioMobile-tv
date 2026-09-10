import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.nuvioTheme) private var theme
    @State private var email = ""
    @State private var password = ""
    @State private var showCredentials = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case email, password, signIn, refresh, guest, credentials }

    var body: some View {
        HStack(spacing: 72) {
            brandPanel
            signInPanel
        }
        .padding(70)
        .background(theme.background.ignoresSafeArea())
        .defaultFocus($focus, .refresh)
        .task { if auth.qrSession == nil { await auth.startQRLogin() } }
    }

    private var brandPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 20) {
                Image("NuvioLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                Text("Nuvio").font(.largeTitle.weight(.bold))
            }
            Text("Watch your library anywhere")
                .font(.title.weight(.semibold))
            Text("Sync addons, profiles, your library, and viewing progress across Nuvio devices.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 540, alignment: .leading)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signInPanel: some View {
        NuvioPanel {
            VStack(alignment: .leading, spacing: 20) {
                NuvioPageHeader(
                    title: "Sign In",
                    subtitle: "Scan with your phone for the fastest setup"
                )
                qrRow
                if showCredentials { credentials }
                Divider()
                HStack(spacing: 18) {
                    if !showCredentials {
                        NuvioButton(title: "Email", symbol: "keyboard") {
                            showCredentials = true
                            focus = .email
                        }
                        .accessibilityLabel("Use Email Instead")
                        .focused($focus, equals: .credentials)
                    }
                    NuvioButton(title: "Refresh", symbol: "arrow.clockwise") {
                        Task { await auth.startQRLogin() }
                    }
                    .accessibilityLabel("Refresh Code")
                    .focused($focus, equals: .refresh)
                    NuvioButton(title: "Guest", symbol: "person") {
                        auth.continueAsGuest()
                    }
                    .accessibilityLabel("Continue as Guest")
                    .focused($focus, equals: .guest)
                }
                if let message = auth.message {
                    NuvioStatusMessage(
                        message: message,
                        symbol: isInformational(message) ? "iphone.gen3" : "exclamationmark.triangle.fill",
                        tint: isInformational(message) ? .secondary : .orange
                    )
                }
            }
        }
        .frame(width: 870)
    }

    private var qrRow: some View {
        HStack(spacing: 32) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.white)
                if let image = auth.qrImage {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(14)
                } else {
                    ProgressView().tint(.black)
                }
            }
            .frame(width: 260, height: 260)
            .accessibilityLabel("Nuvio sign-in QR code")

            VStack(alignment: .leading, spacing: 12) {
                Label("Open your phone camera", systemImage: "camera")
                Label("Scan this code", systemImage: "qrcode.viewfinder")
                Label("Approve sign-in", systemImage: "checkmark.circle")
                if let code = auth.qrSession?.code {
                    Text("Code \(code.tvSafe)")
                        .font(.headline.monospaced())
                        .accessibilityLabel("Sign-in code \(code)")
                }
            }
            .font(.headline)
        }
    }

    private var credentials: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Email Sign In").font(.title2.weight(.semibold))
            accountField("Email", text: $email, field: .email, secure: false)
            accountField("Password", text: $password, field: .password, secure: true)
            NuvioButton(
                title: auth.isWorking ? "Signing In" : "Sign In",
                symbol: "person.crop.circle.badge.checkmark",
                prominent: true,
                disabled: email.trimmedNonEmpty == nil || password.isEmpty || auth.isWorking
            ) {
                Task { await auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password) }
            }
            .focused($focus, equals: .signIn)
        }
    }

    @ViewBuilder
    private func accountField(_ title: String, text: Binding<String>, field: Field, secure: Bool) -> some View {
        NuvioInputField(
            title: title,
            prompt: title,
            text: text,
            isSecure: secure,
            icon: secure ? "lock" : "envelope",
            textContentType: secure ? .password : .username,
            onSubmit: { focus = field == .email ? .password : .signIn }
        )
        .focused($focus, equals: field)
    }

    private func isInformational(_ message: String) -> Bool {
        message.contains("Waiting") || message.contains("Scan") || message.contains("code")
    }
}
