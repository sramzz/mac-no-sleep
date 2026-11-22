import AppKit
import Foundation

func renderMasterIcon() -> NSImage {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // Standard macOS squircle geometry (824x824 centered in 1024x1024)
    let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 185.0

    // 1. Drop shadow under squircle
    ctx.saveGState()
    let shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 36, color: shadowColor)
    let shadowPath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(shadowPath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Base squircle clipping
    ctx.saveGState()
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(squirclePath)
    ctx.clip()

    // Background gradient: Rich modern graphite/warm espresso
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 0.18, green: 0.16, blue: 0.20, alpha: 1.0).cgColor,
        NSColor(red: 0.10, green: 0.09, blue: 0.12, alpha: 1.0).cgColor,
        NSColor(red: 0.06, green: 0.05, blue: 0.08, alpha: 1.0).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.55, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(
            bgGradient,
            start: CGPoint(x: 512, y: 924),
            end: CGPoint(x: 512, y: 100),
            options: []
        )
    }

    // Warm radial glow in upper-center (resembling warm coffee aroma / power light)
    let glowColors = [
        NSColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 0.22).cgColor,
        NSColor(red: 0.95, green: 0.45, blue: 0.10, alpha: 0.0).cgColor
    ] as CFArray
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            glowGradient,
            startCenter: CGPoint(x: 512, y: 560),
            startRadius: 20,
            endCenter: CGPoint(x: 512, y: 560),
            endRadius: 380,
            options: []
        )
    }

    // Inner subtle top specular highlight
    let rimColors = [
        NSColor.white.withAlphaComponent(0.25).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ] as CFArray
    if let rimGradient = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 1.0]) {
        let rimRect = NSRect(x: 100, y: 840, width: 824, height: 84)
        ctx.saveGState()
        ctx.clip(to: rimRect)
        ctx.drawLinearGradient(rimGradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 840), options: [])
        ctx.restoreGState()
    }

    ctx.restoreGState() // Exit squircle clip

    // 3. Inner border stroke
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setLineWidth(3.0)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Central Icon: Pure vector Active Syringe + Eye tinted with warm amber gradient
    let targetRect = NSRect(x: 232, y: 232, width: 560, height: 560)
    let offX = 4.0
    let offY = 11.0
    let scale = targetRect.width / 165.0

    func canvasPoint(cx: Double, cy: Double) -> CGPoint {
        CGPoint(
            x: targetRect.minX + CGFloat(cx) * scale,
            y: targetRect.maxY - CGFloat(cy) * scale
        )
    }

    func uvPoint(_ u: Double, _ v: Double) -> CGPoint {
        let cx = offX + (u + v) * 0.5
        let cy = offY + (u - v) * 0.5
        return canvasPoint(cx: cx, cy: cy)
    }

    func addUVRect(_ path: CGMutablePath, uMin: Double, uMax: Double, vMin: Double, vMax: Double) {
        path.move(to: uvPoint(uMin, vMin))
        path.addLine(to: uvPoint(uMax, vMin))
        path.addLine(to: uvPoint(uMax, vMax))
        path.addLine(to: uvPoint(uMin, vMax))
        path.closeSubpath()
    }

    let syringePath = CGMutablePath()
    // Plunger handle
    addUVRect(syringePath, uMin: 127, uMax: 173, vMin: -128, vMax: -116)
    // Plunger shaft
    addUVRect(syringePath, uMin: 143, uMax: 159, vMin: -116, vMax: -83)
    // Finger flange
    addUVRect(syringePath, uMin: 107, uMax: 193, vMin: -83, vMax: -72)
    // Filled syringe barrel
    addUVRect(syringePath, uMin: 121, uMax: 177, vMin: -72, vMax: 52)
    // 3 negative-space graduation notches (subtracted via even-odd fill)
    addUVRect(syringePath, uMin: 134, uMax: 152, vMin: -45, vMax: -35)
    addUVRect(syringePath, uMin: 134, uMax: 152, vMin: -17, vMax: -7)
    addUVRect(syringePath, uMin: 134, uMax: 152, vMin: 11, vMax: 21)
    // Needle hub
    addUVRect(syringePath, uMin: 137, uMax: 159, vMin: 52, vMax: 71)
    // Needle
    addUVRect(syringePath, uMin: 145, uMax: 151, vMin: 71, vMax: 148)

    // 1.38x Eye centered at (122.0, 128.0) in 165x165 space
    let eyeCX = 122.0
    let eyeCY = 128.0
    let eyeRX = 35.0
    let eyeCtrlY = 21.0 / 0.75 // peak height ry = 21.0
    let eyePath = CGMutablePath()
    let leftCorner = canvasPoint(cx: eyeCX - eyeRX, cy: eyeCY)
    let rightCorner = canvasPoint(cx: eyeCX + eyeRX, cy: eyeCY)
    eyePath.move(to: leftCorner)
    eyePath.addCurve(
        to: rightCorner,
        control1: canvasPoint(cx: eyeCX - 0.45 * eyeRX, cy: eyeCY - eyeCtrlY),
        control2: canvasPoint(cx: eyeCX + 0.45 * eyeRX, cy: eyeCY - eyeCtrlY)
    )
    eyePath.addCurve(
        to: leftCorner,
        control1: canvasPoint(cx: eyeCX + 0.45 * eyeRX, cy: eyeCY + eyeCtrlY),
        control2: canvasPoint(cx: eyeCX - 0.45 * eyeRX, cy: eyeCY + eyeCtrlY)
    )
    eyePath.closeSubpath()

    let pupilCenter = canvasPoint(cx: eyeCX, cy: eyeCY)
    let pupilRadius = CGFloat(9.8 * scale)
    let pupilRect = CGRect(
        x: pupilCenter.x - pupilRadius,
        y: pupilCenter.y - pupilRadius,
        width: pupilRadius * 2.0,
        height: pupilRadius * 2.0
    )

    // Draw drop shadow and alpha-masked gradient in a transparency layer
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)

    ctx.setFillColor(NSColor.white.cgColor)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(CGFloat(6.8 * scale))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    ctx.addPath(syringePath)
    ctx.fillPath(using: .evenOdd)

    ctx.addPath(eyePath)
    ctx.strokePath()

    ctx.fillEllipse(in: pupilRect)

    ctx.setBlendMode(.sourceIn)
    ctx.clip(to: targetRect)

    let iconColors = [
        NSColor(red: 1.0, green: 0.92, blue: 0.72, alpha: 1.0).cgColor,
        NSColor(red: 1.0, green: 0.74, blue: 0.34, alpha: 1.0).cgColor,
        NSColor(red: 0.96, green: 0.56, blue: 0.16, alpha: 1.0).cgColor
    ] as CFArray
    if let iconGrad = CGGradient(colorsSpace: colorSpace, colors: iconColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawLinearGradient(
            iconGrad,
            start: CGPoint(x: 512, y: targetRect.maxY),
            end: CGPoint(x: 512, y: targetRect.minY),
            options: []
        )
    }

    ctx.endTransparencyLayer()
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, targetSize: Int, fileURL: URL) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetSize,
        pixelsHigh: targetSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: targetSize, height: targetSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(
        in: NSRect(x: 0, y: 0, width: targetSize, height: targetSize),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: fileURL)
    }
}

let master = renderMasterIcon()
let outDir = URL(fileURLWithPath: "Sources/PreventSleepApp/Resources/Assets.xcassets/AppIcon.appiconset")

let iconSpecs: [(size: Int, scale: Int, filename: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

for spec in iconSpecs {
    let pixelDimension = spec.size * spec.scale
    let fileURL = outDir.appendingPathComponent(spec.filename)
    savePNG(image: master, targetSize: pixelDimension, fileURL: fileURL)
    print("Generated \(spec.filename) (\(pixelDimension)x\(pixelDimension))")
}

// Generate Contents.json
let contentsJSON = """
{
  "images": [
    {
      "size": "16x16",
      "idiom": "mac",
      "filename": "icon_16x16.png",
      "scale": "1x"
    },
    {
      "size": "16x16",
      "idiom": "mac",
      "filename": "icon_16x16@2x.png",
      "scale": "2x"
    },
    {
      "size": "32x32",
      "idiom": "mac",
      "filename": "icon_32x32.png",
      "scale": "1x"
    },
    {
      "size": "32x32",
      "idiom": "mac",
      "filename": "icon_32x32@2x.png",
      "scale": "2x"
    },
    {
      "size": "128x128",
      "idiom": "mac",
      "filename": "icon_128x128.png",
      "scale": "1x"
    },
    {
      "size": "128x128",
      "idiom": "mac",
      "filename": "icon_128x128@2x.png",
      "scale": "2x"
    },
    {
      "size": "256x256",
      "idiom": "mac",
      "filename": "icon_256x256.png",
      "scale": "1x"
    },
    {
      "size": "256x256",
      "idiom": "mac",
      "filename": "icon_256x256@2x.png",
      "scale": "2x"
    },
    {
      "size": "512x512",
      "idiom": "mac",
      "filename": "icon_512x512.png",
      "scale": "1x"
    },
    {
      "size": "512x512",
      "idiom": "mac",
      "filename": "icon_512x512@2x.png",
      "scale": "2x"
    }
  ],
  "info": {
    "version": 1,
    "author": "xcode"
  }
}
"""

try! contentsJSON.write(
    to: outDir.appendingPathComponent("Contents.json"),
    atomically: true,
    encoding: .utf8
)
print("Generated Contents.json successfully.")
