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
        ctx.stroke(cap, with: .color(variant.tint), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        let shelf = Path { p in
            p.move(to: CGPoint(x: 3, y: 11))
            p.addLine(to: CGPoint(x: 21, y: 11))
        }
        ctx.stroke(shelf, with: .color(variant.tint), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func drawInnerContent(in ctx: inout GraphicsContext) {
        switch variant {
        case .off:
            let dot = Path(ellipseIn: CGRect(x: 12 - 0.6, y: 15 - 0.6, width: 1.2, height: 1.2))
            ctx.fill(dot, with: .color(variant.tint))

        case .nav:
            // 4-way directional cluster: cross + 4 chevrons, all within
            // x=9.5..14.5, y=12.5..17.5 (entirely inside the lower face).
            let stroke = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            let cross = Path { p in
                p.move(to: CGPoint(x: 12,   y: 12.5)); p.addLine(to: CGPoint(x: 12,   y: 17.5))
                p.move(to: CGPoint(x: 9.5,  y: 15));   p.addLine(to: CGPoint(x: 14.5, y: 15))
            }
            ctx.stroke(cross, with: .color(variant.tint), style: stroke)
            let chevrons = Path { p in
                p.move(to: CGPoint(x: 10.8, y: 13.7)); p.addLine(to: CGPoint(x: 12, y: 12.5)); p.addLine(to: CGPoint(x: 13.2, y: 13.7))
                p.move(to: CGPoint(x: 10.8, y: 16.3)); p.addLine(to: CGPoint(x: 12, y: 17.5)); p.addLine(to: CGPoint(x: 13.2, y: 16.3))
                p.move(to: CGPoint(x: 10.7, y: 14.0)); p.addLine(to: CGPoint(x: 9.5,  y: 15)); p.addLine(to: CGPoint(x: 10.7, y: 16.0))
                p.move(to: CGPoint(x: 13.3, y: 14.0)); p.addLine(to: CGPoint(x: 14.5, y: 15)); p.addLine(to: CGPoint(x: 13.3, y: 16.0))
            }
            ctx.stroke(chevrons, with: .color(variant.tint), style: stroke)

        case .numpad:
            // 3x3 dot grid: cols x=8,12,16; rows y=13,15,17; r=0.7.
            let dotRadius: CGFloat = 0.7
            let columns: [CGFloat] = [8, 12, 16]
            let rows: [CGFloat] = [13, 15, 17]
            var grid = Path()
            for x in columns {
                for y in rows {
                    grid.addEllipse(in: CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    ))
                }
            }
            ctx.fill(grid, with: .color(variant.tint))

        case .denied:
            // Diagonal slash from (5,6) to (19,18) at stroke-width 2.5.
            // Cap shell is already drawn (and tinted .orange via variant.tint);
            // the slash composes on top in the same color.
            let slash = Path { p in
                p.move(to: CGPoint(x: 5, y: 6))
                p.addLine(to: CGPoint(x: 19, y: 18))
            }
            ctx.stroke(slash, with: .color(variant.tint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        case .listenOnly:
            // Six explicit dash segments, three per row, mathematically
            // centered around x=12. y rows at 14.5 and 17.
            let dashStroke = StrokeStyle(lineWidth: 1.7, lineCap: .round)
            let segments = Path { p in
                let xs: [(CGFloat, CGFloat)] = [(6, 8), (11, 13), (16, 18)]
                for y in [CGFloat(14.5), CGFloat(17)] {
                    for (x1, x2) in xs {
                        p.move(to: CGPoint(x: x1, y: y))
                        p.addLine(to: CGPoint(x: x2, y: y))
                    }
                }
            }
            ctx.stroke(segments, with: .color(variant.tint), style: dashStroke)

        case .error:
            // ✕: two crossed lines from (9,13.5)→(15,17.5) and (15,13.5)→(9,17.5).
            // Cap shell is tinted .red via variant.tint.
            let cross = Path { p in
                p.move(to: CGPoint(x: 9,  y: 13.5)); p.addLine(to: CGPoint(x: 15, y: 17.5))
                p.move(to: CGPoint(x: 15, y: 13.5)); p.addLine(to: CGPoint(x: 9,  y: 17.5))
            }
            ctx.stroke(cross, with: .color(variant.tint), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    private func drawUpdateBadge(in ctx: inout GraphicsContext) {
        // Corner badge: filled circle at (20, 6) r=3 with white ↓ glyph inside.
        // Sits in the upper-right outside the cap rect.
        let disc = Path(ellipseIn: CGRect(x: 17, y: 3, width: 6, height: 6))
        ctx.fill(disc, with: .color(variant.tint))

        let arrow = Path { p in
            p.move(to: CGPoint(x: 20,   y: 4.6))
            p.addLine(to: CGPoint(x: 20, y: 7.4))
            p.move(to: CGPoint(x: 18.7, y: 6.2))
            p.addLine(to: CGPoint(x: 20, y: 7.5))
            p.addLine(to: CGPoint(x: 21.3, y: 6.2))
        }
        ctx.stroke(arrow, with: .color(.white), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
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
