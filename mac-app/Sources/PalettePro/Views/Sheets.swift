import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export

struct ExportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let target: ExportTarget
    @State private var preview: NSImage?

    var body: some View {
        @Bindable var model = model
        let format = model.settings.exportFormat
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                List(ExportFormat.allCases, selection: Binding(get: { format }, set: { if let f = $0 { model.settings.exportFormat = f } })) { f in
                    Label(f.title, systemImage: symbol(f)).tag(f)
                }
                .listStyle(.sidebar)
                .frame(width: 220)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Export “\(target.name)”").font(.title2.weight(.semibold))
                    if let note = format.note {
                        Text(note).font(.callout).foregroundStyle(.secondary)
                    }
                    content(format)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(20)
            }
            Divider()
            HStack {
                if format == .clr {
                    Button("Add to macOS Colors") {
                        model.installInColorPicker(name: target.name, entries: target.entries)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if format != .ase && format != .clr {
                    Button(format == .png ? "Copy Image" : "Copy") { copy(format) }
                }
                Button("Save…") { save(format) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 820, height: 560)
        .task(id: format) {
            preview = format == .png ? PaletteImage.render(name: target.name, entries: target.entries) : nil
        }
    }

    @ViewBuilder private func content(_ f: ExportFormat) -> some View {
        switch f {
        case .png:
            if let preview {
                Image(nsImage: preview).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            } else {
                ProgressView()
            }
        case .ase, .clr:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(target.entries, id: \.self) { e in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: e.hex)).frame(width: 22, height: 22)
                        Text(e.role.map { "\($0) · " } ?? "").foregroundStyle(.secondary) + Text(e.exact ? e.label : e.hex)
                        Spacer()
                        Text(e.hex).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
            }
        default:
            ScrollView {
                Text(Exporter.text(f, name: target.name, entries: target.entries) ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func symbol(_ f: ExportFormat) -> String {
        switch f {
        case .css, .scss, .tailwind4, .tailwind3: "curlybraces"
        case .swiftui: "swift"
        case .json: "doc.text"
        case .hex: "number"
        case .gpl: "paintbrush"
        case .ase: "a.square"
        case .clr: "paintpalette"
        case .png: "photo"
        }
    }

    private func data(_ f: ExportFormat) -> Data? {
        switch f {
        case .ase: Exporter.ase(name: target.name, entries: target.entries)
        case .clr: Exporter.clrData(name: target.name, entries: target.entries)
        case .png: PaletteImage.png(name: target.name, entries: target.entries)
        default: Exporter.text(f, name: target.name, entries: target.entries).map { Data($0.utf8) }
        }
    }

    private func copy(_ f: ExportFormat) {
        if f == .png, let img = preview {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([img])
            model.showToast("Copied the image")
        } else if let text = Exporter.text(f, name: target.name, entries: target.entries) {
            model.copy(text, label: f.title)
        }
    }

    private func save(_ f: ExportFormat) {
        guard let d = data(f) else { return }
        if let url = FilePanels.save(d, suggestedName: Exporter.slug(target.name), ext: f.ext) {
            model.showToast("Saved \(url.lastPathComponent)")
            dismiss()
        }
    }
}

/// Pantone-chip style image of a palette, used for PNG export.
struct PaletteImage: View {
    let name: String
    let entries: [ExportEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            Text(name).font(.system(size: 44, weight: .bold)).foregroundStyle(Color(hex: "#151515"))
            HStack(alignment: .top, spacing: 22) {
                ForEach(entries, id: \.self) { e in
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            Rectangle().fill(Color(hex: e.hex))
                            Text(e.hex).font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color(hex: ColorMath.readableOn(e.rgb)).opacity(0.9))
                                .padding(16)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            if let r = e.role { Text(r.uppercased()).font(.system(size: 14, weight: .semibold)).foregroundStyle(.gray) }
                            Text("PANTONE®").font(.system(size: 18, weight: .heavy))
                            Text((e.exact ? "" : "≈ ") + e.pantone).font(.system(size: 24, weight: .bold)).lineLimit(1).minimumScaleFactor(0.5)
                            Text(e.pantoneName.isEmpty ? " " : e.pantoneName).font(.system(size: 18)).foregroundStyle(.gray).lineLimit(1)
                        }
                        .foregroundStyle(Color(hex: "#151515"))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 150, alignment: .top)
                        .background(.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
                }
            }
        }
        .padding(56)
        .frame(width: 1600, height: 900, alignment: .topLeading)
        .background(Color(hex: "#F4F3EF"))
    }

    @MainActor static func render(name: String, entries: [ExportEntry]) -> NSImage? {
        let r = ImageRenderer(content: PaletteImage(name: name, entries: entries))
        r.scale = 1
        return r.nsImage
    }

    @MainActor static func png(name: String, entries: [ExportEntry]) -> Data? {
        guard let img = render(name: name, entries: entries), let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Import

struct ImportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var name = ""

    var body: some View {
        let parsed = model.parseColorList(text)
        VStack(alignment: .leading, spacing: 14) {
            Text("Import Colors").font(.title2.weight(.semibold))
            Text("Paste hex codes or Pantone numbers in any format, such as #F6EB61, 0F4C81, 185 C, 19-4052 TCX or Cool Gray 11 C. Up to \(maxPaletteColors) colors.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 150)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.12)))
            if !text.isEmpty {
                HStack(spacing: 2) {
                    ForEach(parsed.colors.prefix(maxPaletteColors)) { c in
                        Rectangle().fill(Color(hex: c.hex)).frame(height: 26)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("Found \(parsed.colors.count) colors" + (parsed.missed.isEmpty ? "" : ". Couldn’t read: " + parsed.missed.prefix(4).joined(separator: ", ")))
                    .font(.caption)
                    .foregroundStyle(parsed.missed.isEmpty ? Color.secondary : Color.orange)
            }
            TextField("Palette name", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Restore a Backup…") {
                    dismiss()
                    model.runRestore()
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Palette") {
                    let p = model.createPalette(name: name.trimmingCharacters(in: .whitespaces), colors: parsed.colors)
                    dismiss()
                    model.showToast("Created “\(p.name)” with \(p.colors.count) colors", actionTitle: "Open") { model.open(p) }
                    model.destination = .saved
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parsed.colors.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 520)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Matching") {
                Picker("Match colors against", selection: $model.settings.matchLib) {
                    ForEach(MatchLib.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Snap generated colors to Pantone", isOn: $model.settings.snap)
            }
            Section("Palette generator") {
                Picker("Default harmony", selection: $model.settings.harmony) {
                    ForEach(Harmony.allCases) { Text($0.title).tag($0) }
                }
                Picker("Default mood", selection: $model.settings.mood) {
                    ForEach(Mood.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Your library") {
                LabeledContent("Saved palettes", value: "\(model.palettes.count)")
                LabeledContent("Favorites", value: "\(model.favorites.count)")
                HStack {
                    Button("Show Data in Finder") {
                        model.saveNow()
                        NSWorkspace.shared.activateFileViewerSelecting([AppModel.stateURL])
                    }
                    Spacer()
                    Button("Back Up…") { model.runBackup() }
                    Button("Restore…") { model.runRestore() }
                }
            }
            Section {
                Text("PANTONE® is a trademark of Pantone LLC. Hex values are screen approximations from public sources. For print, check against a physical Pantone guide.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}
