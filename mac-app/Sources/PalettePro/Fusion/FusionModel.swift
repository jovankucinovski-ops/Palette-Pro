import Observation
import SwiftUI

/// Fusion settings and saved styles as stored in library.json. Missing values fall back to defaults.
struct FusionSettings: Codable, Hashable {
    var style: FusionStyle?
    var locks: [FusionSlot] = []
    var mood: PairMood = .any
    var tone: FusionTone = .any
    var layout: FusionLayout = .website
    var snapAccent = false
    var saved: [FusionStyle] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decode(T.self, forKey: key)) ?? fallback }
        style = (try? c.decode(FusionStyle.self, forKey: .style)).flatMap { $0.heading != nil && $0.body != nil ? $0 : nil }
        locks = value(.locks, locks)
        mood = value(.mood, mood)
        tone = value(.tone, tone)
        layout = value(.layout, layout)
        snapAccent = value(.snapAccent, snapAccent)
        saved = value(.saved, saved).filter { $0.heading != nil && $0.body != nil }
    }
}

@Observable @MainActor
final class FusionModel {
    var style: FusionStyle?
    var locks: Set<FusionSlot> = []
    var mood: PairMood = .any
    var tone: FusionTone = .any
    var layout: FusionLayout = .website
    var snapAccent = false
    var saved: [FusionStyle] = []

    @ObservationIgnored weak var undoManager: UndoManager?

    /// New colors and fonts; locked slots stay.
    func generate() {
        let next = FusionEngine.generate(from: style, locks: locks, mood: mood, tone: tone, snapAccent: snapAccent)
        set(next, action: "Generate")
    }

    /// Replaces the style, with undo.
    func set(_ next: FusionStyle, action: String) {
        let previous = style
        style = next
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                if let previous { target.set(previous, action: action) }
            }
        }
        undoManager?.setActionName(action)
    }

    func toggle(_ slot: FusionSlot) {
        if locks.contains(slot) { locks.remove(slot) } else { locks.insert(slot) }
    }

    /// A manual color change: it's locked so the next Generate keeps it.
    func setColor(_ role: FusionRole, _ hex: String) {
        guard var s = style else { return }
        s.colors[role] = hex
        s = FusionEngine.derive(s)
        set(s, action: "Change \(role.title)")
        switch role {
        case .background: locks.insert(.background)
        case .text: locks.insert(.text)
        case .accent: locks.insert(.accent)
        default: break
        }
    }

    func setFont(heading: Bool, _ id: String) {
        guard var s = style, let f = FontCatalog.shared.family(id: id) else { return }
        if heading {
            s.headingID = id
            s.headingWeight = PairingEngine.weight(forHeading: f, mood: mood)
            locks.insert(.heading)
        } else {
            s.bodyID = id
            s.bodyWeight = f.regular
            locks.insert(.body)
        }
        set(s, action: heading ? "Change Heading Font" : "Change Body Font")
    }

    func save() {
        guard var s = style else { return }
        guard !saved.contains(where: { $0.colors == s.colors && $0.headingID == s.headingID && $0.bodyID == s.bodyID }) else { return }
        s.id = UUID()
        saved.insert(s, at: 0)
    }

    var isSaved: Bool {
        guard let s = style else { return false }
        return saved.contains { $0.colors == s.colors && $0.headingID == s.headingID && $0.bodyID == s.bodyID }
    }

    var settings: FusionSettings {
        var s = FusionSettings()
        s.style = style; s.locks = locks.sorted { $0.rawValue < $1.rawValue }; s.mood = mood; s.tone = tone
        s.layout = layout; s.snapAccent = snapAccent; s.saved = saved
        return s
    }

    func restore(_ s: FusionSettings) {
        style = s.style; locks = Set(s.locks); mood = s.mood; tone = s.tone
        layout = s.layout; snapAccent = s.snapAccent; saved = s.saved
    }

    /// The six colors as a palette, named by role.
    func paletteColors(_ s: FusionStyle) -> [PaletteColor] {
        FusionRole.allCases.map { r in
            let m = Library.shared.nearest1(s[r], in: .coated)
            return PaletteColor(hex: s[r], sid: m.dE < 0.5 ? m.swatch.id : nil)
        }
    }

    /// CSS custom properties for the colors and fonts.
    func css(_ s: FusionStyle) -> String {
        guard let h = s.heading, let b = s.body else { return "" }
        var lines = ["/* \(s.name), made with Palette Pro */"]
        lines += [h.cssEmbed(weights: [s.headingWeight]), h == b ? nil : b.cssEmbed(weights: [s.bodyWeight, b.nearest(700)])]
            .compactMap { $0 }.map { "/* \($0) */" }
        lines.append(":root {")
        for r in FusionRole.allCases { lines.append("  --color-\(Exporter.slug(r.title)): \(s[r]);") }
        lines.append("  --font-heading: \(h.cssStack);")
        lines.append("  --font-body: \(b.cssStack);")
        lines.append("}")
        lines.append("body { background: var(--color-background); color: var(--color-text); font-family: var(--font-body); font-weight: \(s.bodyWeight); }")
        lines.append("h1, h2, h3 { font-family: var(--font-heading); font-weight: \(s.headingWeight); }")
        lines.append(".button { background: var(--color-accent); color: var(--color-on-accent); }")
        return lines.joined(separator: "\n") + "\n"
    }
}
