import CoreGraphics
import Foundation

final class EventTapService {
    var onModeChange: ((LayerMode) -> Void)?
    var onTapError: ((String) -> Void)?

    private let lock = NSLock()
    private var profile: MappingProfile
    private var engine: EventTapEngine?

    init(profile: MappingProfile) {
        self.profile = profile
    }

    func updateProfile(_ profile: MappingProfile) {
        lock.lock()
        self.profile = profile
        engine?.updateProfile(profile)
        lock.unlock()
    }

    @discardableResult
    func start() -> Bool {
        stop()

        guard PermissionController.currentState().isGranted else {
            onTapError?("Input Monitoring permission has not been granted.")
            return false
        }

        let engine = EventTapEngine(
            profile: lockedProfile(),
            onModeChange: { [weak self] mode in
                self?.onModeChange?(mode)
            },
            onTapError: { [weak self] message in
                self?.onTapError?(message)
            }
        )
        let started = engine.start()
        if started {
            self.engine = engine
        }
        return started
    }

    func stop() {
        lock.lock()
        let engine = engine
        self.engine = nil
        lock.unlock()

        engine?.stop()
    }

    private func lockedProfile() -> MappingProfile {
        lock.lock()
        defer { lock.unlock() }
        return profile
    }
}

private final class EventTapEngine: NSObject {
    private let profileLock = NSLock()
    private var resolvedMappings: ResolvedMappings
    private var stateMachine = LayerStateMachine()
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
        self.onModeChange = onModeChange
        self.onTapError = onTapError
    }

    func updateProfile(_ profile: MappingProfile) {
        profileLock.lock()
        resolvedMappings = profile.resolvedMappings
        profileLock.unlock()
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
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tapPort {
                CGEvent.tapEnable(tap: tapPort, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .flagsChanged:
            let fnHeld = event.flags.contains(.maskSecondaryFn)
            let didChange = stateMachine.handleModifierChange(isGlobeKeyHeld: fnHeld)
            if didChange {
                onModeChange(stateMachine.mode)
            }

            let keyCode = KeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == 0x3F {
                return nil
            }
            return Unmanaged.passUnretained(event)
        case .keyDown, .keyUp:
            let keyCode = KeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let isKeyDown = type == .keyDown

            if stateMachine.handleKeyEvent(keyCode: keyCode, isKeyDown: isKeyDown) {
                onModeChange(stateMachine.mode)
                return nil
            }

            profileLock.lock()
            let mappings = resolvedMappings
            profileLock.unlock()

            guard let remapped = mappings.remappedKeyCode(for: keyCode, mode: stateMachine.mode) else {
                return Unmanaged.passUnretained(event)
            }

            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(remapped))

            var flags = event.flags
            flags.remove(.maskSecondaryFn)
            if mappings.targetRequiresNumericPadFlag(remapped) {
                flags.insert(.maskNumericPad)
            } else {
                flags.remove(.maskNumericPad)
            }
            event.flags = flags

            return Unmanaged.passRetained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

private final class EventTapStartup: NSObject {
    let semaphore = DispatchSemaphore(value: 0)
    var didStart = false
}
