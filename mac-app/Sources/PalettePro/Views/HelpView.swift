import SwiftUI

/// The Help window: a short guide to each part of the app plus keyboard shortcuts.
struct HelpView: View {
    var body: some View {
        ScrollView { HelpPage() }
            .frame(minWidth: 620, minHeight: 520)
    }
}

struct HelpPage: View {
    private struct Topic: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        let points: [String]
    }

    private let topics: [Topic] = [
        Topic(title: "Library", symbol: "square.grid.3x3.fill", points: [
            "Browse more than 5,500 Pantone-style colors by collection in the sidebar.",
            "Search by name, code or hex. A hex such as **#0F4C81** lists the closest Pantones.",
            "Click a chip for its values, contrast and similar colors. Hover and press **+** to add it to your palette.",
        ]),
        Topic(title: "Palette", symbol: "swatchpalette", points: [
            "Press **Space** to generate colors. Lock the ones you like and they stay put.",
            "Edit a hex directly, use the color well, or drag colors to reorder. Drop chips in from the Library.",
            "Turn on **Snap to Pantone** to keep every color a real Pantone. The contrast table checks text readability.",
        ]),
        Topic(title: "Brand Studio", symbol: "sparkles.rectangle.stack", points: [
            "Type your brand name or add your logo (SVG or PNG). **Ideas** previews it in 12 palettes, repainting the logo in each one.",
            "Click an idea to use it everywhere: logo versions, mockups, specs and the brand sheet.",
            "Export a **brand sheet PDF**, design tokens, or a **logo package** with color, dark and white versions.",
        ]),
        Topic(title: "Fonts", symbol: "textformat", points: [
            "Browse 1,500+ free fonts from Google Fonts, Fontshare and open-source foundries, plus the fonts on your Mac.",
            "**Designer Picks** collects the fonts designers use most. Filter by style, search by name or designer, and type your own preview text.",
            "Fonts download the first time you see them and stay inside Palette Pro. Click a font for every weight, its characters and license, or **Get Font** for the full family.",
        ]),
        Topic(title: "Pairing & Type Scale", symbol: "textformat.size", points: [
            "**Pairing** suggests 12 heading and body combinations with a reason for each. Explore, or start from a font you like, and pick a mood.",
            "Double-click a pairing for a full page preview, then **Use in Type Scale**.",
            "**Type Scale** builds every text size from one base size and ratio, with line heights, and exports CSS, SCSS, Tailwind, SwiftUI or design tokens.",
        ]),
        Topic(title: "Match", symbol: "eyedropper", points: [
            "Find the nearest Pantones to any color, ranked by ΔE (under 1 looks identical).",
            "Use **Pick from Screen** to sample anything on your display, or drop in a photo to extract its palette.",
        ]),
        Topic(title: "Export & share", symbol: "square.and.arrow.up", points: [
            "Export palettes as CSS, SCSS, Tailwind, SwiftUI, JSON, GIMP, Adobe .ase, Apple .clr or PNG.",
            "**Add to macOS Colors** puts a palette in the color picker of Pages, Keynote and other Mac apps.",
            "**File › Back Up Library** saves everything to one file you can restore later.",
        ]),
    ]

    private let shortcuts: [(String, String)] = [
        ("⌘1 – ⌘5", "Library, Palette, Brand Studio, My Palettes, Match"),
        ("⌘6 – ⌘8", "Fonts, Pairing, Type Scale"),
        ("Space  /  ⌘G", "Generate a palette"),
        ("⌥⌘N", "Add a color"),
        ("⌘S", "Save palette"),
        ("⌘E", "Export palette"),
        ("⇧⌘I", "Import colors"),
        ("⌘R", "More ideas in Brand Studio and Pairing"),
        ("⌥⌘I", "Show or hide the inspector"),
        ("⌘Z  /  ⇧⌘Z", "Undo / Redo"),
    ]

    var body: some View {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Palette Pro Help").font(.largeTitle.weight(.bold))
                        Text("Colors, fonts, palettes and brand ideas, with Pantone references.")
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 18, alignment: .top)], alignment: .leading, spacing: 18) {
                    ForEach(topics) { topic in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(topic.title, systemImage: topic.symbol).font(.title3.weight(.semibold))
                            ForEach(topic.points, id: \.self) { point in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Circle().fill(.secondary).frame(width: 4, height: 4).offset(y: -3)
                                    Text(LocalizedStringKey(point)).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Keyboard shortcuts", systemImage: "keyboard").font(.title3.weight(.semibold))
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                        ForEach(shortcuts, id: \.0) { keys, action in
                            GridRow {
                                Text(keys).font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
                                Text(action).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                Text("PANTONE® is a trademark of Pantone LLC. Color values are screen approximations from public sources; for print, check against a physical Pantone guide.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .textSelection(.enabled)
    }
}
