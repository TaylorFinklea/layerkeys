import CoreGraphics
import Foundation

struct TriggerKeyReleaseResult {
    let modeDidChange: Bool
    let shouldEmitEscape: Bool
}

struct LayerStateMachine {
    private(set) var mode: LayerMode = .off
    private(set) var isLayerTriggerHeld = false
    private(set) var shouldSwallowTriggerKeyUp = false
    private(set) var shouldEmitEscapeOnTriggerKeyUp = false
    private(set) var triggerKeyDownTimestamp: UInt64?

    static let escapeKeyCode: KeyCode = 0x35
    static let layerTriggerKeyCode = InputKey.space.keyCode
    static let layerTriggerRequiredFlags: CGEventFlags = .maskControl
    static let numpadTriggerKeyCode = InputKey.a.keyCode
    static let escapeTapThreshold: UInt64 = 200_000_000

    @discardableResult
    mutating func handleTriggerKeyDown(timestamp: UInt64) -> Bool {
        guard !isLayerTriggerHeld else {
            return false
        }

        isLayerTriggerHeld = true
        triggerKeyDownTimestamp = timestamp
        shouldEmitEscapeOnTriggerKeyUp = true
        let didChange = mode != .nav
        mode = .nav
        return didChange
    }

    mutating func handleTriggerKeyUp(timestamp: UInt64) -> TriggerKeyReleaseResult {
        guard isLayerTriggerHeld else {
            return TriggerKeyReleaseResult(modeDidChange: false, shouldEmitEscape: false)
        }

        let wasQuickTap: Bool
        if let triggerKeyDownTimestamp {
            wasQuickTap = timestamp >= triggerKeyDownTimestamp
                && (timestamp - triggerKeyDownTimestamp) < Self.escapeTapThreshold
        } else {
            wasQuickTap = false
        }

        let result = TriggerKeyReleaseResult(
            modeDidChange: mode != .off,
            shouldEmitEscape: shouldEmitEscapeOnTriggerKeyUp && wasQuickTap
        )

        isLayerTriggerHeld = false
        mode = .off
        shouldSwallowTriggerKeyUp = false
        shouldEmitEscapeOnTriggerKeyUp = false
        triggerKeyDownTimestamp = nil
        return result
    }

    @discardableResult
    mutating func handleKeyEvent(keyCode: KeyCode, isKeyDown: Bool) -> Bool {
        guard isLayerTriggerHeld else {
            return false
        }

        if keyCode != Self.layerTriggerKeyCode, isKeyDown {
            shouldEmitEscapeOnTriggerKeyUp = false
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
