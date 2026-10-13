import AppKit
import Observation
import SwiftUI

struct ExtractedColor: Identifiable, Hashable {
    let id = UUID()
    let hex: String
    let share: Double
}

/// A palette (or brand) queued for the export sheet.
struct ExportTarget: Identifiable {
    let id = UUID()
    let name: String
    let entries: [ExportEntry]
}

struct PantoneMatch {
    let swatch: Swatch
    let dE: Double
    let exact: Bool
}

@Observable @MainActor
final class AppModel {
    let library = Library.shared

    var destination: Destination = .library
    var palettes: [Palette] = []
    var favorites: Set<String> = []
    var current: WorkingPalette
    var settings = AppSettings()

    // Library browsing
    var libQuery = ""
    var libCollection = "all"
    var libFamily: Family?
    var libSort: LibrarySort = .book

    // Inspector
    var inspector: InspectorItem?
    var showInspector = false

    // Match
    var matchHex = "#0F4C81"
    var matchImage: CGImage?
    var extracted: [ExtractedColor] = []
    var extractCount = 5

    // Sheets & feedback
    var exportTarget: ExportTarget?
    var showImport = false
    var toast: Toast?

    let brand = BrandModel()
    let typography = TypeModel()

    @ObservationIgnored weak var undoManager: UndoManager?
    @ObservationIgnored var draggingColorID: UUID?
    @ObservationIgnored private var saveWork: DispatchWorkItem?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var keyMonitor: Any?

    init() {
        let fresh = WorkingPalette(savedID: nil, name: defaultPaletteName,
                                   colors: ColorMath.generate(5, harmony: .analogous).map { PaletteColor(hex: $0) })
        current = fresh
        Self.migrateLegacyData()
        if let data = try? Data(contentsOf: Self.stateURL), let state = try? Self.decoder.decode(PersistedState.self, from: data) {
            palettes = state.palettes.filter { !$0.colors.isEmpty }
            favorites = Set(state.favorites.filter { library.byID[$0] != nil })
            current = state.current.colors.isEmpty ? fresh : state.current
            settings = state.settings
            if let b = state.brand { brand.restore(b) }
            if let t = state.typography { typography.restore(t) }
        }
        brand.loadSavedLogo()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        }
    }

    // MARK: Persistence

    static var dataDirectory: URL {
        if let custom = ProcessInfo.processInfo.environment["PALETTE_PRO_DATA_DIR"] { return URL(fileURLWithPath: custom, isDirectory: true) }
        return supportDirectory.appendingPathComponent("Palette Pro", isDirectory: true)
    }
    private static var supportDirectory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] }

    /// The app was called Swatchbook before; move its saved library, logo and settings over once.
    static func migrateLegacyData() {
        guard ProcessInfo.processInfo.environment["PALETTE_PRO_DATA_DIR"] == nil else { return }
        let fm = FileManager.default, old = supportDirectory.appendingPathComponent("Swatchbook", isDirectory: true)
        guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: dataDirectory.path) else { return }
        try? fm.moveItem(at: old, to: dataDirectory)
    }
    static var stateURL: URL { dataDirectory.appendingPathComponent("library.json") }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.saveNow() } }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        let state = PersistedState(palettes: palettes, favorites: favorites.sorted(), current: current, settings: settings,
                                   brand: brand.settings, typography: typography.settings)
        do {
            try FileManager.default.createDirectory(at: Self.dataDirectory, withIntermediateDirectories: true)
            try Self.encoder.encode(state).write(to: Self.stateURL, options: .atomic)
        } catch {
            showToast("Couldn’t save your library: \(error.localizedDescription)")
        }
    }

    // MARK: Feedback

    func showToast(_ message: String, swatch: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        let t = Toast(message: message, swatch: swatch, actionTitle: actionTitle, action: action)
        withAnimation(.spring(duration: 0.3)) { toast = t }
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(action == nil ? 2.4 : 6))
            guard !Task.isCancelled, self?.toast?.id == t.id else { return }
            withAnimation(.easeOut(duration: 0.2)) { self?.toast = nil }
        }
    }

    /// Copies text; hex values also go on the pasteboard as a colour, so they paste into design apps.
    func copy(_ text: String, label: String? = nil) {
        let pb = NSPasteboard.general
        pb.clearContents()
        var objects: [NSPasteboardWriting] = [text as NSString]
        let hex = ColorMath.parseHex(text)
        if let hex {
            let c = ColorMath.rgb(hex)
            objects.append(NSColor(srgbRed: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1))
        }
        pb.writeObjects(objects)
        showToast("Copied \(label ?? text)", swatch: hex)
    }

    func inspect(_ item: InspectorItem) {
        inspector = item
        showInspector = true
    }

    func inspect(_ c: PaletteColor) {
        inspect(c.sid.map { .swatch($0) } ?? .custom(c.hex))
    }

    // MARK: Pantone helpers

    func pantone(for c: PaletteColor) -> PantoneMatch {
        if let sid = c.sid, let s = library.byID[sid] { return PantoneMatch(swatch: s, dE: 0, exact: true) }
        let m = library.nearest1(c.hex, in: settings.matchLib)
        return PantoneMatch(swatch: m.swatch, dE: m.dE, exact: m.dE < 0.05)
    }

    func exportEntries(_ colors: [PaletteColor], roles: [String]? = nil) -> [ExportEntry] {
        colors.enumerated().map { i, c in
            let m = pantone(for: c)
            return ExportEntry(hex: c.hex, pantone: m.swatch.code, pantoneName: m.swatch.name,
                               exact: m.exact || m.dE < 0.5, dE: m.dE, role: roles?[i])
        }
    }

    func export(name: String, colors: [PaletteColor], roles: [String]? = nil) {
        exportTarget = ExportTarget(name: name, entries: exportEntries(colors, roles: roles))
    }

    func installInColorPicker(name: String, colors: [PaletteColor], roles: [String]? = nil) {
        installInColorPicker(name: name, entries: exportEntries(colors, roles: roles))
    }

    func installInColorPicker(name: String, entries: [ExportEntry]) {
        do {
            _ = try Exporter.installColorList(name: name, entries: entries)
            showToast("Added “\(name)” to the macOS color picker (Color Palettes tab)")
        } catch {
            showToast("Couldn’t add to the color picker: \(error.localizedDescription)")
        }
    }

    // MARK: Favorites

    func toggleFavorite(_ id: String) {
        guard let s = library.byID[id] else { return }
        if favorites.contains(id) {
            favorites.remove(id)
            showToast("Removed \(s.title) from favorites", swatch: s.hex)
        } else {
            favorites.insert(id)
            showToast("Added \(s.title) to favorites", swatch: s.hex)
        }
    }

    // MARK: Working palette & undo

    var isDirty: Bool {
        guard let id = current.savedID, let p = palettes.first(where: { $0.id == id }) else { return true }
        return p.name != current.name || p.colors.map(\.hex) != current.colors.map(\.hex)
    }

    var isSaved: Bool { current.savedID.map { id in palettes.contains { $0.id == id } } ?? false }

    /// Replaces the working colours and registers the change with the window's undo manager.
    func setColors(_ colors: [PaletteColor], action: String) {
        let old = current.colors
        current.colors = colors
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.setColors(old, action: action) }
        }
        undoManager?.setActionName(action)
    }

    func commit(_ action: String, _ mutate: (inout [PaletteColor]) -> Void) {
        var colors = current.colors
        mutate(&colors)
        setColors(colors, action: action)
    }

    func snapColor(_ c: PaletteColor, used: inout Set<String>) -> PaletteColor {
        guard settings.snap, c.sid == nil, let m = library.nearest(c.hex, in: settings.matchLib, excluding: used).first else { return c }
        used.insert(m.swatch.id)
        var out = c
        out.hex = m.swatch.hex
        out.sid = m.swatch.id
        return out
    }

    func addToPalette(hex: String, sid: String? = nil, at index: Int? = nil) {
        guard current.colors.count < maxPaletteColors else {
            showToast("A palette holds up to \(maxPaletteColors) colors. Remove one first.")
            return
        }
        commit("Add Color") { colors in
            colors.insert(PaletteColor(hex: hex, sid: sid), at: min(index ?? colors.count, colors.count))
        }
        let label = sid.flatMap { library.byID[$0]?.title } ?? hex
        if destination == .builder {
            showToast("Added \(label)", swatch: hex)
        } else {
            showToast("Added \(label) to “\(current.name)”", swatch: hex, actionTitle: "Open") { [weak self] in
                self?.destination = .builder
            }
        }
    }

    func generate() {
        guard current.colors.contains(where: { !$0.locked }) else {
            showToast("Every color is locked. Unlock one to generate.")
            return
        }
        let anchor = current.colors.first { $0.locked }
        let baseHue = anchor.map { ColorMath.oklch(hex: $0.hex).z }
        let fresh = ColorMath.generate(current.colors.count, harmony: settings.harmony, mood: settings.mood, baseHue: baseHue)
        commit("Generate") { colors in
            var used = Set(colors.filter { $0.locked }.compactMap(\.sid))
            var k = 0
            for i in colors.indices where !colors[i].locked {
                colors[i] = snapColor(PaletteColor(hex: fresh[k]), used: &used)
                k += 1
            }
        }
    }

    func addGeneratedColor() {
        guard current.colors.count < maxPaletteColors else {
            showToast("A palette holds up to \(maxPaletteColors) colors.")
            return
        }
        let baseHue = current.colors.last.map { ColorMath.oklch(hex: $0.hex).z + Double.random(in: -30...30) }
        let hex = ColorMath.generate(1, harmony: .monochromatic, mood: settings.mood, baseHue: baseHue)[0]
        var used = Set(current.colors.compactMap(\.sid))
        let c = snapColor(PaletteColor(hex: hex), used: &used)
        commit("Add Color") { $0.append(c) }
    }

    func remove(_ id: UUID) {
        guard current.colors.count > 1 else { return }
        commit("Remove Color") { $0.removeAll { $0.id == id } }
    }

    func toggleLock(_ id: UUID) {
        guard let i = current.colors.firstIndex(where: { $0.id == id }) else { return }
        current.colors[i].locked.toggle()
    }

    func setHex(_ id: UUID, _ hex: String) {
        guard let i = current.colors.firstIndex(where: { $0.id == id }), current.colors[i].hex != hex else { return }
        commit("Change Color") { colors in
            colors[i].hex = hex
            colors[i].sid = nil
        }
    }

    func snapToPantone(_ id: UUID) {
        guard let i = current.colors.firstIndex(where: { $0.id == id }) else { return }
        let m = pantone(for: current.colors[i])
        guard !m.exact else { return }
        commit("Snap to Pantone") { colors in
            colors[i].hex = m.swatch.hex
            colors[i].sid = m.swatch.id
        }
        showToast("Snapped to \(m.swatch.title)", swatch: m.swatch.hex)
    }

    func setSnap(_ on: Bool) {
        settings.snap = on
        guard on, current.colors.contains(where: { !$0.locked && $0.sid == nil }) else { return }
        commit("Snap to Pantone") { colors in
            var used = Set(colors.compactMap(\.sid))
            for i in colors.indices where !colors[i].locked { colors[i] = snapColor(colors[i], used: &used) }
        }
        showToast("Snapped your colors to the nearest Pantone", actionTitle: "Undo") { [weak self] in self?.undoManager?.undo() }
    }

    func move(_ id: UUID, to target: Int) {
        guard let from = current.colors.firstIndex(where: { $0.id == id }) else { return }
        let to = max(0, min(target, current.colors.count - 1))
        guard from != to else { return }
        commit("Move Color") { colors in
            let c = colors.remove(at: from)
            colors.insert(c, at: to)
        }
    }

    /// Swaps in a different palette. Offers Undo when unsaved work would be lost.
    func replaceCurrent(_ next: WorkingPalette, message: String?) {
        let previous = current
        let lostWork = isDirty
        current = next
        undoManager?.removeAllActions(withTarget: self)
        guard let message else { return }
        if lostWork {
            showToast(message, actionTitle: "Undo") { [weak self] in
                self?.current = previous
                self?.destination = .builder
            }
        } else {
            showToast(message)
        }
    }

    func newPalette() {
        var used = Set<String>()
        let colors = ColorMath.generate(5, harmony: settings.harmony, mood: settings.mood).map { snapColor(PaletteColor(hex: $0), used: &used) }
        replaceCurrent(WorkingPalette(savedID: nil, name: defaultPaletteName, colors: colors), message: "Started a new palette")
        destination = .builder
    }

    func savePalette() {
        current.name = current.name.trimmingCharacters(in: .whitespaces).isEmpty ? defaultPaletteName : current.name
        let colors = current.colors.map { PaletteColor(hex: $0.hex, sid: $0.sid) }
        if let id = current.savedID, let i = palettes.firstIndex(where: { $0.id == id }) {
            var p = palettes.remove(at: i)
            p.name = current.name
            p.colors = colors
            p.updatedAt = Date()
            palettes.insert(p, at: 0)
        } else {
            let p = Palette(name: current.name, colors: colors)
            current.savedID = p.id
            palettes.insert(p, at: 0)
        }
        showToast("Saved “\(current.name)”", actionTitle: "View All") { [weak self] in self?.destination = .saved }
    }

    func open(_ palette: Palette) {
        if current.savedID != palette.id || isDirty {
            replaceCurrent(WorkingPalette(savedID: palette.id, name: palette.name, colors: palette.colors.map { PaletteColor(hex: $0.hex, sid: $0.sid) }),
                           message: "Opened “\(palette.name)”")
        }
        destination = .builder
    }

    func usePalette(name: String, colors: [PaletteColor]) {
        replaceCurrent(WorkingPalette(savedID: nil, name: name, colors: Array(colors.prefix(maxPaletteColors))), message: "Opened “\(name)” in the editor")
        destination = .builder
    }

    // MARK: Saved palettes

    func duplicate(_ p: Palette) {
        guard let i = palettes.firstIndex(of: p) else { return }
        let copy = Palette(name: String((p.name + " copy").prefix(60)), colors: p.colors.map { PaletteColor(hex: $0.hex, sid: $0.sid) })
        palettes.insert(copy, at: i + 1)
        showToast("Duplicated “\(p.name)”")
    }

    func delete(_ p: Palette) {
        guard let i = palettes.firstIndex(of: p) else { return }
        palettes.remove(at: i)
        showToast("Deleted “\(p.name)”", actionTitle: "Undo") { [weak self] in
            guard let self else { return }
            self.palettes.insert(p, at: min(i, self.palettes.count))
        }
    }

    func rename(_ p: Palette, to raw: String) {
        guard let i = palettes.firstIndex(where: { $0.id == p.id }) else { return }
        let name = String(raw.trimmingCharacters(in: .whitespaces).prefix(60))
        let finalName = name.isEmpty ? defaultPaletteName : name
        if current.savedID == p.id && !isDirty { current.name = finalName }
        palettes[i].name = finalName
        palettes[i].updatedAt = Date()
    }

    // MARK: Import & backup

    /// Reads hex codes and Pantone numbers from free text.
    func parseColorList(_ text: String) -> (colors: [PaletteColor], missed: [String]) {
        var colors: [PaletteColor] = [], missed: [String] = []
        let hexRegex = try! NSRegularExpression(pattern: #"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b|\b([0-9a-fA-F]{6})\b"#)
        for raw in text.split(whereSeparator: { "\n,;".contains($0) }) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let ns = line as NSString
            let found = hexRegex.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap { m -> String? in
                let r = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 2)
                return ColorMath.parseHex(ns.substring(with: r))
            }
            if !found.isEmpty {
                colors += found.map { PaletteColor(hex: $0) }
            } else if let s = library.lookup(code: line) {
                colors.append(PaletteColor(hex: s.hex, sid: s.id))
            } else {
                missed.append(line)
            }
        }
        return (colors, missed)
    }

    func createPalette(name: String, colors: [PaletteColor]) -> Palette {
        let p = Palette(name: name.isEmpty ? "Imported palette" : name, colors: Array(colors.prefix(maxPaletteColors)))
        palettes.insert(p, at: 0)
        return p
    }

    func backupData() -> Data {
        struct Backup: Encodable {
            let app = "Palette Pro"
            let version = 1
            let exportedAt = Date()
            let palettes: [Palette]
            let favorites: [String]
        }
        return (try? Self.encoder.encode(Backup(palettes: palettes, favorites: favorites.sorted()))) ?? Data()
    }

    /// Restores a Mac or web backup, or a single palette exported as JSON. Skips palettes you already have.
    func restore(_ data: Data) -> Int? {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let incoming: [[String: Any]] = (obj["palettes"] as? [[String: Any]]) ?? (obj["colors"] != nil ? [obj] : [])
        let signature: (String, [String]) -> String = { $0 + "|" + $1.joined(separator: ",") }
        var have = Set(palettes.map { signature($0.name, $0.colors.map(\.hex)) })
        var added: [Palette] = []
        for dict in incoming {
            let colors: [PaletteColor] = ((dict["colors"] as? [Any]) ?? []).compactMap { item in
                let hexRaw = (item as? [String: Any])?["hex"] as? String ?? item as? String
                guard let hex = hexRaw.flatMap(ColorMath.parseHex) else { return nil }
                let sid = (item as? [String: Any])?["sid"] as? String
                return PaletteColor(hex: hex, sid: sid.flatMap { library.byID[$0]?.hex == hex ? $0 : nil })
            }
            guard !colors.isEmpty else { continue }
            let name = String(((dict["name"] as? String) ?? "Imported palette").prefix(60))
            let sig = signature(name, colors.map(\.hex))
            guard !have.contains(sig) else { continue }
            have.insert(sig)
            var p = Palette(name: name, colors: Array(colors.prefix(maxPaletteColors)))
            if let ms = dict["createdAt"] as? Double { p.createdAt = Date(timeIntervalSince1970: ms / 1000) }
            if let ms = dict["updatedAt"] as? Double { p.updatedAt = Date(timeIntervalSince1970: ms / 1000) }
            added.append(p)
        }
        palettes = added + palettes
        for id in (obj["favorites"] as? [String]) ?? [] where library.byID[id] != nil { favorites.insert(id) }
        return added.count
    }

    // MARK: Match

    func pickFromScreen(_ completion: @escaping @MainActor (String) -> Void) {
        NSColorSampler().show { color in
            guard let c = color?.usingColorSpace(.sRGB) else { return }
            let hex = ColorMath.hex(RGB(c.redComponent * 255, c.greenComponent * 255, c.blueComponent * 255))
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(hex) } }
        }
    }

    func loadImage(_ image: NSImage) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            showToast("Couldn’t read that image.")
            return
        }
        matchImage = cg
        extractColors()
    }

    func extractColors() {
        guard let cg = matchImage else { return }
        let scale = min(1, 120 / Double(max(cg.width, cg.height)))
        let w = max(1, Int(Double(cg.width) * scale)), h = max(1, Int(Double(cg.height) * scale))
        guard let buf = Self.rgbaPixels(cg, width: w, height: h) else { return }
        var px: [RGB] = []
        px.reserveCapacity(w * h)
        for i in stride(from: 0, to: buf.count, by: 4) where buf[i + 3] >= 128 {
            let a = Double(buf[i + 3]) / 255
            px.append(RGB(Double(buf[i]) / a, Double(buf[i + 1]) / a, Double(buf[i + 2]) / a))
        }
        extracted = ColorMath.extractPalette(px, k: extractCount).map { ExtractedColor(hex: $0.hex, share: $0.share) }
    }

    /// Colour of the image pixel at a relative position (0…1 from top-left).
    func samplePixel(x fx: Double, y fy: Double) -> String? {
        guard let cg = matchImage else { return nil }
        let x = min(cg.width - 1, max(0, Int(fx * Double(cg.width))))
        let y = min(cg.height - 1, max(0, Int(fy * Double(cg.height))))
        guard let crop = cg.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)),
              let buf = Self.rgbaPixels(crop, width: 1, height: 1), buf[3] > 0 else { return nil }
        let a = Double(buf[3]) / 255
        return ColorMath.hex(RGB(Double(buf[0]) / a, Double(buf[1]) / a, Double(buf[2]) / a))
    }

    private static func rgbaPixels(_ cg: CGImage, width w: Int, height h: Int) -> [UInt8]? {
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let ok = buf.withUnsafeMutableBytes { ptr -> Bool in
            guard let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? buf : nil
    }

    func paletteFromImage(snap: Bool) {
        guard !extracted.isEmpty else { return }
        var used = Set<String>()
        let colors = extracted.prefix(maxPaletteColors).map { e -> PaletteColor in
            guard snap, let m = library.nearest(e.hex, in: settings.matchLib, excluding: used).first else { return PaletteColor(hex: e.hex) }
            used.insert(m.swatch.id)
            return PaletteColor(hex: m.swatch.hex, sid: m.swatch.id)
        }
        replaceCurrent(WorkingPalette(savedID: nil, name: "From image", colors: colors), message: "Made a palette from your image")
        destination = .builder
    }

    // MARK: Keyboard

    /// Space generates in the palette editor unless a text field has focus.
    func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard self.destination == .builder, event.keyCode == 49,
                      event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock).isEmpty,
                      let window = NSApp.keyWindow, window.attachedSheet == nil, window.sheetParent == nil,
                      !(window.firstResponder is NSText) else { return false }
                self.generate()
                return true
            }
            return handled ? nil : event
        }
    }
}
