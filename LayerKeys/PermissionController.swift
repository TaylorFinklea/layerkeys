import CoreGraphics
import Foundation

enum InputMonitoringPermissionState: Equatable {
    case granted
    case denied

    var isGranted: Bool {
        self == .granted
    }

    var title: String {
        switch self {
        case .granted:
            return "Input Monitoring Enabled"
        case .denied:
            return "Input Monitoring Required"
        }
    }

    var detail: String {
        switch self {
        case .granted:
            return "LayerKeys can intercept the Globe/Fn chord and remap keys globally."
        case .denied:
            return "Grant Input Monitoring so LayerKeys can see global key events and apply remaps."
        }
    }
}

enum PermissionController {
    static func currentState() -> InputMonitoringPermissionState {
        CGPreflightListenEventAccess() ? .granted : .denied
    }

    @discardableResult
    static func requestListenAccess() -> Bool {
        CGRequestListenEventAccess()
    }
}
