import SwiftUI

struct BrandStudioView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let brand = model.brand
        HSplitView {
            BrandControls()
                .frame(minWidth: 290, idealWidth: 310, maxWidth: 380)
            Group {
                if let concept = brand.selected {
                    BrandResults(concept: concept)
                } else {
                    ContentUnavailableView("No Suggestions Yet", systemImage: "sparkles",
                                           description: Text("Pick an industry and a personality, then press Suggest."))
                }
            }
            .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Brand Studio")
        .navigationSubtitle(brand.selected.map { "\(brand.brandName) · \($0.name)" } ?? "")
        .toolbar { toolbar }
        // Sets saved by earlier versions had only four palettes; refresh them into a full set of ideas.
        .onAppear { if brand.concepts.count < 8 { brand.suggest() } }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        let brand = model.brand
        ToolbarItemGroup(placement: .primaryAction) {
            Button { brand.suggest() } label: { Label("More Ideas", systemImage: "arrow.triangle.2.circlepath") }
                .keyboardShortcut("r")
                .help("New color ideas (⌘R)")
            Button {
                guard let c = brand.selected else { return }
                model.usePalette(name: "\(brand.brandName) – \(c.name)", colors: brand.paletteColors)
                model.savePalette()
            } label: { Label("Save as Palette", systemImage: "square.and.arrow.down") }
                .disabled(brand.selected == nil)
                .help("Save these five colors to My Palettes")
            Menu {
                Button("Brand Sheet (PDF)…", systemImage: "doc.richtext") { exportSheet() }
                Button("Design Tokens & Swatches…", systemImage: "curlybraces") {
                    model.export(name: brand.brandName, colors: brand.paletteColors, roles: brand.roleNames)
                }
                Button("Add to macOS Colors", systemImage: "paintpalette") {
                    model.installInColorPicker(name: brand.brandName, colors: brand.paletteColors, roles: brand.roleNames)
                }
                if brand.hasLogo {
                    Divider()
                    Button("Logo Files…", systemImage: "seal") { model.exportLogoPackage() }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(brand.selected == nil)
        }
    }

    private func exportSheet() {
        let brand = model.brand
        guard let c = brand.selected, let data = BrandSheet.pdf(kit: BrandKit(brand, concept: c), brand: brand) else { return }
        if let url = FilePanels.save(data, suggestedName: "\(Exporter.slug(brand.brandName))-brand-sheet", ext: "pdf") {
            model.showToast("Saved \(url.lastPathComponent)", actionTitle: "Open") { NSWorkspace.shared.open(url) }
        }
    }
}

// MARK: - Controls

struct BrandControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var brand = model.brand
        Form {
            Section("Brand") {
                TextField("Name", text: $brand.brandName)
                TextField("Tagline", text: $brand.tagline)
            }
            Section {
                Picker("Designing a", selection: $brand.focus) {
                    ForEach(ProjectFocus.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                Picker("Industry", selection: $brand.industry) {
                    ForEach(Industry.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Project")
            }
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 6)], spacing: 6) {
                    ForEach(Trait.allCases) { t in
                        Toggle(t.title, isOn: Binding(get: { brand.traits.contains(t) }, set: { _ in brand.toggle(t) }))
                            .toggleStyle(.button)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    }
                }
            } header: {
                Text("Personality")
            } footer: {
                Text("Pick up to three. The first one also chooses the typography.")
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section("Starting point") {
                if brand.hasLogo {
                    Toggle("Keep ideas close to my logo’s colors", isOn: $brand.logoDriven)
                        .help("Off: ideas explore the whole color wheel. On: they stay near your logo’s main color.")
                }
                Toggle("Start from a color", isOn: $brand.useBaseColor)
                    .disabled(brand.logoDriven && brand.hasLogo)
                if brand.useBaseColor {
                    LabeledContent("Base color") {
                        HexField(hex: brand.baseHex) { brand.baseHex = $0 }
                    }
                }
                Toggle("Snap to Pantone (Coated)", isOn: $brand.snapToPantone)
                Button("Use My Current Palette") {
                    brand.adopt(palette: model.current.colors.map(\.hex), name: model.current.name)
                }
                .help("Assign brand roles to the colors in the palette editor")
            }
            Section {
                LogoWell()
                if brand.hasLogo {
                    if !brand.logoHasTransparency {
                        if brand.logoBackground != nil {
                            Toggle("Remove solid background", isOn: $brand.removeLogoBackground)
                        } else {
                            Label("This logo has no transparent background. Use a PNG with transparency so it sits cleanly on any color.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Recolor logo with palette", isOn: $brand.recolorLogo)
                        .help("Repaint the logo in each palette’s colors. Turn off to keep its original colors.")
                    Toggle("Show brand name next to it", isOn: $brand.showNameWithLogo)
                }
                Picker("Mark", selection: $brand.logoStyle) {
                    if brand.hasLogo { Text(LogoStyle.custom.title).tag(LogoStyle.custom) }
                    ForEach(LogoStyle.generated) { Text($0.title).tag($0) }
                }
                Picker("Typeface", selection: $brand.typeface) {
                    ForEach(BrandTypeface.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Logo")
            } footer: {
                if !brand.hasLogo {
                    Text("Add your own logo to see it in every mockup, or pick a generated mark.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Section {
                Button {
                    brand.suggest()
                } label: {
                    Label("New Ideas", systemImage: "sparkles").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .formStyle(.grouped)
        .onChange(of: brand.industry) { brand.suggest() }
        .onChange(of: brand.traits) { brand.suggest() }
        .onChange(of: brand.useBaseColor) { brand.suggest() }
        .onChange(of: brand.baseHex) { if brand.useBaseColor { brand.suggest() } }
        .onChange(of: brand.snapToPantone) { brand.suggest() }
        .onChange(of: brand.logoDriven) { brand.suggest() }
        .onChange(of: brand.removeLogoBackground) {
            brand.processLogo()
            if brand.logoDriven { brand.suggest() }
        }
    }
}

// MARK: - Results

struct BrandResults: View {
    @Environment(AppModel.self) private var model
    let concept: BrandConcept

    var body: some View {
        @Bindable var brand = model.brand
        let kit = BrandKit(brand, concept: concept)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if brand.tab != .ideas { conceptPicker }
                Picker("View", selection: $brand.tab) {
                    ForEach(BrandTab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 520)

                switch brand.tab {
                case .ideas: BrandIdeasView()
                case .overview: BrandOverview(concept: concept, kit: kit)
                case .logo: BrandLogoTab(kit: kit)
                case .mockups: BrandMockupsTab(kit: kit)
                case .specs: BrandSpecs(concept: concept)
                }
            }
            .padding(22)
        }
    }

    private var conceptPicker: some View {
        let brand = model.brand
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(brand.concepts) { c in
                    let selected = c.id == brand.selected?.id
                    Button { brand.selectedID = c.id } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    ForEach([BrandRole.primary, .secondary, .accent, .dark, .light], id: \.self) { r in
                                        Rectangle().fill(c[r].color).frame(width: geo.size.width * weight(r))
                                    }
                                }
                            }
                            .frame(height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.primary.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.name).font(.callout.weight(.semibold))
                                Text(c.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .frame(width: 190)
                        .background(selected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? Color.accentColor : .primary.opacity(0.08), lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
        }
    }

    private func weight(_ r: BrandRole) -> Double {
        switch r {
        case .primary: 0.34
        case .secondary: 0.22
        case .accent: 0.14
        case .dark: 0.15
        case .light: 0.15
        }
    }
}

struct BrandOverview: View {
    @Environment(AppModel.self) private var model
    let concept: BrandConcept
    let kit: BrandKit

    var body: some View {
        let brand = model.brand
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(BrandRole.allCases) { r in RoleCard(role: r, color: concept[r]) }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "Suggested balance in a layout")
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach([BrandRole.light, .primary, .secondary, .dark, .accent], id: \.self) { r in
                            Rectangle().fill(concept[r].color)
                                .frame(width: max(0, geo.size.width * r.share - 2))
                                .overlay(Text("\(Int(r.share * 100))%").font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color(hex: ColorMath.readableOn(ColorMath.rgb(concept.hex(r))))))
                        }
                    }
                }
                .frame(height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.08)))
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(BrandEngine.guidance(concept, focus: brand.focus, traits: brand.traits, brandName: brand.brandName)) { section in
                        GuidanceCard(section: section)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 16) {
                    TypeCard(kit: kit, suggestion: BrandEngine.typeSuggestion(brand.traits))
                    LogoVariantCard(kit: kit, variant: .full)
                        .card(padding: 12)
                }
                .frame(width: 300)
            }
        }
    }
}

struct RoleCard: View {
    @Environment(AppModel.self) private var model
    let role: BrandRole
    let color: BrandColor

    var body: some View {
        let brand = model.brand
        let coated = BrandEngine.pantone(color), uncoated = BrandEngine.pantone(color, in: .uncoated)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Rectangle().fill(color.color).frame(height: 96)
                ColorPicker("", selection: Binding(get: { color.color }, set: { c in
                    if let h = c.hexString { brand.setColor(role, hex: h) }
                }), supportsOpacity: false)
                .labelsHidden()
                .padding(6)
                .help("Adjust this color")
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(role.title).font(.callout.weight(.semibold))
                Text(role.usage).font(.caption2).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
                Divider().padding(.vertical, 3)
                Text(color.hex).font(.system(.caption, design: .monospaced).weight(.semibold)).textSelection(.enabled)
                Text((coated.dE < 0.5 ? "" : "≈ ") + coated.swatch.code).font(.caption).lineLimit(1)
                Text("≈ " + uncoated.swatch.code).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.08)))
        .contextMenu {
            Button("Copy HEX") { model.copy(color.hex) }
            Button("Copy Pantone") { model.copy(coated.swatch.title) }
            if coated.dE >= 0.5 { Button("Snap to \(coated.swatch.title)") { brand.snapRole(role) } }
            Button("Show Details") { model.inspect(color.sid.map { .swatch($0) } ?? .custom(color.hex)) }
        }
        .onTapGesture { model.inspect(color.sid.map { .swatch($0) } ?? .custom(color.hex)) }
    }
}

struct GuidanceCard: View {
    let section: GuidanceSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(section.title, systemImage: section.symbol).font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(.secondary).frame(width: 4, height: 4).offset(y: -3)
                        Text(LocalizedStringKey(item)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .font(.callout)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct TypeCard: View {
    let kit: BrandKit
    let suggestion: TypeSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Typography", systemImage: "textformat").font(.headline)
            Text(kit.name).font(kit.font(30, nil)).foregroundStyle(kit.c(.primary)).lineLimit(1).minimumScaleFactor(0.6)
            Text("Body copy sits quietly underneath, easy to read at any size.").font(.callout).foregroundStyle(.secondary)
            Divider()
            LabeledContent("Headlines", value: suggestion.headline)
            LabeledContent("Body", value: suggestion.body)
            Text("Free on Google Fonts. Chosen for \(suggestion.why). The preview uses the closest system font.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
}

struct BrandLogoTab: View {
    @Environment(AppModel.self) private var model
    let kit: BrandKit

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.brand.hasLogo { LogoColorsCard(concept: kit.concept) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                ForEach(LogoVariant.allCases) { v in LogoVariantCard(kit: kit, variant: v) }
            }
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "App icon & favicon")
                HStack(alignment: .bottom, spacing: 24) {
                    ForEach([128.0, 64, 32, 16], id: \.self) { s in
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: s * 0.225, style: .continuous).fill(kit.c(.primary))
                                LogoMark(kit: kit, palette: LogoPalette.make(kit, .reversed), size: s * 0.62, fitSquare: true)
                            }
                            .frame(width: s, height: s)
                            .shadow(color: .black.opacity(0.15), radius: s / 16, y: s / 32)
                            Text("\(Int(s)) pt").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
            .card()
            ForEach(BrandEngine.guidance(kit.concept, focus: .logo, traits: [], brandName: kit.name).prefix(2)) { GuidanceCard(section: $0) }
        }
    }
}

struct BrandMockupsTab: View {
    let kit: BrandKit

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 18)], spacing: 22) {
            MockupFrame(title: "Business cards", detail: "Front in Primary with the reversed logo; back on Light with an Accent edge.") { BusinessCards(kit: kit).scaleEffect(0.9).frame(width: 330, height: 300) }
            MockupFrame(title: "Website", detail: "Primary for actions, Accent for one badge, Dark on Light for reading.") { WebsiteHero(kit: kit).scaleEffect(0.62).frame(width: 310, height: 202) }
            MockupFrame(title: "Mobile app", detail: "Brand header, neutral content area, Accent reserved for the main action.") { PhoneApp(kit: kit) }
            MockupFrame(title: "Social post", detail: "Primary background with Light type. Secondary and Accent add motion.") { SocialPost(kit: kit) }
            MockupFrame(title: "Packaging", detail: "Primary band for shelf recognition; Accent for a single callout.") { PackagingPouch(kit: kit) }
            MockupFrame(title: "Letterhead", detail: "Mostly white. The logo, a short Accent rule and a Primary footer carry the brand.") { Letterhead(kit: kit) }
        }
    }
}

struct BrandSpecs: View {
    @Environment(AppModel.self) private var model
    let concept: BrandConcept

    private struct Pair: Identifiable {
        let bg: BrandRole, fg: BrandRole, ratio: Double
        var id: String { bg.rawValue + fg.rawValue }
    }

    /// Every role pair that reaches at least 3:1, with the lighter color as the background.
    private var pairs: [Pair] {
        let roles = BrandRole.allCases
        return roles.indices.flatMap { i in
            roles.indices.filter { $0 > i }.map { j -> Pair in
                let a = roles[i], b = roles[j]
                let aLighter = ColorMath.luminance(ColorMath.rgb(concept.hex(a))) >= ColorMath.luminance(ColorMath.rgb(concept.hex(b)))
                return Pair(bg: aLighter ? a : b, fg: aLighter ? b : a, ratio: ColorMath.contrast(concept.hex(a), concept.hex(b)))
            }
        }
        .filter { $0.ratio >= 3 }
        .sorted { $0.ratio > $1.ratio }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow {
                    ForEach(["", "Role", "HEX", "RGB", "CMYK ≈", "Pantone C", "Pantone U"], id: \.self) {
                        Text($0).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                Divider()
                ForEach(BrandRole.allCases) { r in
                    let c = concept[r], rgb = ColorMath.rgb(c.hex)
                    GridRow {
                        RoundedRectangle(cornerRadius: 4).fill(c.color).frame(width: 22, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.1)))
                        Text(r.title).font(.callout.weight(.medium))
                        Text(c.hex).font(.system(.callout, design: .monospaced))
                        Text(rgb.ints.map(String.init).joined(separator: " ")).font(.system(.callout, design: .monospaced))
                        Text(ColorMath.cmyk(rgb).map(String.init).joined(separator: " ")).font(.system(.callout, design: .monospaced))
                        Text(BrandEngine.pantoneLabel(c)).font(.callout)
                        Text(BrandEngine.pantoneLabel(c, in: .uncoated)).font(.callout)
                    }
                    .textSelection(.enabled)
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                Label("Tint ramps for UI", systemImage: "slider.horizontal.3").font(.headline)
                Text("Use the 50–200 steps for backgrounds and borders, 500–600 for buttons, and 700–900 for text on light. Click a step to copy it.")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach([BrandRole.primary, .secondary, .accent], id: \.self) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(r.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            ForEach(ColorMath.ramp(concept.hex(r)), id: \.step) { step in
                                let fg = ColorMath.readableOn(ColorMath.rgb(step.hex))
                                Button { model.copy(step.hex, label: "\(r.title) \(step.step) \(step.hex)") } label: {
                                    VStack(spacing: 1) {
                                        Text("\(step.step)").font(.system(size: 10, weight: .semibold))
                                        Text(step.hex.dropFirst()).font(.system(size: 8.5, design: .monospaced))
                                    }
                                    .foregroundStyle(Color(hex: fg))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Color(hex: step.hex))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help(String(format: "%@ · white %.1f:1 · black %.1f:1", step.hex, ColorMath.contrast(step.hex, "#FFFFFF"), ColorMath.contrast(step.hex, "#000000")))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 10) {
                Label("Accessible pairings", systemImage: "eye").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], spacing: 8) {
                    ForEach(pairs) { p in
                        HStack {
                            Text("Aa").font(.system(size: 18, weight: .bold)).foregroundStyle(concept[p.fg].color)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(p.fg.title) on \(p.bg.title)").font(.caption.weight(.semibold))
                                Text(String(format: "%.1f:1 · %@", p.ratio, ColorMath.grade(p.ratio))).font(.system(.caption2, design: .monospaced))
                            }
                            .foregroundStyle(Color(hex: ColorMath.readableOn(ColorMath.rgb(concept.hex(p.bg)))))
                            Spacer()
                        }
                        .padding(10)
                        .background(concept[p.bg].color, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .card()

            if let css = Exporter.text(.css, name: model.brand.brandName, entries: model.exportEntries(model.brand.paletteColors, roles: model.brand.roleNames)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("CSS tokens", systemImage: "curlybraces").font(.headline)
                        Spacer()
                        Button("Copy") { model.copy(css, label: "CSS tokens") }
                        Button("More Formats…") { model.export(name: model.brand.brandName, colors: model.brand.paletteColors, roles: model.brand.roleNames) }
                    }
                    Text(css).font(.system(size: 11.5, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
                .card()
            }
        }
    }
}
