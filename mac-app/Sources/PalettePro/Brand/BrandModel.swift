import AppKit
import Observation
import SwiftUI

enum BrandTab: String, CaseIterable, Identifiable {
    case ideas, overview, logo, mockups, specs
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Brand Studio inputs and results as saved in library.json. Unknown or missing values fall back to defaults.
struct BrandSettings: Codable, Hashable {
    var brandName = "Lumen"
    var tagline = "Made with care"
    var focus: ProjectFocus = .identity
    var industry: Industry = .tech
    var traits: [Trait] = [.trustworthy, .modern]
    var useBaseColor = false
    var baseHex = "#2F62C4"
    var snapToPantone = true
    var logoStyle: LogoStyle = .monogram
    var typeface: BrandTypeface = .suggested
    var removeLogoBackground = true
    var showNameWithLogo = false
    var logoDriven = false
    var recolorLogo = true
    var concepts: [BrandConcept] = []
    var selectedID: UUID?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decode(T.self, forKey: key)) ?? fallback }
        brandName = value(.brandName, brandName)
        tagline = value(.tagline, tagline)
        focus = value(.focus, focus)
        industry = value(.industry, industry)
        traits = value(.traits, traits)
        useBaseColor = value(.useBaseColor, useBaseColor)
        baseHex = value(.baseHex, baseHex)
        snapToPantone = value(.snapToPantone, snapToPantone)
        logoStyle = value(.logoStyle, logoStyle)
        typeface = value(.typeface, typeface)
        removeLogoBackground = value(.removeLogoBackground, removeLogoBackground)
        showNameWithLogo = value(.showNameWithLogo, showNameWithLogo)
        logoDriven = value(.logoDriven, logoDriven)
        recolorLogo = value(.recolorLogo, recolorLogo)
        concepts = value(.concepts, concepts)
        selectedID = try? c.decode(UUID.self, forKey: .selectedID)
    }
}

@Observable @MainActor
final class BrandModel {
    var brandName = "Lumen"
    var tagline = "Made with care"
    var focus: ProjectFocus = .identity
    var industry: Industry = .tech
    var traits: [Trait] = [.trustworthy, .modern]
    var useBaseColor = false
    var baseHex = "#2F62C4"
    var snapToPantone = true
    var logoStyle: LogoStyle = .monogram
    var typeface: BrandTypeface = .suggested

    var concepts: [BrandConcept] = []
    var selectedID: UUID?
    var tab: BrandTab = .ideas

    // Imported logo
    var logo: NSImage?
    /// The logo with white (or background-colored) areas cut out, for one-color versions.
    var logoMask: NSImage?
    var logoAspect: CGFloat = 1
    var logoHasTransparency = true
    var logoBackground: RGB?
    var logoColors: [ExtractedColor] = []
    var removeLogoBackground = true
    var showNameWithLogo = false
    /// Ideas stay close to the logo's own hue instead of exploring the whole color wheel.
    var logoDriven = false
    /// Show the logo repainted in each palette's colors (otherwise its original colors).
    var recolorLogo = true
    @ObservationIgnored private var logoCG: CGImage?
    @ObservationIgnored private var artCache: [String: NSImage] = [:]
    @ObservationIgnored private var logoVersion = UUID()
    /// Set when the logo is an SVG with a transparent background; it then stays vector everywhere.
    var logoVector: VectorLogo?
    /// Shown under the logo when an SVG had to be treated as an image.
    var logoNote: String?
    @ObservationIgnored private var logoSource: CGImage?

    var selected: BrandConcept? { concepts.first { $0.id == selectedID } ?? concepts.first }

    var initial: String { brandName.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "B" }

    var hasLogo: Bool { logo != nil }
    var isVectorLogo: Bool { logoVector != nil }
    var usesLogoImage: Bool { logoStyle == .custom && logo != nil }
    var logoMainHex: String? { logoColors.first?.hex }
    /// True for white or very pale logos, which need a dark backdrop to be seen.
    var logoIsLight: Bool { logoMainHex.map { ColorMath.contrast($0, "#FFFFFF") < 1.6 } ?? false }

    func toggle(_ t: Trait) {
        if let i = traits.firstIndex(of: t) {
            traits.remove(at: i)
        } else {
            traits.append(t)
            if traits.count > 3 { traits.removeFirst() }
        }
    }

    /// New ideas. With a logo, its original colors come first for comparison; the rest explore the
    /// color wheel (or stay near the logo's hue when `logoDriven` is on).
    func suggest() {
        let fromLogo = hasLogo ? BrandEngine.concept(fromLogo: logoColors, industry: industry, traits: traits) : nil
        let base = logoDriven ? fromLogo?.hex(.primary) : (useBaseColor ? baseHex : nil)
        var ideas = BrandEngine.suggest(industry: industry, traits: traits, baseHex: base ?? (useBaseColor ? baseHex : nil),
                                        snapToPantone: snapToPantone, count: fromLogo == nil ? 12 : 11)
        if let fromLogo { ideas.insert(fromLogo, at: 0) }
        concepts = ideas
        selectedID = ideas.first?.id
    }

    // MARK: Logo in palette colors

    /// The logo in `concept`'s colors (or its original colors when recoloring is off). Vector stays vector.
    func logoArt(for concept: BrandConcept) -> NSImage? {
        guard let logo else { return nil }
        guard recolorLogo, !logoColors.isEmpty else { return logoVector?.full ?? logo }
        let key = "\(logoVersion)|" + BrandRole.allCases.map { concept.hex($0) }.joined()
        if let cached = artCache[key] { return cached }
        let map = LogoRecolor.mapping(logoColors, concept)
        var art: NSImage?
        if let vector = logoVector {
            art = VectorLogo.image(svg: LogoRecolor.recolorSVG(vector.svg, map), aspect: vector.aspect)
        } else if let cg = logoCG, let out = LogoRecolor.recolorRaster(cg, map) {
            art = NSImage(cgImage: out, size: NSSize(width: out.width, height: out.height))
        }
        let result = art ?? logo
        if artCache.count > 64 { artCache.removeAll() }
        artCache[key] = result
        return result
    }

    /// SVG markup of the full-color logo in `concept`'s colors, for export.
    func logoSVG(for concept: BrandConcept) -> String? {
        guard let vector = logoVector else { return nil }
        guard recolorLogo, !logoColors.isEmpty else { return vector.svg }
        return LogoRecolor.recolorSVG(vector.svg, LogoRecolor.mapping(logoColors, concept))
    }

    func adopt(palette hexes: [String], name: String) {
        let c = BrandEngine.concept(fromPalette: hexes, name: name, industry: industry, traits: traits)
        concepts.insert(c, at: 0)
        selectedID = c.id
    }

    func setColor(_ role: BrandRole, hex: String, sid: String? = nil) {
        guard let i = concepts.firstIndex(where: { $0.id == selected?.id }) else { return }
        concepts[i].colors[role] = BrandColor(hex: hex, sid: sid)
        concepts[i].rationale = BrandEngine.rationale(concepts[i], industry: industry, traits: traits, fromBase: true)
    }

    func snapRole(_ role: BrandRole) {
        guard let c = selected else { return }
        let m = BrandEngine.lib.nearest1(c.hex(role), in: .coated)
        setColor(role, hex: m.swatch.hex, sid: m.swatch.id)
    }

    // MARK: Logo

    static var logoURL: URL { AppModel.dataDirectory.appendingPathComponent("brand-logo.png") }
    static var svgURL: URL { AppModel.dataDirectory.appendingPathComponent("brand-logo.svg") }

    /// Imports a logo file. SVGs keep their vector source; everything else goes through NSImage.
    @discardableResult
    func importLogo(fileURL url: URL) -> Bool {
        if url.pathExtension.lowercased() == "svg", let data = try? Data(contentsOf: url) { return importSVG(data) }
        guard let image = NSImage(contentsOf: url) else { return false }
        return importLogo(image)
    }

    /// Imports SVG markup. If it has a solid background (which can't be removed from vector art
    /// reliably), it falls back to the image pipeline, which can.
    @discardableResult
    func importSVG(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              text.range(of: "<svg", options: .caseInsensitive) != nil,
              let vector = VectorLogo(svg: text) else { return false }
        guard applyVector(vector) else {
            guard importLogo(vector.full) else { return false }
            logoNote = "This SVG has a solid background, so it’s shown as an image with the background removed. Delete the background shape in your design app to keep the logo vector."
            return true
        }
        try? FileManager.default.createDirectory(at: AppModel.dataDirectory, withIntermediateDirectories: true)
        try? Data(text.utf8).write(to: Self.svgURL, options: .atomic)
        try? FileManager.default.removeItem(at: Self.logoURL)
        finishImport()
        return true
    }

    /// Imports a bitmap (or PDF) logo, switches the mark to it and bases the suggestions on its colors.
    @discardableResult
    func importLogo(_ image: NSImage) -> Bool {
        guard let cg = LogoProcessor.rasterize(image) else { return false }
        logoVector = nil
        logoNote = nil
        setSource(cg)
        if let data = LogoProcessor.png(cg) {
            try? FileManager.default.createDirectory(at: AppModel.dataDirectory, withIntermediateDirectories: true)
            try? data.write(to: Self.logoURL, options: .atomic)
        }
        try? FileManager.default.removeItem(at: Self.svgURL)
        finishImport()
        return true
    }

    private func finishImport() {
        logoStyle = .custom
        logoDriven = false
        tab = .ideas
        suggest()
    }

    func loadSavedLogo() {
        if let text = try? String(contentsOf: Self.svgURL, encoding: .utf8), let vector = VectorLogo(svg: text), applyVector(vector) {
            return
        }
        guard let image = NSImage(contentsOf: Self.logoURL), let cg = LogoProcessor.rasterize(image) else {
            if logoStyle == .custom { logoStyle = .monogram }
            logoDriven = false
            return
        }
        setSource(cg)
    }

    func removeLogo() {
        logoSource = nil
        logoCG = nil
        logoVersion = UUID()
        logoVector = nil
        logoNote = nil
        logo = nil
        logoMask = nil
        logoColors = []
        logoBackground = nil
        try? FileManager.default.removeItem(at: Self.logoURL)
        try? FileManager.default.removeItem(at: Self.svgURL)
        if logoStyle == .custom { logoStyle = .monogram }
        if logoDriven {
            logoDriven = false
            suggest()
        }
    }

    /// Uses a vector logo: crops its viewBox to the artwork and reads its colors from a raster copy.
    private func applyVector(_ vector: VectorLogo) -> Bool {
        guard let raster = LogoProcessor.rasterize(vector.full), LogoProcessor.analyze(raster).hasTransparency else { return false }
        var v = vector
        if let bounds = LogoProcessor.contentBounds(raster),
           let cropped = vector.cropped(toPixels: bounds, rasterSize: CGSize(width: raster.width, height: raster.height)) {
            v = cropped
        }
        logoSource = nil
        logoCG = nil
        logoVersion = UUID()
        logoVector = v
        logoNote = nil
        logo = v.full
        logoMask = nil
        logoHasTransparency = true
        logoBackground = nil
        logoAspect = v.aspect
        logoColors = LogoProcessor.rasterize(v.full).map(LogoProcessor.colors) ?? []
        return true
    }

    private func setSource(_ cg: CGImage) {
        logoSource = cg
        let info = LogoProcessor.analyze(cg)
        logoHasTransparency = info.hasTransparency
        logoBackground = info.background
        processLogo()
    }

    /// Applies background removal (when needed and enabled) and trims empty margins.
    func processLogo() {
        guard let src = logoSource else { return }
        var out = src
        if !logoHasTransparency, removeLogoBackground, let bg = logoBackground,
           let cleaned = LogoProcessor.removeBackground(src, background: bg) {
            out = cleaned
        }
        out = LogoProcessor.trim(out) ?? out
        logo = NSImage(cgImage: out, size: NSSize(width: out.width, height: out.height))
        logoCG = out
        logoVersion = UUID()
        let mask = LogoProcessor.knockout(out, key: logoBackground ?? RGB(255, 255, 255)) ?? out
        logoMask = NSImage(cgImage: mask, size: NSSize(width: mask.width, height: mask.height))
        logoAspect = CGFloat(out.width) / CGFloat(max(out.height, 1))
        logoColors = LogoProcessor.colors(out)
    }

    // MARK: Persistence

    var settings: BrandSettings {
        var s = BrandSettings()
        s.brandName = brandName; s.tagline = tagline; s.focus = focus; s.industry = industry; s.traits = traits
        s.useBaseColor = useBaseColor; s.baseHex = baseHex; s.snapToPantone = snapToPantone
        s.logoStyle = logoStyle; s.typeface = typeface
        s.removeLogoBackground = removeLogoBackground; s.showNameWithLogo = showNameWithLogo; s.logoDriven = logoDriven
        s.recolorLogo = recolorLogo
        s.concepts = concepts; s.selectedID = selectedID
        return s
    }

    func restore(_ s: BrandSettings) {
        brandName = s.brandName; tagline = s.tagline; focus = s.focus; industry = s.industry; traits = s.traits
        useBaseColor = s.useBaseColor; baseHex = s.baseHex; snapToPantone = s.snapToPantone
        logoStyle = s.logoStyle; typeface = s.typeface
        removeLogoBackground = s.removeLogoBackground; showNameWithLogo = s.showNameWithLogo; logoDriven = s.logoDriven
        recolorLogo = s.recolorLogo
        concepts = s.concepts; selectedID = s.selectedID
    }

    // MARK: Typography

    /// Resolved font for mockups and the logo wordmark.
    var font: (design: Font.Design, weight: Font.Weight, width: Font.Width) {
        let t = BrandEngine.typeSuggestion(traits)
        switch typeface {
        case .suggested: return (t.design, t.weight, t.width)
        case .sans: return (.default, .bold, .standard)
        case .serif: return (.serif, .semibold, .standard)
        case .rounded: return (.rounded, .bold, .standard)
        case .mono: return (.monospaced, .bold, .standard)
        case .condensed: return (.default, .heavy, .condensed)
        }
    }

    func font(size: CGFloat, weight: Font.Weight? = nil) -> Font {
        let f = font
        return .system(size: size, weight: weight ?? f.weight, design: f.design).width(f.width)
    }

    var paletteColors: [PaletteColor] {
        guard let c = selected else { return [] }
        return BrandRole.allCases.map { PaletteColor(hex: c.hex($0), sid: c[$0].sid) }
    }
    var roleNames: [String] { BrandRole.allCases.map(\.title) }
}
