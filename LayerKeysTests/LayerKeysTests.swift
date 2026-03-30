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
        XCTAssertTrue(mappings.targetRequiresNumericPadFlag(NumpadTargetKey.keypad0.keyCode))
        XCTAssertFalse(mappings.targetRequiresNumericPadFlag(NavigationTargetKey.leftArrow.keyCode))
    }
}
