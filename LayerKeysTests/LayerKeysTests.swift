import XCTest
@testable import LayerKeys

final class LayerKeysTests: XCTestCase {
    func testGlobeKeyEntersNavigationMode() {
        var machine = LayerStateMachine()

        XCTAssertTrue(machine.handleModifierChange(isGlobeKeyHeld: true))
        XCTAssertEqual(machine.mode, .nav)
    }

    func testTriggerKeySwitchesToNumpadUntilGlobeReleased() {
        var machine = LayerStateMachine()
        _ = machine.handleModifierChange(isGlobeKeyHeld: true)

        XCTAssertTrue(machine.handleKeyEvent(keyCode: InputKey.a.keyCode, isKeyDown: true))
        XCTAssertEqual(machine.mode, .numpad)

        XCTAssertTrue(machine.handleKeyEvent(keyCode: InputKey.a.keyCode, isKeyDown: false))
        XCTAssertEqual(machine.mode, .numpad)

        XCTAssertTrue(machine.handleModifierChange(isGlobeKeyHeld: false))
        XCTAssertEqual(machine.mode, .off)
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
