import SwiftUI
import UniformTypeIdentifiers

struct MatchView: View {
    @Environment(AppModel.self) private var model
    @State private var dropTargeted = false

    var body: some View {
        HSplitView {
            matchPane
                .frame(minWidth: 360, idealWidth: 460)
            imagePane
                .frame(minWidth: 360)
        }
        .navigationTitle("Match")
        .navigationSubtitle("Find the closest Pantone to any color")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { pickFromScreen() } label: { Label("Pick from Screen", systemImage: "eyedropper") }
                    .help("Sample any pixel on your screen")
                Button { chooseImage() } label: { Label("Choose Image", systemImage: "photo") }
                    .help("Extract a palette from an image")
            }
        }
        .onPasteCommand(of: [.image, .png, .tiff, .fileURL]) { providers in load(providers) }
    }

    // MARK: Colour matching

    private var matchPane: some View {
        @Bindable var model = model
        let matches = model.library.nearest(model.matchHex, k: 12, in: model.settings.matchLib)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: model.matchHex))
                    .frame(width: 120, height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.1)))
                    .draggable(model.matchHex)
                    .dropDestination(for: String.self) { items, _ in
                        guard let hex = items.first.flatMap(ColorMath.parseHex) else { return false }
                        model.matchHex = hex
                        return true
                    }
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 12) {
                    GridRow {
                        Text("Color").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        HexField(hex: model.matchHex) { model.matchHex = $0 }
                    }
                    GridRow {
                        Text("Match against").foregroundStyle(.secondary)
                        Picker("Match against", selection: $model.settings.matchLib) {
                            ForEach(MatchLib.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    GridRow {
                        Color.clear.frame(width: 1, height: 1)
                        Button { pickFromScreen() } label: { Label("Pick from Screen", systemImage: "eyedropper") }
                    }
                }
            }
            .padding(20)

            Text("Ranked by CIEDE2000 ΔE. Under 1 looks identical; under 2.5 is very close.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            List(matches, id: \.swatch.id) { m in
                MatchRow(match: m)
            }
            .listStyle(.inset)
            .alternatingRowBackgrounds()
        }
    }

    // MARK: Image extraction

    private var imagePane: some View {
        @Bindable var model = model
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Palette from an Image").font(.title3.weight(.semibold))
                Text("Drop a photo, logo or moodboard, or paste one with ⌘V. Click the image to match a single pixel.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let cg = model.matchImage {
                    Image(decorative: cg, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 360)
                        .overlay {
                            GeometryReader { geo in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture(coordinateSpace: .local) { p in
                                        guard let hex = model.samplePixel(x: p.x / geo.size.width, y: p.y / geo.size.height) else { return }
                                        model.matchHex = hex
                                        model.showToast("Sampled \(hex)", swatch: hex)
                                    }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onHover { inside in if inside { NSCursor.crosshair.push() } else { NSCursor.pop() } }
                        .frame(maxWidth: .infinity)

                    HStack {
                        Stepper("\(model.extractCount) colors", value: $model.extractCount, in: 3...10)
                            .onChange(of: model.extractCount) { model.extractColors() }
                        Button("Re-extract", systemImage: "arrow.clockwise") { model.extractColors() }
                        Spacer()
                        Button("Use Colors") { model.paletteFromImage(snap: false) }
                        Button("Use Pantone Matches") { model.paletteFromImage(snap: true) }
                            .buttonStyle(.borderedProminent)
                    }

                    GeometryReader { geo in
                        let total = model.extracted.reduce(0) { $0 + max($1.share, 0.04) }
                        HStack(spacing: 0) {
                            ForEach(model.extracted) { e in
                                Rectangle().fill(Color(hex: e.hex))
                                    .frame(width: geo.size.width * max(e.share, 0.04) / total)
                                    .onTapGesture { model.matchHex = e.hex }
                                    .help("\(e.hex) · \(Int((e.share * 100).rounded()))%")
                            }
                        }
                    }
                    .frame(height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                        ForEach(model.extracted) { e in
                            let m = model.library.nearest1(e.hex, in: model.settings.matchLib)
                            Button { model.matchHex = e.hex } label: {
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 6).fill(Color(hex: e.hex)).frame(width: 34, height: 34)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(e.hex).font(.system(.callout, design: .monospaced).weight(.semibold))
                                        Text("≈ \(m.swatch.code) \(m.swatch.name)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        Text("\(Int((e.share * 100).rounded()))% of image").font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                dropZone
            }
            .padding(20)
        }
    }

    private var dropZone: some View {
        Button { chooseImage() } label: {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus").font(.system(size: 28)).foregroundStyle(.secondary)
                Text(model.matchImage == nil ? "Drop an image here or click to choose" : "Drop another image")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: model.matchImage == nil ? 200 : 90)
            .background(dropTargeted ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(dropTargeted ? Color.accentColor : .secondary.opacity(0.5)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL, .image], isTargeted: $dropTargeted) { providers in load(providers) }
    }

    // MARK: Actions

    private func pickFromScreen() {
        model.pickFromScreen { hex in model.matchHex = hex }
    }

    private func chooseImage() {
        if let url = FilePanels.open(types: [.image]), let img = NSImage(contentsOf: url) { model.loadImage(img) }
    }

    @discardableResult
    private func load(_ providers: [NSItemProvider]) -> Bool {
        guard let p = providers.first else { return false }
        if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url, let img = NSImage(contentsOf: url) else { return }
                DispatchQueue.main.async { model.loadImage(img) }
            }
            return true
        }
        if p.canLoadObject(ofClass: NSImage.self) {
            _ = p.loadObject(ofClass: NSImage.self) { obj, _ in
                guard let img = obj as? NSImage else { return }
                DispatchQueue.main.async { model.loadImage(img) }
            }
            return true
        }
        return false
    }
}

struct MatchRow: View {
    @Environment(AppModel.self) private var model
    let match: Match

    var body: some View {
        let s = match.swatch
        let q = ColorMath.matchQuality(match.dE)
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6).fill(s.color).frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title).font(.body.weight(.semibold))
                Text([s.name, model.library.collectionName(s.coll), s.hex].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "ΔE %.2f", match.dE)).font(.system(.callout, design: .monospaced).weight(.semibold))
                Text(q).font(.caption).foregroundStyle(match.dE < 2.5 ? .green : .secondary)
            }
            Button { model.addToPalette(hex: s.hex, sid: s.id) } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless)
                .help("Add to palette")
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { model.inspect(.swatch(s.id)) }
        .contextMenu { SwatchMenu(swatch: s) }
        .draggable(s.hex)
    }
}
