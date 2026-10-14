import Foundation

/// The color jobs in a style: a page, its text, and one accent.
enum FusionRole: String, CaseIterable, Identifiable, Codable {
    case background, surface, text, muted, accent, onAccent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .background: "Background"
        case .surface: "Surface"
        case .text: "Text"
        case .muted: "Secondary text"
        case .accent: "Accent"
        case .onAccent: "On accent"
        }
    }
    var usage: String {
        switch self {
        case .background: "Page background"
        case .surface: "Cards, panels and fields"
        case .text: "Headlines and body text"
        case .muted: "Captions, metadata and hints"
        case .accent: "Buttons, links and highlights"
        case .onAccent: "Text on accent buttons"
        }
    }
}

/// What can be locked so Generate keeps it. Surface, secondary text and on-accent follow the others.
enum FusionSlot: String, CaseIterable, Identifiable, Codable {
    case background, text, accent, heading, body
    var id: String { rawValue }
}

/// Light, dark or colored pages.
enum FusionTone: String, CaseIterable, Identifiable, Codable {
    case any, light, dark, color
    var id: String { rawValue }
    var title: String {
        switch self {
        case .any: "Any"
        case .light: "Light"
        case .dark: "Dark"
        case .color: "Colored"
        }
    }
}

enum FusionLayout: String, CaseIterable, Identifiable, Codable {
    case website, poster, app
    var id: String { rawValue }
    var title: String {
        switch self {
        case .website: "Website"
        case .poster: "Poster"
        case .app: "App"
        }
    }
    var symbol: String {
        switch self {
        case .website: "macwindow"
        case .poster: "doc.richtext"
        case .app: "iphone"
        }
    }
}

/// A complete look: six colors and a font pairing.
struct FusionStyle: Identifiable, Hashable, Codable {
    var id = UUID()
    var colors: [FusionRole: String]
    var headingID: String
    var headingWeight: Int
    var bodyID: String
    var bodyWeight: Int

    subscript(_ r: FusionRole) -> String { colors[r] ?? "#888888" }
    var heading: FontFamily? { FontCatalog.shared.family(id: headingID) }
    var body: FontFamily? { FontCatalog.shared.family(id: bodyID) }
    var isDark: Bool { ColorMath.oklch(hex: self[.background]).x < 0.55 }

    /// "Classic Blue · Fraunces": the accent's nearest Pantone name and the headline font.
    var name: String {
        let accent = Library.shared.nearest1(self[.accent], in: .tcx).swatch.name
        return [accent.isEmpty ? nil : accent, heading?.family].compactMap { $0 }.joined(separator: " · ")
    }

    var fontsSubtitle: String { [heading?.family, body?.family].compactMap { $0 }.uniqued().joined(separator: " + ") }

    func contrast(_ a: FusionRole, on b: FusionRole) -> Double { ColorMath.contrast(self[a], self[b]) }
}

enum FusionEngine {
    private typealias Range = (L: ClosedRange<Double>, C: ClosedRange<Double>)

    /// Accent lightness and chroma by mood.
    private static func accentRange(_ mood: PairMood) -> Range {
        switch mood {
        case .editorial: (0.45...0.60, 0.08...0.14)
        case .modern: (0.55...0.68, 0.12...0.20)
        case .elegant: (0.40...0.62, 0.04...0.10)
        case .friendly: (0.62...0.75, 0.12...0.18)
        case .corporate: (0.40...0.55, 0.08...0.15)
        case .bold: (0.55...0.70, 0.16...0.24)
        case .any: (0.45...0.70, 0.08...0.20)
        }
    }

    /// A new style. Locked slots come from `current`; everything else is generated around them.
    static func generate(from current: FusionStyle?, locks: Set<FusionSlot>, mood: PairMood, tone: FusionTone,
                         snapAccent: Bool) -> FusionStyle {
        func locked(_ s: FusionSlot) -> Bool { current != nil && locks.contains(s) }
        let o = { (hex: String) in ColorMath.oklch(hex: hex) }

        // Accent first: it sets the hue family.
        var accent: String
        if locked(.accent), let c = current {
            accent = c[.accent]
        } else {
            let r = accentRange(mood)
            var hue = Double.random(in: 0..<360)
            if mood == .corporate && Bool.random() { hue = Double.random(in: 225...265) }
            accent = ColorMath.hex(oklch: Double.random(in: r.L), Double.random(in: r.C), hue)
        }
        let aHue = o(accent).z

        // Which kind of page.
        var kind = tone
        if locked(.background), let c = current {
            let bg = o(c[.background])
            kind = bg.x < 0.55 ? (bg.y > 0.05 ? .color : .dark) : .light
        } else if kind == .any {
            let colored = mood == .bold || mood == .friendly || mood == .modern || mood == .any ? 0.18 : 0.06
            let r = Double.random(in: 0..<1)
            kind = r < colored ? .color : r < colored + 0.32 ? .dark : .light
            // A locked accent has to stay visible: bright accents need a dark page, deep ones a light page.
            if locked(.accent) {
                let L = o(accent).x
                if L > 0.72 && kind == .light { kind = Bool.random() ? .dark : .color }
                if L < 0.42 && kind != .light { kind = .light }
            }
        }

        var background: String
        if locked(.background), let c = current {
            background = c[.background]
        } else {
            switch kind {
            case .dark:
                background = ColorMath.hex(oklch: Double.random(in: 0.14...0.22), Double.random(in: 0.008...0.03), aHue + Double.random(in: -30...30))
            case .color:
                // Deep, saturated pages; the accent stays bright against them.
                background = ColorMath.hex(oklch: Double.random(in: 0.24...0.38), Double.random(in: 0.06...0.12),
                                           aHue + (Bool.random() ? 0 : Double.random(in: 150...210)))
            default:
                let paper = Double.random(in: 0..<1) < 0.4
                background = ColorMath.hex(oklch: Double.random(in: 0.955...0.99), Double.random(in: 0.004...0.02),
                                           paper ? 85 : aHue + Double.random(in: -40...40))
            }
        }
        let bg = o(background)
        let darkPage = bg.x < 0.55

        var text: String
        if locked(.text), let c = current {
            text = c[.text]
        } else {
            text = darkPage
                ? ColorMath.hex(oklch: Double.random(in: 0.93...0.97), Double.random(in: 0.005...0.02), bg.z)
                : ColorMath.hex(oklch: Double.random(in: 0.16...0.24), Double.random(in: 0.01...0.03), bg.z)
            text = push(text, from: background, toContrast: 7)
        }

        if !locked(.accent) {
            if kind == .color {
                // Bright accent on a deep page.
                accent = ColorMath.hex(oklch: Double.random(in: 0.78...0.88), max(0.10, o(accent).y), aHue)
            }
            accent = push(accent, from: background, toContrast: 3)
            // Buttons need readable labels: white on a deeper accent for light pages, dark on a brighter one otherwise.
            let ink = darkPage ? ColorMath.hex(oklch: 0.18, 0.02, aHue) : ColorMath.hex(oklch: 0.985, 0.008, aHue)
            accent = push(accent, from: ink, toContrast: 4.6)
            if snapAccent, let m = Library.shared.nearest(accent, in: .coated).first,
               ColorMath.contrast(m.swatch.hex, background) >= 3,
               max(ColorMath.contrast(m.swatch.hex, "#FFFFFF"), ColorMath.contrast(m.swatch.hex, "#151517")) >= 4.5 {
                accent = m.swatch.hex
            }
        }

        let surface = ColorMath.hex(oklch: bg.x + (darkPage ? 0.05 : (bg.x > 0.975 ? -0.03 : 0.02)), bg.y, bg.z)
        let t = o(text)
        var muted = ColorMath.hex(oklch: t.x + (bg.x - t.x) * 0.38, t.y, t.z)
        muted = push(muted, from: background, toContrast: 4.5)
        let onAccent = ColorMath.contrast("#FFFFFF", accent) >= ColorMath.contrast("#151517", accent)
            ? ColorMath.hex(oklch: 0.985, 0.008, aHue) : ColorMath.hex(oklch: 0.18, 0.02, aHue)

        // Fonts
        var heading = locked(.heading) ? current?.heading : nil
        var headingWeight = current?.headingWeight ?? 700
        var body = locked(.body) ? current?.body : nil
        var bodyWeight = current?.bodyWeight ?? 400
        switch (heading, body) {
        case (nil, nil):
            if let p = PairingEngine.suggest(heading: nil, mood: mood).randomElement(), let h = p.heading, let b = p.body {
                heading = h; headingWeight = p.headingWeight; body = b; bodyWeight = p.bodyWeight
            }
        case (let h?, nil):
            if let p = PairingEngine.suggest(heading: h, mood: mood).prefix(6).randomElement(), let b = p.body {
                body = b; bodyWeight = p.bodyWeight
            }
        case (nil, let b?):
            if let h = PairingEngine.headline(for: mood, excluding: [b.id]) {
                heading = h; headingWeight = PairingEngine.weight(forHeading: h, mood: mood)
            }
        default:
            break
        }
        let inter = FontCatalog.shared.named("Inter")
        let h = heading ?? inter ?? FontCatalog.shared.online[0]
        let b = body ?? inter ?? FontCatalog.shared.online[0]

        return FusionStyle(colors: [.background: background, .surface: surface, .text: text, .muted: muted, .accent: accent, .onAccent: onAccent],
                           headingID: h.id, headingWeight: h.nearest(headingWeight), bodyID: b.id, bodyWeight: b.nearest(bodyWeight))
    }

    /// Recomputes the colors that follow others (surface, secondary text, on accent) after a manual edit.
    static func derive(_ s: FusionStyle) -> FusionStyle {
        var s = s
        let bg = ColorMath.oklch(hex: s[.background]), dark = bg.x < 0.55
        s.colors[.surface] = ColorMath.hex(oklch: bg.x + (dark ? 0.05 : (bg.x > 0.975 ? -0.03 : 0.02)), bg.y, bg.z)
        let t = ColorMath.oklch(hex: s[.text])
        s.colors[.muted] = push(ColorMath.hex(oklch: t.x + (bg.x - t.x) * 0.38, t.y, t.z), from: s[.background], toContrast: 4.5)
        let aHue = ColorMath.oklch(hex: s[.accent]).z
        s.colors[.onAccent] = ColorMath.contrast("#FFFFFF", s[.accent]) >= ColorMath.contrast("#151517", s[.accent])
            ? ColorMath.hex(oklch: 0.985, 0.008, aHue) : ColorMath.hex(oklch: 0.18, 0.02, aHue)
        return s
    }

    /// Moves `hex` away from `background` in lightness until it reaches the contrast ratio (WCAG).
    static func push(_ hex: String, from background: String, toContrast target: Double) -> String {
        var c = ColorMath.oklch(hex: hex)
        let goDarker = ColorMath.oklch(hex: background).x >= 0.55
        var out = hex
        for _ in 0..<40 where ColorMath.contrast(out, background) < target {
            c.x = ColorMath.clamp(c.x + (goDarker ? -0.02 : 0.02), 0.02, 0.99)
            out = ColorMath.hex(oklch: c.x, c.y, c.z)
            if c.x <= 0.02 || c.x >= 0.99 { break }
        }
        return out
    }

    // MARK: Advice

    static func checks(_ s: FusionStyle) -> [(label: String, ratio: Double, needed: Double)] {
        [("Text on background", s.contrast(.text, on: .background), 4.5),
         ("Secondary text on background", s.contrast(.muted, on: .background), 4.5),
         ("Accent on background", s.contrast(.accent, on: .background), 3),
         ("Button text on accent", s.contrast(.onAccent, on: .accent), 4.5)]
    }
}
