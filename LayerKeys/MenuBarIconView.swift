import SwiftUI

struct MenuBarIconView: View {
    enum Variant: Equatable {
        case off
        case nav
        case numpad
        case denied
        case listenOnly
        case error
    }

    let variant: Variant
    let updateBadge: Bool

    var body: some View {
        // Filled in by Task 6. Kept minimal so the type compiles for Task 4
        // (the resolver lives in this file too) and Task 5 (the AppModel
        // computed property references Variant).
        EmptyView()
    }
}

func resolveMenuBarVariant(
    mode: LayerMode,
    perm: InputMonitoringPermissionState,
    tapErrorActive: Bool,
    updateAvailable: Bool
) -> (variant: MenuBarIconView.Variant, badge: Bool) {
    if tapErrorActive { return (.error, false) }
    if perm == .denied { return (.denied, false) }
    if perm == .listenOnly { return (.listenOnly, updateAvailable) }
    switch mode {
    case .off:    return (.off, updateAvailable)
    case .nav:    return (.nav, updateAvailable)
    case .numpad: return (.numpad, updateAvailable)
    }
}
