import Foundation

/// Pure models mirroring the Android profile schema (`UserProfile`,
/// `ProfileBackgroundSelection`, `ProfileLockStateDataStore`,
/// `ProfileManager`). Presentation-only: persistence and network calls are
/// left to the integrator.

// MARK: - Lock state

public enum ProfileLockKind: String, Codable, Sendable {
    case none
    case pin
}

/// Local mirror of the Android PIN lock cache. The server is the source of
/// truth for verification; this state only drives presentation and the
/// client-side retry limit the brief requires.
public struct ProfileLockState: Equatable, Codable, Sendable {
    public static let defaultMaxAttempts = 5
    public static let defaultLockoutInterval: TimeInterval = 30

    public var kind: ProfileLockKind
    public var failedAttempts: Int
    public var maxAttempts: Int
    public var lockoutInterval: TimeInterval
    public var lockedUntil: Date?

    public init(
        kind: ProfileLockKind = .none,
        failedAttempts: Int = 0,
        maxAttempts: Int = ProfileLockState.defaultMaxAttempts,
        lockoutInterval: TimeInterval = ProfileLockState.defaultLockoutInterval,
        lockedUntil: Date? = nil
    ) {
        self.kind = kind
        self.failedAttempts = failedAttempts
        self.maxAttempts = maxAttempts
        self.lockoutInterval = lockoutInterval
        self.lockedUntil = lockedUntil
    }

    public static let unlocked = ProfileLockState(kind: .none)
    public static let pinLocked = ProfileLockState(kind: .pin)

    public var isLocked: Bool { kind != .none }
    public var remainingAttempts: Int { max(0, maxAttempts - failedAttempts) }

    public func isLockedOut(at now: Date = Date()) -> Bool {
        guard let lockedUntil else { return false }
        return now < lockedUntil
    }

    public func retryAfterSeconds(at now: Date = Date()) -> Int {
        guard let lockedUntil else { return 0 }
        return max(0, Int(lockedUntil.timeIntervalSince(now).rounded(.up)))
    }

    /// Records a failed attempt. Returns `true` when this failure starts a
    /// lockout window (retry limit reached, mirroring the server's
    /// `retryAfterSeconds` response on Android).
    @discardableResult
    public mutating func recordFailure(at now: Date = Date()) -> Bool {
        failedAttempts += 1
        guard failedAttempts >= maxAttempts else { return false }
        failedAttempts = 0
        lockedUntil = now.addingTimeInterval(lockoutInterval)
        return true
    }

    public mutating func recordSuccess() {
        failedAttempts = 0
        lockedUntil = nil
    }

    public mutating func disableLock() {
        kind = .none
        recordSuccess()
    }
}

// MARK: - Background selection

/// Mirrors Android `ProfileBackgroundSelection`.
public enum ProfileBackgroundSelection: Equatable, Codable, Sendable {
    case catalog(id: String)
    case custom(url: String)
}

/// Catalog artwork entry offered by the editor's background picker.
public struct ProfileBackgroundChoice: Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let imageURL: URL?

    public init(id: String, displayName: String, imageURL: URL? = nil) {
        self.id = id
        self.displayName = displayName
        self.imageURL = imageURL
    }
}

// MARK: - Profile schema

/// Mirror of Android `UserProfile` plus the lock overlay state.
public struct GatewayProfile: Equatable, Codable, Identifiable, Sendable {
    public static let primaryProfileID = 1
    /// Android `ProfileManager.MAX_PROFILES`.
    public static let maxProfiles = 6

    public var id: Int
    public var serverID: String?
    public var name: String
    public var avatarColorHex: String
    public var avatarID: String?
    public var avatarURL: String?
    public var profileBackgroundID: String?
    public var profileBackgroundURL: String?
    public var usesPrimaryAddons: Bool
    public var usesPrimaryPlugins: Bool
    public var lock: ProfileLockState

    public init(
        id: Int,
        serverID: String? = nil,
        name: String,
        avatarColorHex: String = ProfileAvatarPalette.defaultHex,
        avatarID: String? = nil,
        avatarURL: String? = nil,
        profileBackgroundID: String? = nil,
        profileBackgroundURL: String? = nil,
        usesPrimaryAddons: Bool = false,
        usesPrimaryPlugins: Bool = false,
        lock: ProfileLockState = .unlocked
    ) {
        self.id = id
        self.serverID = serverID
        self.name = name
        self.avatarColorHex = avatarColorHex
        self.avatarID = avatarID
        self.avatarURL = avatarURL
        self.profileBackgroundID = profileBackgroundID
        self.profileBackgroundURL = profileBackgroundURL
        self.usesPrimaryAddons = usesPrimaryAddons
        self.usesPrimaryPlugins = usesPrimaryPlugins
        self.lock = lock
    }

    /// Android `UserProfile.isPrimary` (`id == 1`).
    public var isPrimary: Bool { id == Self.primaryProfileID }

    /// Avatar image to render: a non-blank custom URL wins, exactly like the
    /// Android card (`avatarUrl.takeIf { it.isNotBlank() }` before catalog).
    public var avatarDisplayURL: String? {
        avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    /// Mirror of Android `resolveProfileBackgroundSelection`: access gated,
    /// trimmed non-blank custom URL beats the catalog id.
    public func resolvedBackground(hasAccess: Bool) -> ProfileBackgroundSelection? {
        guard hasAccess else { return nil }
        if let url = profileBackgroundURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return .custom(url: url)
        }
        if let id = profileBackgroundID {
            return .catalog(id: id)
        }
        return nil
    }
}

extension GatewayProfile {
    /// Schema mapping from the tvOS profile type; PIN presentation state
    /// arrives separately via `sync_pull_profile_locks`.
    init(tvProfile: TVProfile, lock: ProfileLockState = .unlocked) {
        self.init(
            id: tvProfile.profileIndex,
            serverID: tvProfile.id.isEmpty ? nil : tvProfile.id,
            name: tvProfile.name,
            avatarColorHex: tvProfile.avatarColorHex,
            avatarID: tvProfile.avatarID,
            avatarURL: tvProfile.avatarURL,
            profileBackgroundID: tvProfile.profileBackgroundID,
            profileBackgroundURL: tvProfile.profileBackgroundURL,
            usesPrimaryAddons: tvProfile.usesPrimaryAddons,
            usesPrimaryPlugins: tvProfile.usesPrimaryPlugins,
            lock: lock
        )
    }
}

// MARK: - Avatar palette

/// Android `PROFILE_AVATAR_COLORS`.
public enum ProfileAvatarPalette {
    public static let colors: [String] = [
        "#E53935", // Crimson
        "#1E88E5", // Ocean
        "#8E24AA", // Violet
        "#43A047", // Emerald
        "#FFB300", // Amber
        "#D81B60", // Rose
        "#00ACC1", // Cyan
        "#6D4C41"  // Brown
    ]

    /// Android create/edit default (`#1E88E5`, also the parse fallback).
    public static let defaultHex = "#1E88E5"
    /// Android primary-profile badge color (`0xFFFFB300`).
    public static let primaryBadgeHex = "#FFB300"
}

// MARK: - Name validation

public enum ProfileNameValidation: Equatable, Sendable {
    case valid(String)
    case empty
}

/// Android name-safety rules: the field caps input at 20 characters
/// (`onValueChange { if (it.length <= 20) ... }`), save/create stay disabled
/// while the name is blank, and `ProfileManager` trims and falls back to
/// `Profile N` when the stored name ends up empty.
public enum ProfileNameValidator {
    public static let maxLength = 20

    /// Mirrors the Android field cap: hard-truncate at `maxLength`.
    public static func sanitize(_ raw: String) -> String {
        String(raw.prefix(maxLength))
    }

    public static func validate(_ raw: String) -> ProfileNameValidation {
        let trimmed = sanitize(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .empty : .valid(trimmed)
    }

    /// Android `profile_default_name` ("Profile %1$d").
    public static func defaultName(for profileID: Int) -> String {
        "Profile \(profileID)"
    }

    /// Mirror of `ProfileManager.createProfile`: trimmed name, default on empty.
    public static func normalized(_ raw: String, profileID: Int) -> String {
        switch validate(raw) {
        case .valid(let name): return name
        case .empty: return defaultName(for: profileID)
        }
    }
}

// MARK: - Editor draft (dirty-state tracking)

/// Editable copy of a `GatewayProfile`. Equatable against a fresh draft of
/// the same original, which is what makes dirty-state tracking testable.
public struct ProfileEditorDraft: Equatable, Sendable {
    public let original: GatewayProfile
    public var name: String
    public var avatarColorHex: String
    public var background: ProfileBackgroundSelection?
    public var usesPrimaryAddons: Bool
    public var usesPrimaryPlugins: Bool
    public var lockEnabled: Bool
    /// New PIN staged by the set flow; applied by the integrator on save.
    public var pendingPIN: String?

    public init(profile: GatewayProfile) {
        original = profile
        name = profile.name
        avatarColorHex = profile.avatarColorHex
        background = profile.profileBackgroundURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            .map { .custom(url: $0) }
            ?? profile.profileBackgroundID.map { .catalog(id: $0) }
        usesPrimaryAddons = profile.usesPrimaryAddons
        usesPrimaryPlugins = profile.usesPrimaryPlugins
        lockEnabled = profile.lock.isLocked
        pendingPIN = nil
    }

    public var isDirty: Bool {
        self != ProfileEditorDraft(profile: original)
    }

    public var nameValidation: ProfileNameValidation {
        ProfileNameValidator.validate(name)
    }

    public var canSave: Bool {
        if case .valid = nameValidation { return true }
        return false
    }

    /// True when saving should also push a lock change (enable, new PIN, or removal).
    public var lockChanged: Bool {
        lockEnabled != original.lock.isLocked || pendingPIN != nil
    }

    public mutating func setName(_ raw: String) {
        name = ProfileNameValidator.sanitize(raw)
    }

    public mutating func reset() {
        self = ProfileEditorDraft(profile: original)
    }

    /// Builds the updated profile the integrator persists. Mirrors the
    /// Android editor `profile.copy(...)` save, plus the lock reconciliation.
    /// A blank draft name keeps the stored name (the Android editor never
    /// saves with a blank name because Save stays disabled).
    public func apply() -> GatewayProfile {
        var updated = original
        updated.name = {
            switch ProfileNameValidator.validate(name) {
            case .valid(let trimmed): return trimmed
            case .empty: return original.name
            }
        }()
        updated.avatarColorHex = avatarColorHex
        switch background {
        case .catalog(let id):
            updated.profileBackgroundID = id
            updated.profileBackgroundURL = nil
        case .custom(let url):
            updated.profileBackgroundID = nil
            updated.profileBackgroundURL = url
        case nil:
            updated.profileBackgroundID = nil
            updated.profileBackgroundURL = nil
        }
        updated.usesPrimaryAddons = usesPrimaryAddons
        updated.usesPrimaryPlugins = usesPrimaryPlugins
        if !lockEnabled {
            updated.lock.disableLock()
        } else if pendingPIN != nil, !updated.lock.isLocked {
            updated.lock = .pinLocked
        }
        return updated
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
