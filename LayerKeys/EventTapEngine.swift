import CoreGraphics
import Foundation

final class EventTapEngine: NSObject {
    private static let syntheticEscapeEventTag: Int64 = 0x4C4B455343
    /// Tag we stamp on events synthesized from `flagsChanged` modifier
    /// remaps (e.g. Right ⌘ → Keypad 0). Tagged events skip the state
    /// machine on re-entry through the tap so we don't recurse.
    private static let syntheticRemapEventTag: Int64 = 0x4C4B5245_4D4150

    private let profileLock = NSLock()
    private var resolvedMappings: ResolvedMappings
    private var stateMachine: LayerStateMachine
    private let onModeChange: (LayerMode) -> Void
    private let onTapError: (String) -> Void

    private var thread: Thread?
    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?

    init(
        profile: MappingProfile,
        onModeChange: @escaping (LayerMode) -> Void,
        onTapError: @escaping (String) -> Void
    ) {
        resolvedMappings = profile.resolvedMappings
        stateMachine = LayerStateMachine(triggers: profile.triggers)
        self.onModeChange = onModeChange
        self.onTapError = onTapError
    }

    func updateProfile(_ profile: MappingProfile) {
        profileLock.lock()
        resolvedMappings = profile.resolvedMappings
        profileLock.unlock()
    }

    /// Idempotently re-enables the event tap on the engine thread. Safe to
    /// call from any thread. If the tap port no longer exists this is a no-op.
    func reEnableTap() {
        guard let thread else { return }
        perform(#selector(reEnableTapOnThread), on: thread, with: nil, waitUntilDone: true)
    }

    /// Whether the kernel still considers our tap active. Synchronously hops to
    /// the engine thread to read `tapPort`.
    func isTapAlive() -> Bool {
        guard let thread else { return false }
        let probe = TapLivenessProbe()
        perform(#selector(checkTapAliveOnThread(_:)), on: thread, with: probe, waitUntilDone: true)
        return probe.isAlive
    }

    @objc
    private func reEnableTapOnThread() {
        if let tapPort {
            CGEvent.tapEnable(tap: tapPort, enable: true)
        }
    }

    @objc
    private func checkTapAliveOnThread(_ probe: TapLivenessProbe) {
        if let tapPort {
            probe.isAlive = CGEvent.tapIsEnabled(tap: tapPort)
        } else {
            probe.isAlive = false
        }
    }

    func start() -> Bool {
        let startup = EventTapStartup()
        let thread = Thread(target: self, selector: #selector(runEventTapThread(_:)), object: startup)

        self.thread = thread
        thread.start()
        startup.semaphore.wait()
        return startup.didStart
    }

    func stop() {
        guard let thread else {
            return
        }

        perform(#selector(stopRunLoop), on: thread, with: nil, waitUntilDone: true)
        self.thread = nil
    }

    @objc
    private func stopRunLoop() {
        if let tapPort {
            CGEvent.tapEnable(tap: tapPort, enable: false)
            CFMachPortInvalidate(tapPort)
        }

        if let runLoopSource, let runLoop {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
        }

        tapPort = nil
        runLoopSource = nil
        if let runLoop {
            CFRunLoopStop(runLoop)
        }
        runLoop = nil
    }

    @objc
    private func runEventTapThread(_ startup: EventTapStartup) {
        Thread.current.name = "LayerKeys.EventTap"
        runLoop = CFRunLoopGetCurrent()

        let eventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            // flagsChanged is how macOS dispatches modifier presses;
            // we need it for bindings whose source is a modifier
            // (e.g. Right ⌘ → Keypad 0).
            | (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tapPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let engine = Unmanaged<EventTapEngine>.fromOpaque(userInfo).takeUnretainedValue()
                return engine.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            onTapError("LayerKeys could not create the keyboard event tap.")
            startup.semaphore.signal()
            return
        }

        self.tapPort = tapPort
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tapPort, 0)
        runLoopSource = source

        if let source {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tapPort, enable: true)

        startup.didStart = true
        startup.semaphore.signal()
        CFRunLoopRun()
    }

    private func handle(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reEnableTapOnThread()
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown || type == .keyUp || type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let userData = event.getIntegerValueField(.eventSourceUserData)
        let isSyntheticEscape = userData == Self.syntheticEscapeEventTag
        let isSyntheticRemap = userData == Self.syntheticRemapEventTag
        // Tagged synthetic remap events must short-circuit immediately
        // — they're our own re-entry from postRemappedModifierKey and
        // they're already in their final form.
        if isSyntheticRemap {
            return Unmanaged.passUnretained(event)
        }
        let keyCode = KeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        profileLock.lock()
        let mappings = resolvedMappings
        profileLock.unlock()

        let decision = stateMachine.decide(
            eventType: type,
            keyCode: keyCode,
            currentFlags: event.flags,
            isSyntheticEscape: isSyntheticEscape,
            timestamp: event.timestamp,
            mappings: mappings
        )

        if decision.modeDidChange {
            onModeChange(stateMachine.mode)
        }

        switch decision.action {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .consume, .enterLayerTrigger:
            return nil
        case let .exitLayerTrigger(emitEscape):
            if emitEscape, PermissionController.hasPostEventAccess {
                postEscapeTap(flags: stateMachine.outputFlags(for: event.flags))
            }
            return nil
        case let .remap(remappedKeyCode, setNumericPadFlag):
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(remappedKeyCode))
            var flags = stateMachine.outputFlags(for: event.flags)
            if setNumericPadFlag {
                flags.insert(.maskNumericPad)
            } else {
                flags.remove(.maskNumericPad)
            }
            event.flags = flags
            return Unmanaged.passRetained(event)
        case let .synthesizeKey(
            remappedKeyCode,
            isKeyDown,
            setNumericPadFlag,
            clearModifierKeyCode
        ):
            postRemappedModifierKey(
                keyCode: remappedKeyCode,
                isKeyDown: isKeyDown,
                flagsBase: event.flags,
                setNumericPadFlag: setNumericPadFlag,
                clearModifierKeyCode: clearModifierKeyCode
            )
            // Consume the original flagsChanged so downstream apps
            // don't also see the raw modifier press.
            return nil
        }
    }

    /// Synthesizes a keyDown/keyUp event for a target keycode whose
    /// trigger was a `flagsChanged` modifier transition. We can't just
    /// rewrite the originating event's type, so we post a fresh
    /// keyboard event through the HID event tap and consume the
    /// original. The new event is tagged with
    /// `syntheticRemapEventTag` so it bypasses the state machine on
    /// re-entry through our tap.
    private func postRemappedModifierKey(
        keyCode: KeyCode,
        isKeyDown: Bool,
        flagsBase: CGEventFlags,
        setNumericPadFlag: Bool,
        clearModifierKeyCode: KeyCode
    ) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: keyCode,
                  keyDown: isKeyDown
              ) else {
            return
        }

        var flags = stateMachine.outputFlags(for: flagsBase)
        if let info = InputKey.modifierFlagInfo(forKeyCode: clearModifierKeyCode) {
            flags.remove(info.device)
            flags.remove(info.general)
        }
        if setNumericPadFlag {
            flags.insert(.maskNumericPad)
        } else {
            flags.remove(.maskNumericPad)
        }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticRemapEventTag)
        event.post(tap: .cghidEventTap)
    }

    private func postEscapeTap(flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        for isKeyDown in [true, false] {
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: LayerStateMachine.escapeKeyCode,
                keyDown: isKeyDown
            ) else {
                continue
            }

            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEscapeEventTag)
            event.post(tap: .cghidEventTap)
        }
    }
}

final class EventTapStartup: NSObject {
    let semaphore = DispatchSemaphore(value: 0)
    var didStart = false
}

final class TapLivenessProbe: NSObject {
    var isAlive = false
}
