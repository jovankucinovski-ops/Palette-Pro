import SwiftUI

struct InspectorView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let item = model.inspector {
            SwatchDetail(item: item)
                .id(item)
        } else {
            ContentUnavailableView("No Color Selected", systemImage: "paintpalette",
                                   description: Text("Click any color to see its values, contrast and the closest Pantone matches."))
        }
    }
}

struct SwatchDetail: View {
    @Environment(AppModel.self) private var model
    let item: InspectorItem

    private var swatch: Swatch? {
        if case .swatch(let id) = item { return model.library.byID[id] }
        return nil
    }
    private var hex: String {
        switch item {
        case .swatch(let id): model.library.byID[id]?.hex ?? "#000000"
        case .custom(let h): h
        }
    }

    var body: some View {
        let rgb = ColorMath.rgb(hex)
        let hsl = ColorMath.hsl(rgb), lab = ColorMath.lab(rgb)
        let fg = Color(hex: ColorMath.readableOn(rgb))
        let similar = model.library.nearest(hex, k: 10, in: swatch == nil ? model.settings.matchLib : .all, excluding: swatch.map { [$0.id] } ?? [])
        let values: [(String, String)] = [
            ("HEX", hex),
            ("RGB", rgb.ints.map(String.init).joined(separator: ", ")),
            ("HSL", String(format: "%.0f°, %.0f%%, %.0f%%", hsl.x, hsl.y, hsl.z)),
            ("Lab", String(format: "%.1f, %.1f, %.1f", lab.x, lab.y, lab.z)),
            ("CMYK ≈", ColorMath.cmyk(rgb).map(String.init).joined(separator: ", ")),
        ]

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack(alignment: .bottom) {
                    Rectangle().fill(Color(rgb: rgb)).frame(height: 180)
                    HStack {
                        Text(swatch.map { model.library.collectionName($0.coll) } ?? "Custom color")
                        Spacer()
                        Text(hex).monospaced()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(fg.opacity(0.85))
                    .padding(14)
                }
                .draggable(hex)

                VStack(alignment: .leading, spacing: 18) {
                    title(similar.first)
                    actions
                    valuesGrid(values)
                    contrast(rgb)
                    tints
                    similarGrid(similar)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder private func title(_ closest: Match?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let s = swatch {
                Text("PANTONE®").font(.system(size: 11, weight: .heavy))
                Text(s.code).font(.system(size: 26, weight: .bold))
                if !s.name.isEmpty {
                    Text(s.name + (s.coll == "coty" ? " · Color of the Year \(s.note)" : "")).foregroundStyle(.secondary)
                }
            } else {
                Text("CUSTOM COLOR").font(.system(size: 11, weight: .heavy))
                Text(hex).font(.system(size: 26, weight: .bold, design: .monospaced))
                if let m = closest {
                    Text(String(format: "Closest: %@ (ΔE %.1f, %@)", m.swatch.title, m.dE, ColorMath.matchQuality(m.dE).lowercased()))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .textSelection(.enabled)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button { model.addToPalette(hex: hex, sid: swatch?.id) } label: {
                Label("Add to Palette", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            if let s = swatch {
                let fav = model.favorites.contains(s.id)
                Button { model.toggleFavorite(s.id) } label: {
                    Image(systemName: fav ? "star.fill" : "star")
                }
                .help(fav ? "Remove from favorites" : "Add to favorites")
            }
            Menu {
                Button("Find Matches") {
                    model.matchHex = hex
                    model.destination = .match
                }
                Button("Build a Brand Around It") {
                    model.brand.useBaseColor = true
                    model.brand.baseHex = hex
                    model.brand.suggest()
                    model.destination = .brand
                }
                Divider()
                Button("Copy HEX") { model.copy(hex) }
                if let s = swatch { Button("Copy Pantone Name") { model.copy("\(s.title) \(s.name)".trimmingCharacters(in: .whitespaces), label: s.title) } }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func valuesGrid(_ values: [(String, String)]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(values, id: \.0) { k, v in
                GridRow {
                    Text(k).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
                    Text(v).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    Spacer(minLength: 0)
                    CopyButton(value: v, label: k)
                }
            }
        }
        .card(padding: 12)
    }

    private func contrast(_ rgb: RGB) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Text contrast")
            HStack(spacing: 8) {
                ForEach([("White", "#FFFFFF"), ("Black", "#111111")], id: \.0) { name, text in
                    let r = ColorMath.contrast(rgb, ColorMath.rgb(text))
                    HStack(alignment: .center) {
                        Text("Aa").font(.system(size: 22, weight: .bold))
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(name) text").font(.system(size: 10.5, weight: .semibold))
                            Text(String(format: "%.2f:1 · %@", r, ColorMath.grade(r))).font(.system(size: 10.5, design: .monospaced))
                        }
                    }
                    .foregroundStyle(Color(hex: text))
                    .padding(10)
                    .background(Color(rgb: rgb), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var tints: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Tints & shades")
            HStack(spacing: 0) {
                ForEach(ColorMath.tintsAndShades(hex), id: \.self) { t in
                    Rectangle().fill(Color(hex: t)).frame(height: 40)
                        .contentShape(Rectangle())
                        .onTapGesture { model.inspect(.custom(t)) }
                        .help(t)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func similarGrid(_ similar: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: swatch == nil ? "Nearest Pantone colors" : "Similar colors")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                ForEach(similar, id: \.swatch.id) { m in
                    MiniChip(swatch: m.swatch, detail: String(format: "ΔE %.1f", m.dE))
                        .onTapGesture { model.inspect(.swatch(m.swatch.id)) }
                        .contextMenu { SwatchMenu(swatch: m.swatch) }
                }
            }
        }
    }
}
