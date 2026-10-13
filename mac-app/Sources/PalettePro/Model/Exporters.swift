import AppKit
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case css, scss, tailwind4, tailwind3, swiftui, json, hex, gpl, ase, clr, png
    var id: String { rawValue }
    var title: String {
        switch self {
        case .css: "CSS variables"
        case .scss: "SCSS"
        case .tailwind4: "Tailwind v4"
        case .tailwind3: "Tailwind v3"
        case .swiftui: "SwiftUI"
        case .json: "JSON"
        case .hex: "Hex list"
        case .gpl: "GIMP / Inkscape / Krita"
        case .ase: "Adobe (.ase)"
        case .clr: "Apple Color List"
        case .png: "PNG image"
        }
    }
    var ext: String {
        switch self {
        case .tailwind4, .css: "css"
        case .tailwind3: "js"
        case .swiftui: "swift"
        case .hex: "txt"
        default: rawValue
        }
    }
    var isBinary: Bool { [.ase, .clr, .png].contains(self) }
    var note: String? {
        switch self {
        case .ase: "Swatches for Illustrator, Photoshop, InDesign, Affinity and Procreate. Exact Pantone matches keep their name."
        case .clr: "A palette file for the macOS color picker. Use “Add to macOS Colors” to install it directly."
        case .png: "A Pantone-chip style image of the palette, for sharing or moodboards."
        default: nil
        }
    }
}

/// One colour as it appears in an export.
struct ExportEntry: Hashable {
    var hex: String
    var pantone: String
    var pantoneName: String
    var exact: Bool
    var dE: Double
    /// Brand role ("Primary", "Accent"…) when exporting from Brand Studio.
    var role: String?

    var rgb: RGB { ColorMath.rgb(hex) }
    var label: String { "\(exact ? "" : "≈ ")PANTONE \(pantone)\(pantoneName.isEmpty ? "" : " " + pantoneName)" }
}

enum Exporter {
    static func slug(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        var out = ""
        for ch in folded {
            if ch.isLetter || ch.isNumber { out.append(ch) } else if !out.isEmpty && !out.hasSuffix("-") { out.append("-") }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "palette" : out
    }

    static func camel(_ s: String) -> String {
        let parts = slug(s).split(separator: "-").map(String.init)
        guard let first = parts.first else { return "palette" }
        let joined = first + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        return joined.first?.isNumber == true ? "c" + joined : joined
    }

    private static func key(_ name: String, _ e: ExportEntry, _ i: Int) -> String {
        e.role.map { "\(slug(name))-\(slug($0))" } ?? "\(slug(name))-\(i + 1)"
    }

    static func text(_ format: ExportFormat, name: String, entries: [ExportEntry]) -> String? {
        let p = slug(name)
        let comment: (ExportEntry) -> String = { " /* \($0.label) */" }
        switch format {
        case .css:
            return "/* \(name) — exported from Palette Pro */\n:root {\n" +
                entries.enumerated().map { "  --\(key(name, $1, $0)): \($1.hex);\(comment($1))" }.joined(separator: "\n") + "\n}\n"
        case .scss:
            return "// \(name) — exported from Palette Pro\n" +
                entries.enumerated().map { "$\(key(name, $1, $0)): \($1.hex); // \($1.label)" }.joined(separator: "\n") +
                "\n\n$\(p): (\n" + entries.enumerated().map { "  \"\(key(name, $1, $0))\": $\(key(name, $1, $0)),"}.joined(separator: "\n") + "\n);\n"
        case .tailwind4:
            return "/* \(name) — Tailwind CSS v4: add to your main CSS file */\n@theme {\n" +
                entries.enumerated().map { "  --color-\(key(name, $1, $0)): \($1.hex);\(comment($1))" }.joined(separator: "\n") + "\n}\n"
        case .tailwind3:
            return "// \(name) — Tailwind CSS v3: merge into tailwind.config.js\nmodule.exports = {\n  theme: {\n    extend: {\n      colors: {\n" +
                entries.enumerated().map { "        '\(key(name, $1, $0))': '\($1.hex)', // \($1.label)" }.joined(separator: "\n") +
                "\n      },\n    },\n  },\n};\n"
        case .swiftui:
            let body = entries.enumerated().map { i, e -> String in
                let c = e.rgb
                // Prefixed with the palette name so roles never shadow Color.primary / .secondary.
                let n = e.role.map { camel("\(name) \($0)") } ?? camel(name) + "\(i + 1)"
                return String(format: "    static let %@ = Color(red: %.3f, green: %.3f, blue: %.3f) // %@ %@", n, c.r / 255, c.g / 255, c.b / 255, e.hex, e.label)
            }.joined(separator: "\n")
            return "// \(name) — exported from Palette Pro\nimport SwiftUI\n\nextension Color {\n\(body)\n}\n"
        case .json:
            let colors: [[String: Any]] = entries.map { e in
                var d: [String: Any] = ["hex": e.hex, "rgb": "rgb(\(e.rgb.ints.map(String.init).joined(separator: ", ")))",
                                        "pantone": "PANTONE \(e.pantone)",
                                        "match": e.exact ? "exact" : String(format: "nearest (ΔE %.1f)", e.dE)]
                if !e.pantoneName.isEmpty { d["pantoneName"] = e.pantoneName }
                if let r = e.role { d["role"] = r }
                return d
            }
            let data = try? JSONSerialization.data(withJSONObject: ["name": name, "colors": colors], options: [.prettyPrinted, .sortedKeys])
            return data.flatMap { String(data: $0, encoding: .utf8) }.map { $0 + "\n" }
        case .hex:
            return entries.map(\.hex).joined(separator: "\n") + "\n"
        case .gpl:
            return "GIMP Palette\nName: \(name)\nColumns: \(entries.count)\n#\n" +
                entries.map { e in e.rgb.ints.map { String(format: "%3d", $0) }.joined(separator: " ") + "\t" + (e.role.map { "\($0) — " } ?? "") + e.label }
                .joined(separator: "\n") + "\n"
        case .ase, .clr, .png:
            return nil
        }
    }

    /// Adobe Swatch Exchange (version 1.0) with one group.
    static func ase(name: String, entries: [ExportEntry]) -> Data {
        var d = Data()
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.bigEndian) { d.append(contentsOf: $0) } }
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.bigEndian) { d.append(contentsOf: $0) } }
        func utf16(_ s: String) -> Data {
            var b = Data()
            let units = Array((s + "\0").utf16)
            withUnsafeBytes(of: UInt16(units.count).bigEndian) { b.append(contentsOf: $0) }
            for u in units { withUnsafeBytes(of: u.bigEndian) { b.append(contentsOf: $0) } }
            return b
        }
        func block(_ type: UInt16, _ body: Data) { u16(type); u32(UInt32(body.count)); d.append(body) }

        d.append(contentsOf: Array("ASEF".utf8)); u16(1); u16(0); u32(UInt32(entries.count + 2))
        block(0xC001, utf16(name))
        for e in entries {
            var body = utf16(e.exact ? e.label : (e.role.map { "\($0) \(e.hex)" } ?? e.hex))
            body.append(contentsOf: Array("RGB ".utf8))
            let c = e.rgb
            for v in [c.r, c.g, c.b] { withUnsafeBytes(of: Float32(v / 255).bitPattern.bigEndian) { body.append(contentsOf: $0) } }
            withUnsafeBytes(of: UInt16(2).bigEndian) { body.append(contentsOf: $0) } // normal (not spot)
            block(0x0001, body)
        }
        block(0xC002, Data())
        return d
    }

    static func colorList(name: String, entries: [ExportEntry]) -> NSColorList {
        let list = NSColorList(name: name)
        var used = Set<String>()
        for (i, e) in entries.enumerated() {
            var key = e.role.map { "\($0) · \(e.exact ? "PANTONE " + e.pantone : e.hex)" } ?? (e.exact ? "PANTONE \(e.pantone)" : e.hex)
            if used.contains(key) { key += " (\(i + 1))" }
            used.insert(key)
            let c = e.rgb
            list.setColor(NSColor(srgbRed: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1), forKey: key)
        }
        return list
    }

    static func clrData(name: String, entries: [ExportEntry]) -> Data? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".clr")
        defer { try? FileManager.default.removeItem(at: url) }
        guard (try? colorList(name: name, entries: entries).write(to: url)) != nil else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Installs the palette in ~/Library/Colors so it shows up in every app's color picker.
    static func installColorList(name: String, entries: [ExportEntry]) throws -> URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Colors", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("\(safe).clr")
        try colorList(name: safe, entries: entries).write(to: url)
        return url
    }
}

@MainActor
enum FilePanels {
    /// Shows a save panel and writes `data`. Returns the chosen URL on success.
    @discardableResult
    static func save(_ data: Data, suggestedName: String, ext: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(suggestedName).\(ext)"
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .data]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do { try data.write(to: url, options: .atomic); return url } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }

    static func open(types: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}
