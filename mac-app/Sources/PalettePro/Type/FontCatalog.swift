import AppKit
import CoreText
import SwiftUI

enum FontCategory: String, CaseIterable, Identifiable, Codable {
    case sans, serif, slab, display, script, mono
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sans: "Sans Serif"
        case .serif: "Serif"
        case .slab: "Slab Serif"
        case .display: "Display"
        case .script: "Script"
        case .mono: "Monospace"
        }
    }
    /// CSS generic family used after the font name.
    var generic: String {
        switch self {
        case .serif, .slab: "serif"
        case .mono: "monospace"
        case .script: "cursive"
        default: "sans-serif"
        }
    }
}

enum FontSource: String, CaseIterable, Identifiable, Codable {
    case google, fontshare, open, installed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .google: "Google Fonts"
        case .fontshare: "Fontshare"
        case .open: "Open source"
        case .installed: "On this Mac"
        }
    }
}

struct FontFamily: Identifiable, Hashable {
    let id: String
    let family: String
    let category: FontCategory
    let source: FontSource
    let weights: [Int]
    let italic: Bool
    let variable: Bool
    let license: String
    let rank: Int
    let designers: String
    let year: Int
    let subset: String
    let slug: String?
    /// Fontshare file ids by style, e.g. "400" or "700i".
    let files: [String: String]
    let pick: Bool
    let search: String
    /// Installed fonts: PostScript names by style, e.g. "400" or "700i".
    let local: [String: String]

    static func == (a: FontFamily, b: FontFamily) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var regular: Int { nearest(400) }

    /// The available weight closest to `w` (heavier wins a tie).
    func nearest(_ w: Int) -> Int {
        weights.min { abs($0 - w) == abs($1 - w) ? $0 > $1 : abs($0 - w) < abs($1 - w) } ?? 400
    }

    /// A bold-ish weight for headings: 700 if available, else the heaviest up to 800.
    var heading: Int {
        if weights.contains(700) { return 700 }
        if weights.contains(600) { return 600 }
        return weights.filter { $0 <= 800 }.max() ?? regular
    }

    var styleCount: Int { weights.count * (italic ? 2 : 1) }

    /// Where the font file for one style can be downloaded.
    func fileURL(weight: Int, italic: Bool) -> URL? {
        switch source {
        case .google, .open:
            return URL(string: "https://cdn.jsdelivr.net/fontsource/fonts/\(id)@latest/\(subset)-\(weight)-\(italic ? "italic" : "normal").ttf")
        case .fontshare:
            return files["\(weight)\(italic ? "i" : "")"].flatMap { URL(string: "https://cdn.fontshare.com/wf/\($0).ttf") }
        case .installed:
            return nil
        }
    }

    /// The font's official page, where the full family can be downloaded.
    var pageURL: URL? {
        switch source {
        case .google: URL(string: "https://fonts.google.com/specimen/" + family.replacingOccurrences(of: " ", with: "+"))
        case .open: URL(string: "https://fontsource.org/fonts/\(id)")
        case .fontshare: slug.flatMap { URL(string: "https://www.fontshare.com/fonts/\($0)") }
        case .installed: nil
        }
    }

    var licenseTitle: String {
        switch license {
        case "OFL-1.1": "SIL Open Font License"
        case "Apache-2.0": "Apache License 2.0"
        case "ITF FFL": "ITF Free Font License"
        case "UFL-1.0": "Ubuntu Font Licence"
        case "": "See the font’s own license"
        default: license
        }
    }

    var licenseNote: String {
        switch source {
        case .installed: "Installed on this Mac. Check its license before using it in client work."
        case .fontshare where license == "ITF FFL": "Free for personal and commercial use. Download it from Fontshare; the files may not be redistributed."
        default: "Free for personal and commercial use, including web, print and apps."
        }
    }

    /// CSS font-family value with a generic fallback.
    var cssStack: String { "'\(family)', \(category.generic)" }

    /// How to load the font on a website.
    func cssEmbed(weights ws: [Int]) -> String? {
        let list = Array(Set(ws.map(nearest))).sorted()
        switch source {
        case .google:
            let name = family.replacingOccurrences(of: " ", with: "+")
            return "<link href=\"https://fonts.googleapis.com/css2?family=\(name):wght@\(list.map(String.init).joined(separator: ";"))&display=swap\" rel=\"stylesheet\">"
        case .fontshare:
            return slug.map { "<link href=\"https://api.fontshare.com/v2/css?f[]=\($0)@\(list.map(String.init).joined(separator: ","))&display=swap\" rel=\"stylesheet\">" }
        case .open:
            return "npm install @fontsource/\(id)   /* then: import '@fontsource/\(id)'; */"
        case .installed:
            return nil
        }
    }
}

/// Every font the app knows: the bundled online catalogue plus the fonts installed on this Mac.
final class FontCatalog: @unchecked Sendable {
    static let shared = FontCatalog()

    let online: [FontFamily]
    private let onlineByID: [String: FontFamily]
    private let onlineByName: [String: FontFamily]

    /// Read on first use (not at launch): classifying every installed font takes a moment.
    private(set) lazy var installed: [FontFamily] = {
        let onlineNames = Set(online.map { $0.family.lowercased() })
        return Self.installedFamilies().filter { !onlineNames.contains($0.family.lowercased()) }
    }()
    private lazy var installedByID = Dictionary(installed.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    var all: [FontFamily] { online + installed }

    private init() {
        let rows = (try? JSONSerialization.jsonObject(with: Data(fontCatalogJSON.utf8))) as? [[String: Any]] ?? []
        online = rows.compactMap(Self.family)
        onlineByID = Dictionary(online.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        onlineByName = Dictionary(online.map { ($0.family.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
    }

    func family(id: String) -> FontFamily? {
        onlineByID[id] ?? (id.hasPrefix("mac-") ? installedByID[id] : nil)
    }

    func named(_ name: String) -> FontFamily? {
        onlineByName[name.lowercased()] ?? installed.first { $0.family.lowercased() == name.lowercased() }
    }

    private static func family(_ r: [String: Any]) -> FontFamily? {
        guard let id = r["id"] as? String, let name = r["family"] as? String,
              let cat = (r["category"] as? String).flatMap(FontCategory.init),
              let src = (r["source"] as? String).flatMap(FontSource.init) else { return nil }
        let designers = r["designers"] as? String ?? ""
        return FontFamily(id: id, family: name, category: cat, source: src, weights: r["weights"] as? [Int] ?? [400],
                          italic: r["italic"] as? Bool ?? false, variable: r["variable"] as? Bool ?? false,
                          license: r["license"] as? String ?? "", rank: r["rank"] as? Int ?? 5000, designers: designers,
                          year: r["year"] as? Int ?? 2000, subset: r["subset"] as? String ?? "latin", slug: r["slug"] as? String,
                          files: r["files"] as? [String: String] ?? [:], pick: r["pick"] as? Bool ?? false,
                          search: "\(name) \(designers) \(cat.title) \(src.title)".lowercased(), local: [:])
    }

    /// Fonts installed on this Mac, classified from their font tables.
    private static func installedFamilies() -> [FontFamily] {
        let fm = NSFontManager.shared
        return fm.availableFontFamilies.filter { !$0.hasPrefix(".") }.compactMap { name -> FontFamily? in
            guard let members = fm.availableMembers(ofFontFamily: name), !members.isEmpty else { return nil }
            var local: [String: String] = [:]
            var category: FontCategory?
            for m in members {
                guard let ps = m.first as? String else { continue }
                let font = CTFontCreateWithName(ps as CFString, 12, nil)
                let traits = CTFontCopyTraits(font) as? [String: Any] ?? [:]
                let w = (traits[kCTFontWeightTrait as String] as? Double) ?? 0
                let sym = CTFontGetSymbolicTraits(font)
                let key = "\(cssWeight(w))\(sym.contains(.traitItalic) ? "i" : "")"
                if local[key] == nil || ps.count < local[key]!.count { local[key] = ps }
                if category == nil { category = classify(font, name: name) }
            }
            guard !local.isEmpty, let category else { return nil }
            let weights = Set(local.keys.map { Int($0.filter(\.isNumber)) ?? 400 }).sorted()
            return FontFamily(id: "mac-" + name.lowercased().replacingOccurrences(of: " ", with: "-"), family: name,
                              category: category, source: .installed, weights: weights,
                              italic: local.keys.contains { $0.hasSuffix("i") }, variable: false, license: "",
                              rank: 3000, designers: "", year: 0, subset: "", slug: nil, files: [:], pick: false,
                              search: "\(name) \(category.title) on this mac installed".lowercased(), local: local)
        }
    }

    private static func cssWeight(_ t: Double) -> Int {
        let stops: [(Double, Int)] = [(-0.8, 100), (-0.6, 200), (-0.4, 300), (0, 400), (0.23, 500), (0.3, 600), (0.4, 700), (0.56, 800), (0.62, 900)]
        return stops.min { abs($0.0 - t) < abs($1.0 - t) }!.1
    }

    private static func classify(_ font: CTFont, name: String) -> FontCategory? {
        let sym = CTFontGetSymbolicTraits(font)
        let lower = name.lowercased()
        if sym.contains(.traitMonoSpace) || lower.contains("mono") || lower.contains("courier") { return .mono }
        let cls = sym.rawValue & CTFontSymbolicTraits.traitClassMask.rawValue
        switch cls {
        case CTFontStylisticClass.slabSerifsClass.rawValue: return .slab
        case CTFontStylisticClass.oldStyleSerifsClass.rawValue, CTFontStylisticClass.transitionalSerifsClass.rawValue,
             CTFontStylisticClass.modernSerifsClass.rawValue, CTFontStylisticClass.clarendonSerifsClass.rawValue,
             CTFontStylisticClass.freeformSerifsClass.rawValue: return .serif
        case CTFontStylisticClass.sansSerifClass.rawValue: return .sans
        case CTFontStylisticClass.ornamentalsClass.rawValue: return .display
        case CTFontStylisticClass.scriptsClass.rawValue: return .script
        case CTFontStylisticClass.symbolicClass.rawValue: return nil
        default:
            if lower.contains("serif") && !lower.contains("sans") { return .serif }
            // Symbol and dingbat fonts can't show sample text.
            if ["symbol", "dingbat", "webdings", "wingdings", "emoji", "ornament"].contains(where: lower.contains) { return nil }
            return .sans
        }
    }
}
