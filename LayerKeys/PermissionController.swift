import ApplicationServices
import CoreGraphics
import Foundation

enum InputMonitoringPermissionState: Equatable {
    case granted
    case listenOnly
    case denied

    var isGranted: Bool {
        self != .denied
    }

    var title: String {
        switch self {
        case .granted:
            return "Keyboard Permissions Enabled"
        case .listenOnly:
            return "Input Monitoring Enabled"
        case .denied:
            return "Input Monitoring Required"
        }
    }

    var detail: String {
        switch self {
        case .granted:
            return "LayerKeys can listen for the layer trigger and post plain Escape taps globally."
        case .listenOnly:
            return "LayerKeys can remap keys globally, but tap-trigger Escape replay is disabled until Accessibility is also granted."
        case .denied:
            return "Grant Input Monitoring so LayerKeys can listen for global key events and apply remaps."
        }
    }
}

enum PermissionController {
    static func currentState() -> InputMonitoringPermissionState {
        let hasListenAccess = CGPreflightListenEventAccess()
        let hasPostAccess = CGPreflightPostEventAccess()

        if hasListenAccess && hasPostAccess {
            return .granted
        }
        if hasListenAccess {
            return .listenOnly
        }
        return .denied
    }

    @discardableResult
    static func requestListenAccess() -> Bool {
        CGRequestListenEventAccess()
    }

    @discardableResult
    static func requestPostAccess() -> Bool {
        CGRequestPostEventAccess()
    }

    /// Triggers the standard Accessibility prompt with the
    /// `AXTrustedCheckOptionPrompt` option. This is the documented path
    /// for registering an app in the Accessibility TCC list and is more
    /// reliable than `CGRequestPostEventAccess` at populating the list
    /// after a prior denial.
    @discardableResult
    static func requestAccessibilityWithPrompt() -> Bool {
        // Literal matches `kAXTrustedCheckOptionPrompt` — the constant
        // isn't Sendable under Swift 6 strict concurrency, and the docs
        // explicitly allow the string form here.
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Forces TCC to register LayerKeys in the Input Monitoring list by
    /// attempting to create a listen-only session event tap. When
    /// permission is denied the tap creation returns nil — the side
    /// effect is the TCC daemon noticing our bundle and adding it to
    /// the visible list. `CGRequestListenEventAccess` alone has been
    /// observed to silently fail to populate the list, particularly
    /// after a previous denial or removal.
    static func probeInputMonitoringRegistration() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )
        guard let tap else { return }
        // Tap creation succeeded — permission is already granted. Tear
        // it down immediately so the real EventTapEngine owns the tap.
        CGEvent.tapEnable(tap: tap, enable: false)
    }

    static var hasListenEventAccess: Bool {
        CGPreflightListenEventAccess()
    }

    static var hasPostEventAccess: Bool {
        CGPreflightPostEventAccess()
    }
}
