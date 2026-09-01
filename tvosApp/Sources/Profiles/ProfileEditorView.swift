import SwiftUI

/// Profile editor sheet ported from Android `EditProfileOverlay`
/// (name field, avatar picker, background picker behind a tab, save) and
/// consolidated with the PIN actions and inheritance flags the brief places
/// in the editor. On Android those live in the long-press options dialog and
/// the create flow; the tvOS editor merges them into one sheet.
public struct ProfileEditorView: View {
    private enum Layout {
        static let panelMaxWidth: CGFloat = 980
        static let panelRadius: CGFloat = 20
        static let previewWidth: CGFloat = 280
        static let previewAvatarSize: CGFloat = 112
        static let fieldRadius: CGFloat = 14
    }

    public let profile: GatewayProfile
    public var backgroundChoices: [ProfileBackgroundChoice] = []
    public var hasBackgroundAccess: Bool = true
    public var isSaving: Bool = false
    public var onSave: (GatewayProfile, String?) -> Void
    public var onDelete: ((GatewayProfile) -> Void)?
    public var onCancel: () -> Void

    @State private var draft: ProfileEditorDraft
    @State private var pinSetup = ProfilePinSetup()
    @State private var pinFlowActive = false
    @State private var pinMessage: String?
    @State private var shakeTrigger = 0
    @State private var confirmDelete = false

    public init(
        profile: GatewayProfile,
        backgroundChoices: [ProfileBackgroundChoice] = [],
        hasBackgroundAccess: Bool = true,
        isSaving: Bool = false,
        onSave: @escaping (GatewayProfile, String?) -> Void,
        onDelete: ((GatewayProfile) -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.profile = profile
        self.backgroundChoices = backgroundChoices
        self.hasBackgroundAccess = hasBackgroundAccess
        self.isSaving = isSaving
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _draft = State(initialValue: ProfileEditorDraft(profile: profile))
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            panel
        }
        .onExitCommand { handleExit() }
        .confirmationDialog(
            "Delete this profile?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Profile", role: .destructive) { onDelete?(draft.original) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Watch history, library, and settings for “\(profile.name)” will be removed.")
        }
    }

    private func handleExit() {
        if pinFlowActive {
            pinFlowActive = false
            pinSetup.reset()
            pinMessage = nil
        } else {
            onCancel()
        }
    }

    private var panel: some View {
        VStack(spacing: 24) {
            header
            ScrollView {
                HStack(alignment: .top, spacing: 28) {
                    previewColumn
                    Rectangle()
                        .fill(NuvioDesignTokens.Colors.neutral700.opacity(0.6))
                        .frame(width: NuvioDesignTokens.Strokes.hairline, height: 320)
                    controlsColumn
                }
            }
        }
        .padding(32)
        .frame(maxWidth: Layout.panelMaxWidth, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Layout.panelRadius, style: .continuous)
                .fill(NuvioDesignTokens.Colors.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.panelRadius, style: .continuous)
                        .strokeBorder(
                            NuvioDesignTokens.Colors.neutral700.opacity(0.7),
                            lineWidth: NuvioDesignTokens.Strokes.hairline
                        )
                )
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EDIT PROFILE")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                Text(profile.name)
                    .font(.system(size: 30, weight: .black))
            }
            Spacer()
            HStack(spacing: 12) {
                Button("Cancel") { onCancel() }
                    .buttonStyle(EditorSecondaryButtonStyle())
                Button("Reset") { draft.reset(); cancelPinFlow() }
                    .buttonStyle(EditorSecondaryButtonStyle())
                    .disabled(!draft.isDirty)
                Button(isSaving ? "Saving…" : "Save") {
                    let pendingPIN = draft.pendingPIN
                    let updated = draft.apply()
                    draft = ProfileEditorDraft(profile: updated)
                    onSave(updated, pendingPIN)
                }
                .buttonStyle(EditorPrimaryButtonStyle())
                .disabled(!draft.canSave || isSaving)
            }
        }
    }

    // MARK: Preview column

    private var previewColumn: some View {
        VStack(spacing: 18) {
            ProfileAvatarCircleView(
                name: draft.name.isEmpty ? "?" : draft.name,
                colorHex: draft.avatarColorHex,
                size: Layout.previewAvatarSize,
                avatarURL: profile.avatarDisplayURL
            )
            Text(draft.name.isEmpty ? "Profile name" : draft.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    draft.name.isEmpty
                        ? NuvioDesignTokens.Colors.secondaryText
                        : NuvioDesignTokens.Colors.primaryText
                )
                .lineLimit(2)
                .multilineTextAlignment(.center)
            TextField("Profile name", text: nameBinding)
            .textFieldStyle(.plain)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Layout.fieldRadius, style: .continuous)
                    .fill(NuvioDesignTokens.Colors.neutral875)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.fieldRadius, style: .continuous)
                    .strokeBorder(nameBorderColor, lineWidth: NuvioDesignTokens.Strokes.thin)
            )
            if case .empty = draft.nameValidation, !draft.name.isEmpty {
                Text("Name can't be blank — saving keeps the current name")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NuvioDesignTokens.Colors.warning)
            }
        }.frame(width: Layout.previewWidth)
    }

    private var nameBinding: Binding<String> {
        Binding(get: { draft.name }, set: { draft.setName($0) })
    }

    private var nameBorderColor: Color {
        if draft.name.isEmpty { return NuvioDesignTokens.Colors.neutral700 }
        if case .valid = draft.nameValidation { return NuvioDesignTokens.Colors.brand.opacity(0.7) }
        return NuvioDesignTokens.Colors.warning
    }

    // MARK: Controls column

    private var controlsColumn: some View {
        VStack(alignment: .leading, spacing: 28) {
            avatarPicker
            backgroundPicker
            lockSection
            inheritanceSection
            deleteSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var avatarPicker: some View {
        VStack(spacing: 14) {
            sectionTitle("Choose avatar color")
            HStack(spacing: 14) {
                ForEach(ProfileAvatarPalette.colors, id: \.self) { hex in
                    Button {
                        draft.avatarColorHex = hex
                    } label: {
                        Circle()
                            .fill(ProfileColorParsing.color(hex: hex))
                            .frame(width: 52, height: 52)
                            .overlay(Circle().strokeBorder(
                                draft.avatarColorHex == hex
                                    ? NuvioDesignTokens.Colors.primaryText
                                    : NuvioDesignTokens.Colors.neutral600,
                                lineWidth: draft.avatarColorHex == hex ? 3 : 1
                            ))
                    }
                    .buttonStyle(SwatchButtonStyle())
                    .accessibilityLabel("Avatar color \(hex)")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var backgroundPicker: some View {
        VStack(spacing: 14) {
            sectionTitle("Profile background")
            if hasBackgroundAccess {
                HStack(spacing: 14) {
                    backgroundOption(id: nil, label: "None")
                    ForEach(backgroundChoices) { choice in
                        backgroundOption(id: choice.id, label: choice.displayName)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Profile backgrounds are a member cosmetic.")
                    .font(.system(size: 15))
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    private func backgroundOption(id: String?, label: String) -> some View {
        let isSelected = isBackgroundSelected(id)
        return Button {
            draft.background = id.map { .catalog(id: $0) }
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    isSelected
                        ? NuvioDesignTokens.Colors.primaryText
                        : NuvioDesignTokens.Colors.secondaryText
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Layout.fieldRadius, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.fieldRadius, style: .continuous)
                        .strokeBorder(
                            isSelected ? NuvioDesignTokens.Colors.primaryText : NuvioDesignTokens.Colors.neutral700,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        }
        .buttonStyle(FlatFocusButtonStyle())
        .accessibilityLabel("Background \(label)")
    }

    private func isBackgroundSelected(_ id: String?) -> Bool {
        switch draft.background {
        case .catalog(let selected): return selected == id
        case .custom: return false
        case nil: return id == nil
        }
    }

    private var lockSection: some View {
        VStack(spacing: 14) {
            sectionTitle("PIN lock")
            Toggle(isOn: Binding(
                get: { draft.lockEnabled },
                set: { enabled in
                    if enabled {
                        draft.lockEnabled = true
                        if draft.pendingPIN == nil, !profile.lock.isLocked { startPinFlow() }
                    } else {
                        draft.lockEnabled = false
                        draft.pendingPIN = nil
                        cancelPinFlow()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Require PIN").font(.system(size: 18, weight: .semibold))
                    Text("Ask for a 4-digit PIN before opening this profile")
                        .font(.system(size: 14))
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
            }
            .toggleStyle(.switch)
            if pinFlowActive { pinFlow }
            else if let message = pinMessage {
                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            }
        }
    }

    private var pinFlow: some View {
        VStack(spacing: 18) {
            Text(pinSetup.stage == .create ? "Enter a new 4-digit PIN" : "Confirm your PIN")
                .font(.system(size: 26, weight: .bold))
            ProfilePinBoxesView(
                filledCount: pinSetup.entry.filledCount,
                isError: pinSetup.stage == .create && pinMessage != nil,
                shakeTrigger: shakeTrigger
            )
            ProfilePinPadView(
                filledCount: pinSetup.entry.filledCount,
                isWorking: false,
                onDigit: { digit in
                    _ = pinSetup.append(Character(String(digit)))
                    submitPinSetupIfComplete()
                },
                onDelete: { _ = pinSetup.deleteLast() },
                onCancel: cancelPinFlow
            )
        }.padding(.top, 8)
    }

    private func startPinFlow() {
        pinFlowActive = true
        pinSetup.reset()
        pinMessage = nil
    }

    private func cancelPinFlow() {
        pinFlowActive = false
        pinSetup.reset()
    }

    private func submitPinSetupIfComplete() {
        guard let outcome = pinSetup.submitIfComplete() else { return }
        switch outcome {
        case .awaitingConfirmation:
            pinMessage = "Re-enter the same PIN to confirm."
        case .mismatch:
            pinMessage = "PINs didn't match. Start again."
            shakeTrigger += 1
        case .ready(let pin):
            draft.pendingPIN = pin
            draft.lockEnabled = true
            pinFlowActive = false
            pinMessage = "PIN set — it will be saved with your changes."
        }
    }

    private var inheritanceSection: some View {
        VStack(spacing: 14) {
            sectionTitle("Inheritance")
            Toggle(isOn: $draft.usesPrimaryAddons) {
                inheritanceLabel("Use primary profile's addons", "Share the primary profile's configured catalogs")
            }
            Toggle(isOn: $draft.usesPrimaryPlugins) {
                inheritanceLabel("Use primary profile's plugins", "Share the primary profile's plugin credentials")
            }
        }
        .toggleStyle(.switch)
    }

    private func inheritanceLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 18, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        if !profile.isPrimary {
            sectionTitle("Danger zone")
            Button("Delete Profile") { confirmDelete = true }
                .buttonStyle(EditorDestructiveButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }
}
