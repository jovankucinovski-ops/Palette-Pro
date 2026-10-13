import Observation
import SwiftUI

enum FontFilter: String, CaseIterable, Identifiable, Codable {
    case all, picks, google, fontshare, open, installed, favorites
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All Fonts"
        case .picks: "Designer Picks"
        case .google: "Google Fonts"
        case .fontshare: "Fontshare"
        case .open: "Open Source"
        case .installed: "On This Mac"
        case .favorites: "Favorite Fonts"
        }
    }
    var symbol: String {
        switch self {
        case .all: "textformat"
        case .picks: "sparkles"
        case .google: "globe"
        case .fontshare: "square.stack.3d.up"
        case .open: "chevron.left.forwardslash.chevron.right"
        case .installed: "desktopcomputer"
        case .favorites: "star"
        }
    }
}

enum PairTab: String, CaseIterable, Identifiable {
    case ideas, details
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum FontSort: String, CaseIterable, Identifiable, Codable {
    case popular, name, newest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .popular: "Most popular"
        case .name: "Name"
        case .newest: "Newest"
        }
    }
}

/// Fonts, pairing and type scale settings as saved in library.json. Missing values fall back to defaults.
struct TypeSettings: Codable, Hashable {
    var filter: FontFilter = .picks
    var category: FontCategory?
    var sort: FontSort = .popular
    var sampleText = ""
    var sampleSize: Double = 40
    var favorites: [String] = []
    var pairHeadingID: String?
    var mood: PairMood = .any
    var headline = "Design is how it works"
    var pairings: [FontPairing] = []
    var selectedPairingID: UUID?
    var scaleHeadingID = "inter"
    var scaleBodyID = "inter"
    var scale = TypeScaleSpec()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decode(T.self, forKey: key)) ?? fallback }
        filter = value(.filter, filter)
        category = try? c.decode(FontCategory.self, forKey: .category)
        sort = value(.sort, sort)
        sampleText = value(.sampleText, sampleText)
        sampleSize = value(.sampleSize, sampleSize)
        favorites = value(.favorites, favorites)
        pairHeadingID = try? c.decode(String.self, forKey: .pairHeadingID)
        mood = value(.mood, mood)
        headline = value(.headline, headline)
        pairings = value(.pairings, pairings).filter { $0.heading != nil && $0.body != nil }
        selectedPairingID = try? c.decode(UUID.self, forKey: .selectedPairingID)
        scaleHeadingID = value(.scaleHeadingID, scaleHeadingID)
        scaleBodyID = value(.scaleBodyID, scaleBodyID)
        scale = value(.scale, scale)
    }
}

@Observable @MainActor
final class TypeModel {
    let catalog = FontCatalog.shared

    // Library
    var filter: FontFilter = .picks
    var category: FontCategory?
    var sort: FontSort = .popular
    var query = ""
    var sampleText = ""
    var sampleSize: Double = 40
    var favorites: Set<String> = []
    var detail: FontFamily?

    // Pairing
    var pairHeadingID: String?
    var mood: PairMood = .any
    var headline = "Design is how it works"
    var pairings: [FontPairing] = []
    var selectedPairingID: UUID?
    var pairTab: PairTab = .ideas

    // Type scale
    var scaleHeadingID = "inter"
    var scaleBodyID = "inter"
    var scale = TypeScaleSpec()

    static let defaultSample = "The quick brown fox jumps over the lazy dog"
    var sample: String { sampleText.trimmingCharacters(in: .whitespaces).isEmpty ? Self.defaultSample : sampleText }

    var pairHeading: FontFamily? { pairHeadingID.flatMap { catalog.family(id: $0) } }
    var selectedPairing: FontPairing? { pairings.first { $0.id == selectedPairingID } ?? pairings.first }
    var scaleHeading: FontFamily { catalog.family(id: scaleHeadingID) ?? catalog.named("Inter") ?? catalog.all[0] }
    var scaleBody: FontFamily { catalog.family(id: scaleBodyID) ?? catalog.named("Inter") ?? catalog.all[0] }
    var scaleHeadingWeight: Int {
        if let p = selectedPairing, p.headingID == scaleHeadingID { return p.headingWeight }
        return scaleHeading.category == .display ? scaleHeading.regular : scaleHeading.heading
    }

    func fonts() -> [FontFamily] {
        var list: [FontFamily] = switch filter {
        case .all: catalog.all
        case .picks: catalog.online.filter(\.pick)
        case .google: catalog.online.filter { $0.source == .google }
        case .fontshare: catalog.online.filter { $0.source == .fontshare }
        case .open: catalog.online.filter { $0.source == .open }
        case .installed: catalog.installed
        case .favorites: catalog.all.filter { favorites.contains($0.id) }
        }
        if let category { list = list.filter { $0.category == category } }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            let tokens = q.split(separator: " ")
            list = list.filter { f in tokens.allSatisfy { f.search.contains($0) } }
        }
        switch sort {
        case .popular: list.sort { ($0.rank, $0.family) < ($1.rank, $1.family) }
        case .name: list.sort { $0.family.localizedStandardCompare($1.family) == .orderedAscending }
        case .newest: list.sort { ($0.year, -$0.rank) > ($1.year, -$1.rank) }
        }
        if !q.isEmpty {
            list = list.enumerated().sorted { a, b in
                let ra = a.element.family.lowercased().hasPrefix(q) ? 0 : 1, rb = b.element.family.lowercased().hasPrefix(q) ? 0 : 1
                return (ra, a.offset) < (rb, b.offset)
            }.map(\.element)
        }
        return list
    }

    func toggleFavorite(_ f: FontFamily) {
        if favorites.contains(f.id) { favorites.remove(f.id) } else { favorites.insert(f.id) }
    }

    func suggestPairings() {
        pairings = PairingEngine.suggest(heading: pairHeading, mood: mood)
        selectedPairingID = pairings.first?.id
    }

    /// Pair a font from the library: it becomes the heading and ideas are made around it.
    func pair(with f: FontFamily) {
        pairHeadingID = f.id
        suggestPairings()
        pairTab = .ideas
    }

    func useInScale(_ p: FontPairing) {
        scaleHeadingID = p.headingID
        scaleBodyID = p.bodyID
    }

    var steps: [ScaleStep] { scale.steps(headingWeight: scaleHeadingWeight, bodyWeight: scaleBody.regular) }

    var settings: TypeSettings {
        var s = TypeSettings()
        s.filter = filter; s.category = category; s.sort = sort; s.sampleText = sampleText; s.sampleSize = sampleSize
        s.favorites = favorites.sorted(); s.pairHeadingID = pairHeadingID; s.mood = mood; s.headline = headline
        s.pairings = pairings; s.selectedPairingID = selectedPairingID
        s.scaleHeadingID = scaleHeadingID; s.scaleBodyID = scaleBodyID; s.scale = scale
        return s
    }

    func restore(_ s: TypeSettings) {
        filter = s.filter; category = s.category; sort = s.sort; sampleText = s.sampleText; sampleSize = s.sampleSize
        favorites = Set(s.favorites.filter { catalog.family(id: $0) != nil })
        pairHeadingID = s.pairHeadingID.flatMap { catalog.family(id: $0)?.id }; mood = s.mood; headline = s.headline
        pairings = s.pairings; selectedPairingID = s.selectedPairingID
        scaleHeadingID = catalog.family(id: s.scaleHeadingID)?.id ?? scaleHeadingID
        scaleBodyID = catalog.family(id: s.scaleBodyID)?.id ?? scaleBodyID
        scale = s.scale
    }
}
