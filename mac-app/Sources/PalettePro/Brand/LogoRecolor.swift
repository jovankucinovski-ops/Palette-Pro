import AppKit

/// Repaints a logo in a brand palette: each of the logo's colors is assigned a palette role
/// (main color → Primary, second color → Accent, …) and replaced by that role's color.
enum LogoRecolor {
    struct Entry {
        let source: RGB
        let lab: Vec3
        let target: String
    }

    /// Assigns the logo's colors (most used first) to roles in `concept`.
    /// White details stay light; near-black text becomes the dark neutral, unless the logo has no
    /// other color, in which case it takes the Primary color so the idea is visible.
    static func mapping(_ colors: [ExtractedColor], _ concept: BrandConcept) -> [Entry] {
        let o = { (h: String) in ColorMath.oklch(hex: h) }
        let isWhite = { (h: String) in o(h).x > 0.92 && o(h).y < 0.035 }
        let isDark = { (h: String) in o(h).x < 0.34 && o(h).y < 0.09 }
        let others = colors.filter { !isWhite($0.hex) }
        var chromatic = others.filter { !isDark($0.hex) }
        var darks = others.filter { isDark($0.hex) }
        if chromatic.isEmpty, !darks.isEmpty { chromatic = [darks.removeFirst()] }

        let order: [BrandRole] = [.primary, .accent, .secondary]
        var result: [Entry] = []
        func add(_ c: ExtractedColor, _ role: BrandRole) {
            let rgb = ColorMath.rgb(c.hex)
            result.append(Entry(source: rgb, lab: ColorMath.lab(rgb), target: concept.hex(role)))
        }
        for (i, c) in chromatic.enumerated() { add(c, order[min(i, order.count - 1)]) }
        for c in darks { add(c, .dark) }
        for c in colors where isWhite(c.hex) { add(c, .light) }
        return result
    }

    private static func nearest(_ lab: Vec3, _ map: [Entry]) -> (first: Int, second: Int?, t: Double) {
        var best = (i: 0, d: Double.infinity), next = (i: -1, d: Double.infinity)
        for (i, e) in map.enumerated() {
            let v = lab - e.lab, d = (v * v).sum().squareRoot()
            if d < best.d { next = best; best = (i, d) } else if d < next.d { next = (i, d) }
        }
        guard next.i >= 0, best.d + next.d > 0 else { return (best.i, nil, 0) }
        // Pixels between two logo colors (anti-aliased edges) get a matching mix of the two targets.
        return (best.i, next.i, min(0.5, best.d / (best.d + next.d)))
    }

    /// SVG version: every color in the markup is replaced by its role's color. Stays vector.
    static func recolorSVG(_ svg: String, _ map: [Entry]) -> String {
        guard !map.isEmpty, let root = SVGLogo.rootTag(svg) else { return svg }
        let replace = { (c: RGB) -> String in map[nearest(ColorMath.lab(c), map).first].target }
        let body = SVGLogo.mapColors(SVGLogo.inner(svg)) { c, _ in replace(c) }
        // Shapes without a fill are black by default, so they follow black's role.
        return String(svg[root]) + "<g fill=\"\(replace(RGB(0, 0, 0)))\">" + body + "</g></svg>"
    }

    /// Bitmap version, keeping alpha and smooth edges.
    static func recolorRaster(_ cg: CGImage, _ map: [Entry]) -> CGImage? {
        guard !map.isEmpty else { return cg }
        var buf = LogoProcessor.pixels(cg)
        let targets = map.map { ColorMath.rgb($0.target) }
        var memo: [UInt32: (UInt8, UInt8, UInt8)] = [:]
        for i in stride(from: 0, to: buf.count, by: 4) {
            let a = buf[i + 3]
            guard a > 0 else { continue }
            let af = Double(a) / 255
            let r = min(255, Double(buf[i]) / af), g = min(255, Double(buf[i + 1]) / af), b = min(255, Double(buf[i + 2]) / af)
            let key = UInt32(r) << 16 | UInt32(g) << 8 | UInt32(b)
            let out: (UInt8, UInt8, UInt8)
            if let hit = memo[key] {
                out = hit
            } else {
                let n = nearest(ColorMath.lab(RGB(r, g, b)), map)
                let t1 = targets[n.first], t2 = n.second.map { targets[$0] } ?? t1
                let mix = { (x: Double, y: Double) in UInt8(ColorMath.clamp(x * (1 - n.t) + y * n.t, 0, 255).rounded()) }
                out = (mix(t1.r, t2.r), mix(t1.g, t2.g), mix(t1.b, t2.b))
                memo[key] = out
            }
            buf[i] = UInt8((Double(out.0) * af).rounded())
            buf[i + 1] = UInt8((Double(out.1) * af).rounded())
            buf[i + 2] = UInt8((Double(out.2) * af).rounded())
        }
        return LogoProcessor.image(from: buf, width: cg.width, height: cg.height)
    }
}
