import AppKit
import UniformTypeIdentifiers

/// Prepares an imported logo: rasterizes it, detects a solid background and removes it,
/// and reads the logo's own colors.
enum LogoProcessor {
    static let fileTypes: [UTType] = [.png, .jpeg, .heic, .tiff, .pdf, .svg, .webP]

    /// Draws any NSImage (bitmap or vector) into an sRGB bitmap with at most `maxSide` pixels on the long edge.
    static func rasterize(_ image: NSImage, maxSide: Int = 1024) -> CGImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let pixels = image.representations.map { max($0.pixelsWide, $0.pixelsHigh) }.max() ?? 0
        let longest = pixels > 0 ? min(pixels, maxSide) : maxSide // 0 means vector: render crisp
        let aspect = image.size.width / image.size.height
        let w = max(1, aspect >= 1 ? longest : Int((Double(longest) * aspect).rounded()))
        let h = max(1, aspect >= 1 ? Int((Double(longest) / aspect).rounded()) : longest)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    /// RGBA (premultiplied) pixels, top row first.
    static func pixels(_ cg: CGImage) -> [UInt8] {
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        buf.withUnsafeMutableBytes { ptr in
            guard let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return buf
    }

    static func image(from buf: [UInt8], width w: Int, height h: Int) -> CGImage? {
        var data = buf
        return data.withUnsafeMutableBytes { ptr -> CGImage? in
            CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }

    /// Whether the image already has transparency, and the color of a solid background if there is one.
    static func analyze(_ cg: CGImage) -> (hasTransparency: Bool, background: RGB?) {
        let w = cg.width, h = cg.height, buf = pixels(cg)
        var transparent = 0, sampled = 0
        for i in stride(from: 3, to: buf.count, by: 4 * 7) {
            sampled += 1
            if buf[i] < 250 { transparent += 1 }
        }
        if Double(transparent) / Double(max(sampled, 1)) > 0.005 { return (true, nil) }

        // Average a 5×5 patch in each corner; a shared color there is almost certainly the background.
        func patch(_ x0: Int, _ y0: Int) -> RGB {
            var r = 0.0, g = 0.0, b = 0.0, n = 0.0
            for y in y0..<min(h, y0 + 5) {
                for x in x0..<min(w, x0 + 5) {
                    let i = (y * w + x) * 4
                    r += Double(buf[i]); g += Double(buf[i + 1]); b += Double(buf[i + 2]); n += 1
                }
            }
            return RGB(r / n, g / n, b / n)
        }
        let corners = [patch(0, 0), patch(max(0, w - 5), 0), patch(0, max(0, h - 5)), patch(max(0, w - 5), max(0, h - 5))]
        let dist = { (a: RGB, b: RGB) in sqrt(pow(a.r - b.r, 2) + pow(a.g - b.g, 2) + pow(a.b - b.b, 2)) }
        let uniform = corners.allSatisfy { c in corners.allSatisfy { dist(c, $0) < 24 } }
        guard uniform else { return (false, nil) }
        let n = Double(corners.count)
        return (false, RGB(corners.map(\.r).reduce(0, +) / n, corners.map(\.g).reduce(0, +) / n, corners.map(\.b).reduce(0, +) / n))
    }

    /// Makes the background transparent by flood-filling from the edges, so enclosed areas that
    /// match the background (like white details inside the mark) are kept. Anti-aliased edge pixels
    /// get partial transparency and are cleaned of the background tint.
    static func removeBackground(_ cg: CGImage, background bg: RGB) -> CGImage? {
        let w = cg.width, h = cg.height
        var buf = pixels(cg)
        let hard = 34.0, soft = 96.0
        let bgChannels = [bg.r, bg.g, bg.b]
        var visited = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        stack.reserveCapacity(w * 4)

        func distance(_ p: Int) -> Double {
            let i = p * 4
            let r = Double(buf[i]) - bg.r, g = Double(buf[i + 1]) - bg.g, b = Double(buf[i + 2]) - bg.b
            return (r * r + g * g + b * b).squareRoot()
        }
        func seed(_ p: Int) { if !visited[p] { visited[p] = true; stack.append(p) } }
        for x in 0..<w { seed(x); seed((h - 1) * w + x) }
        for y in 0..<h { seed(y * w); seed(y * w + w - 1) }

        while let p = stack.popLast() {
            let d = distance(p)
            guard d <= soft else { continue }
            let i = p * 4
            if d <= hard {
                buf[i] = 0; buf[i + 1] = 0; buf[i + 2] = 0; buf[i + 3] = 0
                let x = p % w, y = p / w
                if x > 0 { seed(p - 1) }
                if x < w - 1 { seed(p + 1) }
                if y > 0 { seed(p - w) }
                if y < h - 1 { seed(p + w) }
            } else {
                // Edge pixel: partial alpha, and remove the background color mixed into it.
                let a = (d - hard) / (soft - hard)
                for c in 0..<3 {
                    let v = Double(buf[i + c]), b = bgChannels[c]
                    let clean = ColorMath.clamp((v - b * (1 - a)) / a, 0, 255)
                    buf[i + c] = UInt8((clean * a).rounded())
                }
                buf[i + 3] = UInt8((a * 255).rounded())
            }
        }
        return image(from: buf, width: w, height: h)
    }

    /// Mask for one-color versions: every area close to `key` (usually white) becomes transparent,
    /// including enclosed shapes like the inside of letters. Returns nil if that would erase the logo
    /// (for example an all-white logo), so callers fall back to the full shape.
    static func knockout(_ cg: CGImage, key: RGB) -> CGImage? {
        let w = cg.width, h = cg.height
        var buf = pixels(cg)
        let hard = 40.0, soft = 110.0
        var opaqueBefore = 0, opaqueAfter = 0
        for i in stride(from: 0, to: buf.count, by: 4) where buf[i + 3] > 0 {
            opaqueBefore += 1
            let a = Double(buf[i + 3]) / 255
            let r = Double(buf[i]) / a - key.r, g = Double(buf[i + 1]) / a - key.g, b = Double(buf[i + 2]) / a - key.b
            let d = (r * r + g * g + b * b).squareRoot()
            let keep = d <= hard ? 0 : min(1, (d - hard) / (soft - hard))
            let newAlpha = Double(buf[i + 3]) * keep
            if newAlpha > 10 { opaqueAfter += 1 }
            let scale = keep
            buf[i] = UInt8((Double(buf[i]) * scale).rounded())
            buf[i + 1] = UInt8((Double(buf[i + 1]) * scale).rounded())
            buf[i + 2] = UInt8((Double(buf[i + 2]) * scale).rounded())
            buf[i + 3] = UInt8(newAlpha.rounded())
        }
        guard opaqueBefore > 0, Double(opaqueAfter) / Double(opaqueBefore) > 0.15 else { return nil }
        return image(from: buf, width: w, height: h)
    }

    /// Crops empty (transparent) margins so the logo fills its frame, keeping a small breathing space.
    static func trim(_ cg: CGImage) -> CGImage? {
        guard let rect = contentBounds(cg) else { return nil }
        return rect.width < CGFloat(cg.width) || rect.height < CGFloat(cg.height) ? cg.cropping(to: rect) : cg
    }

    /// Bounding box of the visible pixels (top-left origin) plus 2% breathing space, or nil if fully transparent.
    static func contentBounds(_ cg: CGImage) -> CGRect? {
        let w = cg.width, h = cg.height, buf = pixels(cg)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where buf[(y * w + x) * 4 + 3] > 10 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let pad = Int(Double(max(maxX - minX, maxY - minY)) * 0.02)
        let x0 = max(0, minX - pad), y0 = max(0, minY - pad)
        return CGRect(x: x0, y: y0, width: min(w, maxX + pad + 1) - x0, height: min(h, maxY + pad + 1) - y0)
    }

    /// The logo's distinct colors, most used first. Near-identical shades (anti-aliasing) are merged.
    static func colors(_ cg: CGImage) -> [ExtractedColor] {
        let scale = min(1, 160 / Double(max(cg.width, cg.height)))
        let w = max(1, Int(Double(cg.width) * scale)), h = max(1, Int(Double(cg.height) * scale))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let small = ctx.makeImage() else { return [] }
        let buf = pixels(small)
        var px: [RGB] = []
        for i in stride(from: 0, to: buf.count, by: 4) where buf[i + 3] >= 230 {
            let a = Double(buf[i + 3]) / 255
            px.append(RGB(Double(buf[i]) / a, Double(buf[i + 1]) / a, Double(buf[i + 2]) / a))
        }
        guard !px.isEmpty else { return [] }

        var clusters = ColorMath.extractPalette(px, k: 7).map { (hex: $0.hex, share: $0.share) }
        var merged: [(hex: String, share: Double)] = []
        while !clusters.isEmpty {
            var head = clusters.removeFirst()
            let lab = ColorMath.lab(ColorMath.rgb(head.hex))
            clusters.removeAll { other in
                guard ColorMath.deltaE(lab, ColorMath.lab(ColorMath.rgb(other.hex))) < 9 else { return false }
                head.share += other.share
                return true
            }
            merged.append(head)
        }
        // Small clusters that sit between two bigger colors are anti-aliased edges, not logo colors.
        // Anything else is kept, however small, so accent dots and thin details survive.
        let labs = merged.map { ColorMath.lab(ColorMath.rgb($0.hex)) }
        func isBlend(_ i: Int) -> Bool {
            let p = labs[i]
            for a in merged.indices where a != i && merged[a].share > merged[i].share {
                for b in merged.indices where b > a && b != i && merged[b].share > merged[i].share {
                    let ab = labs[b] - labs[a], len2 = (ab * ab).sum()
                    guard len2 > 1 else { continue }
                    let t = ((p - labs[a]) * ab).sum() / len2
                    guard t > 0.12, t < 0.88 else { continue }
                    let d = p - (labs[a] + ab * t)
                    if (d * d).sum().squareRoot() < 8 { return true }
                }
            }
            return false
        }
        return merged.indices
            .filter { merged[$0].share >= 0.006 && !(merged[$0].share < 0.08 && isBlend($0)) }
            .map { merged[$0] }
            .sorted { $0.share > $1.share }
            .prefix(6)
            .map { ExtractedColor(hex: $0.hex, share: $0.share) }
    }

    static func png(_ cg: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }
}
