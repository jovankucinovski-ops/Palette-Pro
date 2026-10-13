import SwiftUI

struct SwatchCollection: Identifiable, Hashable {
    let id: String
    let name: String
    var count = 0
}

struct Swatch: Identifiable, Hashable {
    let id: String
    let coll: String
    let code: String
    let name: String
    let note: String
    let hex: String
    let rgb: RGB
    let lab: Vec3
    let lch: Vec3
    let family: Family
    let hueKey: Double
    let order: Int
    let search: String

    static func == (a: Swatch, b: Swatch) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var color: Color { Color(rgb: rgb) }
    var title: String { "PANTONE \(code)" }
    /// Name, year for Color of the Year, or the collection.
    var subtitle: String {
        let parts = [name, coll == "coty" ? note : ""].filter { !$0.isEmpty }
        return parts.isEmpty ? Library.shared.collectionName(coll) : parts.joined(separator: " · ")
    }
}

/// Collections a colour can be matched against.
enum MatchLib: String, CaseIterable, Identifiable, Codable {
    case coated, uncoated, tcx, metallic, pastel, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .coated: "Solid Coated"
        case .uncoated: "Solid Uncoated"
        case .tcx: "Fashion, Home + Interiors"
        case .metallic: "Metallics"
        case .pastel: "Pastels & Neons"
        case .all: "All collections"
        }
    }
}

struct Match: Hashable {
    let swatch: Swatch
    let dE: Double
}

final class Library: @unchecked Sendable {
    static let shared = Library()

    let collections: [SwatchCollection]
    let swatches: [Swatch]
    let byID: [String: Swatch]
    private let byCode: [String: Swatch]
    private var libCache: [MatchLib: [Swatch]] = [:]
    private var nearestCache: [String: Match] = [:]

    private init() {
        let root = (try? JSONSerialization.jsonObject(with: Data(swatchDataJSON.utf8))) as? [String: Any] ?? [:]
        var colls = ((root["collections"] as? [[String: String]]) ?? []).map { SwatchCollection(id: $0["id"] ?? "", name: $0["name"] ?? "") }
        let rows = (root["colors"] as? [[Any]]) ?? []
        var list: [Swatch] = []
        list.reserveCapacity(rows.count)
        for (order, row) in rows.enumerated() {
            guard row.count >= 4, let ci = row[0] as? Int, ci < colls.count,
                  let code = row[1] as? String, let name = row[2] as? String, let hex = row[3] as? String else { continue }
            let note = row.count > 4 ? (row[4] as? String ?? "") : ""
            let coll = colls[ci].id
            let rgb = ColorMath.rgb(hex), lab = ColorMath.lab(rgb), lch = ColorMath.lch(lab), hsl = ColorMath.hsl(rgb)
            let family = ColorMath.family(hsl: hsl, lch: lch)
            // Hue sort: 30 hue bands, light to dark inside each band, neutrals last.
            let hueKey = family == .neutral ? 10000 - lch.x : floor((hsl.x + 8).truncatingRemainder(dividingBy: 360) / 12) * 200 + (100 - lch.x)
            list.append(Swatch(id: "\(coll)/\(code)", coll: coll, code: code, name: name, note: note, hex: "#" + hex,
                               rgb: rgb, lab: lab, lch: lch, family: family, hueKey: hueKey, order: order,
                               search: "\(code) \(name) \(hex) #\(hex) \(note) \(colls[ci].name)".lowercased()))
        }
        for i in colls.indices { colls[i].count = list.filter { $0.coll == colls[i].id }.count }
        collections = colls
        swatches = list
        byID = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var codes: [String: Swatch] = [:]
        for s in list where s.coll != "coty" {
            let k = s.code.lowercased()
            if codes[k] == nil { codes[k] = s }
            if s.coll == "tcx" { codes[k.replacingOccurrences(of: " tcx", with: "")] = s }
        }
        byCode = codes
    }

    func collectionName(_ id: String) -> String { collections.first { $0.id == id }?.name ?? id }

    /// Colour of the Year entries duplicate TCX colours, so "all" leaves them out.
    func swatches(in lib: MatchLib) -> [Swatch] {
        if let cached = libCache[lib] { return cached }
        let result = swatches.filter { lib == .all ? $0.coll != "coty" : $0.coll == lib.rawValue }
        libCache[lib] = result
        return result
    }

    func swatches(inCollection id: String) -> [Swatch] {
        id == "all" ? swatches(in: .all) : swatches.filter { $0.coll == id }
    }

    func nearest(_ hex: String, k: Int = 1, in lib: MatchLib, excluding: Set<String> = []) -> [Match] {
        let lab = ColorMath.lab(ColorMath.rgb(hex))
        var top: [Match] = []
        for s in swatches(in: lib) where !excluding.contains(s.id) {
            let d = ColorMath.deltaE(lab, s.lab)
            if top.count < k || d < top[top.count - 1].dE {
                let i = top.firstIndex { $0.dE > d } ?? top.count
                top.insert(Match(swatch: s, dE: d), at: i)
                if top.count > k { top.removeLast() }
            }
        }
        return top
    }

    func nearest1(_ hex: String, in lib: MatchLib) -> Match {
        let key = lib.rawValue + hex
        if let m = nearestCache[key] { return m }
        let m = nearest(hex, in: lib)[0]
        nearestCache[key] = m
        return m
    }

    /// Finds a colour from a pasted Pantone number: "185 C", "PANTONE 19-4052 TCX", "cool gray 11c".
    func lookup(code raw: String) -> Swatch? {
        var key = raw.lowercased()
            .replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: "pantone", with: "")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if let r = key.range(of: #"(\d)([cu])$"#, options: .regularExpression) {
            key.replaceSubrange(r, with: "\(key[r].first!) \(key[r].last!)")
        }
        if let s = byCode[key] { return s }
        for suffix in [" tcx", " tpx", " tpg"] where key.hasSuffix(suffix) {
            if let s = byCode[String(key.dropLast(suffix.count))] { return s }
        }
        return nil
    }
}

extension Color {
    init(rgb c: RGB) { self.init(.sRGB, red: c.r / 255, green: c.g / 255, blue: c.b / 255, opacity: 1) }
    init(hex: String) { self.init(rgb: ColorMath.rgb(hex)) }

    /// sRGB hex of a concrete colour (e.g. from ColorPicker), nil for dynamic colours.
    var hexString: String? {
        guard let ns = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return ColorMath.hex(RGB(ns.redComponent * 255, ns.greenComponent * 255, ns.blueComponent * 255))
    }
}
