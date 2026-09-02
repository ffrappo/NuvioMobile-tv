import Foundation

// MARK: - Profile RPC payloads (Android ProfileSyncService.kt)

/// Row of `sync_pull_profile_locks` (`SupabaseProfileLockState`).
struct ProfileLockRecord: Decodable, Equatable, Sendable {
    let profileIndex: Int
    let pinEnabled: Bool
    let pinLockedUntil: String?

    enum CodingKeys: String, CodingKey {
        case profileIndex = "profile_index"
        case pinEnabled = "pin_enabled"
        case pinLockedUntil = "pin_locked_until"
    }
}

/// Row of `verify_profile_pin` (`SupabaseProfilePinVerifyResult`).
struct ProfilePinVerificationRecord: Decodable, Equatable, Sendable {
    let unlocked: Bool
    let retryAfterSeconds: Int

    enum CodingKeys: String, CodingKey {
        case unlocked
        case retryAfterSeconds = "retry_after_seconds"
    }
}

/// Row of the avatar catalogs (`SupabaseAvatarCatalogItem`).
struct AvatarCatalogRecord: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let storagePath: String
    let category: String?
    let sortOrder: Int?
    let bgColor: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case storagePath = "storage_path"
        case category
        case sortOrder = "sort_order"
        case bgColor = "bg_color"
    }
}

/// A single profile in the `sync_push_profiles` payload.
struct ProfilePushEntry: Encodable, Equatable, Sendable {
    let profileIndex: Int
    let name: String
    let avatarColorHex: String
    let usesPrimaryAddons: Bool
    let usesPrimaryPlugins: Bool
    let avatarID: String?
    let avatarURL: String?
    let profileBackgroundID: String?
    let profileBackgroundURL: String?

    enum CodingKeys: String, CodingKey {
        case profileIndex = "profile_index"
        case name
        case avatarColorHex = "avatar_color_hex"
        case usesPrimaryAddons = "uses_primary_addons"
        case usesPrimaryPlugins = "uses_primary_plugins"
        case avatarID = "avatar_id"
        case avatarURL = "avatar_url"
        case profileBackgroundID = "profile_background_id"
        case profileBackgroundURL = "profile_background_url"
    }
}

enum ProfilePinError: Error, Equatable {
    /// Server message "Current PIN is required" (`SetProfilePinResult.CurrentPinRequired`).
    case currentPinRequired
    case other(String)
}

extension NuvioAccountService {
    /// JSON-body RPC POST returning a decoded value (the generic the
    /// Encodable `request` helper cannot express for dictionary bodies).
    private func requestRaw<T: Decodable>(
        path: String,
        jsonBody: [String: Any],
        accessToken: String
    ) async throws -> T {
        var request = URLRequest(url: Self.baseURL.appending(path: path))
        request.httpMethod = "POST"
        addHeaders(to: &request, accessToken: accessToken)
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        return try await execute(request)
    }

    /// `sync_pull_profile_locks`: per-profile PIN enablement.
    func pullProfileLocks(accessToken: String) async throws -> [ProfileLockRecord] {
        try await request(
            url: endpointURL(path: "/rest/v1/rpc/sync_pull_profile_locks"),
            body: EmptyAccountPayload(),
            accessToken: accessToken
        )
    }

    /// `verify_profile_pin`: returns unlock state and, on failure, the
    /// server lockout window in seconds.
    func verifyProfilePin(profileID: Int, pin: String, accessToken: String) async throws -> ProfilePinVerificationRecord {
        let results: [ProfilePinVerificationRecord] = try await requestRaw(
            path: "/rest/v1/rpc/verify_profile_pin",
            jsonBody: [
                "p_profile_id": profileID,
                "p_pin": pin,
            ],
            accessToken: accessToken
        )
        return results.first ?? ProfilePinVerificationRecord(unlocked: false, retryAfterSeconds: 0)
    }

    /// `set_profile_pin`. Throws `ProfilePinError.currentPinRequired` when
    /// the server rejects the change because the current PIN is missing.
    func setProfilePin(
        profileID: Int,
        pin: String,
        currentPin: String?,
        accessToken: String
    ) async throws {
        var body: [String: Any] = [
            "p_profile_id": profileID,
            "p_pin": pin,
        ]
        if let currentPin, !currentPin.isEmpty {
            body["p_current_pin"] = currentPin
        }
        do {
            try await requestVoid(
                path: "/rest/v1/rpc/set_profile_pin",
                jsonBody: body,
                accessToken: accessToken
            )
        } catch let error as AccountServiceError {
            if case .http(_, let message) = error {
                let detail = message ?? ""
                if detail.localizedCaseInsensitiveContains("current pin is required") {
                    throw ProfilePinError.currentPinRequired
                }
                throw ProfilePinError.other(detail)
            }
            throw error
        }
    }

    /// `clear_profile_pin`.
    func clearProfilePin(profileID: Int, currentPin: String?, accessToken: String) async throws {
        var body: [String: Any] = [
            "p_profile_id": profileID,
        ]
        if let currentPin, !currentPin.isEmpty {
            body["p_current_pin"] = currentPin
        }
        try await requestVoid(
            path: "/rest/v1/rpc/clear_profile_pin",
            jsonBody: body,
            accessToken: accessToken
        )
    }

    /// `sync_push_profiles`: replaces the account's profile list.
    func pushProfiles(_ entries: [ProfilePushEntry], accessToken: String) async throws {
        try await requestVoid(
            path: "/rest/v1/rpc/sync_push_profiles",
            jsonBody: [
                "p_client_max_profiles": 6,
                "p_profiles": entries.map(\.jsonObject),
                "p_origin_client_id": TVSyncClientIdentity.current(),
            ],
            accessToken: accessToken
        )
    }

    /// `get_avatar_catalog`: the standard avatar catalog.
    func avatarCatalog(accessToken: String) async throws -> [AvatarCatalogRecord] {
        try await requestRaw(
            path: "/rest/v1/rpc/get_avatar_catalog",
            jsonBody: [:],
            accessToken: accessToken
        )
    }

    /// Public avatar image URL (`avatarPublicBaseUrl` + storage path).
    static func avatarImageURL(forStoragePath storagePath: String) -> URL? {
        if storagePath.hasPrefix("http://") || storagePath.hasPrefix("https://") {
            return URL(string: storagePath)
        }
        return URL(string: "\(baseURL.absoluteString)/storage/v1/object/public/avatars/\(storagePath)")
    }
}

private extension ProfilePushEntry {
    var jsonObject: [String: Any?] {
        [
            CodingKeys.profileIndex.rawValue: profileIndex,
            CodingKeys.name.rawValue: name,
            CodingKeys.avatarColorHex.rawValue: avatarColorHex,
            CodingKeys.usesPrimaryAddons.rawValue: usesPrimaryAddons,
            CodingKeys.usesPrimaryPlugins.rawValue: usesPrimaryPlugins,
            CodingKeys.avatarID.rawValue: avatarID,
            CodingKeys.avatarURL.rawValue: avatarURL,
            CodingKeys.profileBackgroundID.rawValue: profileBackgroundID,
            CodingKeys.profileBackgroundURL.rawValue: profileBackgroundURL,
        ]
    }
}
