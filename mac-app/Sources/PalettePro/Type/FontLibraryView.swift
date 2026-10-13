import SwiftUI

struct FontLibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var t = model.typography
        let list = t.fonts()
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                FontFilterBar()
                if list.isEmpty {
                    ContentUnavailableView {
                        Label(t.filter == .favorites && t.query.isEmpty ? "No Favorite Fonts Yet" : "No Fonts Match",
                              systemImage: t.filter == .favorites ? "star" : "magnifyingglass")
                    } description: {
                        Text(t.filter == .favorites && t.query.isEmpty
                             ? "Click the star on any font to keep it here."
                             : "Try a different search or style.")
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 16)], spacing: 16) {
                        ForEach(list) { FontCard(family: $0) }
                    }
                }
            }
            .padding(20)
        }
        .searchable(text: $t.query, placement: .toolbar, prompt: "Font name or designer")
        .navigationTitle("Fonts")
        .navigationSubtitle("\(list.count.formatted()) families · \(t.filter.title)")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Picker("Sort", selection: $t.sort) {
                        ForEach(FontSort.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort: \(t.sort.title)", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort order")
            }
        }
        .sheet(item: $t.detail) { FontDetailSheet(family: $0) }
    }
}

/// Collections, styles and the preview text.
struct FontFilterBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var t = model.typography
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FontFilter.allCases) { f in
                        FilterChip(title: f.title, count: f == .favorites ? t.favorites.count : nil, symbol: f.symbol,
                                   selected: t.filter == f) { t.filter = f }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All Styles", selected: t.category == nil) { t.category = nil }
                    ForEach(FontCategory.allCases) { c in
                        FilterChip(title: c.title, selected: t.category == c) { t.category = t.category == c ? nil : c }
                    }
                }
            }
            HStack(spacing: 12) {
                Image(systemName: "character.cursor.ibeam").foregroundStyle(.secondary)
                TextField("Type your own preview text", text: $t.sampleText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 520)
                Slider(value: $t.sampleSize, in: 16...96, step: 2)
                    .frame(width: 160)
                    .help("Preview size")
                Text("\(Int(t.sampleSize)) pt")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)
            }
        }
    }
}

struct FontCard: View {
    @Environment(AppModel.self) private var model
    let family: FontFamily
    @State private var hovering = false

    var body: some View {
        let t = model.typography
        let favorite = t.favorites.contains(family.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(family.family).font(.callout.weight(.semibold)).lineLimit(1)
                if family.pick {
                    Image(systemName: "sparkles").font(.caption).foregroundStyle(.secondary).help("Designer pick")
                }
                Spacer(minLength: 4)
                Button { t.toggleFavorite(family) } label: {
                    Image(systemName: favorite ? "star.fill" : "star")
                        .foregroundStyle(favorite ? Color.yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .opacity(favorite || hovering ? 1 : 0)
                .help(favorite ? "Remove from favorites" : "Add to favorites")
            }
            FontText(family: family, text: t.sample, size: t.sampleSize)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: t.sampleSize * 2.6, maxHeight: t.sampleSize * 2.6, alignment: .topLeading)
                .clipped()
            HStack(spacing: 6) {
                Text(meta).lineLimit(1)
                Spacer(minLength: 4)
                Text(family.source.title)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(.quaternary.opacity(0.6), in: Capsule())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(hovering ? 0.18 : 0.07)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering = $0 }
        .onTapGesture { t.detail = family }
        .contextMenu { FontMenu(family: family) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var meta: String {
        [family.category.title, "\(family.styleCount) style\(family.styleCount == 1 ? "" : "s")", family.variable ? "Variable" : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

struct FontMenu: View {
    @Environment(AppModel.self) private var model
    let family: FontFamily

    var body: some View {
        let t = model.typography
        Button("Show Details", systemImage: "info.circle") { t.detail = family }
        Button(t.favorites.contains(family.id) ? "Remove from Favorites" : "Add to Favorites", systemImage: "star") { t.toggleFavorite(family) }
        Divider()
        Button("Find Pairings", systemImage: "rectangle.on.rectangle") {
            t.pair(with: family)
            model.destination = .pairing
        }
        Menu("Use in Type Scale") {
            Button("For Headings") { t.scaleHeadingID = family.id; model.destination = .scale }
            Button("For Body Text") { t.scaleBodyID = family.id; model.destination = .scale }
            Button("For Both") { t.scaleHeadingID = family.id; t.scaleBodyID = family.id; model.destination = .scale }
        }
        Divider()
        Button("Copy Name") { model.copy(family.family) }
        Button("Copy CSS font-family") { model.copy("font-family: \(family.cssStack);", label: "font-family") }
        if let url = family.pageURL {
            Button("Get Font on \(family.source == .google ? "Google Fonts" : family.source.title)…", systemImage: "arrow.down.circle") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Detail

struct FontDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let family: FontFamily

    private static let weightNames = [100: "Thin", 200: "Extra Light", 300: "Light", 400: "Regular", 500: "Medium",
                                      600: "Semibold", 700: "Bold", 800: "Extra Bold", 900: "Black"]

    var body: some View {
        let t = model.typography
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        FontText(family: family, text: family.family, size: 52, weight: family.heading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(subtitle).foregroundStyle(.secondary)
                    }
                    actions(t)

                    section("Styles") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(family.weights, id: \.self) { w in
                                styleRow(w, italic: false, t)
                                if family.italic { styleRow(w, italic: true, t) }
                            }
                        }
                    }

                    section("Sizes") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach([12, 16, 24, 36, 64] as [CGFloat], id: \.self) { s in
                                HStack(alignment: .firstTextBaseline, spacing: 14) {
                                    Text("\(Int(s))").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 26, alignment: .trailing)
                                    FontText(family: family, text: t.sample, size: s).lineLimit(1)
                                }
                            }
                        }
                    }

                    section("Characters") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(["ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", "0123456789  & @ # % ? ! € $ £ “ ” ‘ ’ ( ) [ ] / – —",
                                     "ÀÉÎÕÜ àéîõü ÆØÅ æøå ß Ç ç Ñ ñ"], id: \.self) { line in
                                FontText(family: family, text: line, size: 26).lineLimit(1).minimumScaleFactor(0.5)
                            }
                        }
                    }

                    section("License") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(family.licenseTitle).font(.callout.weight(.semibold))
                            Text(family.licenseNote).font(.callout).foregroundStyle(.secondary)
                            if family.source != .installed {
                                Text("Previews here use a downloaded copy of the Latin character set. Use “Get Font” for the complete family.")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            Divider()
            HStack {
                if let url = family.pageURL {
                    Link(destination: url) { Label("Open on \(family.source == .open ? "Fontsource" : family.source.title)", systemImage: "safari") }
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 780, height: 680)
    }

    private var subtitle: String {
        var parts = [family.category.title, "\(family.styleCount) styles"]
        if family.variable { parts.append("variable") }
        if !family.designers.isEmpty { parts.append("by \(family.designers)") }
        parts.append(family.source.title)
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func actions(_ t: TypeModel) -> some View {
        HStack(spacing: 10) {
            Button {
                t.pair(with: family)
                model.destination = .pairing
                dismiss()
            } label: { Label("Find Pairings", systemImage: "rectangle.on.rectangle") }
                .buttonStyle(.borderedProminent)
            Menu {
                Button("For Headings") { t.scaleHeadingID = family.id; model.destination = .scale; dismiss() }
                Button("For Body Text") { t.scaleBodyID = family.id; model.destination = .scale; dismiss() }
                Button("For Both") { t.scaleHeadingID = family.id; t.scaleBodyID = family.id; model.destination = .scale; dismiss() }
            } label: { Label("Use in Type Scale", systemImage: "textformat.size") }
                .fixedSize()
            if let embed = family.cssEmbed(weights: family.weights) {
                Button { model.copy(embed, label: "embed code") } label: { Label("Copy Embed Code", systemImage: "chevron.left.forwardslash.chevron.right") }
            }
            if let url = family.pageURL {
                Button { NSWorkspace.shared.open(url) } label: { Label("Get Font", systemImage: "arrow.down.circle") }
                    .help("Download the complete family from \(family.source == .open ? "Fontsource" : family.source.title)")
            }
            Spacer()
            Button { t.toggleFavorite(family) } label: {
                Image(systemName: t.favorites.contains(family.id) ? "star.fill" : "star")
                    .foregroundStyle(t.favorites.contains(family.id) ? Color.yellow : .secondary)
            }
            .help("Favorite")
        }
    }

    private func styleRow(_ w: Int, italic: Bool, _ t: TypeModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(Self.weightNames[w] ?? "\(w)")\(italic ? " Italic" : "") · \(w)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            FontText(family: family, text: t.sample, size: 26, weight: w, italic: italic).lineLimit(1)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title)
            content()
        }
    }
}

// MARK: - Picker

/// A button showing the chosen font; opens a searchable list of every font.
struct FontPickerButton: View {
    @Binding var selection: String?
    var anyTitle: String?
    @State private var open = false

    var body: some View {
        let family = selection.flatMap { FontCatalog.shared.family(id: $0) }
        Button { open = true } label: {
            HStack(spacing: 6) {
                if let family {
                    FontText(family: family, text: family.family, size: 13).lineLimit(1)
                } else {
                    Text(anyTitle ?? "Choose a font").lineLimit(1)
                }
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .popover(isPresented: $open, arrowEdge: .trailing) {
            FontPickerList(selection: $selection, anyTitle: anyTitle) { open = false }
                .frame(width: 340, height: 480)
        }
    }
}

struct FontPickerList: View {
    @Binding var selection: String?
    var anyTitle: String?
    let done: () -> Void
    @State private var query = ""
    @State private var category: FontCategory?

    var body: some View {
        let catalog = FontCatalog.shared
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = catalog.all
            .filter { category == nil || $0.category == category }
            .filter { q.isEmpty || $0.search.contains(q) }
            .sorted { ($0.family.lowercased().hasPrefix(q) ? 0 : 1, $0.rank, $0.family) < ($1.family.lowercased().hasPrefix(q) ? 0 : 1, $1.rank, $1.family) }
        VStack(spacing: 8) {
            TextField("Search fonts", text: $query)
                .textFieldStyle(.roundedBorder)
            Picker("Style", selection: $category) {
                Text("All styles").tag(FontCategory?.none)
                ForEach(FontCategory.allCases) { Text($0.title).tag(FontCategory?.some($0)) }
            }
            .labelsHidden()
            List {
                if let anyTitle, q.isEmpty {
                    Button { selection = nil; done() } label: {
                        Label(anyTitle, systemImage: "sparkles").frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                ForEach(list) { f in
                    Button { selection = f.id; done() } label: {
                        HStack {
                            FontText(family: f, text: f.family, size: 18).lineLimit(1)
                            Spacer()
                            if f.id == selection { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                            Text(f.category.title).font(.caption).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
        .padding(12)
    }
}
