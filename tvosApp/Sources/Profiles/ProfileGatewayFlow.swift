import Foundation

// MARK: - PIN entry

/// Digits-only PIN entry, capped at `length` (Android `ProfilePinLength = 4`).
public struct ProfilePinEntry: Equatable, Sendable {
    public static let length = 4

    public private(set) var digits: String = ""

    public init() {}

    public var filledCount: Int { digits.count }
    public var isComplete: Bool { digits.count == Self.length }
    public var isEmpty: Bool { digits.isEmpty }

    @discardableResult
    public mutating func append(_ digit: Character) -> Bool {
        guard digits.count < Self.length, digit.isASCII, digit.isNumber else { return false }
        digits.append(digit)
        return true
    }

    public mutating func append(_ number: Int) -> Bool {
        append(Character(String(number)))
    }

    @discardableResult
    public mutating func deleteLast() -> Bool {
        guard !digits.isEmpty else { return false }
        digits.removeLast()
        return true
    }

    public mutating func reset() {
        digits = ""
    }
}

/// Two-stage set flow mirroring Android `ProfilePinEntryStage`
/// (Create → Confirm, mismatch restarts at Create).
public struct ProfilePinSetup: Equatable, Sendable {
    public enum Stage: String, Equatable, Sendable {
        case create
        case confirm
    }

    public enum Outcome: Equatable, Sendable {
        case awaitingConfirmation
        case mismatch
        case ready(String)
    }

    public private(set) var stage: Stage = .create
    public private(set) var entry = ProfilePinEntry()
    private var draft: String?

    public init() {}

    public mutating func append(_ digit: Character) -> Bool {
        entry.append(digit)
    }

    public mutating func deleteLast() -> Bool {
        entry.deleteLast()
    }

    @discardableResult
    public mutating func submitIfComplete() -> Outcome? {
        guard entry.isComplete else { return nil }
        switch stage {
        case .create:
            draft = entry.digits
            entry.reset()
            stage = .confirm
            return .awaitingConfirmation
        case .confirm:
            let submitted = entry.digits
            entry.reset()
            let draft = draft
            self.draft = nil
            stage = .create
            return submitted == draft ? .ready(submitted) : .mismatch
        }
    }

    public mutating func reset() {
        stage = .create
        entry.reset()
        draft = nil
    }
}

// MARK: - Verification

/// Mirror of Android `SupabaseProfilePinVerifyResult` (unlocked + retryAfterSeconds).
public struct ProfilePINVerification: Equatable, Sendable {
    public var unlocked: Bool
    public var retryAfterSeconds: Int

    public init(unlocked: Bool, retryAfterSeconds: Int = 0) {
        self.unlocked = unlocked
        self.retryAfterSeconds = retryAfterSeconds
    }

    public static let success = ProfilePINVerification(unlocked: true)
    public static func failure(retryAfterSeconds: Int = 0) -> ProfilePINVerification {
        ProfilePINVerification(unlocked: false, retryAfterSeconds: retryAfterSeconds)
    }
}

public protocol ProfilePINVerifying: Sendable {
    func verify(pin: String, for profileID: Int) -> ProfilePINVerification
}

// MARK: - Selection state machine

public enum ProfileUnlockError: Equatable, Sendable {
    case incorrectPIN(remainingAttempts: Int)
    case lockedOut(retryAfterSeconds: Int)
    case verificationUnavailable
}

public struct ProfileUnlockChallenge: Equatable, Sendable {
    public var profile: GatewayProfile
    public var entry: ProfilePinEntry
    public var lock: ProfileLockState
    public var lastError: ProfileUnlockError?
    public var isVerifying: Bool

    public init(
        profile: GatewayProfile,
        entry: ProfilePinEntry = ProfilePinEntry(),
        lock: ProfileLockState = .unlocked,
        lastError: ProfileUnlockError? = nil,
        isVerifying: Bool = false
    ) {
        self.profile = profile
        self.entry = entry
        self.lock = lock
        self.lastError = lastError
        self.isVerifying = isVerifying
    }
}

public struct ProfileSelectionOutcome: Equatable, Sendable {
    public let profile: GatewayProfile
    public let switchPlan: ProfileSwitchPlan
}

public enum ProfileGatewayState: Equatable, Sendable {
    case browsing
    case enteringPIN(ProfileUnlockChallenge)
    case completed(ProfileSelectionOutcome)
}

/// Presentation-only selection state machine: choose profile (locked vs
/// unlocked), PIN entry with retry limit, cancel. The integrator owns the
/// actual switch, staged via `ProfileSelectionOutcome.switchPlan`.
public struct ProfileGatewayController: Equatable, Sendable {
    public let activeProfileID: Int
    public private(set) var state: ProfileGatewayState = .browsing

    public init(activeProfileID: Int = GatewayProfile.primaryProfileID) {
        self.activeProfileID = activeProfileID
    }

    public var activeChallenge: ProfileUnlockChallenge? {
        guard case .enteringPIN(let challenge) = state else { return nil }
        return challenge
    }

    /// Selecting an unlocked profile completes immediately (Android calls
    /// `selectProfile` right away); a locked profile routes to the PIN
    /// overlay (`ProfilePinOverlayState.Unlock`).
    @discardableResult
    public mutating func choose(profile: GatewayProfile, now: Date = Date()) -> ProfileGatewayState {
        guard !profile.lock.isLocked else {
            var challenge = ProfileUnlockChallenge(profile: profile, lock: profile.lock)
            if challenge.lock.isLockedOut(at: now) {
                challenge.lastError = .lockedOut(retryAfterSeconds: challenge.lock.retryAfterSeconds(at: now))
            }
            state = .enteringPIN(challenge)
            return state
        }
        state = .completed(
            ProfileSelectionOutcome(
                profile: profile,
                switchPlan: ProfileSwitchPlan(from: activeProfileID, to: profile.id)
            )
        )
        return state
    }

    @discardableResult
    public mutating func appendPINDigit(_ digit: Character) -> ProfileGatewayState {
        guard case .enteringPIN(var challenge) = state, !challenge.isVerifying else { return state }
        if challenge.lastError != nil { challenge.lastError = nil }
        challenge.entry.append(digit)
        state = .enteringPIN(challenge)
        return state
    }

    @discardableResult
    public mutating func deletePINDigit() -> ProfileGatewayState {
        guard case .enteringPIN(var challenge) = state, !challenge.isVerifying else { return state }
        if challenge.lastError != nil { challenge.lastError = nil }
        challenge.entry.deleteLast()
        state = .enteringPIN(challenge)
        return state
    }

    /// Clears the entry and returns the submission the integrator must verify.
    /// The entry is cleared before dispatch so a re-trigger cannot reuse the
    /// same digits (the same trick the Android `LaunchedEffect` plays).
    public mutating func finishPINEntry(now: Date = Date()) -> (profileID: Int, pin: String)? {
        guard case .enteringPIN(var challenge) = state,
              challenge.entry.isComplete,
              !challenge.isVerifying,
              !challenge.lock.isLockedOut(at: now)
        else { return nil }
        let submission = (challenge.profile.id, challenge.entry.digits)
        challenge.entry.reset()
        challenge.isVerifying = true
        state = .enteringPIN(challenge)
        return submission
    }

    /// Feeds the verification result back into the state machine.
    @discardableResult
    public mutating func applyVerification(
        _ result: ProfilePINVerification,
        for profileID: Int,
        now: Date = Date()
    ) -> ProfileGatewayState {
        guard case .enteringPIN(var challenge) = state, challenge.profile.id == profileID else { return state }
        challenge.isVerifying = false
        if result.unlocked {
            challenge.lock.recordSuccess()
            state = .completed(
                ProfileSelectionOutcome(
                    profile: challenge.profile,
                    switchPlan: ProfileSwitchPlan(from: activeProfileID, to: challenge.profile.id)
                )
            )
            return state
        }
        if result.retryAfterSeconds > 0 {
            // Server-side throttle: mirror it into the local lockout window.
            challenge.lock.lockedUntil = now.addingTimeInterval(TimeInterval(result.retryAfterSeconds))
            challenge.lastError = .lockedOut(retryAfterSeconds: result.retryAfterSeconds)
        } else {
            let lockoutTriggered = challenge.lock.recordFailure(at: now)
            challenge.lastError = lockoutTriggered
                ? .lockedOut(retryAfterSeconds: challenge.lock.retryAfterSeconds(at: now))
                : .incorrectPIN(remainingAttempts: challenge.lock.remainingAttempts)
        }
        challenge.entry.reset()
        state = .enteringPIN(challenge)
        return state
    }

    public mutating func cancelPINEntry() {
        state = .browsing
    }
}
