import SwiftUI

struct MenuBarIconView: View {
    enum Variant: Equatable {
        case off
        case nav
        case numpad
        case denied
        case listenOnly
        case error

        var tint: Color {
            switch self {
            case .denied: return .orange
            case .error:  return .red
            default:      return .primary
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .off:        return "LayerKeys, idle"
            case .nav:        return "LayerKeys, navigation layer active"
            case .numpad:     return "LayerKeys, numpad layer active"
            case .denied:     return "LayerKeys, input monitoring permission denied"
            case .listenOnly: return "LayerKeys, listen-only mode \u{2014} tap-to-Escape disabled"
            case .error:      return "LayerKeys, event tap error"
            }
        }
    }

    /// Native viewBox the SVG paths were authored in. All draw calls happen
    /// in this 24-unit space and the Canvas scales to the actual size.
    private static let viewBox: CGFloat = 24

    let variant: Variant
    let updateBadge: Bool

    var body: some View {
        Canvas { ctx, size in
            let scale = min(size.width, size.height) / Self.viewBox
            ctx.scaleBy(x: scale, y: scale)

            drawCapShell(in: &ctx)
            drawInnerContent(in: &ctx)
            if updateBadge { drawUpdateBadge(in: &ctx) }
        }
        .foregroundStyle(variant.tint)
        .accessibilityLabel(variant.accessibilityLabel)
    }

    // MARK: - Drawing primitives

    private func drawCapShell(in ctx: inout GraphicsContext) {
        let cap = Path(roundedRect: CGRect(x: 3, y: 5, width: 18, height: 14),
                       cornerSize: CGSize(width: 2.5, height: 2.5))
        ctx.stroke(cap, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        let shelf = Path { p in
            p.move(to: CGPoint(x: 3, y: 11))
            p.addLine(to: CGPoint(x: 21, y: 11))
        }
        ctx.stroke(shelf, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func drawInnerContent(in ctx: inout GraphicsContext) {
        switch variant {
        case .off:
            let dot = Path(ellipseIn: CGRect(x: 12 - 0.6, y: 15 - 0.6, width: 1.2, height: 1.2))
            ctx.fill(dot, with: .foreground)
        case .nav, .numpad, .denied, .listenOnly, .error:
            // Filled in by Tasks 7-9.
            break
        }
    }

    private func drawUpdateBadge(in ctx: inout GraphicsContext) {
        // Filled in by Task 9.
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
