// Draws the Palette Pro app icon: a bold geometric "P" in pink (#FC9BB3) on a deep green
// (#034638) macOS squircle.
// Usage: make-icon <output.png> [pixels]
// The artwork is composed in a 1024-unit space and scaled to the requested size; the flat,
// bold shapes stay crisp down to 16 px.
import AppKit

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "icon.png"
let px = args.count > 2 ? max(16, Int(args[2]) ?? 1024) : 1024

let S = 1024
let space = CGColorSpace(name: CGColorSpace.displayP3)!
let letterColor = "#FC9BB3"
let backgroundColor = "#034638"

func newContext(_ size: Int) -> CGContext {
    CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func color(_ hex: String, _ a: CGFloat = 1) -> CGColor {
    let v = UInt32(hex.dropFirst(), radix: 16)!
    return CGColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}

/// macOS icon squircle (superellipse, exponent 5) on Apple's 824-unit icon grid.
func squircle(_ r: CGRect, exponent n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    for i in 0...720 {
        let t = CGFloat(i) / 720 * 2 * .pi, c = cos(t), s = sin(t)
        let p = CGPoint(x: r.midX + r.width / 2 * (c >= 0 ? 1 : -1) * pow(abs(c), 2 / n),
                        y: r.midY + r.height / 2 * (s >= 0 ? 1 : -1) * pow(abs(s), 2 / n))
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

/// A bold geometric P: a stem plus a round bowl with a small counter, centered optically.
func letterP() -> CGPath {
    let stemW: CGFloat = 166, bowlR: CGFloat = 206, stroke: CGFloat = 152, corner: CGFloat = 34
    let top: CGFloat = 778, bottom: CGFloat = 246, x0: CGFloat = 300
    let cx = x0 + stemW + 72 // where the bowl's straight top meets its round end
    let bowlBottom = top - bowlR * 2
    let stem = CGPath(roundedRect: CGRect(x: x0, y: bottom, width: stemW, height: top - bottom), cornerWidth: corner, cornerHeight: corner, transform: nil)
    let bowlRect = CGPath(roundedRect: CGRect(x: x0, y: bowlBottom, width: cx - x0, height: bowlR * 2), cornerWidth: corner, cornerHeight: corner, transform: nil)
    let bowlRound = CGPath(ellipseIn: CGRect(x: cx - bowlR, y: bowlBottom, width: bowlR * 2, height: bowlR * 2), transform: nil)
    let counterR = bowlR - stroke
    let counterRect = CGPath(rect: CGRect(x: x0 + stemW, y: top - bowlR - counterR, width: cx - x0 - stemW, height: counterR * 2), transform: nil)
    let counterRound = CGPath(ellipseIn: CGRect(x: cx - counterR, y: top - bowlR - counterR, width: counterR * 2, height: counterR * 2), transform: nil)
    let outline = stem.union(bowlRect).union(bowlRound).subtracting(counterRect.union(counterRound))
    let b = outline.boundingBoxOfPath
    var t = CGAffineTransform(translationX: 512 - b.midX + 8, y: 512 - b.midY) // nudged right for optical balance
    return outline.copy(using: &t)!
}

let shape = squircle(CGRect(x: 100, y: 100, width: 824, height: 824))
let art = newContext(S)

// Soft shadow under the body.
art.saveGState()
art.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color("#000000", 0.3))
art.addPath(shape); art.setFillColor(color(backgroundColor)); art.fillPath()
art.restoreGState()

art.saveGState()
art.addPath(shape); art.clip()
art.setFillColor(color(backgroundColor)); art.fill(CGRect(x: 0, y: 0, width: S, height: S))
// A hint of light from above so it sits naturally among other macOS icons.
let sheen = CGGradient(colorsSpace: space, colors: [color("#FFFFFF", 0.10), color("#FFFFFF", 0)] as CFArray, locations: [0, 1])!
art.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 512), options: [])
art.addPath(letterP()); art.setFillColor(color(letterColor)); art.fillPath()
art.addPath(shape); art.setStrokeColor(color("#FFFFFF", 0.14)); art.setLineWidth(px >= 64 ? 5 : 12); art.strokePath()
art.restoreGState()
art.addPath(shape); art.setStrokeColor(color("#000000", 0.25)); art.setLineWidth(1.5); art.strokePath()

// Scale to the requested size with high-quality resampling.
var image = art.makeImage()!
if px != S {
    let out = newContext(px)
    out.interpolationQuality = .high
    out.draw(image, in: CGRect(x: 0, y: 0, width: px, height: px))
    image = out.makeImage()!
}
guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("render failed") }
try! data.write(to: URL(fileURLWithPath: outPath))
