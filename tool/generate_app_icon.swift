import AppKit
import CoreText
import Foundation

// Draw the launcher icon lockup: an open study book, a red bookmark, and the
// aLaStudie wordmark with its signature red i-dot.
// Run from the project root to refresh the 1024px master icon.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let side = 1024
let outputPath =
  CommandLine.arguments.dropFirst().first
  ?? root.appendingPathComponent("assets/brand/alastudie_app_icon.png").path
let output = URL(fileURLWithPath: outputPath)

guard let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: side,
  pixelsHigh: side,
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .deviceRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
) else { fatalError("Unable to create icon bitmap") }

let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let context = graphics.cgContext
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let marine = CGColor(red: 7.0 / 255, green: 63.0 / 255, blue: 86.0 / 255, alpha: 1)
let red = CGColor(red: 226.0 / 255, green: 27.0 / 255, blue: 45.0 / 255, alpha: 1)
let paper = CGColor(red: 245.0 / 255, green: 240.0 / 255, blue: 231.0 / 255, alpha: 1)
let pageEdge = CGColor(red: 198.0 / 255, green: 224.0 / 255, blue: 232.0 / 255, alpha: 1)
let pageInk = CGColor(red: 7.0 / 255, green: 63.0 / 255, blue: 86.0 / 255, alpha: 0.28)

context.setFillColor(marine)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

context.saveGState()
context.translateBy(x: 0, y: 84)
context.translateBy(x: 512, y: 512)
context.scaleBy(x: 1.1, y: 1.1)
context.translateBy(x: -512, y: -512)

let leftPage = CGMutablePath()
leftPage.move(to: CGPoint(x: 214, y: 658))
leftPage.addQuadCurve(
  to: CGPoint(x: 482, y: 581),
  control: CGPoint(x: 343, y: 699)
)
leftPage.addQuadCurve(
  to: CGPoint(x: 510, y: 596),
  control: CGPoint(x: 498, y: 579)
)
leftPage.addLine(to: CGPoint(x: 510, y: 326))
leftPage.addQuadCurve(
  to: CGPoint(x: 487, y: 331),
  control: CGPoint(x: 500, y: 319)
)
leftPage.addLine(to: CGPoint(x: 220, y: 405))
leftPage.addQuadCurve(
  to: CGPoint(x: 190, y: 435),
  control: CGPoint(x: 190, y: 411)
)
leftPage.addLine(to: CGPoint(x: 190, y: 616))
leftPage.addQuadCurve(
  to: CGPoint(x: 214, y: 658),
  control: CGPoint(x: 190, y: 643)
)
leftPage.closeSubpath()

let rightPage = CGMutablePath()
rightPage.move(to: CGPoint(x: 514, y: 596))
rightPage.addQuadCurve(
  to: CGPoint(x: 542, y: 581),
  control: CGPoint(x: 526, y: 579)
)
rightPage.addQuadCurve(
  to: CGPoint(x: 810, y: 658),
  control: CGPoint(x: 681, y: 699)
)
rightPage.addQuadCurve(
  to: CGPoint(x: 834, y: 616),
  control: CGPoint(x: 834, y: 643)
)
rightPage.addLine(to: CGPoint(x: 834, y: 435))
rightPage.addQuadCurve(
  to: CGPoint(x: 804, y: 405),
  control: CGPoint(x: 834, y: 411)
)
rightPage.addLine(to: CGPoint(x: 537, y: 331))
rightPage.addQuadCurve(
  to: CGPoint(x: 514, y: 326),
  control: CGPoint(x: 525, y: 319)
)
rightPage.closeSubpath()

// A single soft shadow lifts the paper without adding a badge or a wordmark.
context.saveGState()
context.setShadow(
  offset: CGSize(width: 0, height: -18),
  blur: 30,
  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.24)
)
context.addPath(leftPage)
context.addPath(rightPage)
context.setFillColor(paper)
context.fillPath()
context.restoreGState()

// A quiet cool edge gives the open pages a little depth at small icon sizes.
context.addPath(leftPage)
context.addPath(rightPage)
context.setStrokeColor(pageEdge)
context.setLineWidth(3)
context.strokePath()

// A pair of short, perspective lines makes the pages read as a study book.
context.setStrokeColor(pageInk)
context.setLineWidth(12)
context.setLineCap(.round)
context.move(to: CGPoint(x: 267, y: 532))
context.addLine(to: CGPoint(x: 425, y: 486))
context.move(to: CGPoint(x: 267, y: 477))
context.addLine(to: CGPoint(x: 425, y: 431))
context.move(to: CGPoint(x: 757, y: 532))
context.addLine(to: CGPoint(x: 599, y: 486))
context.move(to: CGPoint(x: 757, y: 477))
context.addLine(to: CGPoint(x: 599, y: 431))
context.strokePath()

// Book fold: a clean marine crease separates the two pages.
context.setStrokeColor(marine)
context.setLineWidth(13)
context.setLineCap(.round)
context.move(to: CGPoint(x: 512, y: 340))
context.addLine(to: CGPoint(x: 512, y: 575))
context.strokePath()

// One bright red bookmark provides the app's signature accent.
let bookmark = CGMutablePath()
bookmark.move(to: CGPoint(x: 454, y: 604))
bookmark.addLine(to: CGPoint(x: 570, y: 604))
bookmark.addLine(to: CGPoint(x: 570, y: 424))
bookmark.addLine(to: CGPoint(x: 512, y: 458))
bookmark.addLine(to: CGPoint(x: 454, y: 424))
bookmark.closeSubpath()
context.addPath(bookmark)
context.setFillColor(red)
context.fillPath()

context.restoreGState()

// Keep the familiar in-app wordmark treatment on the launcher icon too.
let fontURL = root.appendingPathComponent("assets/fonts/Montserrat-Bold.ttf") as CFURL
CTFontManagerRegisterFontsForURL(fontURL, .process, nil)
let wordmarkFontSize: CGFloat = 90
let wordmarkFont = CTFontCreateWithName("Montserrat-Bold" as CFString, wordmarkFontSize, nil)
let wordmarkString = "aLaStudıe"
let wordmarkAttributes: [NSAttributedString.Key: Any] = [
  NSAttributedString.Key(kCTFontAttributeName as String): wordmarkFont,
  NSAttributedString.Key(kCTForegroundColorAttributeName as String): paper,
]
let wordmarkLine = CTLineCreateWithAttributedString(
  NSAttributedString(string: wordmarkString, attributes: wordmarkAttributes)
)
let wordmarkWidth = CGFloat(CTLineGetTypographicBounds(wordmarkLine, nil, nil, nil))
let wordmarkX = (CGFloat(side) - wordmarkWidth) / 2
let wordmarkBaseline: CGFloat = 226
context.textPosition = CGPoint(x: wordmarkX, y: wordmarkBaseline)
CTLineDraw(wordmarkLine, context)

// The app wordmark uses a custom red dot over the i; keep that detail here.
let iStart = CGFloat(CTLineGetOffsetForStringIndex(wordmarkLine, 7, nil))
let iEnd = CGFloat(CTLineGetOffsetForStringIndex(wordmarkLine, 8, nil))
let dotRadius = wordmarkFontSize * 0.075
let dotCenter = CGPoint(
  x: wordmarkX + (iStart + iEnd) / 2,
  y: wordmarkBaseline + wordmarkFontSize * 0.75
)
context.setFillColor(red)
context.fillEllipse(
  in: CGRect(
    x: dotCenter.x - dotRadius,
    y: dotCenter.y - dotRadius,
    width: dotRadius * 2,
    height: dotRadius * 2
  )
)

NSGraphicsContext.restoreGraphicsState()
try FileManager.default.createDirectory(
  at: output.deletingLastPathComponent(),
  withIntermediateDirectories: true
)
let data = bitmap.representation(using: .png, properties: [:])!
try data.write(to: output)
print("Wrote \(output.path)")
