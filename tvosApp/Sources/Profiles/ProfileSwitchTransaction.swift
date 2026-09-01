import Foundation

// MARK: - Profile-scoped stores

/// Stores whose in-memory state is scoped to the active profile and must be
/// reset together on a switch (the parity spec's "one profile transaction
/// that switches every profile-scoped store together"). The integrator maps
/// each case onto the concrete store reset.
public enum ProfileScopedStore: String, CaseIterable, Codable, Sendable {
    case watchProgress
    case library
    case homeCatalog
    case collections
    case homePreferences
    case integrations
    case discovery

    /// UserDefaults storage identity for the profile-scoped data, when it is
    /// persisted locally (e.g. `nuvio.tv.watchProgress.v2.<profile>`).
    public func storageKey(profileID: Int) -> String {
        switch self {
        case .watchProgress:
            return "nuvio.tv.watchProgress.v2.\(profileID)"
        case .library:
            return "nuvio.tv.library.v1"
        case .homeCatalog:
            return "nuvio.tv.home.v1.\(profileID)"
        case .collections:
            return "nuvio.tv.collections.v1.\(profileID)"
        case .homePreferences:
            return "nuvio.tv.homePreferences.v1.\(profileID)"
        case .integrations:
            return "nuvio.tv.integrations.v1.\(profileID)"
        case .discovery:
            return "nuvio.tv.discovery.v1.\(profileID)"
        }
    }
}

/// One staged reset: drop the outgoing profile's in-memory state for `store`
/// and prepare it for `toProfileID`.
public struct ProfileStoreReset: Equatable, Sendable {
    public let store: ProfileScopedStore
    public let fromProfileID: Int
    public let toProfileID: Int

    public init(store: ProfileScopedStore, fromProfileID: Int, toProfileID: Int) {
        self.store = store
        self.fromProfileID = fromProfileID
        self.toProfileID = toProfileID
    }
}

// MARK: - Switch plan

/// Stages a profile switch without applying anything. A switch to the same
/// profile is a no-op.
public struct ProfileSwitchPlan: Equatable, Sendable {
    public let fromProfileID: Int
    public let toProfileID: Int
    public let stagedResets: [ProfileStoreReset]

    public init(
        from fromProfileID: Int,
        to toProfileID: Int,
        stores: [ProfileScopedStore] = ProfileScopedStore.allCases
    ) {
        self.fromProfileID = fromProfileID
        self.toProfileID = toProfileID
        if fromProfileID == toProfileID {
            stagedResets = []
        } else {
            stagedResets = stores.map {
                ProfileStoreReset(store: $0, fromProfileID: fromProfileID, toProfileID: toProfileID)
            }
        }
    }

    public var isNoOp: Bool { stagedResets.isEmpty }
    public var isSwitch: Bool { !stagedResets.isEmpty }

    public func transaction() -> ProfileSwitchTransaction {
        ProfileSwitchTransaction(plan: self)
    }
}

// MARK: - Transactional switch

/// Transactional wrapper around a `ProfileSwitchPlan`. The integrator drives
/// it: pull `nextReset()`, apply the reset to the concrete store, then
/// `recordApplied()`. When every reset is applied, `commit()` finalizes the
/// switch; on a failure, `rollback()` returns the already-applied resets in
/// reverse order so the integrator can restore the outgoing profile before
/// abandoning the switch. Nothing is applied by this type itself.
public struct ProfileSwitchTransaction: Equatable, Sendable {
    public enum Phase: String, Equatable, Sendable {
        case staged
        case applying
        case committed
        case rolledBack
    }

    public let plan: ProfileSwitchPlan
    public private(set) var phase: Phase
    public private(set) var applied: [ProfileStoreReset]

    public init(plan: ProfileSwitchPlan) {
        self.plan = plan
        phase = plan.isNoOp ? .committed : .staged
        applied = []
    }

    public var pending: [ProfileStoreReset] {
        Array(plan.stagedResets.dropFirst(applied.count))
    }

    public var isComplete: Bool { applied.count == plan.stagedResets.count }

    /// Resets to undo when abandoning: the applied ones, newest first.
    public var rollbackResets: [ProfileStoreReset] { applied.reversed() }

    /// Returns the next staged reset, or nil once everything is applied or
    /// the transaction is finalized.
    @discardableResult
    public mutating func nextReset() -> ProfileStoreReset? {
        guard phase == .staged || phase == .applying else { return nil }
        guard let next = pending.first else { return nil }
        phase = .applying
        return next
    }

    /// Confirms the reset returned by `nextReset()` was applied successfully.
    public mutating func recordApplied() {
        guard phase == .applying, let next = pending.first else { return }
        applied.append(next)
    }

    /// Marks the current reset as failed and rolls the transaction back.
    /// Returns the resets to undo (applied resets in reverse order).
    @discardableResult
    public mutating func rollback() -> [ProfileStoreReset] {
        guard phase == .staged || phase == .applying else { return [] }
        let undo = rollbackResets
        applied = []
        phase = .rolledBack
        return undo
    }

    /// Finalizes the switch once every staged reset is applied.
    @discardableResult
    public mutating func commit() -> Bool {
        guard isComplete, phase == .applying || phase == .staged else { return false }
        phase = .committed
        return true
    }
}
