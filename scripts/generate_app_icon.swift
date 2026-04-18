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

func symbolImage(pointSize: CGFloat) -> NSImage {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold, scale: .large)
    let names = ["keyboard.fill", "keyboard"]

    for name in names {
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        {
            return image
        }
    }

    fatalError("Could not load a keyboard SF Symbol")
}

func pngData(for size: Int) -> Data {
    let width = size
    let height = size
    let imageSize = NSSize(width: width, height: height)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
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

    rep.size = imageSize

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create graphics context")
    }
    NSGraphicsContext.current = context

    let rect = NSRect(origin: .zero, size: imageSize)
    let radius = CGFloat(size) * 0.224
    let cardInset = CGFloat(size) * 0.06
    let cardRect = rect.insetBy(dx: cardInset, dy: cardInset)
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.22)
    shadow.shadowBlurRadius = CGFloat(size) * 0.08
    shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.024)
    shadow.set()

    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.15, green: 0.52, blue: 0.93, alpha: 1.0),
            NSColor(calibratedRed: 0.09, green: 0.26, blue: 0.82, alpha: 1.0),
        ]
    )!
    gradient.draw(in: cardPath, angle: -90)

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let rimPath = NSBezierPath(roundedRect: cardRect.insetBy(dx: CGFloat(size) * 0.006, dy: CGFloat(size) * 0.006), xRadius: radius * 0.94, yRadius: radius * 0.94)
    NSColor(calibratedWhite: 1.0, alpha: 0.16).setStroke()
    rimPath.lineWidth = max(1, CGFloat(size) * 0.012)
    rimPath.stroke()

    let panelHeight = CGFloat(size) * 0.22
    let panelRect = NSRect(
        x: cardRect.minX + CGFloat(size) * 0.04,
        y: cardRect.minY + CGFloat(size) * 0.06,
        width: cardRect.width - CGFloat(size) * 0.08,
        height: panelHeight
    )
    let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: panelHeight * 0.4, yRadius: panelHeight * 0.4)
    NSColor(calibratedWhite: 1.0, alpha: 0.14).setFill()
    panelPath.fill()

    let glyphBackgroundSize = CGFloat(size) * 0.56
    let glyphBackgroundRect = NSRect(
        x: rect.midX - glyphBackgroundSize / 2,
        y: rect.midY - glyphBackgroundSize / 2 + CGFloat(size) * 0.05,
        width: glyphBackgroundSize,
        height: glyphBackgroundSize
    )
    let glyphBackgroundPath = NSBezierPath(roundedRect: glyphBackgroundRect, xRadius: glyphBackgroundSize * 0.22, yRadius: glyphBackgroundSize * 0.22)
    NSColor(calibratedWhite: 1.0, alpha: 0.15).setFill()
    glyphBackgroundPath.fill()

    let symbol = symbolImage(pointSize: CGFloat(size) * 0.33)
    let symbolSize = NSSize(width: CGFloat(size) * 0.38, height: CGFloat(size) * 0.38)
    let symbolRect = NSRect(
        x: rect.midX - symbolSize.width / 2,
        y: rect.midY - symbolSize.height / 2 + CGFloat(size) * 0.05,
        width: symbolSize.width,
        height: symbolSize.height
    )
    symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    let badgeSize = CGFloat(size) * 0.18
    let badgeRect = NSRect(
        x: cardRect.maxX - badgeSize - CGFloat(size) * 0.05,
        y: cardRect.maxY - badgeSize - CGFloat(size) * 0.05,
        width: badgeSize,
        height: badgeSize
    )
    let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeSize * 0.38, yRadius: badgeSize * 0.38)
    NSColor(calibratedRed: 0.45, green: 0.92, blue: 0.76, alpha: 0.95).setFill()
    badgePath.fill()

    let badgeInnerInset = badgeSize * 0.24
    let badgeInner = badgeRect.insetBy(dx: badgeInnerInset, dy: badgeInnerInset)
    NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.28, alpha: 0.9).setFill()
    NSBezierPath(roundedRect: badgeInner, xRadius: badgeInner.width * 0.24, yRadius: badgeInner.height * 0.24).fill()

    NSGraphicsContext.restoreGraphicsState()

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
