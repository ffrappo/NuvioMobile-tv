import SwiftUI

/// PIN entry sheet for the editor's protected actions (Android
/// `VerifyCurrentForChange` / `VerifyCurrentForRemove` /
/// `VerifyCurrentForDelete`): the entered PIN is verified against the
/// server before the action runs.
struct ProfilePinPrompt: View {
    let profileID: Int
    let reason: String
    let onVerified: (String) -> Void
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var profileStore: TVProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var isVerifying = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Profile PIN").font(.title3.weight(.bold))
            Text(reason.tvSafe)
                .font(.callout)
                .foregroundStyle(.secondary)
            SecureField("PIN", text: $pin)
                .frame(maxWidth: 320)
            if let errorText {
                Text(errorText.tvSafe)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
            }
            HStack(spacing: 16) {
                Button("Verify") { verify() }
                    .buttonStyle(.borderedProminent)
                    .disabled(pin.isEmpty || isVerifying)
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(maxWidth: 640)
        .background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(80)
    }

    private func verify() {
        isVerifying = true
        errorText = nil
        Task { @MainActor in
            let result = await profileStore.verifyPin(profileID, pin: pin, auth: auth)
            isVerifying = false
            if result.unlocked {
                let verifiedPin = pin
                dismiss()
                onVerified(verifiedPin)
            } else {
                errorText = result.retryAfterSeconds > 0
                    ? "Too many attempts. Try again in \(result.retryAfterSeconds) seconds."
                    : "Incorrect PIN."
            }
        }
    }
}

/// Hosts the parity `ProfileEditorView` against `TVProfileStore`:
/// saving pushes the full profile list (`sync_push_profiles`), PIN changes
/// and lock removal verify the current PIN first, and deletion guards the
/// primary profile and purges remote profile data.
struct ProfileEditingSheet: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var profileStore: TVProfileStore
    let profile: TVProfile
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var pinPrompt: PinPromptReason?

    enum PinPromptReason: Identifiable {
        case changePin(GatewayProfile, String)
        case removePin(GatewayProfile)
        case deleteLocked(GatewayProfile)

        var id: Int {
            switch self {
            case .changePin: return 1
            case .removePin: return 2
            case .deleteLocked: return 3
            }
        }

        var reasonText: String {
            switch self {
            case .changePin: return "Enter the current PIN to change it."
            case .removePin: return "Enter the current PIN to remove it."
            case .deleteLocked: return "Enter the PIN to delete this profile."
            }
        }
    }

    var body: some View {
        ProfileEditorView(
            profile: GatewayProfile(tvProfile: profile, lock: lockState),
            avatarChoices: ProfileAvatarCatalog.shared.choices,
            isSaving: isSaving,
            onSave: { updated, newPin in save(updated: updated, newPin: newPin) },
            onDelete: onDelete,
            onCancel: { dismiss() }
        )
        .onAppear { ProfileAvatarCatalog.shared.ensureLoaded(auth: auth) }
        .sheet(item: $pinPrompt) { reason in
            ProfilePinPrompt(
                profileID: profile.profileIndex,
                reason: reason.reasonText
            ) { verifiedPin in
                handleVerifiedPin(reason: reason, verifiedPin: verifiedPin)
            }
        }
        .overlay(alignment: .bottom) {
            if let saveMessage {
                Text(saveMessage.tvSafe)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 40)
            }
        }
    }

    private var lockState: ProfileLockState {
        profileStore.isPinEnabled(profile.profileIndex) ? .pinLocked : .unlocked
    }

    private var onDelete: ((GatewayProfile) -> Void)? {
        isNew ? nil : { draft in
            if profileStore.isPinEnabled(draft.id) {
                // Deleting a PIN-locked profile requires verification.
                pinPrompt = .deleteLocked(draft)
            } else {
                delete()
            }
        }
    }

    private func save(updated: GatewayProfile, newPin: String?) {
        let pinWasEnabled = profileStore.isPinEnabled(updated.id)
        let pinNowEnabled = updated.lock.isLocked
        let wantsNewPin = newPin?.isEmpty == false

        // Changing or removing an existing PIN needs the current PIN first.
        if pinWasEnabled && (wantsNewPin || !pinNowEnabled) {
            if wantsNewPin, let newPin {
                pinPrompt = .changePin(updated, newPin)
            } else {
                pinPrompt = .removePin(updated)
            }
            return
        }
        performSave(updated: updated, newPin: newPin, currentPin: nil)
    }

    private func handleVerifiedPin(reason: PinPromptReason, verifiedPin: String) {
        switch reason {
        case .changePin(let updated, let newPin):
            performSave(updated: updated, newPin: newPin, currentPin: verifiedPin)
        case .removePin(let updated):
            Task { @MainActor in
                await profileStore.clearPin(updated.id, currentPin: verifiedPin, auth: auth)
                performSave(updated: updated, newPin: nil, currentPin: nil)
            }
        case .deleteLocked:
            delete()
        }
    }

    private func performSave(updated: GatewayProfile, newPin: String?, currentPin: String?) {
        isSaving = true
        saveMessage = nil
        Task { @MainActor in
            var list = profileStore.profiles
            let merged = merge(updated)
            if let index = list.firstIndex(where: { $0.profileIndex == merged.profileIndex }) {
                list[index] = merged
            } else {
                list.append(merged)
            }
            await profileStore.save(list, auth: auth)
            if let newPin, !newPin.isEmpty {
                let result = await profileStore.setPin(
                    merged.profileIndex,
                    pin: newPin,
                    currentPin: currentPin,
                    auth: auth
                )
                if case .failure(let error) = result {
                    saveMessage = Self.message(for: error)
                }
            }
            isSaving = false
            if saveMessage == nil { dismiss() }
        }
    }

    private func delete() {
        Task { @MainActor in
            await profileStore.delete(profile.profileIndex, auth: auth)
            dismiss()
        }
    }

    /// Maps the edited gateway profile back onto the store schema.
    private func merge(_ updated: GatewayProfile) -> TVProfile {
        TVProfile(
            id: profile.id,
            profileIndex: updated.id,
            name: updated.name,
            avatarColorHex: updated.avatarColorHex,
            avatarID: updated.avatarID,
            avatarURL: updated.avatarURL,
            profileBackgroundID: updated.profileBackgroundID,
            profileBackgroundURL: updated.profileBackgroundURL,
            usesPrimaryAddons: updated.usesPrimaryAddons,
            usesPrimaryPlugins: updated.usesPrimaryPlugins
        )
    }

    private static func message(for error: ProfilePinError) -> String {
        switch error {
        case .currentPinRequired:
            "This profile already has a PIN. Enter the current PIN to change it."
        case .other(let detail):
            "PIN change failed: \(detail)"
        }
    }
}
