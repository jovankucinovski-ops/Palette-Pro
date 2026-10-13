import SwiftUI
import UniformTypeIdentifiers

struct BuilderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    controls
                    HStack(spacing: 0) {
                        ForEach(Array(model.current.colors.enumerated()), id: \.element.id) { i, c in
                            ColorColumn(color: c, index: i, dense: model.current.colors.count > 7)
                        }
                    }
                    .frame(height: max(340, geo.size.height * 0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

                    Label("Press Space to generate. Lock the colors you like and they stay put. Drag a color to reorder, or drop one in from the Library.",
                          systemImage: "keyboard")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    GroupBox {
                        ContrastGrid(hexes: model.current.colors.map(\.hex))
                            .padding(6)
                    } label: {
                        Label("Contrast Check", systemImage: "circle.lefthalf.filled")
                    }
                    Text("Text color (columns) on background (rows). AA needs 4.5:1 for body text and 3:1 for large headings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
        .navigationTitle("Palette")
        .navigationSubtitle(model.current.name)
        .toolbar { toolbar }
    }

    private var header: some View {
        @Bindable var model = model
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            TextField("Palette name", text: $model.current.name)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .bold))
                .fixedSize()
            Label(model.isSaved ? (model.isDirty ? "Edited" : "Saved") : "Not saved",
                  systemImage: model.isSaved && !model.isDirty ? "checkmark.circle.fill" : "circle.dashed")
                .font(.callout)
                .foregroundStyle(model.isSaved && !model.isDirty ? .green : .secondary)
            Spacer()
        }
    }

    private var controls: some View {
        @Bindable var model = model
        return HStack(spacing: 18) {
            Picker("Harmony", selection: $model.settings.harmony) {
                ForEach(Harmony.allCases) { Text($0.title).tag($0) }
            }
            .fixedSize()
            Picker("Mood", selection: $model.settings.mood) {
                ForEach(Mood.allCases) { Text($0.title).tag($0) }
            }
            .fixedSize()
            Divider().frame(height: 18)
            Toggle("Snap to Pantone", isOn: Binding(get: { model.settings.snap }, set: { model.setSnap($0) }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Replace each generated color with its nearest Pantone")
            Picker("Match against", selection: $model.settings.matchLib) {
                ForEach(MatchLib.allCases) { Text($0.title).tag($0) }
            }
            .fixedSize()
            Spacer()
        }
        .onChange(of: model.settings.harmony) { model.generate() }
        .onChange(of: model.settings.mood) { model.generate() }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            Button { model.generate() } label: {
                Label("Generate", systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
            }
            .help("Generate new colors (Space)")
            Button { model.addGeneratedColor() } label: {
                Label("Add Color", systemImage: "plus")
            }
            .disabled(model.current.colors.count >= maxPaletteColors)
            .help("Add a color (⌥⌘N)")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { model.savePalette() } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .help("Save to My Palettes (⌘S)")
            Button { model.export(name: model.current.name, colors: model.current.colors) } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export (⌘E)")
            Menu {
                Button("New Palette", systemImage: "plus.square") { model.newPalette() }
                Button("Add to macOS Colors", systemImage: "paintpalette") {
                    model.installInColorPicker(name: model.current.name, colors: model.current.colors)
                }
                Button("Open in Brand Studio", systemImage: "sparkles.rectangle.stack") {
                    model.brand.adopt(palette: model.current.colors.map(\.hex), name: model.current.name)
                    model.destination = .brand
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
}

struct ColorColumn: View {
    @Environment(AppModel.self) private var model
    let color: PaletteColor
    let index: Int
    let dense: Bool
    @State private var hovering = false
    @State private var hexText = ""
    @State private var targeted = false

    var body: some View {
        let rgb = ColorMath.rgb(color.hex)
        let fg = Color(hex: ColorMath.readableOn(rgb))
        let m = model.pantone(for: color)

        ZStack(alignment: .top) {
            Rectangle().fill(Color(rgb: rgb))
            if color.locked && !hovering {
                Image(systemName: "lock.fill").font(.system(size: 13)).padding(.top, 16).foregroundStyle(fg.opacity(0.8))
            }
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                tools
                    .opacity(hovering ? 1 : 0)
                TextField("", text: $hexText)
                    .textFieldStyle(.plain)
                    .font(.system(size: dense ? 17 : 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .onSubmit(commitHex)
                    .accessibilityLabel("Hex value of color \(index + 1)")
                Button { m.exact ? model.inspect(.swatch(m.swatch.id)) : model.snapToPantone(color.id) } label: {
                    VStack(spacing: 2) {
                        Text("\(m.exact ? "" : "≈ ")\(m.swatch.title)").font(.system(size: dense ? 10 : 11.5, weight: .semibold))
                        if !m.swatch.name.isEmpty { Text(m.swatch.name).font(.system(size: dense ? 10 : 11)) }
                        if !m.exact { Text(String(format: "ΔE %.1f", m.dE)).font(.system(size: 10, design: .monospaced)).opacity(0.75) }
                    }
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(m.exact ? "Exact Pantone color. Click for details." : String(format: "Nearest Pantone (ΔE %.1f). Click to snap to it.", m.dE))
                .opacity(0.9)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.bottom, 22)
        }
        .overlay(alignment: .leading) {
            if targeted { Rectangle().fill(fg).frame(width: 3) }
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .onDrag {
            model.draggingColorID = color.id
            return NSItemProvider(object: color.hex as NSString)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let text = items.first else { return false }
            if let id = model.draggingColorID, let dragged = model.current.colors.first(where: { $0.id == id }), dragged.hex == text {
                model.move(id, to: index)
            } else if let hex = ColorMath.parseHex(text) {
                let sid = model.library.swatches(in: model.settings.matchLib).first { $0.hex == hex }?.id
                model.addToPalette(hex: hex, sid: sid, at: index)
            }
            model.draggingColorID = nil
            return true
        } isTargeted: { targeted = $0 }
        .contextMenu {
            Button(color.locked ? "Unlock" : "Lock") { model.toggleLock(color.id) }
            Button("Copy HEX") { model.copy(color.hex) }
            Button("Show Details") { model.inspect(color) }
            if !m.exact { Button("Snap to \(m.swatch.title)") { model.snapToPantone(color.id) } }
            Divider()
            Button("Move Left") { model.move(color.id, to: index - 1) }.disabled(index == 0)
            Button("Move Right") { model.move(color.id, to: index + 1) }.disabled(index == model.current.colors.count - 1)
            Divider()
            Button("Remove", role: .destructive) { model.remove(color.id) }.disabled(model.current.colors.count <= 1)
        }
        .onAppear { hexText = String(color.hex.dropFirst()) }
        .onChange(of: color.hex) { hexText = String(color.hex.dropFirst()) }
    }

    private var tools: some View {
        VStack(spacing: 2) {
            toolButton("xmark", "Remove") { model.remove(color.id) }
                .disabled(model.current.colors.count <= 1)
            toolButton("info.circle", "Details") { model.inspect(color) }
            ColorPicker("", selection: Binding(get: { Color(hex: color.hex) }, set: { c in
                if let h = c.hexString { model.setHex(color.id, h) }
            }), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 34, height: 30)
            .help("Color picker")
            toolButton("doc.on.doc", "Copy HEX") { model.copy(color.hex) }
            toolButton(color.locked ? "lock.fill" : "lock.open", color.locked ? "Unlock" : "Lock") { model.toggleLock(color.id) }
        }
    }

    private func toolButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 34, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel("\(help) color \(index + 1)")
    }

    private func commitHex() {
        if let h = ColorMath.parseHex(hexText) {
            model.setHex(color.id, h)
        } else {
            hexText = String(color.hex.dropFirst())
            model.showToast("That isn’t a valid hex color. Try something like F6EB61.")
        }
    }
}

struct ContrastGrid: View {
    let hexes: [String]

    var body: some View {
        let fgs = hexes.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } } + ["#FFFFFF", "#111111"].filter { !hexes.contains($0) }
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Color.clear.frame(width: 26, height: 22)
                    ForEach(fgs, id: \.self) { f in
                        RoundedRectangle(cornerRadius: 5).fill(Color(hex: f)).frame(width: 64, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.1)))
                            .help("Text \(f)")
                    }
                }
                ForEach(Array(hexes.enumerated()), id: \.offset) { _, bg in
                    GridRow {
                        RoundedRectangle(cornerRadius: 5).fill(Color(hex: bg)).frame(width: 26, height: 64)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.1)))
                        ForEach(fgs, id: \.self) { fg in cell(bg: bg, fg: fg) }
                    }
                }
            }
        }
    }

    @ViewBuilder private func cell(bg: String, fg: String) -> some View {
        if bg == fg {
            RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.1)).frame(width: 64, height: 64)
        } else {
            let r = ColorMath.contrast(bg, fg), g = ColorMath.grade(r)
            VStack(spacing: 4) {
                Text("Aa").font(.system(size: 19, weight: .bold)).foregroundStyle(Color(hex: fg))
                Text(String(format: "%.1f %@", r, g == "AA Large" ? "AA lg" : g))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: ColorMath.readableOn(ColorMath.rgb(bg))).opacity(g == "Fail" ? 0.6 : 0.9))
            }
            .frame(width: 64, height: 64)
            .background(Color(hex: bg), in: RoundedRectangle(cornerRadius: 8))
            .help("\(fg) text on \(bg): \(String(format: "%.2f", r)):1 (\(g))")
        }
    }
}
