import Foundation

/// Musical-interval ratios used for modular type scales.
enum ScaleRatio: Double, CaseIterable, Identifiable, Codable {
    case minorSecond = 1.067, majorSecond = 1.125, minorThird = 1.2, majorThird = 1.25
    case perfectFourth = 1.333, augmentedFourth = 1.414, perfectFifth = 1.5, golden = 1.618
    var id: Double { rawValue }
    var title: String {
        let name = switch self {
        case .minorSecond: "Minor second"
        case .majorSecond: "Major second"
        case .minorThird: "Minor third"
        case .majorThird: "Major third"
        case .perfectFourth: "Perfect fourth"
        case .augmentedFourth: "Augmented fourth"
        case .perfectFifth: "Perfect fifth"
        case .golden: "Golden ratio"
        }
        return "\(name) · \(String(format: "%.3g", rawValue))"
    }
    var advice: String {
        switch self {
        case .minorSecond, .majorSecond: "Subtle steps. Good for dense apps and dashboards."
        case .minorThird, .majorThird: "Balanced. A safe choice for most websites and apps."
        case .perfectFourth, .augmentedFourth: "Clear hierarchy. Good for marketing pages and editorial."
        case .perfectFifth, .golden: "Dramatic. Big headlines; best for landing pages and posters."
        }
    }
}

enum ScaleUnit: String, CaseIterable, Identifiable, Codable {
    case px, rem
    var id: String { rawValue }
}

struct ScaleStep: Identifiable {
    let id: String
    let name: String
    let exponent: Int
    let size: Double
    let lineHeight: Double
    /// Letter spacing in em.
    let tracking: Double
    let isHeading: Bool
    let weight: Int
}

struct TypeScaleSpec: Hashable, Codable {
    var base: Double = 16
    var ratio: ScaleRatio = .majorThird
    var bodyLineHeight: Double = 1.5
    var unit: ScaleUnit = .rem

    init(base: Double = 16, ratio: ScaleRatio = .majorThird, bodyLineHeight: Double = 1.5, unit: ScaleUnit = .rem) {
        self.base = base; self.ratio = ratio; self.bodyLineHeight = bodyLineHeight; self.unit = unit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = min(24, max(12, (try? c.decode(Double.self, forKey: .base)) ?? 16))
        ratio = (try? c.decode(ScaleRatio.self, forKey: .ratio)) ?? .majorThird
        bodyLineHeight = min(1.8, max(1.3, (try? c.decode(Double.self, forKey: .bodyLineHeight)) ?? 1.5))
        unit = (try? c.decode(ScaleUnit.self, forKey: .unit)) ?? .rem
    }

    static let names: [(String, String, Int)] = [
        ("display", "Display", 6), ("h1", "Heading 1", 5), ("h2", "Heading 2", 4), ("h3", "Heading 3", 3),
        ("h4", "Heading 4", 2), ("h5", "Heading 5", 1), ("body", "Body", 0), ("small", "Small", -1), ("caption", "Caption", -2),
    ]

    func steps(headingWeight: Int, bodyWeight: Int) -> [ScaleStep] {
        Self.names.map { id, name, n in
            // Below body size, half steps keep small text readable (never under 11px).
            let raw = n >= 0 ? base * pow(ratio.rawValue, Double(n)) : max(11, base * pow(ratio.rawValue, Double(n) * 0.6))
            let size = (raw * 2).rounded() / 2
            // Bigger text needs tighter leading and tracking.
            let lh = n <= 0 ? bodyLineHeight + (n < 0 ? 0.05 : 0) : max(1.05, ((bodyLineHeight - 0.08 * Double(n)) * 20).rounded() / 20)
            let tracking = n >= 4 ? -0.02 : n >= 2 ? -0.01 : n < 0 ? 0.01 : 0
            return ScaleStep(id: id, name: name, exponent: n, size: size, lineHeight: lh, tracking: tracking,
                             isHeading: n > 0, weight: n > 0 ? headingWeight : bodyWeight)
        }
    }

    func css(_ px: Double) -> String {
        unit == .px ? "\(fmt(px))px" : "\(fmt(px / 16))rem"
    }
}

func fmt(_ v: Double) -> String {
    var s = String(format: "%.4f", v)
    while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
    return s == "-0" ? "0" : s
}

enum TypeExportFormat: String, CaseIterable, Identifiable {
    case css, scss, tailwind, swiftui, json
    var id: String { rawValue }
    var title: String {
        switch self {
        case .css: "CSS variables"
        case .scss: "SCSS"
        case .tailwind: "Tailwind config"
        case .swiftui: "SwiftUI"
        case .json: "Design tokens (JSON)"
        }
    }
    var ext: String {
        switch self {
        case .css: "css"
        case .scss: "scss"
        case .tailwind: "js"
        case .swiftui: "swift"
        case .json: "json"
        }
    }
}

@MainActor
enum TypeExporter {
    static func text(_ format: TypeExportFormat, heading: FontFamily, body: FontFamily, steps: [ScaleStep], spec: TypeScaleSpec) -> String {
        let embeds = [heading.cssEmbed(weights: steps.filter(\.isHeading).map(\.weight)),
                      heading == body ? nil : body.cssEmbed(weights: [body.regular, body.nearest(700)])].compactMap { $0 }
        let header = "Type scale: \(heading.family) + \(body.family), base \(fmt(spec.base))px, ratio \(String(format: "%.3g", spec.ratio.rawValue)). Made with Palette Pro."
        switch format {
        case .css:
            var lines = ["/* \(header) */"]
            lines += embeds.map { "/* Load fonts: \($0) */" }
            lines += [":root {", "  --font-heading: \(heading.cssStack);", "  --font-body: \(body.cssStack);"]
            for s in steps {
                lines.append("  --text-\(s.id): \(spec.css(s.size));")
                lines.append("  --leading-\(s.id): \(fmt(s.lineHeight));")
                if s.tracking != 0 { lines.append("  --tracking-\(s.id): \(fmt(s.tracking))em;") }
            }
            lines.append("}")
            lines.append("")
            lines.append("body { font-family: var(--font-body); font-size: var(--text-body); line-height: var(--leading-body); font-weight: \(steps.first { $0.id == "body" }?.weight ?? 400); }")
            for s in steps where s.id != "body" {
                let selector = s.isHeading && s.id != "display" ? "\(s.id), .\(s.id)" : ".\(s.id)"
                var rule = "\(selector) { font-family: var(--font-\(s.isHeading ? "heading" : "body")); font-size: var(--text-\(s.id)); line-height: var(--leading-\(s.id)); font-weight: \(s.weight);"
                if s.tracking != 0 { rule += " letter-spacing: var(--tracking-\(s.id));" }
                lines.append(rule + " }")
            }
            return lines.joined(separator: "\n") + "\n"
        case .scss:
            var lines = ["// \(header)", "$font-heading: \(heading.cssStack);", "$font-body: \(body.cssStack);", "", "$type-scale: ("]
            for s in steps {
                lines.append("  \"\(s.id)\": (size: \(spec.css(s.size)), line-height: \(fmt(s.lineHeight)), letter-spacing: \(fmt(s.tracking))em, weight: \(s.weight)),")
            }
            lines += [");", "", "@mixin text($step) {", "  $s: map-get($type-scale, $step);",
                      "  font-size: map-get($s, size);", "  line-height: map-get($s, line-height);",
                      "  letter-spacing: map-get($s, letter-spacing);", "  font-weight: map-get($s, weight);", "}"]
            return lines.joined(separator: "\n") + "\n"
        case .tailwind:
            var lines = ["// \(header)", "// tailwind.config.js (v3). For v4, use the CSS variables export in @theme.", "module.exports = {", "  theme: {", "    extend: {",
                         "      fontFamily: {", "        heading: [\(quoted(heading))],", "        body: [\(quoted(body))],", "      },", "      fontSize: {"]
            for s in steps {
                lines.append("        '\(s.id)': ['\(spec.css(s.size))', { lineHeight: '\(fmt(s.lineHeight))', letterSpacing: '\(fmt(s.tracking))em', fontWeight: '\(s.weight)' }],")
            }
            lines += ["      },", "    },", "  },", "};"]
            return lines.joined(separator: "\n") + "\n"
        case .swiftui:
            let headingPS = FontStore.shared.postScriptName(heading, weight: steps.first(where: \.isHeading)?.weight ?? 700) ?? heading.family
            let bodyPS = FontStore.shared.postScriptName(body, weight: body.regular) ?? body.family
            var lines = ["// \(header)", "// Add the font files to your app target and list them under UIAppFonts / ATSApplicationFontsPath.",
                         "import SwiftUI", "", "extension Font {"]
            for s in steps {
                let ps = s.isHeading ? headingPS : bodyPS
                let style = s.isHeading ? (s.exponent >= 4 ? ".largeTitle" : ".title") : (s.exponent < 0 ? ".caption" : ".body")
                lines.append("    static let \(camel(s.id)) = Font.custom(\"\(ps)\", size: \(fmt(s.size)), relativeTo: \(style))")
            }
            lines += ["}", "", "/// Line spacing to add below each style: (lineHeight − 1) × size.", "enum TypeLeading {"]
            for s in steps { lines.append("    static let \(camel(s.id)): CGFloat = \(fmt((s.lineHeight - 1) * s.size))") }
            lines.append("}")
            return lines.joined(separator: "\n") + "\n"
        case .json:
            var tokens: [String: Any] = [:]
            tokens["font"] = ["heading": ["$type": "fontFamily", "$value": [heading.family, heading.category.generic]],
                              "body": ["$type": "fontFamily", "$value": [body.family, body.category.generic]]]
            var text: [String: Any] = [:]
            for s in steps {
                text[s.id] = ["$type": "typography", "$value": [
                    "fontFamily": s.isHeading ? "{font.heading}" : "{font.body}",
                    "fontSize": spec.css(s.size), "fontWeight": s.weight,
                    "lineHeight": s.lineHeight, "letterSpacing": "\(fmt(s.tracking))em",
                ]]
            }
            tokens["text"] = text
            let data = (try? JSONSerialization.data(withJSONObject: tokens, options: [.prettyPrinted, .sortedKeys])) ?? Data()
            return String(decoding: data, as: UTF8.self) + "\n"
        }
    }

    private static func quoted(_ f: FontFamily) -> String { "'\(f.family)', '\(f.category.generic)'" }

    private static func camel(_ id: String) -> String { id == "display" ? "display" : id }
}
