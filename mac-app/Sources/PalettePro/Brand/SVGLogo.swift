import AppKit

/// Text-level helpers for SVG logos: reading the root viewBox, cropping it, and building
/// one-color versions that stay vector.
enum SVGLogo {
    /// Range of the root `<svg …>` opening tag (quotes are respected when looking for `>`).
    static func rootTag(_ svg: String) -> Range<String.Index>? {
        guard let start = svg.range(of: "<svg", options: .caseInsensitive)?.lowerBound else { return nil }
        var quote: Character?
        var i = start
        while i < svg.endIndex {
            let ch = svg[i]
            if let q = quote {
                if ch == q { quote = nil }
            } else if ch == "\"" || ch == "'" {
                quote = ch
            } else if ch == ">" {
                return start..<svg.index(after: i)
            }
            i = svg.index(after: i)
        }
        return nil
    }

    static func attribute(_ name: String, in tag: Substring) -> String? {
        let pattern = "\\s\(name)\\s*=\\s*(\"([^\"]*)\"|'([^']*)')"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let s = String(tag), ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let r = m.range(at: 2).location != NSNotFound ? m.range(at: 2) : m.range(at: 3)
        return ns.substring(with: r)
    }

    static func numbers(_ s: String) -> [Double] {
        s.split(whereSeparator: { $0 == "," || $0.isWhitespace }).compactMap { Double($0.trimmingCharacters(in: .letters.union(CharacterSet(charactersIn: "%")))) }
    }

    /// The user-space rectangle the logo is drawn in: viewBox, or width/height as a fallback.
    static func viewBox(_ svg: String) -> CGRect? {
        guard let r = rootTag(svg) else { return nil }
        let tag = svg[r]
        if let vb = attribute("viewBox", in: tag).map(numbers), vb.count == 4, vb[2] > 0, vb[3] > 0 {
            return CGRect(x: vb[0], y: vb[1], width: vb[2], height: vb[3])
        }
        if let w = attribute("width", in: tag).flatMap({ numbers($0).first }), let h = attribute("height", in: tag).flatMap({ numbers($0).first }), w > 0, h > 0 {
            return CGRect(x: 0, y: 0, width: w, height: h)
        }
        return nil
    }

    static func fmt(_ v: Double) -> String {
        var s = String(format: "%.4f", v)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
        return s == "-0" ? "0" : s
    }

    /// Returns the SVG with its root viewBox (and width/height) set to `rect`, which crops or pads it.
    static func withViewBox(_ svg: String, _ rect: CGRect) -> String {
        guard let r = rootTag(svg) else { return svg }
        var tag = String(svg[r])
        if let re = try? NSRegularExpression(pattern: "\\s(width|height|viewBox|preserveAspectRatio)\\s*=\\s*(\"[^\"]*\"|'[^']*')", options: [.caseInsensitive]) {
            tag = re.stringByReplacingMatches(in: tag, range: NSRange(location: 0, length: (tag as NSString).length), withTemplate: "")
        }
        let attrs = " viewBox=\"\(fmt(rect.minX)) \(fmt(rect.minY)) \(fmt(rect.width)) \(fmt(rect.height))\" width=\"\(fmt(rect.width))\" height=\"\(fmt(rect.height))\""
        tag.insert(contentsOf: attrs, at: tag.index(tag.startIndex, offsetBy: 4))
        return svg.replacingCharacters(in: r, with: tag)
    }

    /// Everything between the root opening tag and the final `</svg>`.
    static func inner(_ svg: String) -> String {
        guard let r = rootTag(svg) else { return svg }
        let end = svg.range(of: "</svg>", options: [.caseInsensitive, .backwards])?.lowerBound ?? svg.endIndex
        return end > r.upperBound ? String(svg[r.upperBound..<end]) : ""
    }

    // MARK: Colors

    static let named: [String: String] = [
        "white": "FFFFFF", "black": "000000", "red": "FF0000", "green": "008000", "blue": "0000FF", "yellow": "FFFF00",
        "orange": "FFA500", "purple": "800080", "gray": "808080", "grey": "808080", "silver": "C0C0C0", "navy": "000080",
        "teal": "008080", "maroon": "800000", "olive": "808000", "lime": "00FF00", "aqua": "00FFFF", "cyan": "00FFFF",
        "fuchsia": "FF00FF", "magenta": "FF00FF", "pink": "FFC0CB", "brown": "A52A2A", "gold": "FFD700", "indigo": "4B0082",
        "violet": "EE82EE", "coral": "FF7F50", "salmon": "FA8072", "tomato": "FF6347", "crimson": "DC143C", "khaki": "F0E68C",
        "beige": "F5F5DC", "ivory": "FFFFF0", "snow": "FFFAFA", "whitesmoke": "F5F5F5", "gainsboro": "DCDCDC",
        "lightgray": "D3D3D3", "lightgrey": "D3D3D3", "darkgray": "A9A9A9", "darkgrey": "A9A9A9", "dimgray": "696969",
        "dimgrey": "696969", "skyblue": "87CEEB", "royalblue": "4169E1", "steelblue": "4682B4", "darkblue": "00008B",
        "darkgreen": "006400", "forestgreen": "228B22", "seagreen": "2E8B57", "turquoise": "40E0D0", "tan": "D2B48C",
        "chocolate": "D2691E", "firebrick": "B22222", "darkred": "8B0000", "orchid": "DA70D6", "plum": "DDA0DD",
    ]

    /// Applies `map` (rgb, alpha → replacement) to every color in the markup: hex, rgb()/rgba() and
    /// named colors in fill/stroke/stop-color/flood-color. Content of existing `<mask>` elements is left
    /// alone, since its colors mean visibility rather than paint.
    static func mapColors(_ text: String, _ map: (RGB, Double) -> String) -> String {
        guard let maskRE = try? NSRegularExpression(pattern: "<mask\\b.*?</mask\\s*>", options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return text }
        let ns = text as NSString
        var out = "", last = 0
        for m in maskRE.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out += mapOutsideMasks(ns.substring(with: NSRange(location: last, length: m.range.location - last)), map)
            out += ns.substring(with: m.range)
            last = m.range.location + m.range.length
        }
        return out + mapOutsideMasks(ns.substring(from: last), map)
    }

    private static func mapOutsideMasks(_ text: String, _ map: (RGB, Double) -> String) -> String {
        var s = text
        // 1. Hex colors (not url(#id), href="#id" or character entities).
        s = replace(s, #"(?<!url\()(?<!href=")(?<!href=')(?<![\w&])#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})(?![\w-])"#) { g in
            var h = g[1]
            if h.count <= 4 { h = h.map { "\($0)\($0)" }.joined() }
            let alpha = h.count == 8 ? Double(UInt8(h.suffix(2), radix: 16) ?? 255) / 255 : 1
            return map(ColorMath.rgb(String(h.prefix(6))), alpha)
        }
        // 2. rgb()/rgba() with numbers or percentages.
        s = replace(s, #"rgba?\(\s*([\d.]+%?)\s*[,\s]\s*([\d.]+%?)\s*[,\s]\s*([\d.]+%?)\s*(?:[,/]\s*([\d.]+%?)\s*)?\)"#) { g in
            func v(_ t: String, _ scale: Double) -> Double { t.hasSuffix("%") ? (Double(t.dropLast()) ?? 0) / 100 * scale : Double(t) ?? 0 }
            let alpha = g[4].isEmpty ? 1 : v(g[4], 1)
            return map(RGB(v(g[1], 255), v(g[2], 255), v(g[3], 255)), alpha)
        }
        // 3. Named colors used as paint.
        s = replace(s, #"((?:fill|stroke|stop-color|flood-color)\s*[:=]\s*["']?\s*)([a-zA-Z]+)"#) { g in
            guard let hex = named[g[2].lowercased()] else { return g[0] }
            return g[1] + map(ColorMath.rgb(hex), 1)
        }
        return s
    }

    private static func replace(_ text: String, _ pattern: String, _ transform: ([String]) -> String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        var out = "", last = 0
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let groups = (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last)) + transform(groups)
            last = m.range.location + m.range.length
        }
        return out + ns.substring(from: last)
    }

    static func isKnockout(_ c: RGB, key: RGB = RGB(255, 255, 255)) -> Bool {
        ((c.r - key.r) * (c.r - key.r) + (c.g - key.g) * (c.g - key.g) + (c.b - key.b) * (c.b - key.b)).squareRoot() < 60
    }

    /// How many paints in the artwork are white-ish (cut-outs in one-color versions) versus colored.
    static func paintCounts(_ svg: String) -> (shown: Int, knockouts: Int) {
        var shown = 0, knockouts = 0
        _ = mapColors(inner(svg)) { c, _ in
            if isKnockout(c) { knockouts += 1 } else { shown += 1 }
            return ""
        }
        return (shown, knockouts)
    }

    private static func root(_ vb: CGRect, scale k: Double) -> String {
        "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" viewBox=\"0 0 \(fmt(vb.width * k)) \(fmt(vb.height * k))\" width=\"\(fmt(vb.width * k))\" height=\"\(fmt(vb.height * k))\">"
    }

    /// Normalizes coordinates to start at 0,0 and scales them by `k` (a larger user space makes
    /// renderers rasterize masks at a higher resolution).
    private static func placed(_ content: String, _ vb: CGRect, scale k: Double) -> String {
        "<g transform=\"scale(\(fmt(k))) translate(\(fmt(-vb.minX)) \(fmt(-vb.minY)))\">\(content)</g>"
    }

    /// Recolors the artwork with plain fills, no masks, so it stays vector in every renderer and in PDFs.
    /// White-ish parts get `knockoutFill` (the background they sit on) or the main color when nil.
    static func recolor(_ svg: String, hex: String, knockoutFill: String?) -> String {
        let vb = viewBox(svg) ?? CGRect(x: 0, y: 0, width: 100, height: 100)
        let allWhite = paintCounts(svg).shown == 0
        let mapped = mapColors(inner(svg)) { c, _ in
            !allWhite && isKnockout(c) ? (knockoutFill ?? hex) : hex
        }
        return root(vb, scale: 1) + "<g fill=\"\(hex)\">" + placed(mapped, vb, scale: 1) + "</g></svg>"
    }

    /// A one-color version with true cut-outs: white-ish areas are removed through a luminance mask,
    /// so they stay holes on any background, even when they sit on top of other shapes.
    static func oneColor(_ svg: String, hex: String, scale k: Double = 1) -> String {
        let vb = viewBox(svg) ?? CGRect(x: 0, y: 0, width: 100, height: 100)
        let body = inner(svg)
        let allWhite = paintCounts(svg).shown == 0
        let mapped = mapColors(body) { c, alpha in
            if !allWhite && isKnockout(c) { return "#000000" }
            return alpha >= 1 ? "#FFFFFF" : ColorMath.hex(RGB(255 * alpha, 255 * alpha, 255 * alpha))
        }
        let (w, h) = (fmt(vb.width * k), fmt(vb.height * k))
        return root(vb, scale: k) + """
        <defs><mask id="palette-pro-knockout" maskUnits="userSpaceOnUse" x="0" y="0" width="\(w)" height="\(h)"><g fill="#FFFFFF">\(placed(mapped, vb, scale: k))</g></mask></defs>
        <rect x="0" y="0" width="\(w)" height="\(h)" fill="\(hex)" mask="url(#palette-pro-knockout)"/>
        </svg>
        """
    }
}

/// An SVG logo kept as vector. `full` is the original artwork; one-color versions are generated on demand.
final class VectorLogo {
    let svg: String
    let viewBox: CGRect
    let full: NSImage
    /// The artwork has white details that one-color versions must cut out.
    let hasKnockouts: Bool
    private var cache: [String: NSImage] = [:]

    var aspect: CGFloat { viewBox.width / max(viewBox.height, 0.0001) }

    init?(svg: String) {
        guard let image = NSImage(data: Data(svg.utf8)), image.size.width > 0, image.size.height > 0 else { return nil }
        self.svg = svg
        viewBox = SVGLogo.viewBox(svg) ?? CGRect(origin: .zero, size: image.size)
        let counts = SVGLogo.paintCounts(svg)
        hasKnockouts = counts.shown > 0 && counts.knockouts > 0
        full = Self.sized(image, aspect: viewBox.width / max(viewBox.height, 0.0001))
    }

    /// An SVG string as a crisp NSImage.
    static func image(svg: String, aspect: CGFloat) -> NSImage? {
        NSImage(data: Data(svg.utf8)).map { sized($0, aspect: aspect) }
    }

    /// A large point size makes SwiftUI render the vector crisply at every size used in the app.
    private static func sized(_ image: NSImage, aspect: CGFloat) -> NSImage {
        image.size = aspect >= 1 ? NSSize(width: 1024, height: 1024 / aspect) : NSSize(width: 1024 * aspect, height: 1024)
        return image
    }

    /// The same logo with its viewBox cropped to `content`, given in pixels of a raster of size `rasterSize`.
    func cropped(toPixels content: CGRect, rasterSize: CGSize) -> VectorLogo? {
        let sx = viewBox.width / rasterSize.width, sy = viewBox.height / rasterSize.height
        let rect = CGRect(x: viewBox.minX + content.minX * sx, y: viewBox.minY + content.minY * sy,
                          width: content.width * sx, height: content.height * sy)
        return VectorLogo(svg: SVGLogo.withViewBox(svg, rect))
    }

    /// One-color SVG file: true cut-outs (mask) when the logo has white details, plain fills otherwise.
    func oneColorSVG(_ hex: String) -> String {
        hasKnockouts ? SVGLogo.oneColor(svg, hex: hex) : SVGLogo.recolor(svg, hex: hex, knockoutFill: nil)
    }

    /// One-color artwork for a known background: white details are painted in the background color,
    /// which looks identical to a cut-out and stays 100% vector (used in the app and on the brand sheet).
    func oneColor(_ hex: String, on background: String) -> NSImage {
        image(for: "screen|\(hex)|\(background)") { SVGLogo.recolor(svg, hex: hex, knockoutFill: background) }
    }

    /// One-color artwork for PDF/PNG files used on any background. With white details it uses a
    /// mask drawn in a 4096-unit space, so renderers rasterize it at high resolution.
    func oneColorPrint(_ hex: String) -> NSImage {
        image(for: "print|\(hex)") {
            hasKnockouts ? SVGLogo.oneColor(svg, hex: hex, scale: 4096 / max(viewBox.width, viewBox.height))
                         : SVGLogo.recolor(svg, hex: hex, knockoutFill: nil)
        }
    }

    private func image(for key: String, _ make: () -> String) -> NSImage {
        if let img = cache[key] { return img }
        let img = NSImage(data: Data(make().utf8)).map { Self.sized($0, aspect: aspect) } ?? full
        cache[key] = img
        return img
    }
}

/// Collects where vector logos sit on the brand sheet, so they can be drawn into the PDF as real
/// vectors after SwiftUI (which rasterizes images) has drawn the rest of the page.
final class VectorSlotCollector {
    struct Slot { let rect: CGRect; let image: NSImage }
    static let space = "brandSheet"
    private(set) var slots: [String: Slot] = [:]

    func record(_ id: String, _ rect: CGRect, _ image: NSImage) { slots[id] = Slot(rect: rect, image: image) }

    /// Draws every slot, aspect-fit, into a PDF context whose page is `pageHeight` tall.
    func draw(in ctx: CGContext, pageHeight: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        for slot in slots.values {
            let r = slot.rect, size = slot.image.size
            let scale = min(r.width / size.width, r.height / size.height)
            let w = size.width * scale, h = size.height * scale
            let fitted = CGRect(x: r.midX - w / 2, y: pageHeight - r.midY - h / 2, width: w, height: h)
            slot.image.draw(in: fitted, from: .zero, operation: .sourceOver, fraction: 1)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
