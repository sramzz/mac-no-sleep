import AppKit
import Foundation

func loadRGBAPixels(from imageURL: URL) -> (width: Int, height: Int, pixels: [UInt8]) {
    guard let nsImage = NSImage(contentsOf: imageURL),
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Failed to load image at \(imageURL.path)")
    }

    let width = cgImage.width
    let height = cgImage.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create CGContext for pixel extraction")
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (width, height, pixels)
}

func luminance(pixels: [UInt8], width: Int, x: Int, y: Int) -> Double {
    let index = (y * width + x) * 4
    let r = Double(pixels[index]) / 255.0
    let g = Double(pixels[index + 1]) / 255.0
    let b = Double(pixels[index + 2]) / 255.0
    return 0.299 * r + 0.587 * g + 0.114 * b
}

func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
    Swift.max(minVal, Swift.min(maxVal, value))
}

func extractRawCropMask(
    pixels: [UInt8],
    imageWidth: Int,
    darkX: Int,
    lightX: Int,
    y: Int,
    width: Int,
    height: Int
) -> [[Double]] {
    var mask = Array(repeating: Array(repeating: 0.0, count: width), count: height)
    for dy in 0..<height {
        for dx in 0..<width {
            let lumDark = luminance(pixels: pixels, width: imageWidth, x: darkX + dx, y: y + dy)
            let lumLight = luminance(pixels: pixels, width: imageWidth, x: lightX + dx, y: y + dy)

            let aDark = clamp((lumDark - 0.25) / (0.92 - 0.25), min: 0.0, max: 1.0)
            let aLight = clamp((0.86 - lumLight) / (0.86 - 0.16), min: 0.0, max: 1.0)

            var alpha = 0.5 * (aDark + aLight)
            if alpha < 0.03 {
                alpha = 0.0
            } else if alpha > 0.97 {
                alpha = 1.0
            }
            mask[dy][dx] = alpha
        }
    }
    return mask
}

func sampleBilinear(_ grid: [[Double]], x: Double, y: Double) -> Double {
    let height = grid.count
    let width = grid[0].count
    let x0 = Int(floor(x))
    let y0 = Int(floor(y))
    let x1 = x0 + 1
    let y1 = y0 + 1
    guard x0 >= 0 && y0 >= 0 && x1 < width && y1 < height else { return 0.0 }

    let fx = x - Double(x0)
    let fy = y - Double(y0)
    let v00 = grid[y0][x0]
    let v10 = grid[y0][x1]
    let v01 = grid[y1][x0]
    let v11 = grid[y1][x1]

    return (1.0 - fx) * (1.0 - fy) * v00
        + fx * (1.0 - fy) * v10
        + (1.0 - fx) * fy * v01
        + fx * fy * v11
}

func buildActiveMask(rawActive: [[Double]], canvasSize: Int, offX: Int, offY: Int) -> [[Double]] {
    var canvas = Array(repeating: Array(repeating: 0.0, count: canvasSize), count: canvasSize)
    let cropHeight = rawActive.count
    let cropWidth = rawActive[0].count

    for dy in 0..<cropHeight {
        for dx in 0..<cropWidth {
            // Exclude original small eye region
            if dx >= 92 && dy >= 96 { continue }
            let cx = offX + dx
            let cy = offY + dy
            guard cx >= 0 && cx < canvasSize && cy >= 0 && cy < canvasSize else { continue }

            var alpha = rawActive[dy][dx]
            let u = dx + dy
            let v = dx - dy
            // Fill syringe barrel interior, keeping 3 graduation ticks as crisp negative space
            if u >= 131 && u <= 168 && v >= -72 && v <= 41 {
                if u >= 134 && u <= 153 && v >= -58 && v <= 22 {
                    alpha = 1.0 - alpha
                } else {
                    alpha = 1.0
                }
            }
            canvas[cy][cx] = alpha
        }
    }

    // Resample eye at 1.38x scale centered at (122.0, 128.0)
    let eyeScale = 1.38
    let eyeTargetCX = 122.0
    let eyeTargetCY = 128.0
    for cy in 90..<canvasSize {
        for cx in 75..<canvasSize {
            let srcX = 120.5 + (Double(cx) - eyeTargetCX) / eyeScale
            let srcY = 116.0 + (Double(cy) - eyeTargetCY) / eyeScale
            if srcX >= 92.0 && srcX <= 148.0 && srcY >= 97.0 && srcY <= 135.0 {
                let sampled = sampleBilinear(rawActive, x: srcX, y: srcY)
                canvas[cy][cx] = max(canvas[cy][cx], sampled)
            }
        }
    }

    return canvas
}

func buildInactiveMask(rawInactive: [[Double]], canvasSize: Int, offX: Int, offY: Int) -> [[Double]] {
    var canvas = Array(repeating: Array(repeating: 0.0, count: canvasSize), count: canvasSize)
    let cropHeight = rawInactive.count
    let cropWidth = rawInactive[0].count

    for dy in 0..<cropHeight {
        for dx in 0..<cropWidth {
            // Exclude original small zZ region
            if dx >= 114 && dy <= 32 { continue }
            let cx = offX + dx
            let cy = offY + dy
            guard cx >= 0 && cx < canvasSize && cy >= 0 && cy < canvasSize else { continue }
            canvas[cy][cx] = rawInactive[dy][dx]
        }
    }

    // Resample small 'z' at 1.70x scale centered at (119.0, 27.0)
    let zScale = 1.70
    for cy in 5..<48 {
        for cx in 100..<136 {
            let srcX = 120.5 + (Double(cx) - 119.0) / zScale
            let srcY = 24.0 + (Double(cy) - 27.0) / zScale
            if srcX >= 114.0 && srcX <= 128.0 && srcY >= 16.0 && srcY <= 32.0 {
                let sampled = sampleBilinear(rawInactive, x: srcX, y: srcY)
                canvas[cy][cx] = max(canvas[cy][cx], sampled)
            }
        }
    }

    // Resample large 'Z' at 1.70x scale centered at (147.0, 19.0)
    for cy in 0..<42 {
        for cx in 128..<canvasSize {
            let srcX = 139.5 + (Double(cx) - 147.0) / zScale
            let srcY = 9.5 + (Double(cy) - 19.0) / zScale
            if srcX >= 131.0 && srcX <= 148.0 && srcY >= 0.0 && srcY <= 20.0 {
                let sampled = sampleBilinear(rawInactive, x: srcX, y: srcY)
                canvas[cy][cx] = max(canvas[cy][cx], sampled)
            }
        }
    }

    return canvas
}

func makeMasterImage(mask: [[Double]], rgb: (r: Double, g: Double, b: Double)) -> NSImage {
    let size = mask.count
    let rep = NSBitmapImageRep(
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
    )!
    rep.size = NSSize(width: size, height: size)

    for y in 0..<size {
        for x in 0..<size {
            let alpha = mask[y][x]
            let color = NSColor(
                deviceRed: alpha > 0 ? rgb.r : 0.0,
                green: alpha > 0 ? rgb.g : 0.0,
                blue: alpha > 0 ? rgb.b : 0.0,
                alpha: alpha
            )
            rep.setColor(color, atX: x, y: y)
        }
    }

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

func renderDownsampledPNG(master: NSImage, targetPixels: Int, to fileURL: URL) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetPixels,
        pixelsHigh: targetPixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: targetPixels, height: targetPixels)

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)
    context?.imageInterpolation = .high
    NSGraphicsContext.current = context

    NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0).set()
    NSRect(x: 0, y: 0, width: targetPixels, height: targetPixels).fill()

    master.draw(
        in: NSRect(x: 0, y: 0, width: targetPixels, height: targetPixels),
        from: NSRect(origin: .zero, size: master.size),
        operation: .sourceOver,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for \(fileURL.path)")
    }
    try! data.write(to: fileURL)
}

func contentsJSON(baseName: String) -> String {
    """
    {
      "images" : [
        {
          "filename" : "\(baseName).png",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "appearances" : [
            {
              "appearance" : "luminosity",
              "value" : "dark"
            }
          ],
          "filename" : "\(baseName)Dark.png",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "filename" : "\(baseName)@2x.png",
          "idiom" : "universal",
          "scale" : "2x"
        },
        {
          "appearances" : [
            {
              "appearance" : "luminosity",
              "value" : "dark"
            }
          ],
          "filename" : "\(baseName)Dark@2x.png",
          "idiom" : "universal",
          "scale" : "2x"
        },
        {
          "filename" : "\(baseName)@3x.png",
          "idiom" : "universal",
          "scale" : "3x"
        },
        {
          "appearances" : [
            {
              "appearance" : "luminosity",
              "value" : "dark"
            }
          ],
          "filename" : "\(baseName)Dark@3x.png",
          "idiom" : "universal",
          "scale" : "3x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      },
      "properties" : {
        "template-rendering-intent" : "template"
      }
    }
    """
}

let defaultInputPath = "/Users/sramzzs4d/.gemini/antigravity/brain/cf7b05db-1fad-49ea-93c2-d8ad2a694472/.user_uploaded/media_1795363035327_ee491b13.jpg"
let inputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultInputPath
let inputURL = URL(fileURLWithPath: inputPath)

let (imgWidth, _, pixels) = loadRGBAPixels(from: inputURL)

let rawActive = extractRawCropMask(
    pixels: pixels,
    imageWidth: imgWidth,
    darkX: 76,
    lightX: 76 + 516,
    y: 209,
    width: 149,
    height: 151
)
let rawInactive = extractRawCropMask(
    pixels: pixels,
    imageWidth: imgWidth,
    darkX: 285,
    lightX: 285 + 516,
    y: 212,
    width: 149,
    height: 151
)

let canvasSize = 165
let offX = 4
let offY = 11

let activeMask = buildActiveMask(rawActive: rawActive, canvasSize: canvasSize, offX: offX, offY: offY)
let inactiveMask = buildInactiveMask(rawInactive: rawInactive, canvasSize: canvasSize, offX: offX, offY: offY)

let scaleSpecs: [(scale: Int, suffix: String, pixels: Int)] = [
    (1, "", 18),
    (2, "@2x", 36),
    (3, "@3x", 54)
]

let assetsRoot = URL(fileURLWithPath: "Sources/PreventSleepApp/Resources/Assets.xcassets")

for (baseName, mask) in [("StatusIconActive", activeMask), ("StatusIconInactive", inactiveMask)] {
    let imagesetDir = assetsRoot.appendingPathComponent("\(baseName).imageset")
    try FileManager.default.createDirectory(at: imagesetDir, withIntermediateDirectories: true)

    let lightMaster = makeMasterImage(mask: mask, rgb: (0.11, 0.11, 0.11))
    let darkMaster = makeMasterImage(mask: mask, rgb: (1.0, 1.0, 1.0))

    for scaleSpec in scaleSpecs {
        let lightURL = imagesetDir.appendingPathComponent("\(baseName)\(scaleSpec.suffix).png")
        renderDownsampledPNG(master: lightMaster, targetPixels: scaleSpec.pixels, to: lightURL)
        print("Generated \(lightURL.path) (\(scaleSpec.pixels)x\(scaleSpec.pixels))")

        let darkURL = imagesetDir.appendingPathComponent("\(baseName)Dark\(scaleSpec.suffix).png")
        renderDownsampledPNG(master: darkMaster, targetPixels: scaleSpec.pixels, to: darkURL)
        print("Generated \(darkURL.path) (\(scaleSpec.pixels)x\(scaleSpec.pixels))")
    }

    let jsonURL = imagesetDir.appendingPathComponent("Contents.json")
    try contentsJSON(baseName: baseName).write(to: jsonURL, atomically: true, encoding: .utf8)
    print("Generated \(jsonURL.path)")
}
