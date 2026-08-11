import SwiftUI

struct AccountGateView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        switch auth.status {
        case .loading:
            ZStack {
                NuvioTheme.background.ignoresSafeArea()
                ProgressView("Restoring your account")
                    .font(.title3)
            }
        case .signedOut:
            SignInView()
        case .guest, .authenticated:
            AppShellView()
        }
    }
}

struct SignInView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable { case email, password, signIn, refresh, guest }

    var body: some View {
        HStack(spacing: 70) {
            brandPanel
            loginPanel
        }
        .padding(70)
        .background(NuvioTheme.background.ignoresSafeArea())
        .defaultFocus($focus, .email)
    }

    private var brandPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 20) {
                Image("NuvioLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                Text("Nuvio")
                    .font(.system(size: 64, weight: .bold))
            }
            Text("Watch your library, anywhere")
                .font(.title.weight(.semibold))
            Text("Sign in to sync addons, your library, profiles, and viewing progress across Nuvio devices.")
                .font(.title3)
                .foregroundStyle(NuvioTheme.secondaryText)
                .frame(maxWidth: 560, alignment: .leading)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loginPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sign in to Nuvio")
                .font(.largeTitle.weight(.bold))
            Text("Use your email and password, or scan the QR code with your phone.")
                .font(.title3)
                .foregroundStyle(NuvioTheme.secondaryText)

            HStack(alignment: .top, spacing: 34) {
                credentials
                qrBlock
            }

            if let message = auth.message {
                Text(message.tvSafe)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(message.contains("Waiting") || message.contains("Scan") ? NuvioTheme.secondaryText : .orange)
                    .lineLimit(2)
            }

            HStack(spacing: 18) {
                NuvioButton(title: "Refresh QR", symbol: "arrow.clockwise", focused: focus == .refresh) {
                    Task { await auth.startQRLogin() }
                }
                .focused($focus, equals: .refresh)

                NuvioButton(title: "Continue as Guest", symbol: "person", focused: focus == .guest) {
                    auth.continueAsGuest()
                }
                .focused($focus, equals: .guest)
            }
        }
        .padding(38)
        .frame(width: 890)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 28))
    }

    private var credentials: some View {
        VStack(spacing: 16) {
            accountField("Email", text: $email, field: .email, contentType: .username)
            accountField("Password", text: $password, field: .password, contentType: .password, secure: true)
            NuvioButton(
                title: auth.isWorking ? "Signing In..." : "Sign In",
                symbol: "person.crop.circle.badge.checkmark",
                focused: focus == .signIn,
                prominent: true,
                disabled: email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || auth.isWorking
            ) {
                Task { await auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password) }
            }
            .focused($focus, equals: .signIn)
        }
        .frame(width: 430)
    }

    private var qrBlock: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.white)
                if let image = auth.qrImage {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(14)
                } else {
                    ProgressView()
                        .tint(.black)
                }
            }
            .frame(width: 250, height: 250)
            if let code = auth.qrSession?.code {
                Text("Code")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NuvioTheme.secondaryText)
                Text(code)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(width: 300)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func accountField(
        _ title: String,
        text: Binding<String>,
        field: Field,
        contentType: UITextContentType,
        secure: Bool = false
    ) -> some View {
        Group {
            if secure {
                SecureField(title, text: text)
            } else {
                TextField(title, text: text)
            }
        }
        .textContentType(contentType)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($focus, equals: field)
        .onSubmit { focus = field == .email ? .password : .signIn }
    }
}
