import AppKit
import CoreGraphics
import Foundation

struct SleepWakeHandler {
    var reEnableTap: () -> Void
    var isTapAlive: () -> Bool
    var restartEngine: () -> Void
    var onError: (String) -> Void
    var onRecover: () -> Void

    private(set) var sleepPending = false

    mutating func willSleep() {
        sleepPending = true
    }

    mutating func didWake() {
        guard sleepPending else { return }
        sleepPending = false

        reEnableTap()
        if isTapAlive() {
            onRecover()
            return
        }
        if isTapAlive() {
            onRecover()
            return
        }

        onError("Restarting event tap after sleep recovery.")
        restartEngine()

        if isTapAlive() {
            onRecover()
        }
    }
}

final class EventTapService {
    var onModeChange: ((LayerMode) -> Void)?
    var onTapError: ((String) -> Void)?
    var onTapRecovered: (() -> Void)?

    private let lock = NSLock()
    private var profile: MappingProfile
    private var engine: EventTapEngine?

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var sleepWakeHandler: SleepWakeHandler?

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
            installSleepWakeObservers(for: engine)
        }
        return started
    }

    func stop() {
        removeSleepWakeObservers()

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

    private func installSleepWakeObservers(for engine: EventTapEngine) {
        sleepWakeHandler = SleepWakeHandler(
            reEnableTap: { [weak engine] in engine?.reEnableTap() },
            isTapAlive: { [weak engine] in engine?.isTapAlive() ?? false },
            restartEngine: { [weak self] in
                guard let self else { return }
                self.stop()
                _ = self.start()
            },
            onError: { [weak self] message in
                self?.onTapError?(message)
            },
            onRecover: { [weak self] in
                self?.onTapRecovered?()
            }
        )

        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sleepWakeHandler?.willSleep()
        }
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sleepWakeHandler?.didWake()
        }
    }

    private func removeSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        if let sleepObserver {
            center.removeObserver(sleepObserver)
        }
        if let wakeObserver {
            center.removeObserver(wakeObserver)
        }
        sleepObserver = nil
        wakeObserver = nil
        sleepWakeHandler = nil
    }
}
