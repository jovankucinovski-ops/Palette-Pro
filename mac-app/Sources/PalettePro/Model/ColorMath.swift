import Foundation

typealias Vec3 = SIMD3<Double>

/// sRGB colour with 0–255 channels.
struct RGB: Hashable, Codable {
    var r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    var ints: [Int] { [r, g, b].map { Int($0.rounded()) } }
}

enum Harmony: String, CaseIterable, Identifiable, Codable {
    case auto, analogous, monochromatic, complementary, split, triadic, tetradic
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Surprise me"
        case .analogous: "Analogous"
        case .monochromatic: "Monochromatic"
        case .complementary: "Complementary"
        case .split: "Split complementary"
        case .triadic: "Triadic"
        case .tetradic: "Tetradic"
        }
    }
    func offsets(_ n: Int) -> [Double] {
        switch self {
        case .auto, .analogous:
            return (0..<n).map { (Double($0) - Double(n - 1) / 2) * (n > 1 ? 70 / Double(n - 1) : 0) }
        case .monochromatic: return [0]
        case .complementary: return [0, 180]
        case .split: return [0, 150, 210]
        case .triadic: return [0, 120, 240]
        case .tetradic: return [0, 90, 180, 270]
        }
    }
}

enum Mood: String, CaseIterable, Identifiable, Codable {
    case balanced, pastel, vibrant, muted, earthy, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var lightness: ClosedRange<Double> {
        switch self {
        case .balanced: 0.35...0.92
        case .pastel: 0.82...0.95
        case .vibrant: 0.55...0.82
        case .muted: 0.42...0.82
        case .earthy: 0.30...0.78
        case .dark: 0.22...0.48
        }
    }
    var chroma: ClosedRange<Double> {
        switch self {
        case .balanced: 0.05...0.19
        case .pastel: 0.035...0.10
        case .vibrant: 0.17...0.32
        case .muted: 0.025...0.075
        case .earthy: 0.04...0.12
        case .dark: 0.04...0.15
        }
    }
    var hueRange: ClosedRange<Double>? { self == .earthy ? 20...120 : nil }
}

enum Family: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, teal, blue, purple, pink, brown, neutral
    var id: String { rawValue }
    var title: String { rawValue.capitalized + (self == .neutral ? "s" : "s") }
    var dotHex: String {
        switch self {
        case .red: "#D3343B"
        case .orange: "#EE7A2D"
        case .yellow: "#F2C531"
        case .green: "#3E9C55"
        case .teal: "#1C9A9A"
        case .blue: "#2F62C4"
        case .purple: "#7A4DBA"
        case .pink: "#E46AA6"
        case .brown: "#8A5A3B"
        case .neutral: "#9C9C9C"
        }
    }
}

enum ColorMath {
    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }
    private static let deg = 180 / Double.pi
    private static let rad = Double.pi / 180

    // MARK: Parsing & formatting

    static func parseHex(_ input: String) -> String? {
        var h = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        if h.count == 3, h.allSatisfy(\.isHexDigit) { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6, h.allSatisfy(\.isHexDigit) else { return nil }
        return "#" + h.uppercased()
    }

    static func rgb(_ hex: String) -> RGB {
        let v = UInt32(hex.hasPrefix("#") ? String(hex.dropFirst()) : hex, radix: 16) ?? 0
        return RGB(Double((v >> 16) & 255), Double((v >> 8) & 255), Double(v & 255))
    }

    static func hex(_ c: RGB) -> String {
        String(format: "#%02X%02X%02X", Int(clamp(c.r, 0, 255).rounded()), Int(clamp(c.g, 0, 255).rounded()), Int(clamp(c.b, 0, 255).rounded()))
    }

    // MARK: sRGB transfer

    static func toLinear(_ c: Double) -> Double { let v = c / 255; return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    static func fromLinear(_ c: Double) -> Double { 255 * (c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055) }

    // MARK: HSL

    static func hsl(_ c: RGB) -> Vec3 {
        let r = c.r / 255, g = c.g / 255, b = c.b / 255
        let mx = max(r, g, b), mn = min(r, g, b), l = (mx + mn) / 2
        var h = 0.0, s = 0.0
        if mx != mn {
            let d = mx - mn
            s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
            if mx == r { h = (g - b) / d + (g < b ? 6 : 0) } else if mx == g { h = (b - r) / d + 2 } else { h = (r - g) / d + 4 }
            h *= 60
        }
        return Vec3(h, s * 100, l * 100)
    }

    // MARK: CIE Lab (D65)

    static func lab(_ c: RGB) -> Vec3 {
        let r = toLinear(c.r), g = toLinear(c.g), b = toLinear(c.b)
        let x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
        let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        let z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
        func f(_ t: Double) -> Double { t > 216.0 / 24389 ? cbrt(t) : (24389.0 / 27 * t + 16) / 116 }
        let fx = f(x), fy = f(y), fz = f(z)
        return Vec3(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    static func lch(_ lab: Vec3) -> Vec3 {
        Vec3(lab.x, hypot(lab.y, lab.z), (atan2(lab.z, lab.y) * deg + 360).truncatingRemainder(dividingBy: 360))
    }

    /// CIEDE2000 colour difference (Sharma, Wu & Dalal 2005).
    static func deltaE(_ p: Vec3, _ q: Vec3) -> Double {
        let (L1, a1, b1, L2, a2, b2) = (p.x, p.y, p.z, q.x, q.y, q.z)
        let C1 = hypot(a1, b1), C2 = hypot(a2, b2)
        let cb7 = pow((C1 + C2) / 2, 7)
        let G = 0.5 * (1 - sqrt(cb7 / (cb7 + 6103515625)))
        let a1p = (1 + G) * a1, a2p = (1 + G) * a2
        let C1p = hypot(a1p, b1), C2p = hypot(a2p, b2)
        let h1p = (b1 == 0 && a1p == 0) ? 0 : (atan2(b1, a1p) * deg + 360).truncatingRemainder(dividingBy: 360)
        let h2p = (b2 == 0 && a2p == 0) ? 0 : (atan2(b2, a2p) * deg + 360).truncatingRemainder(dividingBy: 360)
        let dLp = L2 - L1, dCp = C2p - C1p, prod = C1p * C2p
        var dhp = 0.0
        if prod != 0 {
            dhp = h2p - h1p
            if dhp > 180 { dhp -= 360 } else if dhp < -180 { dhp += 360 }
        }
        let dHp = 2 * sqrt(prod) * sin(dhp * rad / 2)
        let Lbp = (L1 + L2) / 2, Cbp = (C1p + C2p) / 2
        var hbp = h1p + h2p
        if prod != 0 {
            hbp = abs(h1p - h2p) > 180 ? (h1p + h2p < 360 ? (h1p + h2p + 360) / 2 : (h1p + h2p - 360) / 2) : (h1p + h2p) / 2
        }
        let T = 1 - 0.17 * cos((hbp - 30) * rad) + 0.24 * cos(2 * hbp * rad) + 0.32 * cos((3 * hbp + 6) * rad) - 0.20 * cos((4 * hbp - 63) * rad)
        let dTheta = 30 * exp(-pow((hbp - 275) / 25, 2))
        let cbp7 = pow(Cbp, 7)
        let Rc = 2 * sqrt(cbp7 / (cbp7 + 6103515625))
        let lm = (Lbp - 50) * (Lbp - 50)
        let Sl = 1 + 0.015 * lm / sqrt(20 + lm), Sc = 1 + 0.045 * Cbp, Sh = 1 + 0.015 * Cbp * T
        let Rt = -sin(2 * dTheta * rad) * Rc
        let l = dLp / Sl, c = dCp / Sc, h = dHp / Sh
        return sqrt(l * l + c * c + h * h + Rt * c * h)
    }

    static func matchQuality(_ dE: Double) -> String {
        switch dE {
        case ..<1: "Exact"
        case ..<2.5: "Very close"
        case ..<5: "Close"
        case ..<10: "Similar"
        default: "Distant"
        }
    }

    // MARK: OKLab / OKLCH

    static func oklch(_ c: RGB) -> Vec3 {
        let r = toLinear(c.r), g = toLinear(c.g), b = toLinear(c.b)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        return Vec3(L, hypot(A, B), (atan2(B, A) * deg + 360).truncatingRemainder(dividingBy: 360))
    }

    static func oklch(hex: String) -> Vec3 { oklch(rgb(hex)) }

    private static func oklchToLinear(_ L: Double, _ C: Double, _ H: Double) -> Vec3 {
        let a = C * cos(H * rad), b = C * sin(H * rad)
        let l = pow(L + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(L - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(L - 0.0894841775 * a - 1.2914855480 * b, 3)
        return Vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    }

    /// Converts OKLCH to hex, reducing chroma until the colour fits in sRGB.
    static func hex(oklch L0: Double, _ C0: Double, _ H0: Double) -> String {
        let L = clamp(L0, 0, 1), H = (H0.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        func inGamut(_ c: Double) -> Bool {
            let v = oklchToLinear(L, c, H)
            return [v.x, v.y, v.z].allSatisfy { $0 >= -0.0001 && $0 <= 1.0001 }
        }
        var C = max(0, C0)
        if !inGamut(C) {
            var lo = 0.0, hi = C
            for _ in 0..<20 { let mid = (lo + hi) / 2; if inGamut(mid) { lo = mid } else { hi = mid } }
            C = lo
        }
        let v = oklchToLinear(L, C, H)
        return hex(RGB(fromLinear(clamp(v.x, 0, 1)), fromLinear(clamp(v.y, 0, 1)), fromLinear(clamp(v.z, 0, 1))))
    }

    // MARK: Contrast (WCAG 2)

    static func luminance(_ c: RGB) -> Double { 0.2126 * toLinear(c.r) + 0.7152 * toLinear(c.g) + 0.0722 * toLinear(c.b) }

    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func contrast(_ a: String, _ b: String) -> Double { contrast(rgb(a), rgb(b)) }

    static func grade(_ ratio: Double) -> String {
        ratio >= 7 ? "AAA" : ratio >= 4.5 ? "AA" : ratio >= 3 ? "AA Large" : "Fail"
    }

    /// White or near-black, whichever reads better on the colour.
    static func readableOn(_ c: RGB) -> String {
        contrast(c, RGB(255, 255, 255)) >= contrast(c, RGB(17, 17, 17)) ? "#FFFFFF" : "#111111"
    }

    /// Naive conversion; real print values depend on the press profile.
    static func cmyk(_ c: RGB) -> [Int] {
        let r = c.r / 255, g = c.g / 255, b = c.b / 255
        let k = 1 - max(r, g, b)
        if k >= 1 { return [0, 0, 0, 100] }
        return [(1 - r - k) / (1 - k), (1 - g - k) / (1 - k), (1 - b - k) / (1 - k), k].map { Int(($0 * 100).rounded()) }
    }

    // MARK: Families

    static func family(hsl: Vec3, lch: Vec3) -> Family {
        let h = hsl.x, L = lch.x, C = lch.y
        if C < 8 { return .neutral }
        if h >= 12 && h < 50 && L < 55 && C < 45 { return .brown }
        if h < 12 || h >= 345 { return L > 72 ? .pink : .red }
        if h < 40 { return .orange }
        if h < 66 { return .yellow }
        if h < 165 { return .green }
        if h < 195 { return .teal }
        if h < 252 { return .blue }
        if h < 292 { return .purple }
        return .pink
    }

    static func family(hex: String) -> Family {
        let c = rgb(hex)
        return family(hsl: hsl(c), lch: lch(lab(c)))
    }

    // MARK: Generation

    /// Returns `n` hex colours. `baseHue` (OKLCH degrees) anchors the harmony, e.g. to a locked colour.
    static func generate(_ n: Int, harmony: Harmony = .auto, mood: Mood = .balanced, baseHue: Double? = nil) -> [String] {
        let h = harmony == .auto ? Harmony.allCases.filter { $0 != .auto }.randomElement()! : harmony
        let base = baseHue ?? (mood.hueRange.map { Double.random(in: $0) } ?? Double.random(in: 0..<360))
        let offsets = h.offsets(n)
        let L = mood.lightness, C = mood.chroma
        let lights = (0..<n).map { i in
            L.lowerBound + (L.upperBound - L.lowerBound) * (n > 1 ? Double(i) / Double(n - 1) : 0.5) + Double.random(in: -0.03...0.03)
        }.shuffled()
        return (0..<n).map { i in
            let jitter = h == .monochromatic ? Double.random(in: -6...6) : Double.random(in: -10...10)
            return hex(oklch: lights[i], Double.random(in: C), base + offsets[i % offsets.count] + jitter)
        }
    }

    static func tintsAndShades(_ hex: String, steps: Int = 9) -> [String] {
        let o = oklch(hex: hex)
        return (0..<steps).map { i in
            let t = Double(i), mid = Double(steps - 1) / 2
            return self.hex(oklch: 0.96 - t * (0.82 / Double(steps - 1)), o.y * (1 - abs(t - mid) / Double(steps)), o.z)
        }
    }

    /// Tailwind-style 50–900 ramp around a colour's hue and chroma.
    static func ramp(_ hex: String) -> [(step: Int, hex: String)] {
        let o = oklch(hex: hex)
        let steps: [(Int, Double, Double)] = [
            (50, 0.975, 0.18), (100, 0.945, 0.32), (200, 0.89, 0.55), (300, 0.82, 0.78), (400, 0.72, 0.95),
            (500, 0.63, 1.0), (600, 0.54, 0.95), (700, 0.45, 0.85), (800, 0.37, 0.72), (900, 0.29, 0.6),
        ]
        return steps.map { ($0.0, self.hex(oklch: $0.1, o.y * $0.2 * 1.05, o.z)) }
    }

    // MARK: Image palette extraction (k-means++ in Lab)

    static func extractPalette(_ pixels: [RGB], k kIn: Int) -> [(hex: String, share: Double)] {
        let pts = pixels.map(lab)
        guard !pts.isEmpty else { return [] }
        let k = min(kIn, pts.count)
        func d2(_ p: Vec3, _ q: Vec3) -> Double { let d = p - q; return (d * d).sum() }
        var centers = [pts.randomElement()!]
        while centers.count < k {
            let dist = pts.map { p in centers.map { d2(p, $0) }.min()! }
            var r = Double.random(in: 0..<max(dist.reduce(0, +), .leastNonzeroMagnitude))
            var i = 0
            while i < dist.count - 1 { r -= dist[i]; if r <= 0 { break }; i += 1 }
            centers.append(pts[i])
        }
        var assign = [Int](repeating: 0, count: pts.count)
        for _ in 0..<14 {
            var sums = [Vec3](repeating: .zero, count: k), counts = [Int](repeating: 0, count: k)
            for (i, p) in pts.enumerated() {
                var best = 0, bd = Double.infinity
                for (j, c) in centers.enumerated() { let d = d2(p, c); if d < bd { bd = d; best = j } }
                assign[i] = best; sums[best] += p; counts[best] += 1
            }
            for j in 0..<k where counts[j] > 0 { centers[j] = sums[j] / Double(counts[j]) }
        }
        var counts = [Int](repeating: 0, count: k)
        assign.forEach { counts[$0] += 1 }
        // Report the real pixel nearest each centre, so every colour actually appears in the image.
        var reps = [(d: Double, i: Int)](repeating: (.infinity, 0), count: k)
        for (i, p) in pts.enumerated() {
            let a = assign[i], d = d2(p, centers[a])
            if d < reps[a].d { reps[a] = (d, i) }
        }
        return (0..<k).filter { counts[$0] > 0 }
            .map { (hex: hex(pixels[reps[$0].i]), share: Double(counts[$0]) / Double(pts.count)) }
            .sorted { $0.share > $1.share }
    }
}
