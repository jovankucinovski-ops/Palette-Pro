import Foundation

let maxPaletteColors = 12
let defaultPaletteName = "Untitled palette"

struct PaletteColor: Codable, Hashable, Identifiable {
    var id = UUID()
    var hex: String
    var locked = false
    /// Library swatch this colour came from, when it is an exact Pantone.
    var sid: String?

    init(hex: String, locked: Bool = false, sid: String? = nil) {
        self.hex = hex; self.locked = locked; self.sid = sid
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        hex = ColorMath.parseHex(try c.decode(String.self, forKey: .hex)) ?? "#000000"
        locked = (try? c.decode(Bool.self, forKey: .locked)) ?? false
        let s = try? c.decode(String.self, forKey: .sid)
        sid = s.flatMap { Library.shared.byID[$0]?.hex == hex ? $0 : nil }
    }
}

struct Palette: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var colors: [PaletteColor]
    var createdAt = Date()
    var updatedAt = Date()
}

/// The palette open in the editor. `savedID` links it to an entry in My Palettes.
struct WorkingPalette: Codable, Hashable {
    var savedID: UUID?
    var name: String
    var colors: [PaletteColor]
}

struct AppSettings: Codable, Hashable {
    var matchLib: MatchLib = .coated
    var harmony: Harmony = .auto
    var mood: Mood = .balanced
    var snap = false
    var exportFormat: ExportFormat = .css

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matchLib = (try? c.decode(MatchLib.self, forKey: .matchLib)) ?? .coated
        harmony = (try? c.decode(Harmony.self, forKey: .harmony)) ?? .auto
        mood = (try? c.decode(Mood.self, forKey: .mood)) ?? .balanced
        snap = (try? c.decode(Bool.self, forKey: .snap)) ?? false
        exportFormat = (try? c.decode(ExportFormat.self, forKey: .exportFormat)) ?? .css
    }
}

struct PersistedState: Codable {
    var version = 1
    var palettes: [Palette]
    var favorites: [String]
    var current: WorkingPalette
    var settings: AppSettings
    var brand: BrandSettings?
    var typography: TypeSettings?
    var fusion: FusionSettings?

    init(palettes: [Palette], favorites: [String], current: WorkingPalette, settings: AppSettings, brand: BrandSettings?,
         typography: TypeSettings?, fusion: FusionSettings?) {
        self.palettes = palettes; self.favorites = favorites; self.current = current; self.settings = settings
        self.brand = brand; self.typography = typography; self.fusion = fusion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        palettes = try c.decode([Palette].self, forKey: .palettes)
        favorites = (try? c.decode([String].self, forKey: .favorites)) ?? []
        current = try c.decode(WorkingPalette.self, forKey: .current)
        settings = (try? c.decode(AppSettings.self, forKey: .settings)) ?? AppSettings()
        brand = try? c.decode(BrandSettings.self, forKey: .brand)
        typography = try? c.decode(TypeSettings.self, forKey: .typography)
        fusion = try? c.decode(FusionSettings.self, forKey: .fusion)
    }
}

enum Destination: String, CaseIterable, Identifiable, Hashable {
    // Order sets the ⌘1… shortcuts; new sections go at the end so existing shortcuts stay the same.
    case library, builder, brand, saved, match, fonts, pairing, scale, fusion
    var id: String { rawValue }
    var title: String {
        switch self {
        case .library: "Library"
        case .builder: "Palette"
        case .brand: "Brand Studio"
        case .saved: "My Palettes"
        case .match: "Match"
        case .fonts: "Fonts"
        case .pairing: "Pairing"
        case .scale: "Type Scale"
        case .fusion: "Fusion"
        }
    }
    var symbol: String {
        switch self {
        case .library: "square.grid.3x3.fill"
        case .builder: "swatchpalette"
        case .brand: "sparkles.rectangle.stack"
        case .saved: "rectangle.stack"
        case .match: "eyedropper"
        case .fonts: "textformat"
        case .pairing: "rectangle.on.rectangle"
        case .scale: "textformat.size"
        case .fusion: "wand.and.stars"
        }
    }
}

/// What the inspector shows: a library swatch or any colour.
enum InspectorItem: Hashable {
    case swatch(String)
    case custom(String)
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    var swatch: String?
    var actionTitle: String?
    var action: (() -> Void)?

    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case book, hue, light, name
    var id: String { rawValue }
    var title: String {
        switch self {
        case .book: "Book order"
        case .hue: "By hue"
        case .light: "Light to dark"
        case .name: "Name"
        }
    }
}
