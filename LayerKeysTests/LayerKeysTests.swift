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
}
