import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = URL(fileURLWithPath: "/Users/naheeminnis/Documents/Xcode Projects - Corsair/DoneNow/AppStore/Screenshots", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// App Store Connect currently requests the 6.5-inch portrait canvas for this
// listing. Keep the captured app UI intact while placing it on this exact
// required canvas.
let width = 1284
let height = 2778
let margin: CGFloat = 70
let targetRect = CGRect(x: margin, y: 170, width: CGFloat(width) - margin * 2, height: CGFloat(height) - 300)

let variants: [(String, String, CGColor, CGColor, CGColor)] = [
    ("01-home-focus", "/private/tmp/donenow-home-2.png", CGColor(red: 0.035, green: 0.04, blue: 0.055, alpha: 1), CGColor(red: 0.95, green: 0.32, blue: 0.06, alpha: 1), CGColor(red: 0.18, green: 0.22, blue: 0.34, alpha: 1)),
    ("02-soundscapes", "/private/tmp/donenow-11-soundscapes.png", CGColor(red: 0.025, green: 0.055, blue: 0.065, alpha: 1), CGColor(red: 0.18, green: 0.62, blue: 0.56, alpha: 1), CGColor(red: 0.10, green: 0.16, blue: 0.25, alpha: 1)),
    ("03-hourglass", "/private/tmp/donenow-hourglass-final2.png", CGColor(red: 0.07, green: 0.045, blue: 0.035, alpha: 1), CGColor(red: 1.0, green: 0.48, blue: 0.08, alpha: 1), CGColor(red: 0.28, green: 0.13, blue: 0.06, alpha: 1))
]

func writePNG(_ context: CGContext, _ name: String) throws {
    let outputURL = outputDirectory.appendingPathComponent("\(name)-1284x2778.png")
    guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil),
          let rendered = context.makeImage() else { throw NSError(domain: "DoneNowScreenshots", code: 1) }
    CGImageDestinationAddImage(destination, rendered, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "DoneNowScreenshots", code: 2) }
}

for (name, inputPath, base, accent, secondary) in variants {
    let inputURL = URL(fileURLWithPath: inputPath)
    guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Unable to load simulator capture at \(inputPath)")
    }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Unable to create context") }
    context.setFillColor(base)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let glowColors = [accent.copy(alpha: 0.30)!, accent.copy(alpha: 0.0)!] as CFArray
    let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0, 1])!
    context.drawRadialGradient(glow, startCenter: CGPoint(x: 90, y: 430), startRadius: 0, endCenter: CGPoint(x: 90, y: 430), endRadius: 760, options: [])
    let coolColors = [secondary.copy(alpha: 0.24)!, secondary.copy(alpha: 0.0)!] as CFArray
    let coolGlow = CGGradient(colorsSpace: colorSpace, colors: coolColors, locations: [0, 1])!
    context.drawRadialGradient(coolGlow, startCenter: CGPoint(x: 1200, y: 2400), startRadius: 0, endCenter: CGPoint(x: 1200, y: 2400), endRadius: 880, options: [])

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 20), blur: 44, color: CGColor(gray: 0, alpha: 0.62))
    context.addPath(CGPath(roundedRect: targetRect, cornerWidth: 65, cornerHeight: 65, transform: nil))
    context.setFillColor(CGColor(gray: 0.02, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(CGPath(roundedRect: targetRect, cornerWidth: 65, cornerHeight: 65, transform: nil))
    context.clip()
    context.interpolationQuality = .high
    context.draw(image, in: targetRect)
    context.restoreGState()

    try writePNG(context, name)
}
