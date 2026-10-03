// Renders the app icon (1024×1024 PNG): a purple macOS-style squircle with three window tiles.
// Usage: swift Tools/make-icon.swift <output.png>
import AppKit

let size = 1024.0
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"

func color(_ hex: UInt32, _ alpha: Double = 1) -> NSColor {
    NSColor(srgbRed: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Body: Apple's icon grid – 824 pt squircle centered on a 1024 canvas
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
color(0x5B33B0).setFill()
bodyPath.fill()
ctx.restoreGState()

NSGradient(colors: [color(0x9B6BEA), color(0x6A3CC9), color(0x3E1F8F)],
           atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: bodyPath, angle: -90)

// Soft top highlight
ctx.saveGState()
bodyPath.addClip()
NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
ctx.restoreGState()

// Window tiles: one tall on the left, two stacked on the right
let area = body.insetBy(dx: 118, dy: 130)
let gap = 30.0
let leftW = (area.width - gap) * 0.5
let rightW = area.width - gap - leftW
let halfH = (area.height - gap) / 2
let tiles: [(NSRect, UInt32, UInt32)] = [
    (NSRect(x: area.minX, y: area.minY, width: leftW, height: area.height), 0xC7B4FF, 0x9F86F0),
    (NSRect(x: area.maxX - rightW, y: area.minY + halfH + gap, width: rightW, height: halfH), 0x9BE8B4, 0x5FC68A),
    (NSRect(x: area.maxX - rightW, y: area.minY, width: rightW, height: halfH), 0xFFE08A, 0xF2B94B),
]

for (rect, top, bottom) in tiles {
    let path = NSBezierPath(roundedRect: rect, xRadius: 44, yRadius: 44)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    color(bottom).setFill()
    path.fill()
    ctx.restoreGState()
    NSGradient(starting: color(top), ending: color(bottom))!.draw(in: path, angle: -90)

    // Title bar with three dots
    ctx.saveGState()
    path.addClip()
    color(0xFFFFFF, 0.35).setFill()
    NSRect(x: rect.minX, y: rect.maxY - 62, width: rect.width, height: 62).fill()
    for i in 0..<3 {
        let d = NSRect(x: rect.minX + 30 + Double(i) * 34, y: rect.maxY - 42, width: 22, height: 22)
        color(0x3E1F8F, 0.45).setFill()
        NSBezierPath(ovalIn: d).fill()
    }
    ctx.restoreGState()

    color(0xFFFFFF, 0.55).setStroke()
    let border = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 42, yRadius: 42)
    border.lineWidth = 4
    border.stroke()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
