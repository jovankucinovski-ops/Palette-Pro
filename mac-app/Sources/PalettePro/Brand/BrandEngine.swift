import SwiftUI

// MARK: - Inputs

enum ProjectFocus: String, CaseIterable, Identifiable, Codable {
    case logo, identity, digital, packaging, social, print
    var id: String { rawValue }
    var title: String {
        switch self {
        case .logo: "Logo"
        case .identity: "Brand identity"
        case .digital: "Website & app"
        case .packaging: "Packaging"
        case .social: "Social media"
        case .print: "Print & stationery"
        }
    }
    var symbol: String {
        switch self {
        case .logo: "seal"
        case .identity: "square.stack.3d.up"
        case .digital: "macwindow"
        case .packaging: "shippingbox"
        case .social: "square.and.arrow.up.on.square"
        case .print: "printer"
        }
    }
}

enum Industry: String, CaseIterable, Identifiable, Codable {
    case tech, finance, health, food, fashion, luxury, kids, eco, creative, realEstate, fitness, travel
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tech: "Tech & software"
        case .finance: "Finance & legal"
        case .health: "Health & wellness"
        case .food: "Food & drink"
        case .fashion: "Fashion & beauty"
        case .luxury: "Luxury"
        case .kids: "Kids & education"
        case .eco: "Eco & outdoors"
        case .creative: "Creative & arts"
        case .realEstate: "Real estate & home"
        case .fitness: "Sports & fitness"
        case .travel: "Travel & hospitality"
        }
    }
    /// Candidate primary hues (OKLCH degrees), one per suggested concept.
    var hues: [Double] {
        switch self {
        case .tech: [262, 285, 195, 305]
        case .finance: [255, 155, 232, 25]
        case .health: [185, 150, 232, 20]
        case .food: [30, 55, 140, 95]
        case .fashion: [355, 15, 305, 60]
        case .luxury: [300, 160, 25, 255]
        case .kids: [255, 30, 145, 95]
        case .eco: [140, 120, 70, 200]
        case .creative: [330, 300, 50, 190]
        case .realEstate: [250, 200, 70, 160]
        case .fitness: [30, 50, 130, 265]
        case .travel: [215, 185, 40, 85]
        }
    }
    var lightness: Double {
        switch self {
        case .finance, .luxury: 0.38
        case .realEstate: 0.42
        case .eco, .tech, .fashion: 0.52
        case .kids: 0.62
        default: 0.58
        }
    }
    var chroma: Double {
        switch self {
        case .luxury, .realEstate: 0.08
        case .finance, .eco: 0.10
        case .health, .fashion, .travel: 0.12
        case .tech: 0.17
        case .food, .kids: 0.18
        case .creative, .fitness: 0.21
        }
    }
    var warmNeutrals: Bool { [.food, .fashion, .luxury, .eco, .realEstate, .travel].contains(self) }
    var note: String {
        switch self {
        case .tech: "Tech brands lean on blues and violets for clarity and trust. A vivid accent stops you from blending in with every other blue logo."
        case .finance: "Finance has to feel secure: deep, low-saturation hues and restrained accents. Avoid pure red as a main color, since it reads as “loss”."
        case .health: "Health and wellness brands use teal, green and soft blue to feel clean and caring. Keep saturation gentle so nothing feels clinical or alarming."
        case .food: "Warm hues (red, orange, yellow) stimulate appetite, and a fresh green signals natural ingredients."
        case .fashion: "Fashion and beauty favor nuanced tones like blush, plum and nude, with generous neutral space so product photography leads."
        case .luxury: "Luxury is about restraint: dark bases, very few colors, gold-like accents and lots of negative space."
        case .kids: "Kids and education brands use bright, clearly different hues. Keep contrast high so text stays readable for young readers."
        case .eco: "Sustainability brands lean on greens and earthy browns. Muted, natural tones avoid the cliché of neon “eco” green."
        case .creative: "Creative brands can take risks: unexpected pairings and saturated accents show personality."
        case .realEstate: "Real estate mixes a trustworthy navy or slate with warm neutrals that feel like home."
        case .fitness: "Sports and fitness brands use high-energy colors with strong contrast, and they really pop on dark backgrounds."
        case .travel: "Hospitality and travel borrow from destinations: ocean blues, warm sand and sunset coral."
        }
    }
}

enum Trait: String, CaseIterable, Identifiable, Codable {
    case trustworthy, bold, playful, calm, premium, natural, modern, warm, energetic, minimal, friendly, rebellious
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var dL: Double {
        switch self {
        case .trustworthy: -0.04
        case .playful, .calm: 0.07
        case .premium: -0.1
        case .friendly: 0.05
        case .energetic: 0.04
        case .warm: 0.02
        case .rebellious: -0.05
        default: 0
        }
    }
    var chromaScale: Double {
        switch self {
        case .trustworthy: 0.85
        case .bold, .energetic: 1.3
        case .playful: 1.25
        case .calm, .premium: 0.7
        case .natural: 0.75
        case .minimal: 0.85
        case .friendly: 1.05
        case .rebellious: 1.35
        default: 1
        }
    }
    /// Hue this trait nudges the primary toward, and how strongly.
    var huePull: (target: Double, weight: Double)? {
        switch self {
        case .trustworthy: (255, 0.25)
        case .natural: (130, 0.2)
        case .warm: (45, 0.25)
        case .friendly: (60, 0.12)
        default: nil
        }
    }
    var harmony: Harmony {
        switch self {
        case .trustworthy, .calm, .natural, .friendly: .analogous
        case .bold, .energetic: .complementary
        case .playful: .triadic
        case .premium, .minimal: .monochromatic
        case .modern, .rebellious: .split
        case .warm: .analogous
        }
    }
    var adjective: String {
        switch self {
        case .trustworthy: "Steady"
        case .bold: "Bold"
        case .playful: "Pop"
        case .calm: "Quiet"
        case .premium: "Noir"
        case .natural: "Field"
        case .modern: "Grid"
        case .warm: "Ember"
        case .energetic: "Pulse"
        case .minimal: "Pure"
        case .friendly: "Sunny"
        case .rebellious: "Riot"
        }
    }
    var note: String {
        switch self {
        case .trustworthy: "Trustworthy: saturation kept moderate, hues pulled toward blue."
        case .bold: "Bold: saturation pushed up, with a high-contrast accent."
        case .playful: "Playful: lighter, brighter tones spread across the color wheel."
        case .calm: "Calm: softened saturation, hues kept close together."
        case .premium: "Premium: darker base, restrained color and a gold-leaning accent."
        case .natural: "Natural: muted, earthy tones nudged toward green."
        case .modern: "Modern: a clean split-complementary system on cool neutrals."
        case .warm: "Warm: hues nudged toward orange, on warm neutrals."
        case .energetic: "Energetic: high saturation with complementary contrast."
        case .minimal: "Minimal: neutrals do most of the work, with one decisive accent."
        case .friendly: "Friendly: lighter tones and approachable, warm-leaning hues."
        case .rebellious: "Rebellious: a clashing accent on a very dark base."
        }
    }
    var type: TypeSuggestion {
        switch self {
        case .trustworthy: TypeSuggestion(headline: "IBM Plex Sans", body: "IBM Plex Serif", design: .default, weight: .semibold, width: .standard, why: "a clear, engineered sans that feels reliable")
        case .bold: TypeSuggestion(headline: "Archivo Black", body: "Archivo", design: .default, weight: .black, width: .standard, why: "heavy, confident letterforms")
        case .playful: TypeSuggestion(headline: "Fredoka", body: "Nunito", design: .rounded, weight: .bold, width: .standard, why: "soft, rounded shapes that feel fun")
        case .calm: TypeSuggestion(headline: "DM Serif Display", body: "DM Sans", design: .serif, weight: .regular, width: .standard, why: "a gentle serif with lots of air")
        case .premium: TypeSuggestion(headline: "Playfair Display", body: "Inter", design: .serif, weight: .medium, width: .standard, why: "high-contrast serifs read as editorial and luxurious")
        case .natural: TypeSuggestion(headline: "Fraunces", body: "Work Sans", design: .serif, weight: .semibold, width: .standard, why: "a warm, slightly quirky serif with an organic feel")
        case .modern: TypeSuggestion(headline: "Space Grotesk", body: "Inter", design: .default, weight: .medium, width: .standard, why: "geometric and current without being cold")
        case .warm: TypeSuggestion(headline: "Young Serif", body: "Lato", design: .serif, weight: .regular, width: .standard, why: "friendly serifs that feel handmade")
        case .energetic: TypeSuggestion(headline: "Bebas Neue", body: "Montserrat", design: .default, weight: .heavy, width: .condensed, why: "tall, condensed capitals full of motion")
        case .minimal: TypeSuggestion(headline: "Inter", body: "Inter", design: .default, weight: .regular, width: .standard, why: "one neutral family, so the colors stay the focus")
        case .friendly: TypeSuggestion(headline: "Nunito", body: "Nunito Sans", design: .rounded, weight: .semibold, width: .standard, why: "rounded terminals that feel approachable")
        case .rebellious: TypeSuggestion(headline: "Anton", body: "Space Mono", design: .default, weight: .black, width: .condensed, why: "loud condensed headlines with a raw monospace body")
        }
    }
}

struct TypeSuggestion: Hashable {
    let headline: String
    let body: String
    let design: Font.Design
    let weight: Font.Weight
    let width: Font.Width
    let why: String
}

enum LogoStyle: String, CaseIterable, Identifiable, Codable {
    case monogram, orbit, stack, petal, spark, wordmark, custom
    var id: String { rawValue }
    var title: String { self == .custom ? "My logo" : rawValue.capitalized }
    /// Generated marks; `.custom` is only offered once a logo image is imported.
    static var generated: [LogoStyle] { allCases.filter { $0 != .custom } }
}

enum BrandTypeface: String, CaseIterable, Identifiable, Codable {
    case suggested, sans, serif, rounded, mono, condensed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .suggested: "Suggested"
        case .sans: "Sans"
        case .serif: "Serif"
        case .rounded: "Rounded"
        case .mono: "Mono"
        case .condensed: "Condensed"
        }
    }
}

// MARK: - Output

enum BrandRole: String, CaseIterable, Identifiable, Codable {
    case primary, secondary, accent, dark, light
    var id: String { rawValue }
    var title: String {
        switch self {
        case .primary: "Primary"
        case .secondary: "Secondary"
        case .accent: "Accent"
        case .dark: "Dark neutral"
        case .light: "Light neutral"
        }
    }
    var usage: String {
        switch self {
        case .primary: "Logo, headers, key surfaces"
        case .secondary: "Supporting graphics, secondary buttons, illustration"
        case .accent: "Calls to action, highlights, small details"
        case .dark: "Body text, icons, dark backgrounds"
        case .light: "Backgrounds, cards, breathing room"
        }
    }
    /// Approximate share of a typical layout (60-30-10 with neutrals carrying the 60).
    var share: Double {
        switch self {
        case .light: 0.5
        case .primary: 0.25
        case .secondary: 0.12
        case .dark: 0.08
        case .accent: 0.05
        }
    }
}

struct BrandColor: Hashable, Codable {
    var hex: String
    var sid: String?
    var color: Color { Color(hex: hex) }
}

struct BrandConcept: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var harmony: Harmony
    var colors: [BrandRole: BrandColor]
    var rationale: [String]
    /// "Softer" or "Deeper" for tonal variations of an idea.
    var tone: String?

    /// Short description for idea cards.
    var subtitle: String {
        if harmony == .auto { return name == logoConceptName ? "Original colors" : "From your palette" }
        return [harmony.title, tone].compactMap { $0 }.joined(separator: " · ")
    }

    subscript(role: BrandRole) -> BrandColor { colors[role] ?? BrandColor(hex: "#808080") }
    func hex(_ role: BrandRole) -> String { self[role].hex }
    var ordered: [(role: BrandRole, color: BrandColor)] { BrandRole.allCases.map { ($0, self[$0]) } }
}

let logoConceptName = "Your logo"

struct GuidanceSection: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let symbol: String
    let items: [String]
}

// MARK: - Engine

enum BrandEngine {
    static let lib = Library.shared

    static func familyNouns(_ f: Family) -> [String] {
        switch f {
        case .red: ["Crimson", "Ember", "Poppy", "Cherry"]
        case .orange: ["Citrus", "Apricot", "Marigold", "Copper"]
        case .yellow: ["Sun", "Saffron", "Honey", "Lemon"]
        case .green: ["Grove", "Fern", "Meadow", "Moss"]
        case .teal: ["Lagoon", "Reef", "Jade", "Tide"]
        case .blue: ["Harbor", "Atlas", "Cobalt", "Horizon"]
        case .purple: ["Plum", "Iris", "Velvet", "Dusk"]
        case .pink: ["Bloom", "Petal", "Rosé", "Coral"]
        case .brown: ["Clay", "Cocoa", "Timber", "Umber"]
        case .neutral: ["Stone", "Slate", "Linen", "Graphite"]
        }
    }

    static func familyMeaning(_ f: Family) -> String {
        switch f {
        case .red: "Red raises energy and urgency: appetite, passion, action. Use it where you need attention."
        case .orange: "Orange feels friendly, affordable and energetic, approachable without the alarm of red."
        case .yellow: "Yellow signals optimism and grabs attention, but it needs a dark partner to stay legible."
        case .green: "Green reads as growth, health and sustainability, and as success in interfaces."
        case .teal: "Teal blends the calm of blue with the freshness of green: clinical but human."
        case .blue: "Blue reads as dependable and competent. It lowers perceived risk, which is why so many banks and tech companies use it."
        case .purple: "Purple suggests imagination and wisdom, with a touch of luxury."
        case .pink: "Pink feels caring, playful or romantic depending on saturation. Muted pinks read modern and fashion-forward."
        case .brown: "Brown is grounded, natural and crafted: think coffee, leather and earth."
        case .neutral: "A neutral-led palette feels minimal and premium, and the accent does all the talking."
        }
    }

    static func harmonyNote(_ h: Harmony) -> String {
        switch h {
        case .analogous: "Neighboring hues keep the system cohesive. The accent sits a little further around the wheel for emphasis."
        case .complementary: "The accent sits opposite the primary for maximum pop. Use it sparingly, at about 10% of a layout."
        case .split: "Split-complementary: the secondary and accent flank the primary’s opposite, giving contrast with less tension than a direct complement."
        case .triadic: "Triadic: three evenly spaced hues for a lively, balanced system. Let one dominate."
        case .monochromatic, .tetradic, .auto: "One hue in several values gives a calm, sophisticated system. The accent provides the only real contrast."
        }
    }

    private static func blendHue(_ a: Double, _ b: Double, _ w: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        return a + d * w
    }

    /// Snaps to the nearest Solid Coated Pantone that keeps the contrast requirement.
    private static func snap(_ hex: String, used: inout Set<String>, against bg: String? = nil, minContrast: Double = 0) -> BrandColor {
        for m in lib.nearest(hex, k: 8, in: .coated, excluding: used) {
            if let bg, ColorMath.contrast(m.swatch.hex, bg) < minContrast { continue }
            used.insert(m.swatch.id)
            return BrandColor(hex: m.swatch.hex, sid: m.swatch.id)
        }
        return BrandColor(hex: hex)
    }

    /// Brand palette ideas. The first round follows the industry's typical hues; later ones explore
    /// the rest of the color wheel and add softer and deeper tones, so there's real variety to compare.
    static func suggest(industry: Industry, traits: [Trait], baseHex: String?, snapToPantone: Bool = true, count: Int = 12) -> [BrandConcept] {
        var harmonies: [Harmony] = []
        for h in [traits.first?.harmony ?? .analogous, .analogous, .complementary, .split, .triadic] where !harmonies.contains(h) {
            harmonies.append(h)
        }
        let premium = traits.contains(.premium), minimal = traits.contains(.minimal), rebellious = traits.contains(.rebellious)
        var usedNames = Set<String>()

        return (0..<count).map { i -> BrandConcept in
            let harmony = harmonies[i % harmonies.count]
            let round = i / harmonies.count
            var hue: Double, L: Double, C: Double
            if let baseHex {
                let o = ColorMath.oklch(hex: baseHex)
                (L, C, hue) = (o.x, max(o.y, 0.04), o.z)
            } else {
                // The first four follow the industry's typical hues; the rest step around the wheel by the
                // golden angle so every idea lands on a clearly different color.
                let exploring = i >= industry.hues.count
                let seed = exploring ? industry.hues[0] + Double(i - industry.hues.count + 1) * 137.508 : industry.hues[i]
                hue = seed + Double.random(in: -6...6)
                L = industry.lightness + Double.random(in: -0.03...0.03)
                C = industry.chroma
                for t in traits {
                    L += t.dL
                    C *= t.chromaScale
                    if !exploring, let pull = t.huePull { hue = blendHue(hue, pull.target, pull.weight) }
                }
                L = ColorMath.clamp(L, 0.3, 0.7)
                C = ColorMath.clamp(C, 0.035, 0.24)
            }
            var tone: String?
            if round == 1 { L += 0.07; C *= 0.78; tone = "Softer" }
            if round >= 2 { L -= 0.07; C *= 1.15; tone = "Deeper" }
            L = ColorMath.clamp(L, 0.25, 0.75)
            C = ColorMath.clamp(C, 0.03, 0.26)

            let lightHue = traits.contains(.warm) || industry.warmNeutrals ? 80 : hue
            let light = ColorMath.hex(oklch: 0.975, 0.012, lightHue)
            let dark = ColorMath.hex(oklch: rebellious ? 0.17 : 0.23, 0.028, hue)

            // The primary carries the logo, so it must hold 3:1 against the light neutral.
            var primary = ColorMath.hex(oklch: L, C, hue)
            while ColorMath.contrast(primary, light) < 3.2 && L > 0.2 {
                L -= 0.02
                primary = ColorMath.hex(oklch: L, C, hue)
            }

            let (secOffset, accOffset): (Double, Double) = switch harmony {
            case .analogous: (35, 75)
            case .complementary: (25, 180)
            case .split: (150, 210)
            case .triadic: (120, 240)
            default: (0, 180)
            }
            let secL = L < 0.5 ? min(L + 0.24, 0.82) : max(L - 0.2, 0.3)
            let secondary = ColorMath.hex(oklch: secL, minimal ? C * 0.35 : C * 0.8, hue + secOffset)
            var accHue = hue + accOffset + (rebellious ? Double.random(in: -25...25) : 0)
            var accL = L > 0.6 ? 0.55 : 0.72, accC = ColorMath.clamp(max(C * 1.3, 0.15), 0.12, 0.28)
            if premium { (accHue, accL, accC) = (85, 0.74, 0.12) }
            let accent = ColorMath.hex(oklch: accL, accC, accHue)

            var colors: [BrandRole: BrandColor] = [.light: BrandColor(hex: light), .dark: BrandColor(hex: dark)]
            if snapToPantone {
                var used = Set<String>()
                colors[.primary] = snap(primary, used: &used, against: light, minContrast: 3)
                colors[.secondary] = snap(secondary, used: &used)
                colors[.accent] = snap(accent, used: &used)
            } else {
                colors[.primary] = BrandColor(hex: primary)
                colors[.secondary] = BrandColor(hex: secondary)
                colors[.accent] = BrandColor(hex: accent)
            }

            let family = ColorMath.family(hex: colors[.primary]!.hex)
            let adjectives = traits.map(\.adjective) + ["Signal", "Fresh", "True", "Bright", "Clear", "Soft", "Deep"]
            let candidates = familyNouns(family).flatMap { noun in adjectives.map { "\($0) \(noun)" } }
            let name = candidates.first { !usedNames.contains($0) } ?? "Concept \(i + 1)"
            usedNames.insert(name)

            var concept = BrandConcept(name: name, harmony: harmony, colors: colors, rationale: [], tone: tone)
            concept.rationale = rationale(concept, industry: industry, traits: traits, fromBase: baseHex != nil)
            return concept
        }
    }

    /// Assigns brand roles to an existing palette: lightest, darkest, most colorful…
    static func concept(fromPalette hexes: [String], name: String, industry: Industry, traits: [Trait]) -> BrandConcept {
        var pool = hexes
        let byL = { (h: String) in ColorMath.oklch(hex: h).x }
        let byC = { (h: String) in ColorMath.oklch(hex: h).y }
        var colors: [BrandRole: BrandColor] = [:]

        if let l = pool.max(by: { byL($0) < byL($1) }), byL(l) > 0.86 {
            colors[.light] = BrandColor(hex: l); pool.removeAll { $0 == l }
        }
        if let d = pool.min(by: { byL($0) < byL($1) }), byL(d) < 0.38 {
            colors[.dark] = BrandColor(hex: d); pool.removeAll { $0 == d }
        }
        let vivid = pool.sorted { byC($0) > byC($1) }
        let primaryHex = vivid.first ?? hexes.first ?? "#3355AA"
        colors[.primary] = BrandColor(hex: primaryHex)
        let pHue = ColorMath.oklch(hex: primaryHex).z
        let rest = vivid.dropFirst()
        let hueGap = { (h: String) -> Double in let d = abs(ColorMath.oklch(hex: h).z - pHue).truncatingRemainder(dividingBy: 360); return min(d, 360 - d) }
        if let acc = rest.first(where: { hueGap($0) > 40 }) ?? rest.first {
            colors[.accent] = BrandColor(hex: acc)
            if let sec = rest.first(where: { $0 != acc }) { colors[.secondary] = BrandColor(hex: sec) }
        }
        let o = ColorMath.oklch(hex: primaryHex)
        if colors[.secondary] == nil { colors[.secondary] = BrandColor(hex: ColorMath.hex(oklch: o.x < 0.5 ? o.x + 0.24 : o.x - 0.2, o.y * 0.8, o.z + 30)) }
        if colors[.accent] == nil { colors[.accent] = BrandColor(hex: ColorMath.hex(oklch: 0.7, max(o.y * 1.3, 0.15), o.z + 180)) }
        if colors[.light] == nil { colors[.light] = BrandColor(hex: ColorMath.hex(oklch: 0.975, 0.012, o.z)) }
        if colors[.dark] == nil { colors[.dark] = BrandColor(hex: ColorMath.hex(oklch: 0.23, 0.028, o.z)) }
        for (role, c) in colors {
            if let s = lib.swatches.first(where: { $0.hex == c.hex && $0.coll != "coty" }) { colors[role]?.sid = s.id }
        }
        var concept = BrandConcept(name: name, harmony: .auto, colors: colors, rationale: [])
        concept.rationale = rationale(concept, industry: industry, traits: traits, fromBase: true)
        return concept
    }

    /// Builds a concept around a logo's own colors. The most-used colorful color becomes Primary,
    /// a clearly different hue becomes Accent, and missing roles are derived from Primary.
    static func concept(fromLogo colors: [ExtractedColor], industry: Industry, traits: [Trait]) -> BrandConcept? {
        guard !colors.isEmpty else { return nil }
        let o = { (h: String) in ColorMath.oklch(hex: h) }
        let chromatic = colors.filter { o($0.hex).y > 0.04 }
        let primary = (chromatic.first ?? colors[0]).hex
        let pHue = o(primary).z
        let hueGap = { (h: String) -> Double in let d = abs(o(h).z - pHue).truncatingRemainder(dividingBy: 360); return min(d, 360 - d) }
        // A very dark logo color (often the wordmark) becomes the dark neutral, not the accent.
        let darkest = colors.min { o($0.hex).x < o($1.hex).x }!
        let darkHex = o(darkest.hex).x < 0.35 && darkest.hex != primary ? darkest.hex : nil
        // Accent: the most vivid remaining color with a clearly different hue.
        let others = chromatic.filter { $0.hex != primary && $0.hex != darkHex }.sorted { o($0.hex).y > o($1.hex).y }
        let accent = others.first { hueGap($0.hex) > 40 }?.hex
        let secondary = others.first { $0.hex != accent }?.hex
        let p = o(primary)

        var roles: [BrandRole: BrandColor] = [.primary: BrandColor(hex: primary)]
        roles[.accent] = BrandColor(hex: accent ?? ColorMath.hex(oklch: p.x > 0.6 ? 0.55 : 0.72, max(p.y * 1.3, 0.15), p.z + 180))
        roles[.secondary] = BrandColor(hex: secondary ?? ColorMath.hex(oklch: p.x < 0.5 ? min(p.x + 0.24, 0.82) : max(p.x - 0.2, 0.3), p.y * 0.8, p.z + 30))
        let lightest = colors.max { o($0.hex).x < o($1.hex).x }!
        roles[.dark] = BrandColor(hex: darkHex ?? ColorMath.hex(oklch: 0.23, 0.028, p.z))
        roles[.light] = BrandColor(hex: o(lightest.hex).x > 0.93 ? lightest.hex : ColorMath.hex(oklch: 0.975, 0.012, p.z))
        for (role, c) in roles {
            if let s = lib.swatches.first(where: { $0.hex == c.hex && $0.coll != "coty" }) { roles[role]?.sid = s.id }
        }
        var concept = BrandConcept(name: logoConceptName, harmony: .auto, colors: roles, rationale: [])
        concept.rationale = ["Built from the colors in your logo: Primary is its most-used color" +
                             (accent != nil ? ", and Accent is its most distinct second hue." : ". Accent was added opposite it on the color wheel.")] +
            rationale(concept, industry: industry, traits: traits, fromBase: true)
        return concept
    }

    static func rationale(_ c: BrandConcept, industry: Industry, traits: [Trait], fromBase: Bool) -> [String] {
        let family = ColorMath.family(hex: c.hex(.primary))
        var out = [familyMeaning(family), industry.note]
        if !fromBase, !traits.isEmpty { out.append(traits.map(\.note).joined(separator: " ")) }
        if c.harmony != .auto { out.append(harmonyNote(c.harmony)) }
        let pr = ColorMath.contrast(c.hex(.primary), c.hex(.light))
        let tr = ColorMath.contrast(c.hex(.dark), c.hex(.light))
        out.append(String(format: "Primary on light neutral is %.1f:1 (%@), safe for the logo and large headings. Body text (dark on light) is %.1f:1 (%@).",
                          pr, ColorMath.grade(pr), tr, ColorMath.grade(tr)))
        return out
    }

    // MARK: Helpers for guidance and mockups

    static func pantone(_ c: BrandColor, in lib: MatchLib = .coated) -> Match {
        if lib == .coated, let sid = c.sid, let s = self.lib.byID[sid] { return Match(swatch: s, dE: 0) }
        return self.lib.nearest1(c.hex, in: lib)
    }

    static func pantoneLabel(_ c: BrandColor, in lib: MatchLib = .coated) -> String {
        let m = pantone(c, in: lib)
        return (m.dE < 0.5 ? "" : "≈ ") + m.swatch.title
    }

    /// The candidate with the best contrast on `bg`.
    static func bestText(on bg: String, from candidates: [String]) -> (hex: String, ratio: Double) {
        candidates.map { ($0, ColorMath.contrast($0, bg)) }.max { $0.1 < $1.1 } ?? ("#FFFFFF", 1)
    }

    static func typeSuggestion(_ traits: [Trait]) -> TypeSuggestion {
        traits.first?.type ?? Trait.modern.type
    }

    static func guidance(_ c: BrandConcept, focus: ProjectFocus, traits: [Trait], brandName: String) -> [GuidanceSection] {
        let p = c[.primary], s = c[.secondary], a = c[.accent], d = c[.dark], l = c[.light]
        let pOnL = ColorMath.contrast(p.hex, l.hex), lOnP = ColorMath.contrast(l.hex, p.hex)
        let onPrimary = bestText(on: p.hex, from: [l.hex, d.hex, "#FFFFFF", "#000000"])
        let onAccent = bestText(on: a.hex, from: [d.hex, l.hex, "#FFFFFF", "#000000"])
        let body = ColorMath.contrast(d.hex, l.hex)
        let type = typeSuggestion(traits)
        let r1 = { (v: Double) in String(format: "%.1f:1", v) }
        let name = brandName.isEmpty ? "your brand" : brandName

        var sections: [GuidanceSection] = []
        switch focus {
        case .logo:
            sections.append(GuidanceSection(title: "Logo color rules", symbol: "seal", items: [
                "Design the mark in **one color first** (\(d.hex)). If it works in one color, it will work on a fax, an embroidery or a favicon.",
                "Main version: **Primary \(p.hex)** on **Light \(l.hex)** (\(r1(pOnL))). Reversed: Light on Primary (\(r1(lOnP))).",
                "Keep the logo to **two colors at most**. Use Accent \(a.hex) only for a small detail such as a dot or underline, never for the wordmark.",
                "Check the smallest sizes: a 16 px favicon and a 1 cm print should both stay recognizable.",
            ]))
            sections.append(GuidanceSection(title: "Specify it for production", symbol: "checklist", items: [
                "Print, spot color: **\(pantoneLabel(p))** (coated) / **\(pantoneLabel(p, in: .uncoated))** (uncoated).",
                "Print, process: CMYK ≈ \(ColorMath.cmyk(ColorMath.rgb(p.hex)).map(String.init).joined(separator: " / ")). Ask your printer for a proof.",
                "Screen: HEX \(p.hex), RGB \(ColorMath.rgb(p.hex).ints.map(String.init).joined(separator: ", ")).",
                "Deliver the logo files as SVG + PDF (vector) and PNG on transparent backgrounds, in full color, one-color dark and one-color white.",
            ]))
        case .identity:
            sections.append(GuidanceSection(title: "Build the system", symbol: "square.stack.3d.up", items: [
                "Use roughly **60-30-10**: 60% light neutral and white space, 30% Primary and Secondary, 10% Accent. Use dark neutral for text.",
                "Headlines in **\(type.headline)** with body text in **\(type.body)**: \(type.why). Both are free on Google Fonts.",
                "Give each color a job (see Specs). Consistent roles make \(name) recognizable before anyone reads the name.",
                "Photography: pick images with a natural hint of Primary or Secondary, or apply a subtle color grade toward them.",
            ]))
            sections.append(GuidanceSection(title: "Avoid", symbol: "exclamationmark.triangle", items: [
                "Accent as a background for long text. It’s for emphasis, and it gets tiring at scale.",
                "Introducing new colors per campaign. Use the tint ramps in Specs for variety.",
                "Primary text on Secondary unless the contrast table says it passes.",
            ]))
        case .digital:
            sections.append(GuidanceSection(title: "UI tokens", symbol: "macwindow", items: [
                "Primary button: **\(p.hex)** fill with **\(onPrimary.hex)** label (\(r1(onPrimary.ratio)), \(ColorMath.grade(onPrimary.ratio))). Hover: one step darker on the ramp. Pressed: two steps.",
                "Body text: Dark \(d.hex) on Light \(l.hex) is \(r1(body)) (\(ColorMath.grade(body))).",
                "Links: \(pOnL >= 4.5 ? "Primary works for links (\(r1(pOnL)))" : "use the 700 step of the Primary ramp for links, because Primary is only \(r1(pOnL)) on light"). Always add an underline or other non-color cue.",
                "Focus ring: Accent \(a.hex), 2 px plus a 2 px offset. Error, warning and success colors stay separate from brand colors.",
                "Dark mode: Dark neutral becomes the background. Lift Primary one or two ramp steps lighter so it keeps contrast.",
            ]))
        case .packaging:
            sections.append(GuidanceSection(title: "On the shelf", symbol: "shippingbox", items: [
                "Print Primary and Accent as **Pantone spot colors** so every batch matches. Use CMYK for photography.",
                "Uncoated stock (kraft, matte labels) prints lighter and duller. **\(pantoneLabel(p, in: .uncoated))** is the uncoated equivalent of Primary.",
                "Use a large block of Primary for shelf recognition and the Accent for one callout, such as a flavor, a “new” badge or a seal.",
                "Check your category: if competitors all use the same hue, lean on the Secondary or Accent to stand apart.",
            ]))
        case .social:
            sections.append(GuidanceSection(title: "Templates that stop the scroll", symbol: "square.and.arrow.up.on.square", items: [
                "Quote or tip: Primary background, **\(onPrimary.hex)** text (\(r1(onPrimary.ratio))).",
                "Announcement: Accent background, **\(onAccent.hex)** text (\(r1(onAccent.ratio))). Keep it to one per week so it stays special.",
                "Photo posts: a Dark neutral overlay at 60–70% keeps white headlines readable on any image.",
                "Keep the logo in the same corner on every post. Consistency beats variety in a grid.",
            ]))
        case .print:
            sections.append(GuidanceSection(title: "Print specs", symbol: "printer", items: [
                "Spot: Primary **\(pantoneLabel(p))**, Secondary **\(pantoneLabel(s))**, Accent **\(pantoneLabel(a))**.",
                "Uncoated paper: Primary **\(pantoneLabel(p, in: .uncoated))**. Expect lighter, softer color, and approve it on the real stock.",
                "Large dark areas: rich black (C60 M40 Y40 K100). Small text: 100% K only, to avoid misregistration.",
                "Keep body text at least 9 pt, and don’t print text in Accent on Light. Check the contrast table first.",
            ]))
        }
        sections.append(GuidanceSection(title: "Why these colors", symbol: "lightbulb", items: c.rationale))
        return sections
    }
}
