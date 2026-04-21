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

    var triggers: TriggerProfile

    static let escapeKeyCode: KeyCode = 0x35
    static let escapeTapThreshold: UInt64 = 200_000_000

    init(triggers: TriggerProfile = .default) {
        self.triggers = triggers
    }

    var layerTriggerKeyCode: KeyCode {
        triggers.layerKey.keyCode
    }

    var layerTriggerRequiredFlags: CGEventFlags {
        triggers.layerModifiers.eventFlags
    }

    var numpadTriggerKeyCode: KeyCode {
        triggers.numpadSubTrigger.keyCode
    }

    @discardableResult
    mutating func handleTriggerKeyDown(timestamp: UInt64) -> Bool {
        guard !isLayerTriggerHeld else {
            return false
        }

        isLayerTriggerHeld = true
        triggerKeyDownTimestamp = timestamp
        shouldEmitEscapeOnTriggerKeyUp = triggers.tapToEscapeEnabled
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

        if keyCode != layerTriggerKeyCode, isKeyDown {
            shouldEmitEscapeOnTriggerKeyUp = false
        }

        if isKeyDown, mode == .nav, keyCode == numpadTriggerKeyCode {
            mode = .numpad
            shouldSwallowTriggerKeyUp = true
            return true
        }

        if !isKeyDown, shouldSwallowTriggerKeyUp, keyCode == numpadTriggerKeyCode {
            shouldSwallowTriggerKeyUp = false
            return true
        }

        return false
    }
}
