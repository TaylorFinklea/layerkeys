#!/usr/bin/env swift

import AppKit
import Foundation

struct IconSpec {
    let filename: String
    let size: Int
}

let specs: [IconSpec] = [
    .init(filename: "icon_16x16.png", size: 16),
    .init(filename: "icon_16x16@2x.png", size: 32),
    .init(filename: "icon_32x32.png", size: 32),
    .init(filename: "icon_32x32@2x.png", size: 64),
    .init(filename: "icon_128x128.png", size: 128),
    .init(filename: "icon_128x128@2x.png", size: 256),
    .init(filename: "icon_256x256.png", size: 256),
    .init(filename: "icon_256x256@2x.png", size: 512),
    .init(filename: "icon_512x512.png", size: 512),
    .init(filename: "icon_512x512@2x.png", size: 1024),
]

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: generate_app_icon.swift <output-directory>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// MARK: - Drawing

/// Renders the LayerKeys app icon at the given pixel size.
///
/// A single stylized keycap (matching MenuBarIconView's silhouette: rounded
/// rect with a horizontal "shelf" line) centered on a deep-indigo squircle.
/// 10% canvas padding leaves the squircle at 80% of canvas — Apple's modern
/// macOS icon grid.
func pngData(for size: Int) -> Data {
    let s = CGFloat(size)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap rep")
    }

    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create graphics context")
    }
    NSGraphicsContext.current = context

    // At 16×16 the canvas is too small for gradients, shading, or a 3D
    // shelf to render — anti-aliasing eats the detail and the icon
    // becomes a mushy rectangle. Render a flat, high-contrast version
    // so the silhouette stays legible.
    if size <= 16 {
        let smallInset = s * 0.05
        let smallSquircle = NSRect(
            x: smallInset, y: smallInset,
            width: s - smallInset * 2, height: s - smallInset * 2
        )
        let smallRadius = smallSquircle.width * 0.2237
        let smallPath = NSBezierPath(
            roundedRect: smallSquircle,
            xRadius: smallRadius, yRadius: smallRadius
        )
        NSColor(srgbRed: 0.18, green: 0.22, blue: 0.55, alpha: 1.0).setFill()
        smallPath.fill()

        let smallCapWidth = smallSquircle.width * 0.62
        let smallCapHeight = smallSquircle.height * 0.50
        let smallCapRect = NSRect(
            x: smallSquircle.midX - smallCapWidth / 2,
            y: smallSquircle.midY - smallCapHeight / 2,
            width: smallCapWidth,
            height: smallCapHeight
        )
        let smallCapPath = NSBezierPath(
            roundedRect: smallCapRect,
            xRadius: smallCapHeight * 0.20,
            yRadius: smallCapHeight * 0.20
        )
        NSColor.white.setFill()
        smallCapPath.fill()

        guard let data = rep.representation(using: .png, properties: [:]) else {
            fatalError("Could not encode PNG")
        }
        return data
    }

    let inset = s * 0.10
    let squircleRect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let squircleRadius = squircleRect.width * 0.2237

    // Drop shadow under the squircle (depth on Finder/Launchpad backgrounds).
    if size >= 64 {
        let bgShadow = NSShadow()
        bgShadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.18)
        bgShadow.shadowBlurRadius = s * 0.025
        bgShadow.shadowOffset = NSSize(width: 0, height: -s * 0.015)
        bgShadow.set()
    }

    let squirclePath = NSBezierPath(
        roundedRect: squircleRect,
        xRadius: squircleRadius,
        yRadius: squircleRadius
    )

    let backgroundGradient = NSGradient(colors: [
        NSColor(srgbRed: 0.34, green: 0.42, blue: 0.78, alpha: 1.0),  // top
        NSColor(srgbRed: 0.10, green: 0.13, blue: 0.36, alpha: 1.0),  // bottom
    ])!
    backgroundGradient.draw(in: squirclePath, angle: 270)

    NSShadow().set()

    // Inner top highlight on the squircle (lit-from-above feel).
    if size >= 64 {
        NSGraphicsContext.saveGraphicsState()
        squirclePath.addClip()
        let highlightRect = NSRect(
            x: squircleRect.minX,
            y: squircleRect.maxY - squircleRect.height * 0.45,
            width: squircleRect.width,
            height: squircleRect.height * 0.45
        )
        let highlight = NSGradient(colors: [
            NSColor(calibratedWhite: 1.0, alpha: 0.10),
            NSColor(calibratedWhite: 1.0, alpha: 0.0),
        ])!
        highlight.draw(in: highlightRect, angle: 270)
        NSGraphicsContext.restoreGraphicsState()
    }

    // Thin inner rim on the squircle.
    if size >= 32 {
        let rimInset = max(s * 0.004, 0.5)
        let rimPath = NSBezierPath(
            roundedRect: squircleRect.insetBy(dx: rimInset, dy: rimInset),
            xRadius: squircleRadius - rimInset,
            yRadius: squircleRadius - rimInset
        )
        NSColor(calibratedWhite: 1.0, alpha: 0.08).setStroke()
        rimPath.lineWidth = max(s * 0.003, 0.5)
        rimPath.stroke()
    }

    // Keycap geometry. Larger than the menu-bar icon's proportions so the
    // shape survives at 16×16. Top face (above shelf) is taller than the
    // side face below it — keycap perspective.
    let capWidth = squircleRect.width * 0.74
    let capHeight = squircleRect.height * 0.62
    let capRect = NSRect(
        x: squircleRect.midX - capWidth / 2,
        y: squircleRect.midY - capHeight / 2,
        width: capWidth,
        height: capHeight
    )
    let capRadius = capHeight * 0.16
    // Shelf sits above middle so the lit top face is the dominant area
    // and the shadowed side face is a thinner band.
    let shelfY = capRect.minY + capHeight * 0.35

    // Keycap drop shadow under the whole cap.
    if size >= 32 {
        let capShadow = NSShadow()
        capShadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.32)
        capShadow.shadowBlurRadius = s * 0.022
        capShadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
        capShadow.set()
    }

    let capPath = NSBezierPath(roundedRect: capRect, xRadius: capRadius, yRadius: capRadius)
    capPath.addClip()  // shadow applies to the whole silhouette below
    NSColor.white.setFill()
    capPath.fill()

    NSShadow().set()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    // Re-fill the cap with a subtle top-down highlight, then darken the
    // lower face so the shelf reads as a 3D edge rather than a divider.
    NSGraphicsContext.saveGraphicsState()
    capPath.addClip()

    // Top face: bright white with a hint of off-white at the bottom of
    // the top face (just above the shelf).
    let topFaceRect = NSRect(
        x: capRect.minX,
        y: shelfY,
        width: capRect.width,
        height: capRect.maxY - shelfY
    )
    let topFaceGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.97, alpha: 1.0),  // just above shelf
        NSColor(calibratedWhite: 1.00, alpha: 1.0),  // top edge
    ])!
    topFaceGradient.draw(in: topFaceRect, angle: 90)

    // Side face (below shelf): darker grey, suggests the cap's vertical
    // side wall in shadow.
    let sideFaceRect = NSRect(
        x: capRect.minX,
        y: capRect.minY,
        width: capRect.width,
        height: shelfY - capRect.minY
    )
    let sideFaceGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.78, alpha: 1.0),  // bottom edge — darkest
        NSColor(calibratedWhite: 0.88, alpha: 1.0),  // just below shelf
    ])!
    sideFaceGradient.draw(in: sideFaceRect, angle: 90)

    NSGraphicsContext.restoreGraphicsState()

    // Crisp shelf line at the boundary between the two faces.
    if size >= 32 {
        let shelf = NSBezierPath()
        shelf.move(to: NSPoint(x: capRect.minX, y: shelfY))
        shelf.line(to: NSPoint(x: capRect.maxX, y: shelfY))

        NSGraphicsContext.saveGraphicsState()
        capPath.addClip()
        NSColor(calibratedWhite: 0.0, alpha: 0.16).setStroke()
        shelf.lineWidth = max(s * 0.006, 0.5)
        shelf.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    return data
}

let contents = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

for spec in specs {
    let data = pngData(for: spec.size)
    try data.write(to: outputDirectory.appendingPathComponent(spec.filename))
}

try contents.data(using: .utf8)?.write(to: outputDirectory.appendingPathComponent("Contents.json"))

// Also produce an AppIcon.icns adjacent to Info.plist. We bundle this
// .icns directly rather than letting actool compile the asset catalog,
// because on macOS 26 actool drops several icns slots (notably 512px and
// 1024px) when source PNGs at "duplicate" pixel counts are byte-identical
// — leaving the app with a visibly missing icon in Finder/Dock at large
// sizes. iconutil produces a complete .icns from the same PNGs.
let parent = outputDirectory.deletingLastPathComponent()  // Assets.xcassets/
let layerKeysDir = parent.deletingLastPathComponent()     // LayerKeys/
let icnsURL = layerKeysDir.appendingPathComponent("AppIcon.icns")

let tmpIconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("layerkeys-build-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: tmpIconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tmpIconset) }

for spec in specs {
    try FileManager.default.copyItem(
        at: outputDirectory.appendingPathComponent(spec.filename),
        to: tmpIconset.appendingPathComponent(spec.filename)
    )
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", tmpIconset.path, "-o", icnsURL.path]
let errPipe = Pipe()
iconutil.standardError = errPipe
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 {
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    fputs("iconutil failed: \(String(data: errData, encoding: .utf8) ?? "")\n", stderr)
    exit(Int32(iconutil.terminationStatus))
}
