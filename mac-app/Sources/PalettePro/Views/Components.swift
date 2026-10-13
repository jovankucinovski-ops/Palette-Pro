import SwiftUI

/// Pantone-style chip: colour block over a white label.
struct ChipView: View {
    @Environment(AppModel.self) private var model
    let swatch: Swatch
    var deltaE: Double?
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(swatch.color)
                .aspectRatio(1 / 0.92, contentMode: .fit)
            VStack(alignment: .leading, spacing: 1) {
                Text("PANTONE®").font(.system(size: 9.5, weight: .heavy)).tracking(0.2)
                Text(swatch.code).font(.system(size: 13, weight: .bold)).lineLimit(1)
                Text(swatch.subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(hovering ? 0.2 : 0.09), radius: hovering ? 10 : 3, y: hovering ? 6 : 1.5)
        .offset(y: hovering ? -2 : 0)
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { model.addToPalette(hex: swatch.hex, sid: swatch.id) } label: {
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(.white, in: Circle())
                        .foregroundStyle(.black)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .help("Add to palette")
                .padding(7)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            if let deltaE {
                Text(String(format: "ΔE %.1f", deltaE))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(.white)
                    .padding(7)
            } else if model.favorites.contains(swatch.id) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorMath.readableOn(swatch.rgb) == "#FFFFFF" ? .white : .black.opacity(0.75))
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .onTapGesture { model.inspect(.swatch(swatch.id)) }
        .draggable(swatch.hex)
        .contextMenu { SwatchMenu(swatch: swatch) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(swatch.title) \(swatch.name)")
        .accessibilityAddTraits(.isButton)
    }
}

struct SwatchMenu: View {
    @Environment(AppModel.self) private var model
    let swatch: Swatch

    var body: some View {
        Button("Add to Palette") { model.addToPalette(hex: swatch.hex, sid: swatch.id) }
        Button(model.favorites.contains(swatch.id) ? "Remove from Favorites" : "Add to Favorites") { model.toggleFavorite(swatch.id) }
        Divider()
        Button("Copy HEX \(swatch.hex)") { model.copy(swatch.hex) }
        Button("Copy Name") { model.copy("\(swatch.title)\(swatch.name.isEmpty ? "" : " " + swatch.name)", label: swatch.title) }
        Divider()
        Button("Find Matches") {
            model.matchHex = swatch.hex
            model.destination = .match
        }
        Button("Build a Brand Around It") {
            model.brand.useBaseColor = true
            model.brand.baseHex = swatch.hex
            model.brand.suggest()
            model.destination = .brand
        }
    }
}

/// Small chip used for similar colours and matches.
struct MiniChip: View {
    let swatch: Swatch
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(swatch.color).frame(height: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(swatch.code).font(.system(size: 11, weight: .bold)).lineLimit(1)
                Text(swatch.name.isEmpty ? Library.shared.collectionName(swatch.coll) : swatch.name)
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                if let detail { Text(detail).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary) }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}

struct FilterChip: View {
    let title: String
    var count: Int?
    var dot: Color?
    var symbol: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot { Circle().fill(dot).frame(width: 10, height: 10).overlay(Circle().strokeBorder(.black.opacity(0.12))) }
                if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)) }
                Text(title).font(.system(size: 12, weight: .medium))
                if let count { Text(count.formatted()).font(.system(size: 10.5, weight: .semibold)).opacity(0.55) }
            }
            .padding(.horizontal, 11)
            .frame(height: 26)
            .background(selected ? Color.primary : Color(nsColor: .controlBackgroundColor), in: Capsule())
            .foregroundStyle(selected ? Color(nsColor: .windowBackgroundColor) : .primary)
            .overlay(Capsule().strokeBorder(Color.primary.opacity(selected ? 0 : 0.12)))
        }
        .buttonStyle(.plain)
    }
}

struct CopyButton: View {
    @Environment(AppModel.self) private var model
    let value: String
    var label: String?

    var body: some View {
        Button { model.copy(value, label: label) } label: {
            Image(systemName: "doc.on.doc").font(.system(size: 11))
        }
        .buttonStyle(.borderless)
        .help("Copy \(label ?? value)")
    }
}

/// Text field for a hex value with an attached system colour well.
struct HexField: View {
    let hex: String
    let onCommit: (String) -> Void
    @State private var text = ""

    var body: some View {
        HStack(spacing: 6) {
            TextField("Hex", text: $text)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .frame(width: 112)
                .onSubmit(commit)
            ColorPicker("", selection: Binding(get: { Color(hex: hex) }, set: { c in c.hexString.map(onCommit) }), supportsOpacity: false)
                .labelsHidden()
        }
        .onAppear { text = hex }
        .onChange(of: hex) { text = hex }
    }

    private func commit() {
        if let h = ColorMath.parseHex(text) { onCommit(h) } else { text = hex }
    }
}

extension View {
    /// Card surface used across panels.
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.07)))
    }
}

struct SectionTitle: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}
