import SwiftUI

struct LibraryView: View {
    @Environment(AppModel.self) private var model

    private struct Result {
        var list: [Swatch]
        var deltaE: [String: Double] = [:]
        var hexQuery: String?
    }

    private func query() -> Result {
        let lib = model.library
        var list: [Swatch] = switch model.libCollection {
        case "fav": lib.swatches.filter { model.favorites.contains($0.id) }
        case "all": lib.swatches(in: .all)
        default: lib.swatches(inCollection: model.libCollection)
        }
        if let f = model.libFamily { list = list.filter { $0.family == f } }

        var q = model.libQuery.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "®", with: "")
        if q.hasPrefix("pantone") { q = q.dropFirst(7).trimmingCharacters(in: .whitespaces) }

        let looksHex = (q.hasPrefix("#") && (q.count == 4 || q.count == 7)) || (q.count == 6 && q.allSatisfy(\.isHexDigit))
        if looksHex, let hex = ColorMath.parseHex(q) {
            let lab = ColorMath.lab(ColorMath.rgb(hex))
            let ranked = list.map { ($0, ColorMath.deltaE(lab, $0.lab)) }.sorted { $0.1 < $1.1 }.prefix(120)
            return Result(list: ranked.map(\.0), deltaE: Dictionary(uniqueKeysWithValues: ranked.map { ($0.0.id, $0.1) }), hexQuery: hex)
        }
        if !q.isEmpty {
            let tokens = q.split(separator: " ")
            list = list.filter { s in tokens.allSatisfy { s.search.contains($0) } }
        }
        switch model.libSort {
        case .book: break
        case .hue: list.sort { $0.hueKey < $1.hueKey }
        case .light: list.sort { $0.lch.x > $1.lch.x }
        case .name: list.sort { ($0.name.isEmpty ? $0.code : $0.name).localizedStandardCompare($1.name.isEmpty ? $1.code : $1.name) == .orderedAscending }
        }
        if !q.isEmpty {
            func rank(_ s: Swatch) -> Int {
                let code = s.code.lowercased()
                if code == q || code.split(separator: " ").first.map(String.init) == q { return 0 }
                if code.hasPrefix(q) { return 1 }
                return s.name.lowercased().hasPrefix(q) ? 2 : 3
            }
            list = list.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map(\.element)
        }
        return Result(list: list)
    }

    var body: some View {
        @Bindable var model = model
        let result = query()
        Group {
            if result.list.isEmpty {
                ContentUnavailableView {
                    Label(model.libCollection == "fav" && model.libQuery.isEmpty ? "No Favorites Yet" : "No Colors Match",
                          systemImage: model.libCollection == "fav" ? "star" : "magnifyingglass")
                } description: {
                    Text(model.libCollection == "fav" && model.libQuery.isEmpty
                         ? "Star colors in the inspector or from a chip’s context menu."
                         : "Try a different search, or clear the filters.")
                } actions: {
                    if !model.libQuery.isEmpty || model.libFamily != nil {
                        Button("Clear Filters") {
                            model.libQuery = ""
                            model.libFamily = nil
                        }
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let hex = result.hexQuery {
                            Label("Closest Pantone colors to \(hex), best match first", systemImage: "scope")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128, maximum: 190), spacing: 16)], spacing: 20) {
                            ForEach(result.list) { s in
                                ChipView(swatch: s, deltaE: result.deltaE[s.id])
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .searchable(text: $model.libQuery, placement: .toolbar, prompt: "Name, code or hex")
        .navigationTitle(title)
        .navigationSubtitle("\(result.list.count.formatted()) colors")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Picker("Hue", selection: $model.libFamily) {
                        Text("All Hues").tag(Family?.none)
                        Divider()
                        ForEach(Family.allCases) { f in Text(f.title).tag(Family?.some(f)) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(model.libFamily?.title ?? "All Hues", systemImage: model.libFamily == nil
                          ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .help("Filter by hue")
                Menu {
                    Picker("Sort", selection: $model.libSort) {
                        ForEach(LibrarySort.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort: \(model.libSort.title)", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort order")
            }
        }
    }

    private var title: String {
        switch model.libCollection {
        case "all": "All Colors"
        case "fav": "Favorites"
        default: model.library.collectionName(model.libCollection)
        }
    }
}
