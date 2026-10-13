import AppKit

/// Writes a folder of ready-to-use logo files: full color, dark and white versions
/// (SVG + PDF + PNG for vector logos, PNG for bitmap logos) and a PNG on the primary color.
@MainActor
enum LogoPackage {
    static func export(brand: BrandModel, concept: BrandConcept, into parent: URL) throws -> URL {
        guard let logo = brand.logo else { throw CocoaError(.fileNoSuchFile) }
        let slug = Exporter.slug(brand.brandName)
        let folder = uniqueFolder(in: parent, named: "\(brand.brandName.isEmpty ? "Brand" : brand.brandName) logo")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let versions: [(suffix: String, hex: String?)] = [("color", nil), ("dark", concept.hex(.dark)), ("white", "#FFFFFF")]
        for v in versions {
            let base = folder.appendingPathComponent("\(slug)-logo-\(v.suffix)")
            if let vector = brand.logoVector {
                let svg = v.hex.map { vector.oneColorSVG($0) } ?? (brand.logoSVG(for: concept) ?? vector.svg)
                try Data(svg.utf8).write(to: base.appendingPathExtension("svg"))
                let art = v.hex.map { vector.oneColorPrint($0) } ?? (brand.logoArt(for: concept) ?? vector.full)
                if let pdf = pdf(art) { try pdf.write(to: base.appendingPathExtension("pdf")) }
                if let png = png(art) { try png.write(to: base.appendingPathExtension("png")) }
            } else {
                if let png = png(v.hex == nil ? (brand.logoArt(for: concept) ?? logo) : (brand.logoMask ?? logo), tint: v.hex) {
                    try png.write(to: base.appendingPathExtension("png"))
                }
            }
        }

        // Reversed logo on the primary color, with breathing room: handy for avatars and slides.
        let light = concept.hex(.light)
        let reversed: NSImage = brand.logoVector?.oneColor(light, on: concept.hex(.primary)) ?? (brand.logoMask ?? logo)
        if let png = png(reversed, tint: brand.logoVector == nil ? light : nil, background: concept.hex(.primary), padding: 0.18) {
            try png.write(to: folder.appendingPathComponent("\(slug)-logo-on-primary.png"))
        }
        try readme(brand: brand, concept: concept).write(to: folder.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        return folder
    }

    private static func uniqueFolder(in parent: URL, named name: String) -> URL {
        var url = parent.appendingPathComponent(name, isDirectory: true), n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = parent.appendingPathComponent("\(name) \(n)", isDirectory: true)
            n += 1
        }
        return url
    }

    /// Vector PDF of the artwork, 1000 pt on its long side.
    static func pdf(_ art: NSImage) -> Data? {
        let s = art.size, scale = 1000 / max(s.width, s.height)
        var box = CGRect(x: 0, y: 0, width: s.width * scale, height: s.height * scale)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        ctx.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        art.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    /// Transparent sRGB PNG, 2048 px on the long side of the artwork. `tint` fills the artwork's
    /// shape with one color; `background` and `padding` (fraction of the long side) frame it.
    static func png(_ art: NSImage, tint: String? = nil, background: String? = nil, padding: CGFloat = 0, longSide: CGFloat = 2048) -> Data? {
        let s = art.size
        guard s.width > 0, s.height > 0 else { return nil }
        let inner = longSide / (1 + 2 * padding)
        let scale = inner / max(s.width, s.height)
        let artW = s.width * scale, artH = s.height * scale
        let pad = inner * padding
        let w = Int((artW + 2 * pad).rounded()), h = Int((artH + 2 * pad).rounded())
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        func context() -> CGContext? {
            CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }
        let artRect = CGRect(x: pad, y: pad, width: artW, height: artH)
        func cgColor(_ hex: String) -> CGColor {
            let c = ColorMath.rgb(hex)
            return CGColor(colorSpace: space, components: [c.r / 255, c.g / 255, c.b / 255, 1])!
        }

        // Draw the artwork on its own layer so a tint only affects the logo, not the background.
        guard let layer = context() else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: layer, flipped: false)
        art.draw(in: artRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        if let tint {
            layer.setBlendMode(.sourceIn)
            layer.setFillColor(cgColor(tint))
            layer.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
        guard let artImage = layer.makeImage(), let out = context() else { return nil }
        if let background {
            out.setFillColor(cgColor(background))
            out.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
        out.draw(artImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let final = out.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: final).representation(using: .png, properties: [:])
    }

    private static func readme(brand: BrandModel, concept: BrandConcept) -> String {
        let name = brand.brandName.isEmpty ? "Brand" : brand.brandName
        var lines = ["\(name) logo files — made with Palette Pro", ""]
        lines.append(brand.isVectorLogo
            ? "SVG and PDF files are vector: use them for print, signage and anywhere the logo is scaled. PNGs are 2048 px with transparent backgrounds."
            : "PNGs are 2048 px with transparent backgrounds. For print, ask your designer for a vector (SVG or PDF) version.")
        if brand.logoVector?.hasKnockouts == true {
            lines.append("The white details are cut out in the one-color versions. The SVGs keep the cut-outs as vector masks; the one-color PDFs draw them from a high-resolution mask.")
        }
        lines += ["", "-color: full color\(brand.recolorLogo ? " in the \(concept.name) palette" : ""), for light backgrounds",
                  "-dark: one color (\(concept.hex(.dark))), for light backgrounds and single-color printing",
                  "-white: one color (white), for dark or photo backgrounds",
                  "-on-primary: the logo reversed on the primary color \(concept.hex(.primary))", "", "Logo colors:"]
        for c in brand.logoColors {
            let color = BrandColor(hex: c.hex)
            lines.append("  \(c.hex)   \(BrandEngine.pantoneLabel(color)) / \(BrandEngine.pantoneLabel(color, in: .uncoated))   CMYK ≈ \(ColorMath.cmyk(ColorMath.rgb(c.hex)).map(String.init).joined(separator: " "))")
        }
        lines += ["", "Pantone values are the nearest matches to screen colors. Approve print color against a physical Pantone guide."]
        return lines.joined(separator: "\n") + "\n"
    }
}

extension AppModel {
    /// Asks for a destination folder and writes the logo package there.
    func exportLogoPackage() {
        guard let concept = brand.selected, brand.hasLogo else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose where to save the logo files. A new folder is created inside it."
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        do {
            let folder = try LogoPackage.export(brand: brand, concept: concept, into: dir)
            showToast("Saved logo files to “\(folder.lastPathComponent)”", actionTitle: "Show") {
                NSWorkspace.shared.activateFileViewerSelecting([folder])
            }
        } catch {
            showToast("Couldn’t export the logo files: \(error.localizedDescription)")
        }
    }
}
