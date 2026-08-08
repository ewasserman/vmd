// Generates Support/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(pixels)
    // macOS icon grid: content occupies ~824/1024 of the canvas.
    let inset = size * 100 / 1024
    let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let radius = rect.width * 185 / 824
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let top = NSColor(calibratedRed: 0x31 / 255.0, green: 0x8d / 255.0, blue: 0xf8 / 255.0, alpha: 1)
    let bottom = NSColor(calibratedRed: 0x05 / 255.0, green: 0x50 / 255.0, blue: 0xae / 255.0, alpha: 1)
    NSGradient(starting: top, ending: bottom)!.draw(in: squircle, angle: -90)

    let glyph = "M↓" as NSString
    let font = NSFont.systemFont(ofSize: size * 0.34, weight: .heavy)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let glyphSize = glyph.size(withAttributes: attributes)
    glyph.draw(
        at: NSPoint(x: (size - glyphSize.width) / 2, y: (size - glyphSize.height) / 2),
        withAttributes: attributes
    )

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = URL(fileURLWithPath: "Support/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let rep = drawIcon(pixels: base * scale)
        let suffix = scale == 2 ? "@2x" : ""
        let url = iconset.appendingPathComponent("icon_\(base)x\(base)\(suffix).png")
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Support/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(iconutil.terminationStatus == 0 ? "wrote Support/AppIcon.icns" : "iconutil failed")
