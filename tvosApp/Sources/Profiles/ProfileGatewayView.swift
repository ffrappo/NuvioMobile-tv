import SwiftUI

/// Startup profile gateway, ported from Android `ProfileSelectionScreen` in
/// Selection mode. Presentation-only: selection is delivered through
/// `onSelection` as a `ProfileSelectionOutcome` whose `switchPlan` stages the
/// per-profile store resets the integrator applies.
public struct ProfileGatewayView: View {
    // Android ProfileSelectionSpacing
    private enum Layout {
        static let screenPaddingHorizontal: CGFloat = 56
        static let screenPaddingVertical: CGFloat = 48
        static let logoHeight: CGFloat = 44
        static let logoToHeading: CGFloat = 28
        static let headingToSubheading: CGFloat = 12
        static let gridItemGap: CGFloat = 28
        static let cardWidth: CGFloat = 152
        static let cardPaddingHorizontal: CGFloat = 10
        static let cardPaddingVertical: CGFloat = 8
        static let avatarContainer: CGFloat = 126
        static let avatarToName: CGFloat = 12
        static let nameToMeta: CGFloat = 8
        static let metaSlotHeight: CGFloat = 16
        static let focusScale: CGFloat = 1.04
        static let cardFocusDuration: TimeInterval = 0.21
    }

    public let profiles: [GatewayProfile]
    public let activeProfileID: Int
    public var hasBackgroundAccess: Bool = true
    public var backgroundArtworkURL: (String) -> URL? = { _ in nil }
    public var verifyPIN: (GatewayProfile, String, @escaping (ProfilePINVerification) -> Void) -> Void
    public var onSelection: (ProfileSelectionOutcome) -> Void
    public var onCreateProfile: (() -> Void)?

    @State private var controller: ProfileGatewayController
    @State private var focusedProfileID: Int?
    @State private var shakeTrigger = 0
    @State private var deliveredSelection = false
    @State private var previousErrorLockout = false

    public init(
        profiles: [GatewayProfile],
        activeProfileID: Int,
        hasBackgroundAccess: Bool = true,
        backgroundArtworkURL: @escaping (String) -> URL? = { _ in nil },
        verifyPIN: @escaping (GatewayProfile, String, @escaping (ProfilePINVerification) -> Void) -> Void,
        onSelection: @escaping (ProfileSelectionOutcome) -> Void,
        onCreateProfile: (() -> Void)? = nil
    ) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.hasBackgroundAccess = hasBackgroundAccess
        self.backgroundArtworkURL = backgroundArtworkURL
        self.verifyPIN = verifyPIN
        self.onSelection = onSelection
        self.onCreateProfile = onCreateProfile
        _controller = State(initialValue: ProfileGatewayController(activeProfileID: activeProfileID))
    }

    private var focusedProfile: GatewayProfile? {
        if case .enteringPIN(let challenge) = controller.state { return challenge.profile }
        guard let id = focusedProfileID ?? initialFocusID else { return nil }
        return profiles.first { $0.id == id }
    }

    private var initialFocusID: Int? {
        profiles.first { $0.id == activeProfileID }?.id ?? profiles.first?.id
    }

    public var body: some View {
        ZStack {
            background
            content
        }
        .ignoresSafeArea()
        .onAppear {
            if focusedProfileID == nil { focusedProfileID = initialFocusID }
        }
        .onChange(of: controller.state) { _, _ in deliverSelectionIfComplete() }
    }

    // MARK: Selection delivery

    private func deliverSelectionIfComplete() {
        guard case .completed(let outcome) = controller.state, !deliveredSelection else { return }
        deliveredSelection = true
        onSelection(outcome)
    }

    private func choose(_ profile: GatewayProfile) {
        focusedProfileID = profile.id
        deliveredSelection = false
        _ = controller.choose(profile: profile)
        deliverSelectionIfComplete()
    }

    // MARK: Background

    private var background: some View {
        let profile = focusedProfile
        let avatarColor = ProfileColorParsing.color(hex: profile?.avatarColorHex ?? ProfileAvatarPalette.defaultHex)
        return ZStack {
            if let selection = profile?.resolvedBackground(hasAccess: hasBackgroundAccess) {
                let url: URL? = {
                    switch selection {
                    case .custom(let urlString): return URL(string: urlString)
                    case .catalog(let id): return backgroundArtworkURL(id)
                    }
                }()
                if let url {
                    NuvioArtworkView(
                        url: url,
                        mode: .backdrop,
                        pixelSize: CGSize(width: 1920, height: 1080),
                        cornerRadius: 0,
                        fadeDuration: NuvioMotion.contentTransition
                    )
                    .overlay(Color.black.opacity(NuvioDesignTokens.Effects.imageOverlayOpacity))
                }
            }
            if profile?.resolvedBackground(hasAccess: hasBackgroundAccess) == nil {
                // Android ProfileSelectionBackground: vertical gradient tinted
                // toward the focused avatar color, plus a left horizontal fade.
                LinearGradient(
                    stops: [
                        .init(color: NuvioDesignTokens.Colors.elevated.mix(with: avatarColor, by: 0.3), location: 0),
                        .init(color: NuvioDesignTokens.Colors.canvas.mix(with: avatarColor, by: 0.14), location: 0.42),
                        .init(color: NuvioDesignTokens.Colors.canvas, location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                LinearGradient(
                    stops: [
                        .init(color: avatarColor.opacity(0.26), location: 0),
                        .init(color: avatarColor.opacity(0.08), location: 0.45),
                        .init(color: .clear, location: 0.72),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            }
        }
        .animation(.easeInOut(duration: 0.52), value: focusedProfile?.avatarColorHex)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch controller.state {
        case .browsing, .completed:
            mainContent
        case .enteringPIN(let challenge):
            pinOverlay(challenge)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Text("NUVIO")
                .font(.system(size: Layout.logoHeight, weight: .heavy))
                .kerning(8)
                .foregroundStyle(Color.white.opacity(0.92))
            Text("Who's watching?")
                .font(.system(size: 44, weight: .bold))
                .padding(.top, Layout.logoToHeading)
            Text("Choose a profile to start")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .padding(.top, Layout.headingToSubheading)
            Spacer(minLength: 0)
            grid
            Spacer(minLength: 0)
            Text("Press the center button to select a profile")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText.opacity(0.9))
        }
        .padding(.horizontal, Layout.screenPaddingHorizontal)
        .padding(.vertical, Layout.screenPaddingVertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canAddProfile: Bool {
        profiles.count < GatewayProfile.maxProfiles
    }

    @ViewBuilder
    private var grid: some View {
        if profiles.isEmpty && !canAddProfile {
            Text("No profiles yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
        } else {
            HStack(spacing: Layout.gridItemGap) {
                ForEach(profiles) { profile in
                    ProfileGatewayCardView(
                        profile: profile,
                        width: Layout.cardWidth
                    ) {
                        choose(profile)
                    }
                    .onFocusChanged { focused in
                        if focused { focusedProfileID = profile.id }
                    }
                }
                if canAddProfile, let onCreateProfile {
                    ProfileAddCardView(width: Layout.cardWidth, action: onCreateProfile)
                }
            }
        }
    }

    // MARK: PIN overlay

    private func pinOverlay(_ challenge: ProfileUnlockChallenge) -> some View {
        VStack(spacing: 0) {
            Text("Enter PIN")
                .font(.system(size: 42, weight: .bold))
                .padding(.bottom, 42)
            ProfilePinBoxesView(
                filledCount: challenge.entry.filledCount,
                isError: challenge.lastError != nil,
                shakeTrigger: shakeTrigger
            )
            .padding(.bottom, 26)
            Text(supportText(for: challenge))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    challenge.lastError == nil
                        ? NuvioDesignTokens.Colors.secondaryText
                        : Color(red: 1.0, green: 0.557, blue: 0.557)
                )
                .frame(maxWidth: 720)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.bottom, 10)
            Text("Forgot your PIN? Reset it from the Nuvio web app.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText.opacity(0.7))
                .frame(maxWidth: 720)
                .multilineTextAlignment(.center)
                .padding(.bottom, 36)
            ProfilePinPadView(
                filledCount: challenge.entry.filledCount,
                isWorking: challenge.isVerifying,
                onDigit: { digit in
                    _ = controller.appendPINDigit(Character(String(digit)))
                    submitWhenComplete()
                },
                onDelete: { _ = controller.deletePINDigit() },
                onCancel: { controller.cancelPINEntry() }
            )
        }
        .padding(.horizontal, Layout.screenPaddingHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: challenge.lastError) { _, error in
            if error != nil { shakeTrigger += 1 }
        }
        .onExitCommand { controller.cancelPINEntry() }
    }

    private func supportText(for challenge: ProfileUnlockChallenge) -> String {
        if let error = challenge.lastError {
            switch error {
            case .incorrectPIN(let remaining):
                return "Incorrect PIN. \(remaining) attempt\(remaining == 1 ? "" : "s") left."
            case .lockedOut(let seconds):
                return "Too many attempts. Try again in \(seconds) seconds."
            case .verificationUnavailable:
                return "PIN verification is unavailable right now."
            }
        }
        if challenge.isVerifying { return "Verifying PIN…" }
        return "Enter the PIN for \(challenge.profile.name)."
    }

    private func submitWhenComplete() {
        guard let submission = controller.finishPINEntry(),
              let profile = profiles.first(where: { $0.id == submission.profileID })
        else { return }
        verifyPIN(profile, submission.pin) { result in
            _ = controller.applyVerification(result, for: submission.profileID)
        }
    }
}

// MARK: - Focus helper

private struct FocusChangedModifier: ViewModifier {
    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        content.background(
            FocusChangedSink(action: action)
        )
    }
}

private struct FocusChangedSink: View {
    let action: (Bool) -> Void
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: isFocused) { _, focused in action(focused) }
    }
}

extension View {
    fileprivate func onFocusChanged(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(FocusChangedModifier(action: action))
    }
}
