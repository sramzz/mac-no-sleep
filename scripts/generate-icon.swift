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

    // 4. Central Icon: SF Symbol or Custom Rendered Coffee Cup
    let iconConfig = NSImage.SymbolConfiguration(pointSize: 340, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?.withSymbolConfiguration(iconConfig) {
        let targetRect = NSRect(x: 232, y: 240, width: 560, height: 500)

        // Draw shadow under coffee cup
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: NSColor.black.withAlphaComponent(0.4).cgColor)

        // Draw warm amber gradient on the cup
        if let tinted = symbol.copy() as? NSImage {
            tinted.lockFocus()
            NSColor(red: 1.0, green: 0.76, blue: 0.38, alpha: 1.0).set()
            let imageRect = NSRect(origin: .zero, size: tinted.size)
            imageRect.fill(using: .sourceAtop)
            tinted.unlockFocus()
            tinted.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        ctx.restoreGState()

        // Highlight layer on top of cup
        if let highlight = symbol.copy() as? NSImage {
            highlight.lockFocus()
            let highlightGrad = NSGradient(
                colors: [
                    NSColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 0.95),
                    NSColor(red: 1.0, green: 0.65, blue: 0.22, alpha: 0.85)
                ]
            )
            highlightGrad?.draw(in: NSRect(origin: .zero, size: highlight.size), angle: 90)
            highlight.unlockFocus()
            highlight.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 0.92)
        }
    }

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
