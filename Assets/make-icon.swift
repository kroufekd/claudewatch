import AppKit

// Renders the ClaudeWatch app icon: an orange gauge arc on a dark graphite
// gradient squircle (Big Sur icon grid: 824 pt shape on a 1024 pt canvas).
// Usage: swift make-icon.swift <output-dir>
// Writes AppIcon.iconset/*.png; caller converts with iconutil.

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift make-icon.swift <output-dir>\n".utf8))
    exit(1)
}
let outputDir = URL(fileURLWithPath: arguments[1], isDirectory: true)
    .appendingPathComponent("AppIcon.iconset", isDirectory: true)

func renderIcon(canvas: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { rect in
        let shapeSide = canvas * 824.0 / 1024.0
        let shapeRect = NSRect(
            x: (canvas - shapeSide) / 2,
            y: (canvas - shapeSide) / 2,
            width: shapeSide,
            height: shapeSide
        )
        let cornerRadius = shapeSide * 0.2237
        let shape = NSBezierPath(roundedRect: shapeRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Background: dark graphite, slightly lighter at the top.
        NSGradient(
            starting: NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.20, alpha: 1),
            ending: NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 1)
        )?.draw(in: shape, angle: -90)

        // Gauge: track arc + partial fill arc in Claude orange.
        let center = NSPoint(x: rect.midX, y: rect.midY - shapeSide * 0.06)
        let radius = shapeSide * 0.30
        let lineWidth = shapeSide * 0.09

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 200, endAngle: -20, clockwise: true)
        track.lineWidth = lineWidth
        track.lineCapStyle = .round
        NSColor(calibratedWhite: 1.0, alpha: 0.18).setStroke()
        track.stroke()

        let fill = NSBezierPath()
        fill.appendArc(withCenter: center, radius: radius, startAngle: 200, endAngle: 55, clockwise: true)
        fill.lineWidth = lineWidth
        fill.lineCapStyle = .round
        NSColor(calibratedRed: 0.85, green: 0.47, blue: 0.25, alpha: 1).setStroke()
        fill.stroke()

        // Needle dot at the end of the fill.
        let angle = 55.0 * .pi / 180
        let dotCenter = NSPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
        let dotRadius = lineWidth * 0.75
        let dot = NSBezierPath(ovalIn: NSRect(
            x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
            width: dotRadius * 2, height: dotRadius * 2
        ))
        NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.45, alpha: 1).setFill()
        dot.fill()

        return true
    }
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return }
    rep.size = image.size
    guard let resized = rep.retagging(with: .sRGB) ?? rep as NSBitmapImageRep?,
          let cgImage = resized.cgImage else { return }

    let target = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: target)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.interpolationQuality = .high
    context.cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = target.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: url)
}

try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let sizes: [(name: String, points: Int, scale: Int)] = [
    ("icon_16x16", 16, 1), ("icon_16x16@2x", 16, 2),
    ("icon_32x32", 32, 1), ("icon_32x32@2x", 32, 2),
    ("icon_128x128", 128, 1), ("icon_128x128@2x", 128, 2),
    ("icon_256x256", 256, 1), ("icon_256x256@2x", 256, 2),
    ("icon_512x512", 512, 1), ("icon_512x512@2x", 512, 2)
]

for entry in sizes {
    let pixels = entry.points * entry.scale
    let image = renderIcon(canvas: CGFloat(pixels))
    writePNG(image, to: outputDir.appendingPathComponent("\(entry.name).png"), pixels: pixels)
}
print("iconset written to \(outputDir.path)")
