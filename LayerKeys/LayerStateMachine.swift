import CoreGraphics
import Foundation

struct LayerStateMachine {
    private(set) var mode: LayerMode = .off
    private(set) var isGlobeKeyHeld = false
    private(set) var shouldSwallowTriggerKeyUp = false

    static let numpadTriggerKeyCode = InputKey.a.keyCode

    @discardableResult
    mutating func handleModifierChange(isGlobeKeyHeld: Bool) -> Bool {
        guard self.isGlobeKeyHeld != isGlobeKeyHeld else {
            return false
        }

        self.isGlobeKeyHeld = isGlobeKeyHeld
        if isGlobeKeyHeld {
            mode = .nav
        } else {
            mode = .off
            shouldSwallowTriggerKeyUp = false
        }
        return true
    }

    @discardableResult
    mutating func handleKeyEvent(keyCode: KeyCode, isKeyDown: Bool) -> Bool {
        guard isGlobeKeyHeld else {
            return false
        }

        if isKeyDown, mode == .nav, keyCode == Self.numpadTriggerKeyCode {
            mode = .numpad
            shouldSwallowTriggerKeyUp = true
            return true
        }

        if !isKeyDown, shouldSwallowTriggerKeyUp, keyCode == Self.numpadTriggerKeyCode {
            shouldSwallowTriggerKeyUp = false
            return true
        }

        return false
    }
}
