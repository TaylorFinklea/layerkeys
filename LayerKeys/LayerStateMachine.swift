import CoreGraphics
import Foundation

struct TriggerKeyReleaseResult {
    let modeDidChange: Bool
    let shouldEmitEscape: Bool
}

enum EventAction: Equatable {
    case passThrough
    case consume
    case enterLayerTrigger
    case exitLayerTrigger(emitEscape: Bool)
    case remap(keyCode: KeyCode, setNumericPadFlag: Bool)
    /// Synthesize a fresh keyboard event because the originating event
    /// was a `flagsChanged` for a modifier source — we can't just
    /// rewrite its keycode and forward it like a normal remap.
    /// `clearModifierKeyCode` identifies the source modifier whose
    /// device + general flag bits must be stripped from the emitted
    /// event so apps don't see e.g. `Cmd+Keypad0`.
    case synthesizeKey(
        keyCode: KeyCode,
        isKeyDown: Bool,
        setNumericPadFlag: Bool,
        clearModifierKeyCode: KeyCode
    )
}

struct EventDecision: Equatable {
    let action: EventAction
    let modeDidChange: Bool
}

struct LayerStateMachine {
    private(set) var mode: LayerMode = .off
    private(set) var isLayerTriggerHeld = false
    private(set) var shouldSwallowTriggerKeyUp = false
    private(set) var shouldEmitEscapeOnTriggerKeyUp = false
    private(set) var triggerKeyDownTimestamp: UInt64?

    /// Source-modifier keycodes for which we've already synthesized a
    /// keyDown for a remapped target. Used to emit the matching keyUp
    /// even if the layer trigger has since released — otherwise the
    /// downstream app would see a stuck keypad key.
    private struct SynthesizedDown {
        let target: KeyCode
        let requiresNumericPadFlag: Bool
    }
    private var synthesizedDownsByModifierKeyCode: [KeyCode: SynthesizedDown] = [:]

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

    /// Sanitizes an incoming event's modifier flags before we forward or replay
    /// it: always drop `.maskSecondaryFn` (Fn was only present to generate the
    /// arrow/keypad keycode in the first place) and drop the user's trigger
    /// modifier set (so downstream apps don't see a ghost `Control` / `Command`
    /// chord). Caller is responsible for adding or removing `.maskNumericPad`
    /// per target.
    func outputFlags(for originalFlags: CGEventFlags) -> CGEventFlags {
        var flags = originalFlags
        flags.remove(.maskSecondaryFn)
        flags.remove(layerTriggerRequiredFlags)
        return flags
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

    /// Pure decision function over a single key event. All state mutation
    /// happens here; the caller is responsible for applying the returned
    /// action to the underlying `CGEvent` (or a test double).
    mutating func decide(
        eventType: CGEventType,
        keyCode: KeyCode,
        currentFlags: CGEventFlags,
        isSyntheticEscape: Bool,
        timestamp: UInt64,
        mappings: ResolvedMappings
    ) -> EventDecision {
        if isSyntheticEscape {
            return EventDecision(action: .passThrough, modeDidChange: false)
        }

        if eventType == .flagsChanged {
            return decideFlagsChanged(
                keyCode: keyCode,
                currentFlags: currentFlags,
                mappings: mappings
            )
        }

        guard eventType == .keyDown || eventType == .keyUp else {
            return EventDecision(action: .passThrough, modeDidChange: false)
        }

        let isKeyDown = eventType == .keyDown

        if keyCode == layerTriggerKeyCode {
            if isKeyDown {
                guard currentFlags.contains(layerTriggerRequiredFlags) else {
                    return EventDecision(action: .passThrough, modeDidChange: false)
                }
                let didChange = handleTriggerKeyDown(timestamp: timestamp)
                return EventDecision(action: .enterLayerTrigger, modeDidChange: didChange)
            } else {
                guard isLayerTriggerHeld else {
                    return EventDecision(action: .passThrough, modeDidChange: false)
                }
                let result = handleTriggerKeyUp(timestamp: timestamp)
                return EventDecision(
                    action: .exitLayerTrigger(emitEscape: result.shouldEmitEscape),
                    modeDidChange: result.modeDidChange
                )
            }
        }

        if handleKeyEvent(keyCode: keyCode, isKeyDown: isKeyDown) {
            return EventDecision(action: .consume, modeDidChange: true)
        }

        guard let remapped = mappings.remappedKeyCode(for: keyCode, mode: mode) else {
            return EventDecision(action: .passThrough, modeDidChange: false)
        }

        return EventDecision(
            action: .remap(
                keyCode: remapped,
                setNumericPadFlag: mappings.targetRequiresNumericPadFlag(remapped)
            ),
            modeDidChange: false
        )
    }

    /// Decide what to do with a `flagsChanged` event. macOS dispatches
    /// modifier press/release as `flagsChanged` rather than
    /// keyDown/keyUp, so we have to derive the press edge ourselves
    /// from the device-side bit on `currentFlags`. Only modifiers that
    /// are bound as a remap source (e.g. Right ⌘ → Keypad 0) cause us
    /// to synthesize an event; everything else passes through so
    /// normal modifier behavior (⌘C, ⌥-click, …) is preserved.
    private mutating func decideFlagsChanged(
        keyCode: KeyCode,
        currentFlags: CGEventFlags,
        mappings: ResolvedMappings
    ) -> EventDecision {
        guard let info = InputKey.modifierFlagInfo(forKeyCode: keyCode) else {
            return EventDecision(action: .passThrough, modeDidChange: false)
        }

        let isPressed = !currentFlags.intersection(info.device).isEmpty

        if isPressed {
            // Only intercept if the trigger is held and this modifier
            // has a binding in the current mode. Otherwise pass
            // through so the user keeps normal Cmd / Option behavior.
            guard isLayerTriggerHeld,
                  let remapped = mappings.remappedKeyCode(for: keyCode, mode: mode) else {
                return EventDecision(action: .passThrough, modeDidChange: false)
            }
            shouldEmitEscapeOnTriggerKeyUp = false
            let requiresPad = mappings.targetRequiresNumericPadFlag(remapped)
            synthesizedDownsByModifierKeyCode[keyCode] = SynthesizedDown(
                target: remapped,
                requiresNumericPadFlag: requiresPad
            )
            return EventDecision(
                action: .synthesizeKey(
                    keyCode: remapped,
                    isKeyDown: true,
                    setNumericPadFlag: requiresPad,
                    clearModifierKeyCode: keyCode
                ),
                modeDidChange: false
            )
        }

        // Release edge — only emit the matching keyUp if we previously
        // synthesized a keyDown for this modifier. Do this even if the
        // trigger has since released, otherwise the downstream app
        // sees a stuck keypad key.
        guard let entry = synthesizedDownsByModifierKeyCode.removeValue(forKey: keyCode) else {
            return EventDecision(action: .passThrough, modeDidChange: false)
        }
        return EventDecision(
            action: .synthesizeKey(
                keyCode: entry.target,
                isKeyDown: false,
                setNumericPadFlag: entry.requiresNumericPadFlag,
                clearModifierKeyCode: keyCode
            ),
            modeDidChange: false
        )
    }
}
