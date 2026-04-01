import XCTest
@testable import LayerKeys

final class LayerKeysTests: XCTestCase {
    private let triggerDownTimestamp: UInt64 = 1_000_000_000

    func testEscapeTriggerEntersNavigationMode() {
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

    func testHoldingAThenPressingEscapeStartsInNumpadMode() {
        var machine = LayerStateMachine()

        XCTAssertFalse(machine.handleKeyEvent(keyCode: InputKey.a.keyCode, isKeyDown: true))
        XCTAssertTrue(machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp))
        XCTAssertEqual(machine.mode, .numpad)

        XCTAssertTrue(machine.handleKeyEvent(keyCode: InputKey.a.keyCode, isKeyDown: false))
        let result = machine.handleTriggerKeyUp(timestamp: triggerDownTimestamp + 50_000_000)
        XCTAssertFalse(result.shouldEmitEscape)
        XCTAssertEqual(machine.mode, .off)
    }

    func testTapEscapeEmitsEscapeOnTriggerRelease() {
        var machine = LayerStateMachine()
        _ = machine.handleTriggerKeyDown(timestamp: triggerDownTimestamp)

        let result = machine.handleTriggerKeyUp(timestamp: triggerDownTimestamp + 50_000_000)
        XCTAssertTrue(result.modeDidChange)
        XCTAssertTrue(result.shouldEmitEscape)
        XCTAssertEqual(machine.mode, .off)
    }

    func testHoldingEscapeDoesNotEmitEscapeOnRelease() {
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
        XCTAssertFalse(mappings.targetRequiresNumericPadFlag(NumpadTargetKey.keypad7.keyCode))
        XCTAssertFalse(mappings.targetRequiresNumericPadFlag(NavigationTargetKey.leftArrow.keyCode))
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
}
