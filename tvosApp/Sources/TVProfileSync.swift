import Foundation

/// Profile PIN and mutation operations on top of `TVProfileStore`, talking
/// to the same Supabase RPCs the Android `ProfileSyncService` uses.
extension TVProfileStore {
    /// `sync_pull_profile_locks`: which profiles have a server-side PIN.
    func syncLockStates(auth: AuthStore, service: NuvioAccountService = NuvioAccountService()) async {
        guard auth.session != nil else {
            applyLockRecords([:])
            return
        }
        do {
            let token = try await auth.validAccessToken()
            let records = try await service.pullProfileLocks(accessToken: token)
            applyLockRecords(Dictionary(uniqueKeysWithValues: records.map { ($0.profileIndex, $0) }))
        } catch {
            let detail = AppLog.safeDescription(error)
            AppLog.sync.error("Profile lock sync failed detail=\(detail, privacy: .public)")
        }
    }

    func isPinEnabled(_ profileID: Int) -> Bool {
        lockRecords[profileID]?.pinEnabled == true
    }

    /// Server-side PIN verification (`verify_profile_pin`). Returns the
    /// unlock verdict plus the server lockout window on failure.
    func verifyPin(
        _ profileID: Int,
        pin: String,
        auth: AuthStore,
        service: NuvioAccountService = NuvioAccountService()
    ) async -> ProfilePinVerificationRecord {
        do {
            let token = try await auth.validAccessToken()
            return try await service.verifyProfilePin(profileID: profileID, pin: pin, accessToken: token)
        } catch {
            let detail = AppLog.safeDescription(error)
            AppLog.sync.error("Profile PIN verify failed detail=\(detail, privacy: .public)")
            return ProfilePinVerificationRecord(unlocked: false, retryAfterSeconds: 0)
        }
    }

    /// Sets or replaces a profile PIN, then refreshes lock states.
    @discardableResult
    func setPin(
        _ profileID: Int,
        pin: String,
        currentPin: String?,
        auth: AuthStore,
        service: NuvioAccountService = NuvioAccountService()
    ) async -> Result<Void, ProfilePinError> {
        do {
            let token = try await auth.validAccessToken()
            try await service.setProfilePin(profileID: profileID, pin: pin, currentPin: currentPin, accessToken: token)
            await syncLockStates(auth: auth, service: service)
            return .success(())
        } catch let error as ProfilePinError {
            return .failure(error)
        } catch {
            return .failure(.other(AppLog.safeDescription(error)))
        }
    }

    /// Clears a profile PIN, then refreshes lock states.
    func clearPin(
        _ profileID: Int,
        currentPin: String?,
        auth: AuthStore,
        service: NuvioAccountService = NuvioAccountService()
    ) async {
        do {
            let token = try await auth.validAccessToken()
            try await service.clearProfilePin(profileID: profileID, currentPin: currentPin, accessToken: token)
            await syncLockStates(auth: auth, service: service)
        } catch {
            let detail = AppLog.safeDescription(error)
            AppLog.sync.error("Profile PIN clear failed detail=\(detail, privacy: .public)")
        }
    }

    // MARK: - Profile mutations (sync_push_profiles)

    /// Replaces the account's profile list with the given profiles, then
    /// refreshes the local snapshot. Enforces the Android guards: at most
    /// `TVProfile.maxProfiles` profiles, the primary profile must exist.
    func save(
        _ updated: [TVProfile],
        auth: AuthStore,
        service: NuvioAccountService = NuvioAccountService()
    ) async {
        guard auth.session != nil else { return }
        let trimmed = Array(updated.prefix(TVProfile.maxProfiles))
        do {
            let token = try await auth.validAccessToken()
            try await service.pushProfiles(trimmed.map(ProfilePushEntry.init), accessToken: token)
            applyPushedProfiles(trimmed)
        } catch {
            let detail = AppLog.safeDescription(error)
            AppLog.sync.error("Profile push failed detail=\(detail, privacy: .public)")
        }
    }

    /// Deletes a profile locally and remotely. The primary profile is
    /// protected (Android `ProfileManager` invariant).
    func delete(
        _ profileID: Int,
        auth: AuthStore,
        service: NuvioAccountService = NuvioAccountService()
    ) async {
        guard profileID != TVProfile.primaryProfileID else { return }
        var remaining = profiles
        remaining.removeAll { $0.profileIndex == profileID }
        await save(remaining, auth: auth, service: service)
    }
}

extension ProfilePushEntry {
    init(profile: TVProfile) {
        let avatarURL = profile.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let backgroundURL = profile.profileBackgroundURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            profileIndex: profile.profileIndex,
            name: profile.name,
            avatarColorHex: profile.avatarColorHex,
            usesPrimaryAddons: profile.usesPrimaryAddons,
            usesPrimaryPlugins: profile.usesPrimaryPlugins,
            // Android: avatar_id drops to null whenever a custom URL exists.
            avatarID: (avatarURL?.isEmpty == false) ? nil : profile.avatarID,
            avatarURL: (avatarURL?.isEmpty == false) ? avatarURL : nil,
            profileBackgroundID: profile.profileBackgroundID,
            profileBackgroundURL: (backgroundURL?.isEmpty == false) ? backgroundURL : nil
        )
    }
}
