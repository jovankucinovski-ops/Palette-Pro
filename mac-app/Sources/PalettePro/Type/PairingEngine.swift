import Foundation

/// The feel a pairing should have.
enum PairMood: String, CaseIterable, Identifiable, Codable {
    case any, editorial, modern, elegant, friendly, corporate, bold
    var id: String { rawValue }
    var title: String {
        switch self {
        case .any: "Any"
        case .editorial: "Editorial"
        case .modern: "Modern & tech"
        case .elegant: "Elegant"
        case .friendly: "Friendly"
        case .corporate: "Corporate"
        case .bold: "Bold"
        }
    }
}

/// How a text face is built; pairing contrast depends on it.
private enum TextKind: String {
    case grotesque, geometric, humanist, transitional, oldstyle, slab, mono

    var description: String {
        switch self {
        case .grotesque: "neutral grotesque"
        case .geometric: "geometric sans"
        case .humanist: "humanist sans"
        case .transitional: "crisp text serif"
        case .oldstyle: "classic book serif"
        case .slab: "slab serif"
        case .mono: "monospace"
        }
    }
    var isSerif: Bool { self == .transitional || self == .oldstyle || self == .slab }
}

/// Proven text faces for body copy, with their construction and feel.
private struct TextFace {
    let family: String
    let kind: TextKind
    let moods: Set<PairMood>
}

private let textFaces: [TextFace] = [
    .init(family: "Inter", kind: .grotesque, moods: [.modern, .corporate]),
    .init(family: "Satoshi", kind: .geometric, moods: [.modern, .friendly]),
    .init(family: "General Sans", kind: .grotesque, moods: [.modern, .bold]),
    .init(family: "Switzer", kind: .grotesque, moods: [.modern, .corporate, .editorial]),
    .init(family: "Geist Sans", kind: .grotesque, moods: [.modern]),
    .init(family: "Hanken Grotesk", kind: .grotesque, moods: [.modern, .editorial]),
    .init(family: "Instrument Sans", kind: .grotesque, moods: [.modern, .elegant]),
    .init(family: "Schibsted Grotesk", kind: .grotesque, moods: [.editorial, .modern]),
    .init(family: "Public Sans", kind: .grotesque, moods: [.corporate]),
    .init(family: "IBM Plex Sans", kind: .grotesque, moods: [.corporate, .modern]),
    .init(family: "Work Sans", kind: .grotesque, moods: [.modern, .editorial]),
    .init(family: "Libre Franklin", kind: .grotesque, moods: [.editorial, .corporate]),
    .init(family: "Archivo", kind: .grotesque, moods: [.bold, .modern]),
    .init(family: "Onest", kind: .grotesque, moods: [.modern, .friendly]),
    .init(family: "Manrope", kind: .geometric, moods: [.modern, .corporate]),
    .init(family: "DM Sans", kind: .geometric, moods: [.friendly, .modern]),
    .init(family: "Plus Jakarta Sans", kind: .geometric, moods: [.modern, .friendly]),
    .init(family: "Outfit", kind: .geometric, moods: [.friendly, .bold]),
    .init(family: "Figtree", kind: .geometric, moods: [.friendly]),
    .init(family: "Poppins", kind: .geometric, moods: [.friendly, .bold]),
    .init(family: "Montserrat", kind: .geometric, moods: [.bold, .corporate]),
    .init(family: "Albert Sans", kind: .geometric, moods: [.modern, .elegant]),
    .init(family: "Source Sans 3", kind: .humanist, moods: [.corporate, .editorial]),
    .init(family: "Lato", kind: .humanist, moods: [.corporate, .friendly]),
    .init(family: "Open Sans", kind: .humanist, moods: [.corporate, .friendly]),
    .init(family: "Fira Sans", kind: .humanist, moods: [.modern, .editorial]),
    .init(family: "Nunito Sans", kind: .humanist, moods: [.friendly]),
    .init(family: "Karla", kind: .humanist, moods: [.friendly, .editorial]),
    .init(family: "Mulish", kind: .humanist, moods: [.elegant, .friendly]),
    .init(family: "Source Serif 4", kind: .transitional, moods: [.editorial, .corporate]),
    .init(family: "Literata", kind: .transitional, moods: [.editorial]),
    .init(family: "Newsreader", kind: .transitional, moods: [.editorial, .elegant]),
    .init(family: "Merriweather", kind: .transitional, moods: [.editorial, .corporate]),
    .init(family: "PT Serif", kind: .transitional, moods: [.corporate, .editorial]),
    .init(family: "IBM Plex Serif", kind: .transitional, moods: [.corporate, .modern]),
    .init(family: "Gelasio", kind: .transitional, moods: [.editorial]),
    .init(family: "Zodiak", kind: .transitional, moods: [.elegant, .modern]),
    .init(family: "Sentient", kind: .transitional, moods: [.editorial, .modern]),
    .init(family: "Erode", kind: .transitional, moods: [.editorial, .friendly]),
    .init(family: "Lora", kind: .oldstyle, moods: [.editorial, .friendly]),
    .init(family: "Crimson Pro", kind: .oldstyle, moods: [.elegant, .editorial]),
    .init(family: "EB Garamond", kind: .oldstyle, moods: [.elegant]),
    .init(family: "Libre Baskerville", kind: .oldstyle, moods: [.elegant, .editorial]),
    .init(family: "Gambetta", kind: .oldstyle, moods: [.elegant, .editorial]),
    .init(family: "Alegreya", kind: .oldstyle, moods: [.editorial, .friendly]),
    .init(family: "Cardo", kind: .oldstyle, moods: [.elegant]),
    .init(family: "Roboto Slab", kind: .slab, moods: [.bold, .corporate]),
    .init(family: "Zilla Slab", kind: .slab, moods: [.editorial, .bold]),
    .init(family: "IBM Plex Mono", kind: .mono, moods: [.modern, .corporate]),
    .init(family: "JetBrains Mono", kind: .mono, moods: [.modern]),
    .init(family: "Space Mono", kind: .mono, moods: [.modern, .bold]),
    .init(family: "DM Mono", kind: .mono, moods: [.modern, .friendly]),
]

/// Striking headline faces used when exploring without a chosen heading font.
private let headlineFaces: [(String, Set<PairMood>)] = [
    ("Playfair Display", [.editorial, .elegant]), ("Fraunces", [.editorial, .friendly]), ("DM Serif Display", [.elegant, .editorial]),
    ("Instrument Serif", [.elegant, .modern]), ("Gloock", [.elegant, .bold]), ("Bodoni Moda", [.elegant]),
    ("Cormorant Garamond", [.elegant]), ("Young Serif", [.friendly, .editorial]), ("Zodiak", [.elegant, .editorial]),
    ("Boska", [.elegant, .editorial]), ("Gambetta", [.editorial]), ("Erode", [.editorial, .friendly]),
    ("Clash Display", [.bold, .modern]), ("Cabinet Grotesk", [.bold, .modern]), ("Satoshi", [.modern, .friendly]),
    ("General Sans", [.modern]), ("Space Grotesk", [.modern]), ("Syne", [.bold, .modern]), ("Unbounded", [.bold, .modern]),
    ("Bricolage Grotesque", [.friendly, .bold]), ("Sora", [.modern, .friendly]), ("Chillax", [.friendly, .modern]),
    ("Archivo", [.bold, .corporate]), ("Anton", [.bold]), ("Bebas Neue", [.bold]), ("Oswald", [.bold, .corporate]),
    ("Montserrat", [.corporate, .bold]), ("Manrope", [.corporate, .modern]), ("IBM Plex Sans", [.corporate]),
    ("Libre Baskerville", [.editorial, .corporate]), ("Merriweather", [.corporate, .editorial]), ("Panchang", [.bold]),
]

struct FontPairing: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var headingID: String
    var headingWeight: Int
    var bodyID: String
    var bodyWeight: Int
    /// Labels, captions and small UI text.
    var accentID: String
    var accentWeight: Int
    var accentUppercase: Bool
    var rationale: String

    var heading: FontFamily? { FontCatalog.shared.family(id: headingID) }
    var body: FontFamily? { FontCatalog.shared.family(id: bodyID) }
    var accent: FontFamily? { FontCatalog.shared.family(id: accentID) }
    var subtitle: String { [heading?.family, body?.family].compactMap { $0 }.uniqued().joined(separator: " + ") }
}

enum PairingEngine {
    private static var catalog: FontCatalog { .shared }

    /// Twelve pairings. With a heading font, it stays fixed and the body text varies;
    /// without one, each idea starts from a different well-loved headline face.
    static func suggest(heading: FontFamily?, mood: PairMood, count: Int = 12) -> [FontPairing] {
        heading.map { fixedHeading($0, mood: mood, count: count) } ?? explore(mood: mood, count: count)
    }

    private static func available() -> [(TextFace, FontFamily)] {
        textFaces.compactMap { t in catalog.named(t.family).map { (t, $0) } }
    }

    private static func fixedHeading(_ h: FontFamily, mood: PairMood, count: Int) -> [FontPairing] {
        var scored = available().filter { $0.1.id != h.id }.map { t, f -> (TextFace, FontFamily, Double) in
            (t, f, score(heading: h, body: t, family: f, mood: mood))
        }
        scored.sort { $0.2 > $1.2 }

        var result: [FontPairing] = []
        // A single family works when the heading font is also a good text face.
        let headlineOnly = ["display", "poster", "headline", "title"].contains { h.family.lowercased().contains($0) }
        if [.sans, .serif].contains(h.category), !headlineOnly, h.weights.count >= 4, h.weights.contains(400) {
            result.append(make("One family", h, h.heading, h, mood: mood, rationale:
                "\(h.family) on its own: bold for headlines, regular for reading. One family keeps everything consistent and loads fast."))
        }
        var serifs = 0, sans = 0, monos = 0
        for (t, f, _) in scored where result.count < count {
            if t.kind == .mono { if monos >= 1 { continue }; monos += 1 }
            else if t.kind.isSerif { if serifs >= 6 { continue }; serifs += 1 }
            else { if sans >= 7 { continue }; sans += 1 }
            let accent = t.kind == .mono ? f : (mood == .modern && result.count % 4 == 3 ? monoAccent() : nil)
            result.append(make(title(h, t), h, headingWeight(h, mood), f, mood: mood, accent: accent, rationale: rationale(h, t)))
        }
        return Array(result.prefix(count))
    }

    private static func explore(mood: PairMood, count: Int) -> [FontPairing] {
        var heads = headlineFaces.filter { mood == .any || $0.1.contains(mood) }.compactMap { catalog.named($0.0) }.shuffled()
        if heads.count < count {
            heads += headlineFaces.compactMap { catalog.named($0.0) }.filter { !heads.contains($0) }.shuffled()
        }
        var used = Set<String>()
        return heads.prefix(count).compactMap { h in
            let options = available().filter { $0.1.id != h.id && !used.contains($0.1.id) }
                .map { ($0.0, $0.1, score(heading: h, body: $0.0, family: $0.1, mood: mood)) }
                .sorted { $0.2 > $1.2 }
            guard let (t, f, _) = options.prefix(3).randomElement() else { return nil }
            used.insert(f.id)
            return make(title(h, t), h, headingWeight(h, mood), f, mood: mood, rationale: rationale(h, t))
        }
    }

    private static func score(heading h: FontFamily, body t: TextFace, family f: FontFamily, mood: PairMood) -> Double {
        var s = 0.0
        switch h.category {
        case .serif, .slab: s += t.kind.isSerif ? (mood == .editorial || mood == .elegant ? 1.5 : 0.5) : 3
        case .sans: s += t.kind.isSerif ? 2.5 : (t.kind == .humanist || t.kind == .grotesque ? 1.5 : 1)
        case .display: s += t.kind.isSerif ? 2 : 3
        case .script: s += 2.5
        case .mono: s += t.kind.isSerif ? 1.5 : 3
        }
        if t.kind == .mono { s -= 1.5 }
        if mood != .any && t.moods.contains(mood) { s += 2 }
        if f.rank < 60 { s += 0.6 } else if f.rank < 200 { s += 0.3 }
        return s + Double.random(in: 0...1.2)
    }

    private static func headingWeight(_ h: FontFamily, _ mood: PairMood) -> Int {
        if h.category == .display || h.category == .script || h.weights.count <= 2 { return h.regular }
        // Elegant serif headlines look best light or regular; everything else bolder.
        if mood == .elegant && (h.category == .serif) { return h.nearest(400) }
        return h.category == .serif ? h.nearest(600) : h.heading
    }

    private static func monoAccent() -> FontFamily? {
        ["IBM Plex Mono", "JetBrains Mono", "DM Mono", "Space Mono"].compactMap { catalog.named($0) }.randomElement()
    }

    private static func make(_ title: String, _ h: FontFamily, _ hw: Int, _ b: FontFamily, mood: PairMood,
                             accent: FontFamily? = nil, rationale: String) -> FontPairing {
        let a = accent ?? b
        return FontPairing(title: title, headingID: h.id, headingWeight: hw, bodyID: b.id, bodyWeight: b.regular,
                           accentID: a.id, accentWeight: a.category == .mono ? a.regular : a.nearest(600),
                           accentUppercase: a.category != .mono, rationale: rationale)
    }

    private static func title(_ h: FontFamily, _ t: TextFace) -> String {
        switch (h.category, t.kind.isSerif) {
        case (.serif, false), (.slab, false): "Classic contrast"
        case (.sans, true): "Reverse contrast"
        case (.display, _): "Statement + text"
        case (.script, _): "Script accent"
        case (.serif, true), (.slab, true): "Serif harmony"
        default: t.kind == .mono ? "Technical" : "Clean and modern"
        }
    }

    private static func rationale(_ h: FontFamily, _ t: TextFace) -> String {
        let head = "\(h.family) (\(h.category.title.lowercased()))"
        switch (h.category, t.kind.isSerif) {
        case (.serif, false), (.slab, false):
            return "\(head) headlines over \(t.family), a \(t.kind.description). Serif against sans is the most reliable contrast: the headline has character, the text stays easy to read."
        case (.sans, true):
            return "\(head) headlines with \(t.family), a \(t.kind.description), for long reading. The serif adds warmth and rhythm to paragraphs."
        case (.display, _):
            return "\(head) is made for big sizes only. \(t.family), a \(t.kind.description), carries the text quietly so the headline can shout."
        case (.script, _):
            return "\(head) works as an accent for short headings. Keep everything else in \(t.family), a \(t.kind.description)."
        case (.mono, _):
            return "\(head) gives a technical, coded feel. \(t.family), a \(t.kind.description), keeps longer text comfortable."
        case (.serif, true), (.slab, true):
            return "Two serifs: \(head) for headlines, \(t.family) for text. It works because they differ clearly in weight and contrast, which suits books and magazines."
        default:
            return "\(head) with \(t.family), a \(t.kind.description). Two sans serifs pair well when one leads and the other stays neutral."
        }
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
