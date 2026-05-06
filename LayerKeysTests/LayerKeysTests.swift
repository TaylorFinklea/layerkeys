import ServiceManagement
import SwiftUI
import XCTest
@testable import LayerKeys

final class LayerKeysTests: XCTestCase {
    private let triggerDownTimestamp: UInt64 = 1_000_000_000

    func testSpaceTriggerEntersNavigationMode() {
        var machine = LayerStateMachine()

        XCTAssertTrue(machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp))
        XCTAssertEqual(machine.mode, .nav)
    }

    func testTriggerKeySwitchesToNumpadUntilEscapeReleased() {
        var machine = LayerStateMachine()
        _ = machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp)

        XCTAssertTrue(machine.handleKeyEvent(keyCode: InputKey.a.keyCode, isKeyDown: true))
        XCTAssertEqual(machine.mode, .numpad)

        XCTAssertTrue(machine.handleKeyEvent(keyCode: InputKey.a.keyCode, isKeyDown: false))
        XCTAssertEqual(machine.mode, .numpad)

        let result = machine.handleTriggerKeyUp(timestamp: triggerDownTimestamp + 50_000_000)
        XCTAssertTrue(result.modeDidChange)
        XCTAssertFalse(result.shouldEmitEscape)
        XCTAssertEqual(machine.mode, .off)
    }

    func testHoldingABeforeTriggerDoesNotStartInNumpadMode() {
        var machine = LayerStateMachine()

        XCTAssertFalse(machine.handleKeyEvent(keyCode: InputKey.a.keyCode, isKeyDown: true))
        XCTAssertTrue(machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp))
        XCTAssertEqual(machine.mode, .nav)

        let result = machine.handleTriggerKeyUp(timestamp: triggerDownTimestamp + 50_000_000)
        XCTAssertTrue(result.shouldEmitEscape)
        XCTAssertEqual(machine.mode, .off)
    }

    func testTapTriggerEmitsEscapeOnTriggerRelease() {
        var machine = LayerStateMachine()
        _ = machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp)

        let result = machine.handleTriggerKeyUp(timestamp: triggerDownTimestamp + 50_000_000)
        XCTAssertTrue(result.modeDidChange)
        XCTAssertTrue(result.shouldEmitEscape)
        XCTAssertEqual(machine.mode, .off)
    }

    func testHoldingTriggerDoesNotEmitEscapeOnRelease() {
        var machine = LayerStateMachine()
        _ = machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp)

        let result = machine.handleTriggerKeyUp(timestamp: triggerDownTimestamp + 500_000_000)
        XCTAssertTrue(result.modeDidChange)
        XCTAssertFalse(result.shouldEmitEscape)
        XCTAssertEqual(machine.mode, .off)
    }

    func testUsingAnotherKeySuppressesTapEscape() {
        var machine = LayerStateMachine()
        _ = machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp)

        XCTAssertFalse(machine.handleKeyEvent(keyCode: InputKey.q.keyCode, isKeyDown: true))

        let result = machine.handleTriggerKeyUp(timestamp: triggerDownTimestamp + 50_000_000)
        XCTAssertFalse(result.shouldEmitEscape)
    }

    func testResolvedMappingsPreferNumpadWhileActive() {
        let mappings = MappingProfile.default.resolvedMappings

        XCTAssertEqual(
            mappings.remappedKeyCode(for: InputKey.h.keyCode, mode: .nav),
            NavigationTargetKey.leftArrow.keyCode
        )
        XCTAssertEqual(
            mappings.remappedKeyCode(for: InputKey.j.keyCode, mode: .numpad),
            NumpadTargetKey.keypad4.keyCode
        )
        XCTAssertNil(mappings.remappedKeyCode(for: InputKey.q.keyCode, mode: .nav))
    }

    func testNumericPadTargetsAreTagged() {
        let mappings = MappingProfile.default.resolvedMappings
        XCTAssertTrue(mappings.targetRequiresNumericPadFlag(NumpadTargetKey.keypad7.keyCode))
        XCTAssertFalse(mappings.targetRequiresNumericPadFlag(NavigationTargetKey.leftArrow.keyCode))
    }

    func testNumpadTargetsUseKeypadKeyCodes() {
        XCTAssertEqual(NumpadTargetKey.keypad4.keyCode, 0x56)
        XCTAssertEqual(NumpadTargetKey.keypad5.keyCode, 0x57)
        XCTAssertEqual(NumpadTargetKey.keypad6.keyCode, 0x58)
        XCTAssertEqual(NumpadTargetKey.keypadDecimal.keyCode, 0x41)
    }

    func testDefaultNumpadProfileOnlyContainsNineDigitBindings() {
        let mappings = MappingProfile.default.resolvedMappings

        XCTAssertEqual(mappings.remappedKeyCode(for: InputKey.u.keyCode, mode: .numpad), NumpadTargetKey.keypad7.keyCode)
        XCTAssertEqual(mappings.remappedKeyCode(for: InputKey.i.keyCode, mode: .numpad), NumpadTargetKey.keypad8.keyCode)
        XCTAssertEqual(mappings.remappedKeyCode(for: InputKey.o.keyCode, mode: .numpad), NumpadTargetKey.keypad9.keyCode)
        XCTAssertEqual(mappings.remappedKeyCode(for: InputKey.j.keyCode, mode: .numpad), NumpadTargetKey.keypad4.keyCode)
        XCTAssertEqual(mappings.remappedKeyCode(for: InputKey.k.keyCode, mode: .numpad), NumpadTargetKey.keypad5.keyCode)
        XCTAssertEqual(mappings.remappedKeyCode(for: InputKey.l.keyCode, mode: .numpad), NumpadTargetKey.keypad6.keyCode)
        XCTAssertEqual(mappings.remappedKeyCode(for: InputKey.m.keyCode, mode: .numpad), NumpadTargetKey.keypad1.keyCode)
        XCTAssertEqual(mappings.remappedKeyCode(for: InputKey.comma.keyCode, mode: .numpad), NumpadTargetKey.keypad2.keyCode)
        XCTAssertEqual(mappings.remappedKeyCode(for: InputKey.period.keyCode, mode: .numpad), NumpadTargetKey.keypad3.keyCode)
        XCTAssertNil(mappings.remappedKeyCode(for: InputKey.space.keyCode, mode: .numpad))
        XCTAssertNil(mappings.remappedKeyCode(for: InputKey.semicolon.keyCode, mode: .numpad))
    }

    @MainActor
    func testLegacyStoredDefaultMigratesToCurrentDefault() throws {
        let suiteName = "LayerKeysTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create test defaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = MappingStore(defaults: defaults)
        try store.save(.legacyDefault)

        let migrated = store.load()
        XCTAssertEqual(migrated, .default)
        XCTAssertEqual(store.load(), .default)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testInputKeyDigitKeycodes() {
        XCTAssertEqual(InputKey.one.keyCode, 0x12)
        XCTAssertEqual(InputKey.two.keyCode, 0x13)
        XCTAssertEqual(InputKey.three.keyCode, 0x14)
        XCTAssertEqual(InputKey.four.keyCode, 0x15)
        XCTAssertEqual(InputKey.five.keyCode, 0x17)
        XCTAssertEqual(InputKey.six.keyCode, 0x16)
        XCTAssertEqual(InputKey.seven.keyCode, 0x1A)
        XCTAssertEqual(InputKey.eight.keyCode, 0x1C)
        XCTAssertEqual(InputKey.nine.keyCode, 0x19)
        XCTAssertEqual(InputKey.zero.keyCode, 0x1D)
    }

    func testInputKeyPunctuationKeycodes() {
        XCTAssertEqual(InputKey.grave.keyCode, 0x32)
        XCTAssertEqual(InputKey.minus.keyCode, 0x1B)
        XCTAssertEqual(InputKey.equal.keyCode, 0x18)
        XCTAssertEqual(InputKey.leftBracket.keyCode, 0x21)
        XCTAssertEqual(InputKey.rightBracket.keyCode, 0x1E)
        XCTAssertEqual(InputKey.backslash.keyCode, 0x2A)
        XCTAssertEqual(InputKey.quote.keyCode, 0x27)
        XCTAssertEqual(InputKey.semicolon.keyCode, 0x29)
    }

    func testInputKeyISOSectionKeycode() {
        XCTAssertEqual(InputKey.sectionKey.keyCode, 0x0A)
    }

    func testInputKeyAllCasesContainsEveryExpectedCase() {
        let expected: Set<InputKey> = [
            .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m,
            .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z,
            .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .zero,
            .grave, .minus, .equal, .leftBracket, .rightBracket, .backslash,
            .semicolon, .quote, .comma, .period, .slash, .space,
            .sectionKey,
        ]
        XCTAssertEqual(Set(InputKey.allCases), expected)
        XCTAssertEqual(InputKey.allCases.count, 49)
    }

    func testInputKeyCategoryGrouping() {
        XCTAssertEqual(InputKey.cases(in: .letters).count, 26)
        XCTAssertEqual(InputKey.cases(in: .digits).count, 10)
        XCTAssertEqual(InputKey.cases(in: .punctuation).count, 12)
        XCTAssertEqual(InputKey.cases(in: .iso).count, 1)

        let totalInCategories = InputKey.Category.allCases
            .reduce(0) { $0 + InputKey.cases(in: $1).count }
        XCTAssertEqual(totalInCategories, InputKey.allCases.count)

        XCTAssertEqual(InputKey.a.category, .letters)
        XCTAssertEqual(InputKey.five.category, .digits)
        XCTAssertEqual(InputKey.space.category, .punctuation)
        XCTAssertEqual(InputKey.leftBracket.category, .punctuation)
        XCTAssertEqual(InputKey.sectionKey.category, .iso)
    }

    func testTriggerProfileDefaultsMatchV010Behavior() {
        let triggers = TriggerProfile.default
        XCTAssertEqual(triggers.layerKey, .space)
        XCTAssertEqual(triggers.layerModifiers, [.control])
        XCTAssertEqual(triggers.numpadSubTrigger, .a)
        XCTAssertTrue(triggers.tapToEscapeEnabled)
    }

    func testTriggerModifierEventFlagsMatchCGEventFlags() {
        XCTAssertEqual(TriggerModifier.command.eventFlag, .maskCommand)
        XCTAssertEqual(TriggerModifier.control.eventFlag, .maskControl)
        XCTAssertEqual(TriggerModifier.option.eventFlag,  .maskAlternate)
        XCTAssertEqual(TriggerModifier.shift.eventFlag,   .maskShift)

        let combined: Set<TriggerModifier> = [.control, .option]
        let flags = combined.eventFlags
        XCTAssertTrue(flags.contains(.maskControl))
        XCTAssertTrue(flags.contains(.maskAlternate))
        XCTAssertFalse(flags.contains(.maskCommand))
        XCTAssertFalse(flags.contains(.maskShift))
    }

    func testLayerStateMachineUsesCustomTriggerKey() {
        let custom = TriggerProfile(
            layerKey: .semicolon,
            layerModifiers: [.command],
            numpadSubTrigger: .a,
            tapToEscapeEnabled: true
        )
        var machine = LayerStateMachine(triggers: custom)
        XCTAssertEqual(machine.layerTriggerKeyCode, InputKey.semicolon.keyCode)
        XCTAssertEqual(machine.layerTriggerRequiredFlags, .maskCommand)

        XCTAssertTrue(machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp))
        XCTAssertEqual(machine.mode, .nav)
    }

    func testCustomNumpadSubTriggerSwitchesLayer() {
        let custom = TriggerProfile(
            layerKey: .space,
            layerModifiers: [.control],
            numpadSubTrigger: .quote,
            tapToEscapeEnabled: true
        )
        var machine = LayerStateMachine(triggers: custom)
        _ = machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp)

        // Legacy sub-trigger `A` should NOT switch to numpad.
        XCTAssertFalse(machine.handleKeyEvent(keyCode: InputKey.a.keyCode, isKeyDown: true))
        XCTAssertEqual(machine.mode, .nav)

        // Custom sub-trigger should switch to numpad.
        XCTAssertTrue(machine.handleKeyEvent(keyCode: InputKey.quote.keyCode, isKeyDown: true))
        XCTAssertEqual(machine.mode, .numpad)
    }

    func testTapToEscapeDisabledViaTriggerProfile() {
        let custom = TriggerProfile(
            layerKey: .space,
            layerModifiers: [.control],
            numpadSubTrigger: .a,
            tapToEscapeEnabled: false
        )
        var machine = LayerStateMachine(triggers: custom)
        _ = machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp)

        let result = machine.handleTriggerKeyUp(timestamp: triggerDownTimestamp + 50_000_000)
        XCTAssertTrue(result.modeDidChange)
        XCTAssertFalse(result.shouldEmitEscape)
    }

    func testMappingProfileDecodesPreM2JsonWithDefaultTriggers() throws {
        let preM2Json = """
        {
            "navigation": [
                {"id":"00000000-0000-0000-0000-000000000001","source":"h","target":"leftArrow"}
            ],
            "numpad": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MappingProfile.self, from: preM2Json)
        XCTAssertEqual(decoded.navigation.count, 1)
        XCTAssertEqual(decoded.numpad.count, 0)
        XCTAssertEqual(decoded.triggers, .default)
    }

    func testMappingProfileRoundTripsPreservingTriggers() throws {
        let original = MappingProfile(
            navigation: [NavigationBinding(source: .h, target: .leftArrow)],
            numpad: [],
            triggers: TriggerProfile(
                layerKey: .semicolon,
                layerModifiers: [.command, .option],
                numpadSubTrigger: .quote,
                tapToEscapeEnabled: false
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MappingProfile.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDefaultProfileProducesNoTriggerValidationIssues() {
        XCTAssertEqual(MappingProfile.default.validateTriggers(), [])
    }

    func testTriggerValidationFlagsEmptyModifiersOnTypingKey() {
        let profile = MappingProfile(
            navigation: [],
            numpad: [],
            triggers: TriggerProfile(
                layerKey: .j,
                layerModifiers: [],
                numpadSubTrigger: .a,
                tapToEscapeEnabled: true
            )
        )
        let issues = profile.validateTriggers()
        XCTAssertEqual(issues, [.triggerNeedsModifiers(.j)])
    }

    func testTriggerValidationFlagsSubTriggerEqualsLayerKey() {
        let profile = MappingProfile(
            navigation: [],
            numpad: [],
            triggers: TriggerProfile(
                layerKey: .a,
                layerModifiers: [.control],
                numpadSubTrigger: .a,
                tapToEscapeEnabled: true
            )
        )
        XCTAssertTrue(profile.validateTriggers().contains(.subTriggerEqualsLayerKey))
    }

    func testTriggerValidationFlagsSubTriggerCollisionWithNavSource() {
        let profile = MappingProfile(
            navigation: [NavigationBinding(source: .h, target: .leftArrow)],
            numpad: [],
            triggers: TriggerProfile(
                layerKey: .space,
                layerModifiers: [.control],
                numpadSubTrigger: .h,
                tapToEscapeEnabled: true
            )
        )
        XCTAssertTrue(
            profile.validateTriggers().contains(.subTriggerConflictsWithNavSource(.h))
        )
    }

    func testTriggerChordSummaryFormatting() {
        let triggers = TriggerProfile(
            layerKey: .space,
            layerModifiers: [.control, .option],
            numpadSubTrigger: .a,
            tapToEscapeEnabled: true
        )
        // Modifiers rendered in the stable allCases order (command, control, option, shift).
        XCTAssertEqual(triggers.chordSummary, "\u{2303}\u{2325}Space")
    }

    // MARK: - M3 decide() seam

    private func defaultMappings() -> ResolvedMappings {
        MappingProfile.default.resolvedMappings
    }

    func testDecidePassesThroughSyntheticEscape() {
        var machine = LayerStateMachine()
        let decision = machine.decide(
            eventType: .keyDown,
            keyCode: LayerStateMachine.escapeKeyCode,
            currentFlags: [],
            isSyntheticEscape: true,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        XCTAssertEqual(decision, EventDecision(action: .passThrough, modeDidChange: false))
        XCTAssertFalse(machine.isLayerTriggerHeld)
    }

    func testDecidePassesThroughUnrelatedEventTypes() {
        var machine = LayerStateMachine()
        let decision = machine.decide(
            eventType: .mouseMoved,
            keyCode: 0,
            currentFlags: [],
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        XCTAssertEqual(decision.action, .passThrough)
    }

    func testDecideEntersLayerOnValidTriggerChord() {
        var machine = LayerStateMachine()
        let decision = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.space.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        XCTAssertEqual(decision, EventDecision(action: .enterLayerTrigger, modeDidChange: true))
        XCTAssertEqual(machine.mode, .nav)
    }

    func testDecideRejectsTriggerWithWrongModifiers() {
        var machine = LayerStateMachine()
        let decision = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.space.keyCode,
            currentFlags: .maskAlternate,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        XCTAssertEqual(decision.action, .passThrough)
        XCTAssertFalse(machine.isLayerTriggerHeld)
    }

    func testDecideEmitsEscapeOnQuickTriggerRelease() {
        var machine = LayerStateMachine()
        _ = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.space.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        let release = machine.decide(
            eventType: .keyUp,
            keyCode: InputKey.space.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp + 50_000_000,
            mappings: defaultMappings()
        )
        XCTAssertEqual(release.action, .exitLayerTrigger(emitEscape: true))
        XCTAssertTrue(release.modeDidChange)
        XCTAssertEqual(machine.mode, .off)
    }

    func testDecideSkipsEscapeWhenTapToEscapeDisabled() {
        let triggers = TriggerProfile(
            layerKey: .space,
            layerModifiers: [.control],
            numpadSubTrigger: .a,
            tapToEscapeEnabled: false
        )
        var machine = LayerStateMachine(triggers: triggers)
        _ = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.space.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        let release = machine.decide(
            eventType: .keyUp,
            keyCode: InputKey.space.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp + 50_000_000,
            mappings: defaultMappings()
        )
        XCTAssertEqual(release.action, .exitLayerTrigger(emitEscape: false))
    }

    func testDecideRemapsNavTargetWithoutNumericPadFlag() {
        var machine = LayerStateMachine()
        _ = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.space.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        let decision = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.h.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp + 10_000_000,
            mappings: defaultMappings()
        )
        XCTAssertEqual(
            decision.action,
            .remap(keyCode: NavigationTargetKey.leftArrow.keyCode, setNumericPadFlag: false)
        )
    }

    func testDecideRemapsNumpadTargetWithNumericPadFlag() {
        var machine = LayerStateMachine()
        _ = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.space.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        _ = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.a.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp + 10_000_000,
            mappings: defaultMappings()
        )
        let decision = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.j.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp + 20_000_000,
            mappings: defaultMappings()
        )
        XCTAssertEqual(
            decision.action,
            .remap(keyCode: NumpadTargetKey.keypad4.keyCode, setNumericPadFlag: true)
        )
    }

    func testDecidePassesThroughWhenNoLayerActive() {
        var machine = LayerStateMachine()
        let decision = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.h.keyCode,
            currentFlags: [],
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        XCTAssertEqual(decision.action, .passThrough)
    }

    func testDecideConsumesSubTriggerAndSwitchesToNumpad() {
        var machine = LayerStateMachine()
        _ = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.space.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        let decision = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.a.keyCode,
            currentFlags: .maskControl,
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp + 5_000_000,
            mappings: defaultMappings()
        )
        XCTAssertEqual(decision, EventDecision(action: .consume, modeDidChange: true))
        XCTAssertEqual(machine.mode, .numpad)
    }

    // MARK: - M3 sleep/wake recovery

    private final class SleepWakeRecorder {
        var reEnableTapCallCount = 0
        var restartEngineCallCount = 0
        var onErrorMessages: [String] = []
        var tapAliveResponse = true
    }

    private func makeHandler(recorder: SleepWakeRecorder) -> SleepWakeHandler {
        SleepWakeHandler(
            reEnableTap: { recorder.reEnableTapCallCount += 1 },
            isTapAlive: { recorder.tapAliveResponse },
            restartEngine: { recorder.restartEngineCallCount += 1 },
            onError: { recorder.onErrorMessages.append($0) },
            onRecover: {}
        )
    }

    func testSleepWakeWakeIsNoopWhenNoSleepSeen() {
        let recorder = SleepWakeRecorder()
        var handler = makeHandler(recorder: recorder)

        handler.didWake()

        XCTAssertEqual(recorder.reEnableTapCallCount, 0)
        XCTAssertEqual(recorder.restartEngineCallCount, 0)
        XCTAssertEqual(recorder.onErrorMessages, [])
    }

    func testSleepWakeReEnablesTapAfterSleep() {
        let recorder = SleepWakeRecorder()
        recorder.tapAliveResponse = true
        var handler = makeHandler(recorder: recorder)

        handler.willSleep()
        XCTAssertTrue(handler.sleepPending)

        handler.didWake()
        XCTAssertFalse(handler.sleepPending)
        XCTAssertEqual(recorder.reEnableTapCallCount, 1)
        XCTAssertEqual(recorder.restartEngineCallCount, 0)
        XCTAssertTrue(recorder.onErrorMessages.isEmpty)
    }

    func testSleepWakeRestartsEngineWhenTapDied() {
        let recorder = SleepWakeRecorder()
        recorder.tapAliveResponse = false
        var handler = makeHandler(recorder: recorder)

        handler.willSleep()
        handler.didWake()

        XCTAssertEqual(recorder.reEnableTapCallCount, 1)
        XCTAssertEqual(recorder.restartEngineCallCount, 1)
        XCTAssertEqual(recorder.onErrorMessages.count, 1)
    }

    func testSleepWakeSecondWakeWithoutSleepIsIgnored() {
        let recorder = SleepWakeRecorder()
        var handler = makeHandler(recorder: recorder)

        handler.willSleep()
        handler.didWake()
        handler.didWake()

        XCTAssertEqual(recorder.reEnableTapCallCount, 1)
    }

    // MARK: - M3 CapsLock + flag-hygiene regression

    func testCapsLockDuringHoldDoesNotSuppressTapToEscape() {
        var machine = LayerStateMachine()

        let down = machine.decide(
            eventType: .keyDown,
            keyCode: InputKey.space.keyCode,
            currentFlags: [.maskControl, .maskAlphaShift],
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp,
            mappings: defaultMappings()
        )
        XCTAssertEqual(down.action, .enterLayerTrigger)

        let up = machine.decide(
            eventType: .keyUp,
            keyCode: InputKey.space.keyCode,
            currentFlags: [.maskControl, .maskAlphaShift],
            isSyntheticEscape: false,
            timestamp: triggerDownTimestamp + 50_000_000,
            mappings: defaultMappings()
        )
        XCTAssertEqual(up.action, .exitLayerTrigger(emitEscape: true))
    }

    func testOutputFlagsAlwaysStripsMaskSecondaryFn() {
        let machine = LayerStateMachine()
        let cleaned = machine.outputFlags(for: [.maskSecondaryFn])
        XCTAssertFalse(cleaned.contains(.maskSecondaryFn))
    }

    func testOutputFlagsStripsDefaultTriggerControlModifier() {
        let machine = LayerStateMachine()
        let cleaned = machine.outputFlags(for: [.maskControl, .maskShift])
        XCTAssertFalse(cleaned.contains(.maskControl))
        XCTAssertTrue(cleaned.contains(.maskShift),
                      "Shift was not part of the trigger modifiers and should be preserved.")
    }

    func testOutputFlagsStripsCustomModifierSet() {
        let triggers = TriggerProfile(
            layerKey: .j,
            layerModifiers: [.command, .option],
            numpadSubTrigger: .a,
            tapToEscapeEnabled: true
        )
        let machine = LayerStateMachine(triggers: triggers)
        let cleaned = machine.outputFlags(for: [.maskCommand, .maskAlternate, .maskControl])
        XCTAssertFalse(cleaned.contains(.maskCommand))
        XCTAssertFalse(cleaned.contains(.maskAlternate))
        XCTAssertTrue(cleaned.contains(.maskControl),
                      "Control was not part of the custom trigger modifiers and should be preserved.")
    }

    func testOutputFlagsPreservesCapsLockAndShift() {
        let machine = LayerStateMachine()
        let cleaned = machine.outputFlags(for: [.maskControl, .maskAlphaShift, .maskShift])
        XCTAssertTrue(cleaned.contains(.maskAlphaShift))
        XCTAssertTrue(cleaned.contains(.maskShift))
        XCTAssertFalse(cleaned.contains(.maskControl))
    }

    // MARK: - AppModel updateAvailable

    @MainActor
    func testAppModelUpdateAvailableDefaultsFalse() {
        let model = AppModel(eventTapService: EventTapService(profile: .default))
        XCTAssertFalse(model.updateAvailable)
    }

    @MainActor
    func testAppModelSetUpdateAvailableTogglesFlag() {
        let model = AppModel(eventTapService: EventTapService(profile: .default))

        model.setUpdateAvailable(true)
        XCTAssertTrue(model.updateAvailable)

        model.setUpdateAvailable(false)
        XCTAssertFalse(model.updateAvailable)
    }

    // MARK: - SparkleUpdateObserver

    @MainActor
    func testSparkleUpdateObserverInvokesSetAvailable() {
        var observed: [Bool] = []
        let observer = SparkleUpdateObserver(setAvailable: { observed.append($0) })

        // Drive the observer through its public closure-based init rather than
        // exercising SPUUpdaterDelegate methods directly — we don't want to
        // construct SUAppcastItem (which requires a complex dictionary in
        // Sparkle 2.x) just to verify a 1-line forwarder. The delegate methods
        // each call `setAvailable(true|false)` and are covered by the
        // `xcodebuild build` link step plus the manual smoke test in Task 11.
        observer.applyTrueForTesting()
        observer.applyFalseForTesting()

        XCTAssertEqual(observed, [true, false])
    }

    // MARK: - SleepWakeHandler

    func testSleepWakeHandlerFiresOnRecoverAfterReEnableSucceeds() {
        var reEnableCount = 0
        var aliveSequence = [true]   // single probe after reEnableTap: alive
        var recoveredCount = 0
        var errorMessages: [String] = []

        var handler = SleepWakeHandler(
            reEnableTap: { reEnableCount += 1 },
            isTapAlive: {
                let next = aliveSequence.removeFirst()
                return next
            },
            restartEngine: { XCTFail("restartEngine should not be called when re-enable revives the tap") },
            onError: { errorMessages.append($0) },
            onRecover: { recoveredCount += 1 }
        )

        handler.willSleep()
        handler.didWake()

        XCTAssertEqual(reEnableCount, 1)
        XCTAssertEqual(recoveredCount, 1)
        XCTAssertTrue(errorMessages.isEmpty)
    }

    func testSleepWakeHandlerFiresOnRecoverAfterRestartEnginePath() {
        var reEnableCount = 0
        var restartCount = 0
        var aliveSequence = [false, true]  // dead after re-enable, alive after restart
        var recoveredCount = 0

        var handler = SleepWakeHandler(
            reEnableTap: { reEnableCount += 1 },
            isTapAlive: { aliveSequence.removeFirst() },
            restartEngine: { restartCount += 1 },
            onError: { _ in },
            onRecover: { recoveredCount += 1 }
        )

        handler.willSleep()
        handler.didWake()

        XCTAssertEqual(reEnableCount, 1)
        XCTAssertEqual(restartCount, 1)
        XCTAssertEqual(recoveredCount, 1)
    }

    func testSleepWakeHandlerSkipsRecoverWhenNoSleepPending() {
        var recoveredCount = 0
        var handler = SleepWakeHandler(
            reEnableTap: { XCTFail("should not re-enable without a prior sleep") },
            isTapAlive: { true },
            restartEngine: { XCTFail("should not restart without a prior sleep") },
            onError: { _ in },
            onRecover: { recoveredCount += 1 }
        )

        handler.didWake()

        XCTAssertEqual(recoveredCount, 0)
    }

    // MARK: - LaunchAtLoginController (M4a Phase A.2)

    @MainActor
    func testLaunchControllerReportsEnabledWhenStoreIsEnabled() {
        let store = StubLaunchAtLoginStore(initialStatus: .enabled)
        let controller = LaunchAtLoginController(store: store)

        XCTAssertTrue(controller.isEnabled)

        store.statusValue = .notRegistered
        XCTAssertFalse(controller.isEnabled)
    }

    @MainActor
    func testLaunchControllerRegistersWhenEnabled() throws {
        let store = StubLaunchAtLoginStore()
        let controller = LaunchAtLoginController(store: store)

        try controller.setEnabled(true)

        XCTAssertEqual(store.registerCallCount, 1)
        XCTAssertEqual(store.unregisterCallCount, 0)
        XCTAssertTrue(controller.isEnabled)
    }

    @MainActor
    func testLaunchControllerUnregistersWhenDisabled() throws {
        let store = StubLaunchAtLoginStore(initialStatus: .enabled)
        let controller = LaunchAtLoginController(store: store)

        try controller.setEnabled(false)

        XCTAssertEqual(store.unregisterCallCount, 1)
        XCTAssertEqual(store.registerCallCount, 0)
        XCTAssertFalse(controller.isEnabled)
    }

    @MainActor
    func testLaunchControllerSurfacesStoreErrors() {
        struct StoreFailure: Error {}
        let store = StubLaunchAtLoginStore()
        store.registerError = StoreFailure()
        let controller = LaunchAtLoginController(store: store)

        XCTAssertThrowsError(try controller.setEnabled(true)) { error in
            XCTAssertTrue(error is StoreFailure)
        }
    }

    // MARK: - AppModel tapErrorActive

    @MainActor
    func testAppModelTapErrorActiveDefaultsFalse() {
        let service = EventTapService(profile: .default)
        let model = AppModel(eventTapService: service)
        XCTAssertFalse(model.tapErrorActive)
    }

    @MainActor
    func testAppModelTapErrorActiveBecomesTrueOnTapError() async {
        let service = EventTapService(profile: .default)
        let model = AppModel(eventTapService: service)

        service.onTapError?("simulated tap death")
        await Task.yield()  // let the @MainActor Task scheduled by the closure run

        XCTAssertTrue(model.tapErrorActive)
    }

    @MainActor
    func testAppModelTapErrorActiveBecomesFalseOnTapRecovered() async {
        let service = EventTapService(profile: .default)
        let model = AppModel(eventTapService: service)

        service.onTapError?("simulated tap death")
        await Task.yield()
        XCTAssertTrue(model.tapErrorActive)

        service.onTapRecovered?()
        await Task.yield()
        XCTAssertFalse(model.tapErrorActive)
    }

    // MARK: - resolveMenuBarVariant

    func testResolveOffWhenIdleGrantedNoErrorNoUpdate() {
        let result = resolveMenuBarVariant(mode: .off, perm: .granted, tapErrorActive: false, updateAvailable: false)
        XCTAssertEqual(result.variant, .off)
        XCTAssertFalse(result.badge)
    }

    func testResolveOffBadgesWhenUpdateAvailable() {
        let result = resolveMenuBarVariant(mode: .off, perm: .granted, tapErrorActive: false, updateAvailable: true)
        XCTAssertEqual(result.variant, .off)
        XCTAssertTrue(result.badge)
    }

    func testResolveNavWhenNavGrantedNoErrorNoUpdate() {
        let result = resolveMenuBarVariant(mode: .nav, perm: .granted, tapErrorActive: false, updateAvailable: false)
        XCTAssertEqual(result.variant, .nav)
        XCTAssertFalse(result.badge)
    }

    func testResolveNumpadBadgesWhenUpdateAvailable() {
        let result = resolveMenuBarVariant(mode: .numpad, perm: .granted, tapErrorActive: false, updateAvailable: true)
        XCTAssertEqual(result.variant, .numpad)
        XCTAssertTrue(result.badge)
    }

    func testResolveListenOnlyOverridesMode() {
        let result = resolveMenuBarVariant(mode: .nav, perm: .listenOnly, tapErrorActive: false, updateAvailable: false)
        XCTAssertEqual(result.variant, .listenOnly)
        XCTAssertFalse(result.badge)
    }

    func testResolveListenOnlyBadgesWhenUpdateAvailable() {
        let result = resolveMenuBarVariant(mode: .off, perm: .listenOnly, tapErrorActive: false, updateAvailable: true)
        XCTAssertEqual(result.variant, .listenOnly)
        XCTAssertTrue(result.badge)
    }

    func testResolveDeniedOverridesMode() {
        let result = resolveMenuBarVariant(mode: .nav, perm: .denied, tapErrorActive: false, updateAvailable: false)
        XCTAssertEqual(result.variant, .denied)
        XCTAssertFalse(result.badge)
    }

    func testResolveDeniedNeverBadged() {
        let result = resolveMenuBarVariant(mode: .nav, perm: .denied, tapErrorActive: false, updateAvailable: true)
        XCTAssertEqual(result.variant, .denied)
        XCTAssertFalse(result.badge)
    }

    func testResolveErrorOverridesEverything() {
        let result = resolveMenuBarVariant(mode: .numpad, perm: .listenOnly, tapErrorActive: true, updateAvailable: true)
        XCTAssertEqual(result.variant, .error)
        XCTAssertFalse(result.badge)
    }

    func testResolveErrorOverridesDenied() {
        let result = resolveMenuBarVariant(mode: .off, perm: .denied, tapErrorActive: true, updateAvailable: false)
        XCTAssertEqual(result.variant, .error)
        XCTAssertFalse(result.badge)
    }

    func testResolveModeMappingCoversAllLayerModes() {
        XCTAssertEqual(resolveMenuBarVariant(mode: .off, perm: .granted, tapErrorActive: false, updateAvailable: false).variant, .off)
        XCTAssertEqual(resolveMenuBarVariant(mode: .nav, perm: .granted, tapErrorActive: false, updateAvailable: false).variant, .nav)
        XCTAssertEqual(resolveMenuBarVariant(mode: .numpad, perm: .granted, tapErrorActive: false, updateAvailable: false).variant, .numpad)
    }

    // MARK: - AppModel.menuBarVariant

    @MainActor
    func testAppModelMenuBarVariantReflectsMode() {
        let model = AppModel(eventTapService: EventTapService(profile: .default))
        model.permissionState = .granted
        model.mode = .nav
        let result = model.menuBarVariant
        XCTAssertEqual(result.variant, .nav)
        XCTAssertFalse(result.badge)
    }

    @MainActor
    func testAppModelMenuBarVariantHonorsErrorPriority() async {
        let service = EventTapService(profile: .default)
        let model = AppModel(eventTapService: service)
        model.mode = .numpad

        service.onTapError?("simulated")
        await Task.yield()

        XCTAssertEqual(model.menuBarVariant.variant, .error)
    }

    @MainActor
    func testAppModelMenuBarVariantBadgeOnUpdateWhenSafe() {
        let model = AppModel(eventTapService: EventTapService(profile: .default))
        model.permissionState = .granted
        model.mode = .off
        model.setUpdateAvailable(true)

        XCTAssertEqual(model.menuBarVariant.variant, .off)
        XCTAssertTrue(model.menuBarVariant.badge)
    }

    // MARK: - MenuBarIconView.Variant data

    func testVariantTintColors() {
        XCTAssertEqual(MenuBarIconView.Variant.off.tint,        .primary)
        XCTAssertEqual(MenuBarIconView.Variant.nav.tint,        .primary)
        XCTAssertEqual(MenuBarIconView.Variant.numpad.tint,     .primary)
        XCTAssertEqual(MenuBarIconView.Variant.listenOnly.tint, .primary)
        XCTAssertEqual(MenuBarIconView.Variant.denied.tint,     .orange)
        XCTAssertEqual(MenuBarIconView.Variant.error.tint,      .red)
    }

    func testVariantAccessibilityLabels() {
        XCTAssertEqual(MenuBarIconView.Variant.off.accessibilityLabel,        "LayerKeys, idle")
        XCTAssertEqual(MenuBarIconView.Variant.nav.accessibilityLabel,        "LayerKeys, navigation layer active")
        XCTAssertEqual(MenuBarIconView.Variant.numpad.accessibilityLabel,     "LayerKeys, numpad layer active")
        XCTAssertEqual(MenuBarIconView.Variant.denied.accessibilityLabel,     "LayerKeys, input monitoring permission denied")
        XCTAssertEqual(MenuBarIconView.Variant.listenOnly.accessibilityLabel, "LayerKeys, listen-only mode — tap-to-Escape disabled")
        XCTAssertEqual(MenuBarIconView.Variant.error.accessibilityLabel,      "LayerKeys, event tap error")
    }

    // MARK: - MenuBarIconView smoke render

    @MainActor
    func testMenuBarIconViewOffRendersToNonNilImage() {
        let view = MenuBarIconView(variant: .off, updateBadge: false)
            .frame(width: 18, height: 18)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        let image = renderer.nsImage
        XCTAssertNotNil(image, ".off variant must render to a non-nil NSImage")
        XCTAssertEqual(image?.size, CGSize(width: 18, height: 18))
    }

    @MainActor
    func testMenuBarIconViewNavRenders() {
        let view = MenuBarIconView(variant: .nav, updateBadge: false).frame(width: 18, height: 18)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        XCTAssertNotNil(renderer.nsImage)
    }

    @MainActor
    func testMenuBarIconViewNumpadRenders() {
        let view = MenuBarIconView(variant: .numpad, updateBadge: false).frame(width: 18, height: 18)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        XCTAssertNotNil(renderer.nsImage)
    }

    @MainActor
    func testMenuBarIconViewDeniedRenders() {
        let view = MenuBarIconView(variant: .denied, updateBadge: false).frame(width: 18, height: 18)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        XCTAssertNotNil(renderer.nsImage)
    }

    @MainActor
    func testMenuBarIconViewListenOnlyRenders() {
        let view = MenuBarIconView(variant: .listenOnly, updateBadge: false).frame(width: 18, height: 18)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        XCTAssertNotNil(renderer.nsImage)
    }

    @MainActor
    func testMenuBarIconViewErrorRenders() {
        let view = MenuBarIconView(variant: .error, updateBadge: false).frame(width: 18, height: 18)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        XCTAssertNotNil(renderer.nsImage)
    }

    @MainActor
    func testMenuBarIconViewOffWithBadgeRenders() {
        let view = MenuBarIconView(variant: .off, updateBadge: true).frame(width: 18, height: 18)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        XCTAssertNotNil(renderer.nsImage)
    }

    @MainActor
    func testMenuBarIconViewNavWithBadgeRenders() {
        let view = MenuBarIconView(variant: .nav, updateBadge: true).frame(width: 18, height: 18)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        XCTAssertNotNil(renderer.nsImage)
    }
}

private final class StubLaunchAtLoginStore: LaunchAtLoginStore {
    var statusValue: SMAppService.Status
    var registerError: Error?
    var unregisterError: Error?
    var registerCallCount = 0
    var unregisterCallCount = 0

    init(initialStatus: SMAppService.Status = .notRegistered) {
        self.statusValue = initialStatus
    }

    var status: SMAppService.Status { statusValue }

    func register() throws {
        registerCallCount += 1
        if let registerError { throw registerError }
        statusValue = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError { throw unregisterError }
        statusValue = .notRegistered
    }
}
