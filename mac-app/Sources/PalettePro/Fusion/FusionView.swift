import SwiftUI

struct FusionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let f = model.fusion
        Group {
            if let s = f.style {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        FusionControls()
                        FusionExample(style: s, layout: f.layout, brand: brandName)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.primary.opacity(0.08)))
                            .compositingGroup()
                            .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
                            .frame(maxWidth: 1100)
                            .animation(.easeInOut(duration: 0.25), value: s)
                        FusionSlots(style: s)
                        FusionChecks(style: s)
                        if !f.saved.isEmpty { FusionSaved() }
                    }
                    .padding(22)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Fusion")
        .navigationSubtitle(f.style.map { "\($0.name) · \($0.fontsSubtitle)" } ?? "")
        .toolbar { toolbar }
        .onAppear { if f.style == nil { f.generate() } }
    }

    private var brandName: String {
        let n = model.brand.brandName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "Northwind" : n
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        let f = model.fusion
        ToolbarItemGroup(placement: .primaryAction) {
            Button { f.save() } label: {
                Label(f.isSaved ? "Saved" : "Save Style", systemImage: f.isSaved ? "bookmark.fill" : "bookmark")
            }
            .disabled(f.style == nil || f.isSaved)
            .help("Keep this style in Saved Styles below")
            Menu {
                Button("Copy CSS", systemImage: "chevron.left.forwardslash.chevron.right") {
                    if let s = f.style { model.copy(f.css(s), label: "CSS") }
                }
                Button("Save Colors as Palette", systemImage: "swatchpalette") {
                    guard let s = f.style else { return }
                    let p = model.createPalette(name: s.name, colors: f.paletteColors(s))
                    model.showToast("Saved “\(p.name)” to My Palettes", actionTitle: "View") { model.destination = .saved }
                }
                Button("Use Fonts in Type Scale", systemImage: "textformat.size") {
                    guard let s = f.style else { return }
                    model.typography.scaleHeadingID = s.headingID
                    model.typography.scaleBodyID = s.bodyID
                    model.destination = .scale
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(f.style == nil)
            .help("Copy CSS, save the colors or use the fonts in Type Scale")
        }
    }
}

// MARK: - Controls

struct FusionControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var f = model.fusion
        HStack(spacing: 14) {
            Button { f.generate() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Generate")
                    Text("Space").font(.caption.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 5))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .help("New colors and fonts. Locked ones stay. Undo with ⌘Z.")

            Picker("Mood", selection: $f.mood) {
                ForEach(PairMood.allCases) { Text($0.title).tag($0) }
            }
            .fixedSize()
            Picker("Page", selection: $f.tone) {
                ForEach(FusionTone.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Light, dark or colored backgrounds, or a mix")
            Toggle("Pantone accent", isOn: $f.snapAccent)
                .toggleStyle(.checkbox)
                .help("Snap the accent to the nearest Pantone Coated color")
            Spacer(minLength: 8)
            Picker("Example", selection: $f.layout) {
                ForEach(FusionLayout.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .onChange(of: f.mood) { f.generate() }
        .onChange(of: f.tone) { f.generate() }
    }
}

// MARK: - Slots

struct FusionSlots: View {
    @Environment(AppModel.self) private var model
    let style: FusionStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: "Colors and fonts")
                Spacer()
                Text("Lock what you like; Generate changes the rest. Click a color or font to change it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)], alignment: .leading, spacing: 12) {
                ColorSlot(role: .background, slot: .background, style: style)
                ColorSlot(role: .text, slot: .text, style: style)
                ColorSlot(role: .accent, slot: .accent, style: style)
                ColorSlot(role: .surface, slot: nil, style: style)
                ColorSlot(role: .muted, slot: nil, style: style)
                ColorSlot(role: .onAccent, slot: nil, style: style)
            }
            HStack(spacing: 12) {
                FontSlot(heading: true, style: style)
                FontSlot(heading: false, style: style)
            }
        }
    }
}

private struct LockButton: View {
    @Environment(AppModel.self) private var model
    let slot: FusionSlot
    var ink: Color = .primary

    var body: some View {
        let locked = model.fusion.locks.contains(slot)
        Button { model.fusion.toggle(slot) } label: {
            Image(systemName: locked ? "lock.fill" : "lock.open")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(ink.opacity(locked ? 0.18 : 0.08), in: Circle())
                .foregroundStyle(ink)
        }
        .buttonStyle(.plain)
        .help(locked ? "Locked: Generate keeps it. Click to unlock." : "Lock to keep it when generating")
        .accessibilityLabel(locked ? "Unlock" : "Lock")
    }
}

struct ColorSlot: View {
    @Environment(AppModel.self) private var model
    let role: FusionRole
    /// Nil for colors that follow the others.
    let slot: FusionSlot?
    let style: FusionStyle
    @State private var editing = false

    var body: some View {
        let hex = style[role]
        let ink = Color(hex: ColorMath.readableOn(ColorMath.rgb(hex)))
        let pantone = Library.shared.nearest1(hex, in: .coated)
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: hex))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.1)))
                Text(hex).font(.system(.caption, design: .monospaced).weight(.semibold)).foregroundStyle(ink.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(10)
                if let slot { LockButton(slot: slot, ink: ink).padding(6) }
            }
            .frame(height: 74)
            .contentShape(Rectangle())
            .onTapGesture { if slot != nil { editing = true } else { model.inspect(.custom(hex)) } }
            .popover(isPresented: $editing, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(role.title).font(.headline)
                    HexField(hex: hex) { model.fusion.setColor(role, $0) }
                    Text("Changing it locks it, so Generate keeps it.").font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
            }
            Text(role.title).font(.callout.weight(.semibold))
            Text(slot == nil ? "Follows the others" : "\(pantone.dE < 0.5 ? "" : "≈ ")PANTONE \(pantone.swatch.code)")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .contextMenu {
            Button("Copy HEX") { model.copy(hex) }
            Button("Show Details") { model.inspect(.custom(hex)) }
            Button("Add to Palette") { model.addToPalette(hex: hex) }
        }
        .help(role.usage)
    }
}

struct FontSlot: View {
    @Environment(AppModel.self) private var model
    let heading: Bool
    let style: FusionStyle

    var body: some View {
        let family = heading ? style.heading : style.body
        let weight = heading ? style.headingWeight : style.bodyWeight
        HStack(spacing: 14) {
            if let family {
                FontText(family: family, text: "Aa", size: 40, weight: weight)
                    .foregroundStyle(Color(hex: style[.text]))
                    .frame(width: 84, height: 74)
                    .background(Color(hex: style[.background]), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.1)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(heading ? "Heading font" : "Body font").font(.caption).foregroundStyle(.secondary)
                FontPickerButton(selection: Binding(get: { heading ? style.headingID : style.bodyID },
                                                    set: { if let id = $0 { model.fusion.setFont(heading: heading, id) } }))
                if let family {
                    Text("Weight \(weight) · \(family.category.title) · \(family.source.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            LockButton(slot: heading ? .heading : .body)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.07)))
        .contextMenu {
            if let family {
                Button("Show Font Details") { model.typography.detail = family; model.destination = .fonts }
                Button("Find Pairings for \(family.family)") { model.typography.pair(with: family); model.destination = .pairing }
            }
        }
    }
}

// MARK: - Contrast and saved styles

struct FusionChecks: View {
    let style: FusionStyle

    var body: some View {
        HStack(spacing: 10) {
            ForEach(FusionEngine.checks(style), id: \.label) { check in
                let ok = check.ratio >= check.needed
                HStack(spacing: 8) {
                    Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(ok ? Color.green : Color.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(check.label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Text(String(format: "%.1f : 1 · %@", check.ratio, ColorMath.grade(check.ratio))).font(.callout.weight(.semibold).monospacedDigit())
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .help(ok ? "Readable (needs \(fmt(check.needed)):1)." : "Below \(fmt(check.needed)):1 — hard to read for some people.")
            }
        }
    }
}

struct FusionSaved: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let f = model.fusion
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Saved styles")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(f.saved) { s in
                        Button { f.set(s, action: "Open Saved Style") } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                if let h = s.heading {
                                    FontText(family: h, text: "Aa", size: 30, weight: s.headingWeight)
                                        .foregroundStyle(Color(hex: s[.text]))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .frame(height: 64)
                                        .background(Color(hex: s[.background]))
                                        .overlay(alignment: .bottomTrailing) {
                                            Circle().fill(Color(hex: s[.accent])).frame(width: 22, height: 22).padding(10)
                                        }
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(s.name).font(.caption.weight(.semibold)).lineLimit(1)
                                    Text(s.fontsSubtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.bottom, 8)
                            }
                            .frame(width: 170)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", role: .destructive) { f.saved.removeAll { $0.id == s.id } }
                        }
                    }
                }
                .padding(2)
            }
        }
    }
}
