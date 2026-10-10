import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent(
  "android/app/src/main/res/drawable-xxxhdpi/launch_wordmark.png"
)
let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "")

guard let source = NSBitmapImageRep(data: try Data(contentsOf: sourceURL)) else {
  fatalError("Could not open \(sourceURL.path)")
}
let output = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: source.pixelsWide,
  pixelsHigh: source.pixelsHigh,
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .deviceRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
)!

for y in 0..<source.pixelsHigh {
  for x in 0..<source.pixelsWide {
    guard let color = source.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
      continue
    }
    let alpha = color.alphaComponent
    guard alpha > 0 else { continue }
    let isBrandRed = color.redComponent > color.greenComponent * 1.25
      && color.redComponent > color.blueComponent * 1.25
    let foreground = isBrandRed
      ? NSColor(calibratedRed: 226 / 255, green: 27 / 255, blue: 45 / 255, alpha: alpha)
      : NSColor(calibratedRed: 245 / 255, green: 240 / 255, blue: 231 / 255, alpha: alpha)
    output.setColor(foreground, atX: x, y: y)
  }
}

try FileManager.default.createDirectory(
  at: outputURL.deletingLastPathComponent(),
  withIntermediateDirectories: true
)
try output.representation(using: .png, properties: [:])!.write(to: outputURL)
print("Wrote \(outputURL.path)")
