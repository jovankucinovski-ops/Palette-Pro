import SwiftUI

struct SavedView: View {
    @Environment(AppModel.self) private var model
    @State private var renaming: Palette?
    @State private var newName = ""

    var body: some View {
        Group {
            if model.palettes.isEmpty {
                ContentUnavailableView {
                    Label("No Saved Palettes", systemImage: "rectangle.stack")
                } description: {
                    Text("Build a palette and press ⌘S, or import a list of hex codes or Pantone numbers.")
                } actions: {
                    Button("Start a Palette") { model.destination = .builder }
                        .buttonStyle(.borderedProminent)
                    Button("Import Colors…") { model.showImport = true }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 18)], spacing: 18) {
                        ForEach(model.palettes) { p in
                            PaletteCard(palette: p, isOpen: model.current.savedID == p.id) {
                                newName = p.name
                                renaming = p
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("My Palettes")
        .navigationSubtitle("\(model.palettes.count) saved")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.newPalette() } label: { Label("New Palette", systemImage: "plus") }
                    .help("New palette (⌘N)")
                Menu {
                    Button("Import Colors…", systemImage: "text.badge.plus") { model.showImport = true }
                    Button("Restore Backup…", systemImage: "arrow.counterclockwise") { model.runRestore() }
                    Divider()
                    Button("Back Up Library…", systemImage: "externaldrive") { model.runBackup() }
                } label: {
                    Label("Import & Back Up", systemImage: "tray.and.arrow.down")
                }
            }
        }
        .alert("Rename Palette", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") { if let p = renaming { model.rename(p, to: newName) } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct PaletteCard: View {
    @Environment(AppModel.self) private var model
    let palette: Palette
    let isOpen: Bool
    let onRename: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(palette.colors) { c in
                    Rectangle().fill(Color(hex: c.hex)).help(c.hex)
                }
            }
            .frame(height: 118)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(palette.name).font(.headline).lineLimit(1)
                    Text("\(palette.colors.count) colors · \(palette.updatedAt.formatted(date: .abbreviated, time: .omitted))\(isOpen ? " · Open" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    menuItems
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 15))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isOpen ? Color.accentColor : .primary.opacity(0.08), lineWidth: isOpen ? 2 : 1))
        .shadow(color: .black.opacity(hovering ? 0.14 : 0.06), radius: hovering ? 12 : 4, y: hovering ? 6 : 2)
        .scaleEffect(hovering ? 1.01 : 1)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .onTapGesture(count: 2) { model.open(palette) }
        .contextMenu { menuItems }
        .help("Double-click to open")
    }

    @ViewBuilder private var menuItems: some View {
        Button("Open", systemImage: "swatchpalette") { model.open(palette) }
        Button("Rename…", systemImage: "pencil") { onRename() }
        Button("Duplicate", systemImage: "plus.square.on.square") { model.duplicate(palette) }
        Divider()
        Button("Export…", systemImage: "square.and.arrow.up") { model.export(name: palette.name, colors: palette.colors) }
        Button("Add to macOS Colors", systemImage: "paintpalette") { model.installInColorPicker(name: palette.name, colors: palette.colors) }
        Button("Open in Brand Studio", systemImage: "sparkles.rectangle.stack") {
            model.brand.adopt(palette: palette.colors.map(\.hex), name: palette.name)
            model.destination = .brand
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { model.delete(palette) }
    }
}
