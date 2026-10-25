// Draws the W-Player app icon and writes an .icns: swift scripts/make-icon.swift build/AppIcon.icns
// G-Player's graphite tile, with a screen on it: a dusk scene in the rain under a play mark, and the label strip from
// the library cards with its green "on desktop" dot.
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.icns"

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size / 1024
    // macOS icon grid: 824pt tile centred in 1024 with a continuous corner.
    let tile = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let path = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    ctx.saveGState()
    _ = NSShadow().then { $0.shadowColor = NSColor.black.withAlphaComponent(0.35); $0.shadowBlurRadius = 24 * s; $0.shadowOffset = NSSize(width: 0, height: -10 * s); $0.set() }
    NSColor(calibratedRed: 0.145, green: 0.157, blue: 0.180, alpha: 1).setFill()
    path.fill()
    ctx.restoreGState()
    path.addClip()
    let light = NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])!
    light.draw(in: CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)

    // The screen: dusk, rain, a hill line.
    let screen = CGRect(x: tile.minX + 92 * s, y: tile.minY + 230 * s, width: 640 * s, height: 420 * s)
    let screenPath = NSBezierPath(roundedRect: screen, xRadius: 40 * s, yRadius: 40 * s)
    ctx.saveGState()
    screenPath.addClip()
    NSGradient(colors: [NSColor(calibratedRed: 0.42, green: 0.53, blue: 0.62, alpha: 1),
                        NSColor(calibratedRed: 0.20, green: 0.27, blue: 0.36, alpha: 1)])!
        .draw(in: screen, angle: -90)
    let hill = NSBezierPath()
    hill.move(to: CGPoint(x: screen.minX, y: screen.minY + 120 * s))
    hill.curve(to: CGPoint(x: screen.maxX, y: screen.minY + 90 * s),
               controlPoint1: CGPoint(x: screen.minX + 220 * s, y: screen.minY + 220 * s),
               controlPoint2: CGPoint(x: screen.minX + 420 * s, y: screen.minY + 40 * s))
    hill.line(to: CGPoint(x: screen.maxX, y: screen.minY))
    hill.line(to: CGPoint(x: screen.minX, y: screen.minY))
    hill.close()
    NSColor(calibratedRed: 0.16, green: 0.24, blue: 0.22, alpha: 1).setFill()
    hill.fill()
    NSColor.white.withAlphaComponent(0.28).setStroke()
    for i in 0..<14 {
        let x = screen.minX + CGFloat((i * 53) % 640) * s + 20 * s
        let y = screen.minY + CGFloat((i * 97) % 380) * s + 30 * s
        let drop = NSBezierPath()
        drop.move(to: CGPoint(x: x, y: y))
        drop.line(to: CGPoint(x: x - 18 * s, y: y - 62 * s))
        drop.lineWidth = 7 * s
        drop.lineCapStyle = .round
        drop.stroke()
    }
    ctx.restoreGState()

    // Play mark, slightly rounded.
    let tri = NSBezierPath()
    let cx = screen.midX + 18 * s, cy = screen.midY, h = 190 * s
    tri.move(to: CGPoint(x: cx - h * 0.48, y: cy + h * 0.56))
    tri.line(to: CGPoint(x: cx + h * 0.62, y: cy))
    tri.line(to: CGPoint(x: cx - h * 0.48, y: cy - h * 0.56))
    tri.close()
    tri.lineJoinStyle = .round
    tri.lineWidth = 34 * s
    NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
    NSColor(calibratedWhite: 0.97, alpha: 1).setStroke()
    tri.fill(); tri.stroke()

    // Label strip: green dot and a bar.
    let strip = CGRect(x: tile.minX, y: tile.minY, width: tile.width, height: 150 * s)
    NSColor.black.withAlphaComponent(0.38).setFill()
    strip.fill()
    let d = 46 * s
    NSColor(calibratedRed: 0.30, green: 0.78, blue: 0.40, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: tile.minX + 92 * s, y: strip.midY - d / 2, width: d, height: d)).fill()
    let bar = CGRect(x: tile.minX + 180 * s, y: strip.midY - 9 * s, width: 550 * s, height: 18 * s)
    NSColor.white.withAlphaComponent(0.55).setFill()
    NSBezierPath(roundedRect: bar, xRadius: 9 * s, yRadius: 9 * s).fill()
    image.unlockFocus()
    return image
}

extension NSShadow { func then(_ f: (NSShadow) -> Void) -> NSShadow { f(self); return self } }

let fm = FileManager.default
let iconset = URL(fileURLWithPath: output).deletingPathExtension().appendingPathExtension("iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let img = draw(size: px)
        let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
        rep.size = NSSize(width: px, height: px)
        let png = rep.representation(using: .png, properties: [:])!
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! png.write(to: iconset.appendingPathComponent(name))
    }
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", output]
try! p.run(); p.waitUntilExit()
try? fm.removeItem(at: iconset)
print("icon: \(output)")
