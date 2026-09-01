import XCTest
@testable import NuvioTV

final class ProfileGatewayTests: XCTestCase {

    // MARK: - Fixtures

    private func tvProfile(
        index: Int = 1,
        name: String = "Profile 1",
        color: String = "#1E88E5",
        avatarURL: String? = nil,
        usesPrimaryAddons: Bool = false
    ) throws -> TVProfile {
        var json: [String: Any] = [
            "id": "srv-\(index)", "profile_index": index, "name": name,
            "avatar_color_hex": color, "uses_primary_addons": usesPrimaryAddons
        ]
        if let avatarURL { json["avatar_url"] = avatarURL }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(TVProfile.self, from: data)
    }

    private func profile(
        id: Int = 2,
        name: String = "Kids",
        locked: Bool = false,
        backgroundID: String? = nil,
        backgroundURL: String? = nil
    ) -> GatewayProfile {
        GatewayProfile(
            id: id, name: name, avatarColorHex: "#43A047", avatarID: nil, avatarURL: nil,
            profileBackgroundID: backgroundID, profileBackgroundURL: backgroundURL,
            usesPrimaryAddons: false, usesPrimaryPlugins: false,
            lock: locked ? .pinLocked : .unlocked
        )
    }

    // MARK: - Schema mapping from the existing tvOS type

    func testSchemaMappingFromTVProfile() throws {
        let tv = try tvProfile(index: 3, name: "Guest Room", color: "#D81B60", avatarURL: "https://cdn/avatar.png", usesPrimaryAddons: true)
        let mapped = GatewayProfile(tvProfile: tv)

        XCTAssertEqual(mapped.id, 3)
        XCTAssertEqual(mapped.serverID, "srv-3")
        XCTAssertEqual(mapped.name, "Guest Room")
        XCTAssertEqual(mapped.avatarColorHex, "#D81B60")
        XCTAssertEqual(mapped.avatarURL, "https://cdn/avatar.png")
        XCTAssertEqual(mapped.avatarDisplayURL, "https://cdn/avatar.png")
        XCTAssertTrue(mapped.usesPrimaryAddons)
        XCTAssertFalse(mapped.usesPrimaryPlugins, "TVProfile has no plugin-inheritance field: recorded gap")
        XCTAssertNil(mapped.profileBackgroundID, "TVProfile has no background field: recorded gap")
        XCTAssertNil(mapped.profileBackgroundURL, "TVProfile has no background URL field: recorded gap")
        XCTAssertEqual(mapped.lock.kind, .none, "TVProfile has no PIN state: recorded gap")
    }

    func testSchemaDefaultsMirrorAndroid() {
        let primary = profile(id: 1, name: "Profile 1")
        XCTAssertEqual(GatewayProfile.primaryProfileID, 1)
        XCTAssertTrue(primary.isPrimary)
        XCTAssertFalse(profile(id: 2).isPrimary)
        XCTAssertEqual(GatewayProfile.maxProfiles, 6, "Android ProfileManager.MAX_PROFILES")
        XCTAssertEqual(ProfileAvatarPalette.colors.count, 8, "Android PROFILE_AVATAR_COLORS")
        XCTAssertEqual(ProfileAvatarPalette.defaultHex, "#1E88E5")
    }

    func testAvatarBlankURLFallsBackToInitials() {
        let p = GatewayProfile(id: 2, name: "Den", avatarColorHex: "#1E88E5", avatarURL: "  ")
        XCTAssertNil(p.avatarDisplayURL, "Android avatarUrl.takeIf { it.isNotBlank() }")
    }

    func testBackgroundResolutionMirrorsAndroid() throws {
        let gated = profile(backgroundID: "aurora", backgroundURL: "https://bg/custom.png")
        XCTAssertNil(gated.resolvedBackground(hasAccess: false), "entitlement gate blocks backgrounds")
        XCTAssertEqual(
            gated.resolvedBackground(hasAccess: true),
            .some(.custom(url: "https://bg/custom.png")),
            "trimmed non-blank custom URL wins over catalog id"
        )
        let blank = profile(backgroundID: "aurora", backgroundURL: "   ")
        XCTAssertEqual(
            blank.resolvedBackground(hasAccess: true),
            .some(.catalog(id: "aurora")),
            "blank URL falls back to the catalog id"
        )
        XCTAssertNil(profile().resolvedBackground(hasAccess: true))
    }

    // MARK: - Name validation (Android name-safety rules)

    func testNameValidationTrimsAndRejectsBlank() {
        guard case .valid(let trimmed) = ProfileNameValidator.validate("  Movie Night  ") else {
            return XCTFail("expected valid")
        }
        XCTAssertEqual(trimmed, "Movie Night")
        XCTAssertEqual(ProfileNameValidator.validate("    "), .empty)
        XCTAssertEqual(ProfileNameValidator.validate(""), .empty)
    }

    func testNameValidationCapsAtTwentyCharacters() {
        let raw = String(repeating: "a", count: 27)
        XCTAssertEqual(ProfileNameValidator.sanitize(raw).count, 20)
        XCTAssertEqual(ProfileNameValidator.maxLength, 20)
        if case .valid(let capped) = ProfileNameValidator.validate(raw) {
            XCTAssertEqual(capped.count, 20)
        } else {
            XCTFail("expected capped valid name")
        }
    }

    func testDefaultNameFallbackMirrorsProfileManager() {
        XCTAssertEqual(ProfileNameValidator.defaultName(for: 4), "Profile 4")
        XCTAssertEqual(ProfileNameValidator.normalized("   ", profileID: 4), "Profile 4")
        XCTAssertEqual(ProfileNameValidator.normalized("  Kids ", profileID: 4), "Kids")
    }

    // MARK: - PIN entry and set flow

    func testPinEntryCapsAtFourDigitsAndOnlyDigits() {
        var entry = ProfilePinEntry()
        XCTAssertEqual(ProfilePinEntry.length, 4, "Android ProfilePinLength")
        XCTAssertTrue(entry.append("1"))
        XCTAssertTrue(entry.append(2))
        XCTAssertFalse(entry.append("x"))
        XCTAssertFalse(entry.append("٣"), "ASCII digits only")
        XCTAssertFalse(entry.isComplete)
        entry.append(3); entry.append(4)
        XCTAssertTrue(entry.isComplete)
        XCTAssertFalse(entry.append(5), "caps at 4 digits")
        XCTAssertTrue(entry.deleteLast())
        XCTAssertEqual(entry.filledCount, 3)
        entry.reset()
        XCTAssertTrue(entry.isEmpty)
    }

    func testPinSetupTwoStageFlowWithMismatchRestart() {
        var setup = ProfilePinSetup()
        for digit in "1234" { _ = setup.append(digit) }
        XCTAssertEqual(setup.submitIfComplete(), .awaitingConfirmation)
        for digit in "5678" { _ = setup.append(digit) }
        XCTAssertEqual(setup.submitIfComplete(), .mismatch)
        XCTAssertEqual(setup.stage, .create, "mismatch restarts at create stage")

        for digit in "1357" { _ = setup.append(digit) }
        _ = setup.submitIfComplete()
        for digit in "1357" { _ = setup.append(digit) }
        XCTAssertEqual(setup.submitIfComplete(), .ready("1357"))
    }

    func testLockStateRetryLimitAndLockout() {
        var lock = ProfileLockState.pinLocked
        XCTAssertEqual(lock.maxAttempts, ProfileLockState.defaultMaxAttempts)
        let start = Date(timeIntervalSince1970: 1000)

        XCTAssertFalse(lock.recordFailure(at: start))
        XCTAssertFalse(lock.recordFailure(at: start))
        XCTAssertEqual(lock.remainingAttempts, 3)
        XCTAssertFalse(lock.recordFailure(at: start))
        XCTAssertFalse(lock.recordFailure(at: start))
        XCTAssertEqual(lock.remainingAttempts, 1)

        XCTAssertTrue(lock.recordFailure(at: start), "5th failure starts lockout")
        XCTAssertTrue(lock.isLockedOut(at: start))
        XCTAssertEqual(lock.retryAfterSeconds(at: start), 30, "default lockout interval")
        XCTAssertEqual(lock.remainingAttempts, 5, "attempts reset after lockout")
        XCTAssertFalse(lock.isLockedOut(at: start.addingTimeInterval(31)))

        lock.recordSuccess()
        XCTAssertFalse(lock.isLockedOut(at: start))
        XCTAssertEqual(lock.failedAttempts, 0)
    }

    // MARK: - Selection state machine (locked vs unlocked flow)

    func testUnlockedProfileSelectsImmediatelyWithSwitchPlan() {
        var controller = ProfileGatewayController(activeProfileID: 1)
        _ = controller.choose(profile: profile(id: 2, name: "Den"))

        guard case .completed(let outcome) = controller.state else {
            return XCTFail("unlocked profile should complete immediately")
        }
        XCTAssertEqual(outcome.profile.id, 2)
        XCTAssertTrue(outcome.switchPlan.isSwitch)
        XCTAssertEqual(outcome.switchPlan.fromProfileID, 1)
        XCTAssertEqual(outcome.switchPlan.toProfileID, 2)
    }

    func testLockedProfileRequiresPINThenUnlocks() {
        var controller = ProfileGatewayController(activeProfileID: 1)
        let locked = profile(id: 3, name: "Parental", locked: true)
        _ = controller.choose(profile: locked)

        guard case .enteringPIN(let challenge) = controller.state else {
            return XCTFail("locked profile should route to the PIN overlay")
        }
        XCTAssertEqual(challenge.profile.id, 3)
        XCTAssertTrue(challenge.entry.isEmpty)

        for digit in "9999" { _ = controller.appendPINDigit(digit) }
        guard case .enteringPIN(let filling) = controller.state else {
            return XCTFail("state should remain in the PIN overlay while entering")
        }
        XCTAssertEqual(filling.entry.filledCount, 4)

        let submission = controller.finishPINEntry()
        XCTAssertEqual(submission?.profileID, 3)
        XCTAssertEqual(submission?.pin, "9999")

        _ = controller.applyVerification(.success, for: 3)
        guard case .completed(let outcome) = controller.state else {
            return XCTFail("verified PIN should complete selection")
        }
        XCTAssertEqual(outcome.profile.id, 3)
        XCTAssertTrue(outcome.switchPlan.isSwitch)
    }

    func testWrongPINTracksAttemptsUntilLockout() {
        var controller = ProfileGatewayController(activeProfileID: 1)
        _ = controller.choose(profile: profile(id: 3, name: "Parental", locked: true))
        let start = Date(timeIntervalSince1970: 500)

        for attempt in 0..<ProfileLockState.defaultMaxAttempts {
            for digit in "1111" { _ = controller.appendPINDigit(digit) }
            _ = controller.finishPINEntry(now: start)
            _ = controller.applyVerification(.failure(), for: 3, now: start)

            guard case .enteringPIN(let challenge) = controller.state else {
                return XCTFail("attempt \(attempt) should stay in the overlay")
            }
            XCTAssertTrue(challenge.entry.isEmpty, "entry clears after each submission")
            if attempt < ProfileLockState.defaultMaxAttempts - 1 {
                XCTAssertEqual(
                    challenge.lastError,
                    .incorrectPIN(remainingAttempts: ProfileLockState.defaultMaxAttempts - attempt - 1)
                )
            } else {
                XCTAssertEqual(challenge.lastError, .lockedOut(retryAfterSeconds: 30))
            }
        }

        // Locked out: further attempts are gated client-side.
        for digit in "2222" { _ = controller.appendPINDigit(digit) }
        XCTAssertNil(controller.finishPINEntry(now: start.addingTimeInterval(5)))
    }

    func testServerThrottleMirrorsRetryAfterIntoLocalLockout() {
        var controller = ProfileGatewayController(activeProfileID: 1)
        _ = controller.choose(profile: profile(id: 3, locked: true))
        let now = Date(timeIntervalSince1970: 800)
        for digit in "1234" { _ = controller.appendPINDigit(digit) }
        _ = controller.finishPINEntry(now: now)
        _ = controller.applyVerification(.failure(retryAfterSeconds: 45), for: 3, now: now)

        guard case .enteringPIN(let throttled) = controller.state else { return XCTFail() }
        XCTAssertEqual(throttled.lastError, .lockedOut(retryAfterSeconds: 45))
        XCTAssertEqual(throttled.lock.retryAfterSeconds(at: now), 45)
    }

    func testCancelReturnsToBrowsing() {
        var controller = ProfileGatewayController(activeProfileID: 1)
        _ = controller.choose(profile: profile(id: 3, locked: true))
        controller.cancelPINEntry()
        XCTAssertEqual(controller.state, .browsing)
    }

    // MARK: - Transactional switch staging

    func testSwitchPlanStagesEveryScopedStoreOnce() {
        let plan = ProfileSwitchPlan(from: 1, to: 4)
        XCTAssertFalse(plan.isNoOp)
        XCTAssertEqual(plan.stagedResets.count, ProfileScopedStore.allCases.count)
        XCTAssertEqual(
            Set(plan.stagedResets.map(\.store)),
            Set(ProfileScopedStore.allCases),
            "every profile-scoped store switches together"
        )
        XCTAssertTrue(plan.stagedResets.allSatisfy { $0.fromProfileID == 1 && $0.toProfileID == 4 })
        XCTAssertTrue(ProfileSwitchPlan(from: 2, to: 2).isNoOp)
    }

    func testTransactionCommitAppliesAllStagedResetsInOrder() {
        let plan = ProfileSwitchPlan(from: 1, to: 5)
        var transaction = plan.transaction()

        XCTAssertEqual(transaction.phase, .staged)
        var appliedOrder: [ProfileScopedStore] = []
        while let reset = transaction.nextReset() {
            appliedOrder.append(reset.store)
            XCTAssertEqual(reset.toProfileID, 5)
            transaction.recordApplied()
        }
        XCTAssertEqual(appliedOrder, ProfileScopedStore.allCases.map { $0 })
        XCTAssertEqual(transaction.applied.count, ProfileScopedStore.allCases.count)
        XCTAssertTrue(transaction.isComplete)
        XCTAssertTrue(transaction.commit())
        XCTAssertEqual(transaction.phase, .committed)
        XCTAssertNil(transaction.nextReset(), "committed transaction stages nothing more")
    }

    func testTransactionRollbackReturnsAppliedResetsInReverse() {
        var transaction = ProfileSwitchTransaction(plan: ProfileSwitchPlan(from: 3, to: 1))
        var applied: [ProfileStoreReset] = []
        while let reset = transaction.nextReset(), applied.count < 3 {
            applied.append(reset)
            transaction.recordApplied()
        }
        XCTAssertEqual(transaction.applied.count, 3)

        let undo = transaction.rollback()
        XCTAssertEqual(undo, applied.reversed(), "rollback undoes newest first")
        XCTAssertEqual(transaction.phase, .rolledBack)
        XCTAssertTrue(transaction.applied.isEmpty)
        XCTAssertNil(transaction.nextReset())
        XCTAssertFalse(transaction.commit(), "rolled back transaction cannot commit")
        XCTAssertTrue(transaction.rollback().isEmpty)
    }

    func testTransactionCommitRejectedWhenIncomplete() {
        var transaction = ProfileSwitchTransaction(plan: ProfileSwitchPlan(from: 1, to: 2))
        _ = transaction.nextReset()
        XCTAssertFalse(transaction.commit(), "cannot commit with pending resets")
        transaction.recordApplied()
        XCTAssertFalse(transaction.commit())
    }

    func testNoOpTransactionIsBornCommitted() {
        let transaction = ProfileSwitchTransaction(plan: ProfileSwitchPlan(from: 1, to: 1))
        XCTAssertEqual(transaction.phase, .committed)
        XCTAssertTrue(transaction.isComplete)
    }

    // MARK: - Editor dirty-state transitions

    func testEditorDraftTracksDirtyStateAndReset() {
        var draft = ProfileEditorDraft(profile: profile(id: 2, name: "Den"))
        XCTAssertFalse(draft.isDirty)

        draft.setName("Denny")
        XCTAssertTrue(draft.isDirty)

        draft.reset()
        XCTAssertFalse(draft.isDirty)
        XCTAssertEqual(draft.name, "Den")
        XCTAssertNil(draft.pendingPIN)
        XCTAssertFalse(draft.lockEnabled)
    }

    func testEditorDraftAppliesChangesAndTracksLockTransitions() {
        let original = profile(id: 2, name: " Den ", backgroundID: "aurora")
        var draft = ProfileEditorDraft(profile: original)

        draft.setName("  Denny ")
        draft.avatarColorHex = "#E53935"
        draft.background = .custom(url: "https://bg/den.png")
        draft.usesPrimaryAddons = true
        draft.usesPrimaryPlugins = true
        draft.lockEnabled = true
        draft.pendingPIN = "2468"
        XCTAssertTrue(draft.isDirty)
        XCTAssertTrue(draft.lockChanged)

        let updated = draft.apply()
        XCTAssertEqual(updated.id, 2)
        XCTAssertEqual(updated.name, "Denny", "name is trimmed on save")
        XCTAssertEqual(updated.avatarColorHex, "#E53935")
        XCTAssertEqual(updated.profileBackgroundID, nil)
        XCTAssertEqual(updated.profileBackgroundURL, "https://bg/den.png")
        XCTAssertTrue(updated.usesPrimaryAddons)
        XCTAssertTrue(updated.usesPrimaryPlugins)
        XCTAssertEqual(updated.lock.kind, .pin)
    }

    func testEditorDraftClearingBackgroundAndLock() {
        var draft = ProfileEditorDraft(profile: profile(id: 4, name: "Kids", locked: true))
        XCTAssertTrue(draft.lockEnabled)

        draft.background = nil
        draft.lockEnabled = false
        XCTAssertTrue(draft.isDirty)

        let updated = draft.apply()
        XCTAssertNil(updated.profileBackgroundID)
        XCTAssertNil(updated.profileBackgroundURL)
        XCTAssertEqual(updated.lock.kind, .none)
        XCTAssertTrue(draft.lockChanged, "disabling a stored lock is a lock change to push")
    }

    func testEditorDraftSaveRequiresNonBlankName() {
        var draft = ProfileEditorDraft(profile: profile(id: 2, name: "Den"))
        XCTAssertTrue(draft.canSave)

        draft.setName("     ")
        XCTAssertFalse(draft.canSave, "save is disabled while the name is blank (Android isNotBlank gate)")

        let updated = draft.apply()
        XCTAssertEqual(updated.name, "Den", "empty name keeps the stored name")
    }
}
