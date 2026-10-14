import AppKit
import SwiftUI

/// Development aid: with PALETTE_PRO_SNAPSHOTS=<dir>, walks through every screen,
/// saves a PNG of the window for each, writes sample exports, then quits.
@MainActor
enum SnapshotRunner {
    static var directory: URL? {
        ProcessInfo.processInfo.environment["PALETTE_PRO_SNAPSHOTS"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    static func runIfRequested(_ model: AppModel) {
        guard let dir = directory else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // PALETTE_PRO_PASS=fusion runs only the Fusion checks (quicker, and fewer windows popping up).
        if ProcessInfo.processInfo.environment["PALETTE_PRO_PASS"] == "fusion" {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.isVisible && $0.canBecomeMain }?.setContentSize(NSSize(width: 1440, height: 900))
                await fusionPass(model, dir)
                NSApp.terminate(nil)
            }
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            // A second copy launched from the command line may not be brought forward; show its window.
            NSApp.activate(ignoringOtherApps: true)
            for w in NSApp.windows where w.styleMask.contains(.titled) && !w.isVisible { w.makeKeyAndOrderFront(nil) }
            try? await Task.sleep(for: .seconds(0.5))
            NSApp.windows.first { $0.isVisible && $0.canBecomeMain }?.setContentSize(NSSize(width: 1440, height: 900))

            model.libCollection = "all"
            await shot("01-library", dir)

            model.libQuery = "coral"
            model.inspect(.swatch("tcx/16-1546 TCX"))
            await shot("02-library-search-inspector", dir)
            model.libQuery = ""
            model.showInspector = false

            model.destination = .builder
            model.settings.snap = false
            await shot("03-palette", dir)

            model.savePalette()
            model.destination = .saved
            await shot("04-my-palettes", dir)

            model.destination = .match
            model.matchHex = "#0F4C81"
            if let img = sampleImage() { model.loadImage(img) }
            await shot("05-match", dir)

            model.destination = .brand
            model.brand.brandName = "Lumen"
            model.brand.tagline = "Light for everyday life"
            model.brand.suggest()
            for tab in BrandTab.allCases {
                model.brand.tab = tab
                await shot("06-brand-\(tab.rawValue)", dir)
            }
            renderIdeas(model, dir.appendingPathComponent("ideas-name.png"))

            // Imported logo: an opaque PNG-style image on white, so background removal is exercised.
            model.brand.brandName = "Northwind"
            let imported = model.brand.importLogo(sampleLogo())
            let logoReport = "imported=\(imported) transparent=\(model.brand.logoHasTransparency) background=\(model.brand.logoBackground.map { ColorMath.hex($0) } ?? "none") aspect=\(String(format: "%.2f", model.brand.logoAspect)) style=\(model.brand.logoStyle.rawValue) driven=\(model.brand.logoDriven) colors=\(model.brand.logoColors.map { "\($0.hex) \(Int($0.share * 100))%" }) concepts=\(model.brand.concepts.map(\.name)) primary=\(model.brand.selected?.hex(.primary) ?? "-") saved=\(FileManager.default.fileExists(atPath: BrandModel.logoURL.path))"
            try? logoReport.write(to: dir.appendingPathComponent("logo.txt"), atomically: true, encoding: .utf8)
            for tab in [BrandTab.ideas, .overview, .logo, .mockups] {
                model.brand.tab = tab
                await shot("15-logo-\(tab.rawValue)", dir)
            }
            renderIdeas(model, dir.appendingPathComponent("ideas-png.png"))
            if let c = model.brand.selected {
                try? BrandSheet.pdf(kit: BrandKit(model.brand, concept: c), brand: model.brand)?.write(to: dir.appendingPathComponent("brand-sheet-logo.pdf"))
            }
            if let logo = model.brand.logo, let cg = logo.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                try? LogoProcessor.png(cg)?.write(to: dir.appendingPathComponent("logo-processed.png"))
            }

            // Vector logo: an Illustrator-style SVG with classes, a white inner shape, a letter with a hole and padding.
            let svgURL = dir.appendingPathComponent("sample-logo.svg")
            try? sampleSVG.write(to: svgURL, atomically: true, encoding: .utf8)
            let svgImported = model.brand.importLogo(fileURL: svgURL)
            let vb = model.brand.logoVector.flatMap { SVGLogo.viewBox($0.svg) }
            var svgReport = "imported=\(svgImported) vector=\(model.brand.isVectorLogo) viewBox=\(vb.map { "\(SVGLogo.fmt($0.minX)) \(SVGLogo.fmt($0.minY)) \(SVGLogo.fmt($0.width)) \(SVGLogo.fmt($0.height))" } ?? "-") aspect=\(String(format: "%.2f", model.brand.logoAspect)) colors=\(model.brand.logoColors.map(\.hex)) savedSVG=\(FileManager.default.fileExists(atPath: BrandModel.svgURL.path)) savedPNG=\(FileManager.default.fileExists(atPath: BrandModel.logoURL.path))"
            if let c = model.brand.concepts.first {
                svgReport += "\nlogoConcept=" + BrandRole.allCases.map { "\($0.rawValue):\(c.hex($0))" }.joined(separator: " ")
            }
            for tab in [BrandTab.ideas, .logo, .mockups] {
                model.brand.tab = tab
                await shot("16-svg-\(tab.rawValue)", dir)
            }
            renderIdeas(model, dir.appendingPathComponent("ideas-svg.png"))
            if let c = model.brand.selected {
                try? BrandSheet.pdf(kit: BrandKit(model.brand, concept: c), brand: model.brand)?.write(to: dir.appendingPathComponent("brand-sheet-svg.pdf"))
                if let folder = try? LogoPackage.export(brand: model.brand, concept: c, into: dir) {
                    svgReport += "\npackage=" + ((try? FileManager.default.contentsOfDirectory(atPath: folder.path).sorted().joined(separator: ",")) ?? "")
                }
            }
            // Reload from disk as on next launch.
            let reloaded = BrandModel()
            reloaded.restore(model.brand.settings)
            reloaded.loadSavedLogo()
            svgReport += "\nreloaded vector=\(reloaded.isVectorLogo) style=\(reloaded.logoStyle.rawValue)"
            try? svgReport.write(to: dir.appendingPathComponent("svg.txt"), atomically: true, encoding: .utf8)

            await typePass(model, dir)

            NSApp.appearance = NSAppearance(named: .darkAqua)
            model.destination = .brand
            model.brand.tab = .overview
            await shot("07-brand-dark", dir)
            model.destination = .library
            model.libCollection = "coty"
            await shot("08-library-dark", dir)
            model.destination = .builder
            await shot("09-palette-dark", dir)
            NSApp.appearance = nil

            NSApp.appearance = NSAppearance(named: .aqua)
            model.destination = .library
            model.libCollection = "tcx"
            model.libSort = .hue
            await shot("11-library-light", dir)
            model.destination = .builder
            await shot("12-palette-light", dir)
            model.destination = .brand
            model.brand.tab = .mockups
            await shot("13-brand-mockups-light", dir)
            model.destination = .match
            await shot("14-match-light", dir)
            NSApp.appearance = nil

            model.export(name: model.current.name, colors: model.current.colors)
            await shot("10-export-sheet", dir)
            model.exportTarget = nil

            if let c = model.brand.selected {
                let kit = BrandKit(model.brand, concept: c)
                try? BrandSheet.pdf(kit: kit, brand: model.brand)?.write(to: dir.appendingPathComponent("brand-sheet.pdf"))
                let entries = model.exportEntries(model.brand.paletteColors, roles: model.brand.roleNames)
                try? PaletteImage.png(name: model.brand.brandName, entries: entries)?.write(to: dir.appendingPathComponent("palette.png"))
                try? Exporter.ase(name: model.brand.brandName, entries: entries).write(to: dir.appendingPathComponent("palette.ase"))
                try? Exporter.clrData(name: model.brand.brandName, entries: entries)?.write(to: dir.appendingPathComponent("palette.clr"))
                for f in ExportFormat.allCases {
                    if let t = Exporter.text(f, name: model.brand.brandName, entries: entries) {
                        try? t.write(to: dir.appendingPathComponent("export.\(f.rawValue).\(f.ext)"), atomically: true, encoding: .utf8)
                    }
                }
            }
            // Stress: hide the inspector while switching sections, repeatedly.
            for i in 0..<16 {
                model.inspect(.swatch("coated/185 C"))
                try? await Task.sleep(for: .milliseconds(90))
                model.showInspector = false
                model.destination = Destination.allCases[i % Destination.allCases.count]
                try? await Task.sleep(for: .milliseconds(i.isMultiple(of: 2) ? 30 : 160))
            }

            renderHelp(dir.appendingPathComponent("help.png"))

            // Logic checks: web-app backup restore and pasted Pantone codes.
            let web = ##"{"app":"swatchbook","palettes":[{"id":"abc","name":"From web","colors":[{"hex":"#F6EB61","sid":"coated/100 C"},{"hex":"#0F4C81","sid":null}],"createdAt":1791720000000,"updatedAt":1791720000000}],"favorites":["coated/185 C"]}"##
            let first = model.restore(Data(web.utf8))
            let second = model.restore(Data(web.utf8))
            let parsed = model.parseColorList("PANTONE 185 C\n19-4052 TCX\n#F6EB61, 0f4c81\nCool Gray 11 C\n7621C\nnot a color")
            let report = """
            restore first=\(first ?? -1) second=\(second ?? -1) favorites=\(model.favorites.sorted())
            restored=\(model.palettes.first.map { "\($0.name) \($0.colors.map { "\($0.hex)/\($0.sid ?? "-")" })" } ?? "none")
            parsed=\(parsed.colors.map { "\($0.hex)/\($0.sid ?? "-")" }) missed=\(parsed.missed)
            """
            try? report.write(to: dir.appendingPathComponent("logic.txt"), atomically: true, encoding: .utf8)

            model.saveNow()
            NSApp.terminate(nil)
        }
    }

    static func shot(_ name: String, _ dir: URL) async {
        try? await Task.sleep(for: .seconds(0.9))
        // Another app (or another copy of Palette Pro) may have hidden this one meanwhile; bring it back.
        if !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            for w in NSApp.windows where w.canBecomeMain { w.orderFrontRegardless() }
            try? await Task.sleep(for: .seconds(1))
        }
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) else {
            FileHandle.standardError.write(Data("snapshot \(name): no visible main window; windows=\(NSApp.windows.map { "\(type(of: $0)) visible=\($0.isVisible) main=\($0.canBecomeMain)" })\n".utf8))
            return
        }
        let target = window.attachedSheet ?? window
        guard let frameView = target.contentView?.superview else { return }
        let bounds = frameView.bounds
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        frameView.cacheDisplay(in: bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
    }

    static let sampleSVG = """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg id="Layer_1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 240" width="520px" height="240px">
      <defs><style>.cls-1{fill:#0b6e4f;}.cls-2{fill:#f4b400;}.cls-3{fill:#fff;}.cls-4{fill:#14213d;}</style></defs>
      <g transform="translate(40 40)">
        <path class="cls-1" d="M24 0h112c13.3 0 24 10.7 24 24v112c0 13.3-10.7 24-24 24H24C10.7 160 0 149.3 0 136V24C0 10.7 10.7 0 24 0z"/>
        <path class="cls-3" d="M80 36l40 44-40 44-40-44z"/>
        <circle class="cls-2" cx="152" cy="10" r="18"/>
      </g>
      <path class="cls-4" d="M230 160V80h22l34 48V80h20v80h-21l-35-49v49z"/>
      <path class="cls-4" fill-rule="evenodd" d="M360 78a42 42 0 1 1 0 84a42 42 0 1 1 0-84zm0 20a22 22 0 1 0 0 44a22 22 0 1 0 0-44z"/>
      <rect x="420" y="80" width="20" height="80" style="fill: rgb(20, 33, 61)"/>
    </svg>
    """

    private static func renderHelp(_ url: URL) {
        let r = ImageRenderer(content: HelpPage().frame(width: 760).background(Color(white: 0.12)).environment(\.colorScheme, .dark))
        r.scale = 1
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }

    /// The whole Ideas grid as one image (the window only shows part of it).
    private static func renderIdeas(_ model: AppModel, _ url: URL) {
        let view = BrandIdeasView().environment(model).padding(24).frame(width: 1180).background(Color(white: 0.12))
            .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: view)
        r.scale = 1
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }

    /// A sample wordmark logo drawn on an opaque white background.
    private static func sampleLogo() -> NSImage {
        NSImage(size: NSSize(width: 900, height: 360), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            NSColor(srgbRed: 0.12, green: 0.31, blue: 0.61, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 50, y: 70, width: 220, height: 220), xRadius: 48, yRadius: 48).fill()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: 105, y: 125, width: 110, height: 110)).fill()
            NSColor(srgbRed: 0.95, green: 0.55, blue: 0.16, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 215, y: 235, width: 80, height: 80)).fill()
            let text = NSAttributedString(string: "Northwind", attributes: [
                .font: NSFont.systemFont(ofSize: 104, weight: .heavy),
                .foregroundColor: NSColor(srgbRed: 0.11, green: 0.12, blue: 0.16, alpha: 1),
            ])
            text.draw(at: NSPoint(x: 300, y: 110))
            return true
        }
    }

    /// A simple test image with known color areas.
    private static func sampleImage() -> NSImage? {
        let size = NSSize(width: 600, height: 400)
        return NSImage(size: size, flipped: false) { _ in
            let cols: [(String, CGFloat)] = [("#F2C531", 150), ("#E4583E", 100), ("#0F4C81", 200), ("#88B04B", 90), ("#F4F3EF", 60)]
            var x: CGFloat = 0
            for (hex, w) in cols {
                let c = ColorMath.rgb(hex)
                NSColor(srgbRed: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1).setFill()
                NSRect(x: x, y: 0, width: w, height: size.height).fill()
                x += w
            }
            return true
        }
    }
}
