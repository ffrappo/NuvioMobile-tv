import SwiftUI

/// Hosts the parity `ProfileEditorView` against `TVProfileStore`:
/// saving pushes the full profile list (`sync_push_profiles`), the optional
/// PIN runs `set_profile_pin`, and deletion guards the primary profile.
struct ProfileEditingSheet: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var profileStore: TVProfileStore
    let profile: TVProfile
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var saveMessage: String?

    private var onDelete: ((GatewayProfile) -> Void)? {
        isNew ? nil : { _ in delete() }
    }

    var body: some View {
        ProfileEditorView(
            profile: GatewayProfile(tvProfile: profile, lock: lockState),
            isSaving: isSaving,
            onSave: { updated, newPin in
                save(updated: updated, newPin: newPin)
            },
            onDelete: onDelete,
            onCancel: { dismiss() }
        )
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

    private func save(updated: GatewayProfile, newPin: String?) {
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
                    currentPin: nil,
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
        case .currentPinRequired: "Enter the current PIN before changing it."
        case .other(let detail): "PIN change failed: \(detail)"
        }
    }
}
