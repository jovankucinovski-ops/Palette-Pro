import SwiftUI

/// A grid of color ideas, each previewing the logo (or brand name) in that palette.
struct BrandIdeasView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let brand = model.brand
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Color ideas").font(.title2.weight(.semibold))
                    Text(intro(brand))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { brand.suggest() } label: { Label("More Ideas", systemImage: "arrow.triangle.2.circlepath") }
                    .help("Generate new color ideas (⌘R)")
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 16)], spacing: 18) {
                ForEach(brand.concepts) { concept in
                    IdeaCard(concept: concept, selected: concept.id == brand.selected?.id)
                }
            }
        }
    }

    private func intro(_ brand: BrandModel) -> String {
        let name = brand.brandName.trimmingCharacters(in: .whitespaces)
        if brand.usesLogoImage {
            return brand.recolorLogo
                ? "Your logo repainted in \(brand.concepts.count) palettes. The first card keeps its original colors. Click an idea to use it everywhere."
                : "Your logo with \(brand.concepts.count) palettes around it. Turn on “Recolor logo with palette” to repaint it in each one."
        }
        return name.isEmpty
            ? "Type a brand name or add a logo to preview it in each palette."
            : "“\(name)” in \(brand.concepts.count) palettes. Add a logo to see it recolored too. Click an idea to use it everywhere."
    }
}

struct IdeaCard: View {
    @Environment(AppModel.self) private var model
    let concept: BrandConcept
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        let brand = model.brand
        let kit = BrandKit(brand, concept: concept)
        VStack(spacing: 0) {
            ZStack {
                kit.c(.light)
                VStack(spacing: 10) {
                    LogoLockup(kit: kit, variant: .full, size: 34)
                    if !kit.tagline.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(kit.tagline)
                            .font(kit.font(12, .regular))
                            .foregroundStyle(kit.c(.dark).opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 140)

            HStack(spacing: 0) {
                ZStack {
                    kit.c(.primary)
                    LogoLockup(kit: kit, variant: .reversed, size: 17)
                }
                ZStack {
                    kit.c(.dark)
                    LogoLockup(kit: kit, variant: .monoLight, size: 17)
                }
            }
            .frame(height: 56)
            .clipped()

            HStack(spacing: 10) {
                HStack(spacing: -5) {
                    ForEach([BrandRole.primary, .secondary, .accent, .dark, .light], id: \.self) { r in
                        Circle().fill(concept[r].color).frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(Color(nsColor: .controlBackgroundColor), lineWidth: 1.5))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(concept.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(concept.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor).font(.title3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : .primary.opacity(hovering ? 0.18 : 0.08), lineWidth: selected ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(hovering ? 0.16 : 0.06), radius: hovering ? 12 : 4, y: hovering ? 6 : 2)
        .scaleEffect(hovering ? 1.01 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .onTapGesture(count: 2) {
            brand.selectedID = concept.id
            brand.tab = .overview
        }
        .onTapGesture { brand.selectedID = concept.id }
        .contextMenu {
            Button("Use This Palette", systemImage: "checkmark.circle") { brand.selectedID = concept.id }
            Button("Show Details", systemImage: "info.circle") {
                brand.selectedID = concept.id
                brand.tab = .overview
            }
            Button("See Mockups", systemImage: "rectangle.on.rectangle") {
                brand.selectedID = concept.id
                brand.tab = .mockups
            }
            Divider()
            Button("Save as Palette", systemImage: "square.and.arrow.down") {
                let colors = BrandRole.allCases.map { PaletteColor(hex: concept.hex($0), sid: concept[$0].sid) }
                let p = model.createPalette(name: "\(brand.brandName) – \(concept.name)", colors: colors)
                model.showToast("Saved “\(p.name)” to My Palettes", actionTitle: "View") { model.destination = .saved }
            }
        }
        .help("Click to use this palette. Double-click for details.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(concept.name), \(concept.subtitle)\(selected ? ", selected" : "")")
        .accessibilityAddTraits(.isButton)
    }
}
