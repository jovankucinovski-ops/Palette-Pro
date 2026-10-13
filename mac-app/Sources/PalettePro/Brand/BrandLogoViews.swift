import SwiftUI
import UniformTypeIdentifiers

/// Checkerboard backdrop that makes transparent areas of a logo visible.
/// Light by default, as in design apps; dark for white or pale logos.
struct Checkerboard: View {
    var dark = false
    var square: CGFloat = 8

    var body: some View {
        Canvas { ctx, size in
            let cols = Int(size.width / square) + 1, rows = Int(size.height / square) + 1
            for r in 0..<rows {
                for c in 0..<cols where (r + c).isMultiple(of: 2) {
                    ctx.fill(Path(CGRect(x: CGFloat(c) * square, y: CGFloat(r) * square, width: square, height: square)),
                             with: .color(Color(white: dark ? 0.24 : 0.9)))
                }
            }
        }
        .background(Color(white: dark ? 0.18 : 1))
    }
}

/// Drop target and buttons for importing the brand's logo.
struct LogoWell: View {
    @Environment(AppModel.self) private var model
    @State private var targeted = false

    var body: some View {
        let brand = model.brand
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Checkerboard(dark: brand.logoIsLight)
                if let image = brand.logo {
                    Image(nsImage: image).resizable().interpolation(.high).scaledToFit().padding(12)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 24)).foregroundStyle(.secondary)
                        Text("Drop your logo here").font(.callout.weight(.medium))
                        Text("A PNG with a transparent background works best").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(targeted ? Color.accentColor : .primary.opacity(brand.hasLogo ? 0.1 : 0.25),
                                  style: StrokeStyle(lineWidth: targeted ? 2 : 1, dash: brand.hasLogo ? [] : [5, 4]))
            )
            .contentShape(Rectangle())
            .onTapGesture { if !brand.hasLogo { choose() } }
            .overlay(alignment: .topTrailing) {
                if brand.isVectorLogo {
                    Label("Vector", systemImage: "scribble.variable")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule())
                        .padding(6)
                        .help("This logo is an SVG and stays sharp at any size and in PDF and SVG exports")
                }
            }
            .onDrop(of: [.fileURL, .image], isTargeted: $targeted) { load($0) }
            .help(brand.hasLogo ? "Drop another image to replace the logo" : "Drop a PNG, JPEG, PDF or SVG logo, or click to choose")
            .accessibilityLabel(brand.hasLogo ? "Brand logo" : "Add a logo")

            HStack {
                Button(brand.hasLogo ? "Replace…" : "Choose…") { choose() }
                Button("Paste") { paste() }
                Spacer()
                if brand.hasLogo {
                    Button("Remove", role: .destructive) { brand.removeLogo() }
                }
            }
            .controlSize(.small)

            if let note = brand.logoNote {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func report(_ ok: Bool) {
        if ok {
            let kind = model.brand.isVectorLogo ? "Vector logo added" : "Logo added"
            model.showToast(model.brand.logoDriven ? "\(kind). Palettes now start from its colors." : kind)
        } else {
            model.showToast("Couldn’t read that file. Try exporting your logo as SVG or PNG.")
        }
    }

    private func use(_ url: URL) { report(model.brand.importLogo(fileURL: url)) }

    private func use(_ image: NSImage) {
        if model.brand.importLogo(image) {
            model.showToast(model.brand.logoDriven ? "Logo added. Palettes now start from its colors." : "Logo added")
        } else {
            model.showToast("Couldn’t read that image. Try exporting your logo as a PNG.")
        }
    }

    private func choose() {
        guard let url = FilePanels.open(types: LogoProcessor.fileTypes) else { return }
        use(url)
    }

    private func paste() {
        let pb = NSPasteboard.general
        // SVG copied from Figma, Illustrator or a text editor arrives as SVG data or plain markup.
        let svgData = pb.data(forType: NSPasteboard.PasteboardType("public.svg-image"))
            ?? pb.string(forType: .string).flatMap { $0.range(of: "<svg", options: .caseInsensitive) != nil ? Data($0.utf8) : nil }
        if let svgData {
            report(model.brand.importSVG(svgData))
            return
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], let url = urls.first {
            use(url)
            return
        }
        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            use(image)
        } else {
            model.showToast("There’s no image on the clipboard.")
        }
    }

    private func load(_ providers: [NSItemProvider]) -> Bool {
        guard let p = providers.first else { return false }
        if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async {
                    if let url { use(url) } else { report(false) }
                }
            }
            return true
        }
        guard p.canLoadObject(ofClass: NSImage.self) else { return false }
        _ = p.loadObject(ofClass: NSImage.self) { obj, _ in
            guard let image = obj as? NSImage else { return }
            DispatchQueue.main.async { use(image) }
        }
        return true
    }
}

/// The colors found in the imported logo, with values to hand to a printer or developer.
struct LogoColorsCard: View {
    @Environment(AppModel.self) private var model
    let concept: BrandConcept

    var body: some View {
        let brand = model.brand
        HStack(alignment: .top, spacing: 20) {
            if let image = brand.logo {
                ZStack {
                    Checkerboard(dark: brand.logoIsLight)
                    Image(nsImage: image).resizable().interpolation(.high).scaledToFit().padding(14)
                }
                .frame(width: 210, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.08)))
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Your logo’s colors", systemImage: "eyedropper.halffull").font(.headline)
                    if brand.isVectorLogo {
                        Text("SVG").font(.caption2.weight(.bold)).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()
                    Button("Export Logo Files…", systemImage: "square.and.arrow.up") { model.exportLogoPackage() }
                        .controlSize(.small)
                        .help(brand.isVectorLogo ? "Color, dark and white versions as SVG, PDF and PNG" : "Color, dark and white versions as PNG")
                }
                Text("Use these values when you hand the logo to a printer or developer. Pantone values are the nearest matches, so check them against a printed guide.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
                    GridRow {
                        ForEach(["", "HEX", "Pantone C", "Pantone U", "CMYK ≈", "Share"], id: \.self) {
                            Text($0).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(brand.logoColors) { c in
                        let color = BrandColor(hex: c.hex)
                        GridRow {
                            RoundedRectangle(cornerRadius: 4).fill(color.color).frame(width: 20, height: 20)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.12)))
                            Text(c.hex).font(.system(.callout, design: .monospaced))
                            Text(BrandEngine.pantoneLabel(color)).font(.callout)
                            Text(BrandEngine.pantoneLabel(color, in: .uncoated)).font(.callout)
                            Text(ColorMath.cmyk(ColorMath.rgb(c.hex)).map(String.init).joined(separator: " ")).font(.system(.callout, design: .monospaced))
                            Text("\(Int((c.share * 100).rounded()))%").font(.callout).foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                        .contextMenu {
                            Button("Copy HEX") { model.copy(c.hex) }
                            Button("Add to Palette") { model.addToPalette(hex: c.hex) }
                            Button("Show Details") { model.inspect(.custom(c.hex)) }
                        }
                    }
                }

                if let main = brand.logoMainHex {
                    let dE = ColorMath.deltaE(ColorMath.lab(ColorMath.rgb(main)), ColorMath.lab(ColorMath.rgb(concept.hex(.primary))))
                    if dE < 3 {
                        Label("This palette’s Primary matches your logo.", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    } else {
                        HStack {
                            Label(String(format: "This palette’s Primary is ΔE %.0f away from your logo’s main color.", dE), systemImage: "info.circle")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            if !brand.logoDriven {
                                Button("Base Palettes on My Logo") { brand.logoDriven = true }
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
