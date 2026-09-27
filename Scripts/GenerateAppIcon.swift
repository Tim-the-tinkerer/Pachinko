#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

func renderIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let margin = s * 0.06
    let corner = s * 0.18
    let rect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let colors = [
        CGColor(srgbRed: 0.42, green: 0.06, blue: 0.12, alpha: 1),
        CGColor(srgbRed: 0.18, green: 0.03, blue: 0.06, alpha: 1),
        CGColor(srgbRed: 0.06, green: 0.02, blue: 0.03, alpha: 1),
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.45, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }

    let cx = rect.midX
    let cy = rect.midY
    let gold = CGColor(srgbRed: 0.96, green: 0.78, blue: 0.28, alpha: 1)
    let goldHi = CGColor(srgbRed: 1.0, green: 0.93, blue: 0.62, alpha: 1)
    let nail = CGColor(srgbRed: 0.86, green: 0.80, blue: 0.62, alpha: 1)
    let pink = CGColor(srgbRed: 1.0, green: 0.55, blue: 0.68, alpha: 1)

    // Playfield glass
    let field = CGRect(x: cx - s * 0.28, y: cy - s * 0.32, width: s * 0.52, height: s * 0.62)
    ctx.setFillColor(CGColor(srgbRed: 0.48, green: 0.08, blue: 0.16, alpha: 1))
    ctx.fill(field)
    ctx.setStrokeColor(gold)
    ctx.setLineWidth(max(1, s * 0.012))
    ctx.stroke(field)

    // Nails
    func drawNail(at p: CGPoint, r: CGFloat, g: Bool) {
        ctx.setFillColor(g ? gold : nail)
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    }
    let nr = max(1.2, s * 0.016)
    for row in 0..<7 {
        let cols = row % 2 == 0 ? 5 : 4
        let y = field.minY + s * 0.10 + CGFloat(row) * s * 0.062
        let offset: CGFloat = row % 2 == 0 ? 0 : s * 0.032
        for col in 0..<cols {
            let x = field.minX + s * 0.08 + offset + CGFloat(col) * s * 0.08
            drawNail(at: CGPoint(x: x, y: y), r: nr, g: (row + col) % 3 == 0)
        }
    }

    // Center chucker
    let holeR = s * 0.045
    let hole = CGPoint(x: cx - s * 0.02, y: cy - s * 0.02)
    ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.85))
    ctx.fillEllipse(in: CGRect(x: hole.x - holeR, y: hole.y - holeR, width: holeR * 2, height: holeR * 2))
    ctx.setStrokeColor(goldHi)
    ctx.setLineWidth(max(1, s * 0.01))
    ctx.strokeEllipse(in: CGRect(x: hole.x - holeR, y: hole.y - holeR, width: holeR * 2, height: holeR * 2))

    // Steel ball
    let br = s * 0.07
    let bp = CGPoint(x: cx + s * 0.06, y: cy + s * 0.08)
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: bp.x - br, y: bp.y - br, width: br * 2, height: br * 2))
    ctx.clip()
    if let g = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
            CGColor(srgbRed: 0.72, green: 0.74, blue: 0.78, alpha: 1),
            CGColor(srgbRed: 0.32, green: 0.34, blue: 0.40, alpha: 1),
        ] as CFArray,
        locations: [0, 0.4, 1]
    ) {
        ctx.drawRadialGradient(
            g,
            startCenter: CGPoint(x: bp.x - br * 0.3, y: bp.y + br * 0.3),
            startRadius: 0,
            endCenter: bp,
            endRadius: br,
            options: []
        )
    }
    ctx.restoreGState()

    // Handle knob
    let hx = cx + s * 0.28
    let hy = cy - s * 0.22
    let hr = s * 0.07
    ctx.setFillColor(gold)
    ctx.fillEllipse(in: CGRect(x: hx - hr, y: hy - hr, width: hr * 2, height: hr * 2))
    ctx.setFillColor(CGColor(srgbRed: 0.12, green: 0.04, blue: 0.05, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: hx - hr * 0.35, y: hy - hr * 0.35, width: hr * 0.7, height: hr * 0.7))

    // Petal
    ctx.setFillColor(pink)
    ctx.fillEllipse(in: CGRect(x: cx - s * 0.22, y: cy + s * 0.18, width: s * 0.06, height: s * 0.035))
    ctx.fillEllipse(in: CGRect(x: cx + s * 0.16, y: cy + s * 0.22, width: s * 0.05, height: s * 0.03))

    ctx.restoreGState()

    ctx.setStrokeColor(CGColor(srgbRed: 0.96, green: 0.78, blue: 0.28, alpha: 0.7))
    ctx.setLineWidth(max(1, s * 0.02))
    ctx.addPath(path)
    ctx.strokePath()

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create PNG destination")
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

let iconset = assets.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let atRetina = "@" + "2x.png"
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16" + atRetina),
    (32, "icon_32x32.png"),
    (64, "icon_32x32" + atRetina),
    (128, "icon_128x128.png"),
    (256, "icon_128x128" + atRetina),
    (256, "icon_256x256.png"),
    (512, "icon_256x256" + atRetina),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512" + atRetina),
]

for (size, name) in sizes {
    guard let img = renderIcon(size: size) else { fatalError("render failed \(size)") }
    writePNG(img, to: iconset.appendingPathComponent(name))
}

if let master = renderIcon(size: 1024) {
    writePNG(master, to: assets.appendingPathComponent("AppIcon-1024.png"))
}

let icns = assets.appendingPathComponent("AppIcon.icns")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try proc.run()
proc.waitUntilExit()
guard proc.terminationStatus == 0 else {
    fputs("warning: iconutil failed (status \(proc.terminationStatus))\n", stderr)
    exit(0)
}
print("Wrote \(icns.path)")
