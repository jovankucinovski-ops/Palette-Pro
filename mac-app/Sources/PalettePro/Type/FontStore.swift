import AppKit
import CoreText
import Observation
import SwiftUI

/// Downloads font files on first use and caches them. Fonts are loaded straight from their files
/// (never installed or registered by name), so previewing changes nothing on the Mac. Loading by file
/// also matters because some web font files share placeholder internal names.
@Observable @MainActor
final class FontStore {
    static let shared = FontStore()

    /// Loaded styles at a reference size, keyed by `key(family, weight, italic)`.
    private(set) var faces: [String: CTFont] = [:]
    private(set) var failed: Set<String> = []
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private let gate = DownloadGate(limit: 6)

    static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Palette Pro/Fonts", isDirectory: true)
    }

    nonisolated static func key(_ f: FontFamily, _ weight: Int, _ italic: Bool) -> String { "\(f.id)|\(weight)\(italic ? "i" : "")" }

    /// The style actually used: the nearest weight the family has, and italic only if it has one.
    nonisolated static func resolve(_ f: FontFamily, weight: Int, italic: Bool) -> (Int, Bool) {
        (f.nearest(weight), italic && f.italic)
    }

    /// The style's PostScript name, for exports. Nil while loading or when the file has no usable name.
    func postScriptName(_ f: FontFamily, weight: Int, italic: Bool = false) -> String? {
        guard let font = ctFont(f, weight: weight, italic: italic, size: 12) else { return nil }
        let ps = CTFontCopyPostScriptName(font) as String
        return ps.isEmpty || ps == "false" ? nil : ps
    }

    func isReady(_ f: FontFamily, weight: Int, italic: Bool = false) -> Bool {
        ctFont(f, weight: weight, italic: italic, size: 12) != nil
    }

    func hasFailed(_ f: FontFamily, weight: Int, italic: Bool = false) -> Bool {
        let (w, i) = Self.resolve(f, weight: weight, italic: italic)
        return failed.contains(Self.key(f, w, i))
    }

    func font(_ f: FontFamily, weight: Int, italic: Bool = false, size: CGFloat) -> Font? {
        ctFont(f, weight: weight, italic: italic, size: size).map { Font($0) }
    }

    func ctFont(_ f: FontFamily, weight: Int, italic: Bool = false, size: CGFloat) -> CTFont? {
        let (w, i) = Self.resolve(f, weight: weight, italic: italic)
        if f.source == .installed {
            let ps = f.local["\(w)\(i ? "i" : "")"] ?? f.local["\(w)"] ?? f.local.values.first
            return ps.map { CTFontCreateWithName($0 as CFString, size, nil) }
        }
        return faces[Self.key(f, w, i)].map { CTFontCreateCopyWithAttributes($0, size, nil, nil) }
    }

    /// Makes one style available, downloading it if needed. Safe to call repeatedly.
    func load(_ f: FontFamily, weight: Int, italic: Bool = false) async {
        guard f.source != .installed else { return }
        let (w, i) = Self.resolve(f, weight: weight, italic: italic)
        let key = Self.key(f, w, i)
        guard faces[key] == nil, !failed.contains(key), !inFlight.contains(key) else { return }
        // Already installed on this Mac under the same name: use that, no download.
        if let local = FontCatalog.shared.installedStyle(named: f.family, weight: w, italic: i) {
            faces[key] = CTFontCreateWithName(local as CFString, 12, nil)
            return
        }
        guard let remote = f.fileURL(weight: w, italic: i) else { failed.insert(key); return }
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        let file = Self.cacheDirectory.appendingPathComponent(f.source.rawValue, isDirectory: true)
            .appendingPathComponent("\(f.id)-\(w)\(i ? "i" : "").ttf")
        do {
            if !FileManager.default.fileExists(atPath: file.path) {
                await gate.acquire()
                defer { Task { await gate.release() } }
                try Task.checkCancellation()
                let (data, response) = try await URLSession.shared.data(from: remote)
                guard (response as? HTTPURLResponse)?.statusCode == 200, data.count > 1000 else { throw URLError(.badServerResponse) }
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: file, options: .atomic)
            }
            guard let face = Self.face(from: file) else {
                try? FileManager.default.removeItem(at: file)
                failed.insert(key)
                return
            }
            faces[key] = face
        } catch is CancellationError {
            // Scrolled out of view; it loads again when it reappears.
        } catch let e as URLError where e.code == .cancelled {
        } catch {
            failed.insert(key)
        }
    }

    /// Loads several styles, e.g. every weight of a family for the detail view.
    func loadAll(_ f: FontFamily, italic: Bool = false) async {
        await withTaskGroup(of: Void.self) { group in
            for w in f.weights { group.addTask { await self.load(f, weight: w, italic: italic) } }
        }
    }

    /// Opens a font file directly, without registering it under its (possibly shared) name.
    private static func face(from file: URL) -> CTFont? {
        guard let provider = CGDataProvider(url: file as CFURL), let cg = CGFont(provider), cg.numberOfGlyphs > 1 else { return nil }
        return CTFontCreateWithGraphicsFont(cg, 12, nil, nil)
    }

    /// Size of the downloaded font cache, for Settings.
    static func cacheSize() -> Int {
        guard let e = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return e.compactMap { ($0 as? URL).flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } }.reduce(0, +)
    }
}

/// Limits how many font files download at once.
actor DownloadGate {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) { available = limit }

    func acquire() async {
        if available > 0 { available -= 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty { available += 1 } else { waiters.removeFirst().resume() }
    }
}

extension FontCatalog {
    /// A matching style of a font installed on this Mac, by family name.
    func installedStyle(named family: String, weight: Int, italic: Bool) -> String? {
        guard let members = NSFontManager.shared.availableMembers(ofFontFamily: family) else { return nil }
        var best: (String, Int)?
        for m in members {
            guard let ps = m.first as? String else { continue }
            let font = CTFontCreateWithName(ps as CFString, 12, nil)
            guard CTFontGetSymbolicTraits(font).contains(.traitItalic) == italic else { continue }
            let t = (CTFontCopyTraits(font) as? [String: Any])?[kCTFontWeightTrait as String] as? Double ?? 0
            let stops: [(Double, Int)] = [(-0.8, 100), (-0.6, 200), (-0.4, 300), (0, 400), (0.23, 500), (0.3, 600), (0.4, 700), (0.56, 800), (0.62, 900)]
            let w = stops.min { abs($0.0 - t) < abs($1.0 - t) }!.1
            let d = abs(w - weight)
            if d <= 50, best == nil || d < best!.1 { best = (ps, d) }
        }
        return best?.0
    }
}

/// Text set in a catalogue font. Shows a quiet placeholder while the font downloads.
struct FontText: View {
    let family: FontFamily
    let text: String
    let size: CGFloat
    var weight: Int?
    var italic = false

    var body: some View {
        let store = FontStore.shared
        let w = weight ?? family.regular
        let (rw, ri) = FontStore.resolve(family, weight: w, italic: italic)
        Group {
            if let font = store.font(family, weight: rw, italic: ri, size: size) {
                Text(text).font(font)
            } else if store.hasFailed(family, weight: rw, italic: ri) {
                Text(text).font(.system(size: size, weight: .regular)).foregroundStyle(.tertiary)
                    .help("This font couldn’t be loaded. Check your internet connection.")
            } else {
                Text(text).font(.system(size: size, weight: .regular)).opacity(0.12)
            }
        }
        .task(id: FontStore.key(family, rw, ri)) { await store.load(family, weight: rw, italic: ri) }
    }
}
