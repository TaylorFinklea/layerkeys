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

    static var hasListenEventAccess: Bool {
        CGPreflightListenEventAccess()
    }

    static var hasPostEventAccess: Bool {
        CGPreflightPostEventAccess()
    }
}
