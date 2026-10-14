import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 320)
        } detail: {
            detail
                .overlay(alignment: .bottom) { ToastView() }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { model.showInspector.toggle() } label: {
                            Label("Inspector", systemImage: "sidebar.trailing")
                        }
                        .help("Show or hide the inspector (⌥⌘I)")
                    }
                }
        }
        // Attached to the split view (not the detail) so switching sections never rebuilds the inspector column.
        .inspector(isPresented: $model.showInspector) {
            InspectorView()
                .inspectorColumnWidth(min: 300, ideal: 340, max: 440)
        }
        .sheet(item: $model.exportTarget) { ExportSheet(target: $0) }
        .sheet(isPresented: $model.showImport) { ImportSheet() }
        .onAppear {
            model.undoManager = undoManager
            model.fusion.undoManager = undoManager
            model.installKeyMonitor()
            SnapshotRunner.runIfRequested(model)
        }
        .onChange(of: undoManager) {
            model.undoManager = undoManager
            model.fusion.undoManager = undoManager
        }
        .onChange(of: model.palettes) { model.scheduleSave() }
        .onChange(of: model.current) { model.scheduleSave() }
        .onChange(of: model.settings) { model.scheduleSave() }
        .onChange(of: model.favorites) { model.scheduleSave() }
        .onChange(of: model.brand.settings) { model.scheduleSave() }
        .onChange(of: model.typography.settings) { model.scheduleSave() }
        .onChange(of: model.fusion.settings) { model.scheduleSave() }
    }

    @ViewBuilder private var detail: some View {
        switch model.destination {
        case .library: LibraryView()
        case .builder: BuilderView()
        case .brand: BrandStudioView()
        case .saved: SavedView()
        case .match: MatchView()
        case .fonts: FontLibraryView()
        case .pairing: PairingView()
        case .scale: TypeScaleView()
        case .fusion: FusionView()
        }
    }
}

/// Sidebar rows: library collections (like playlists) plus the app's tools.
enum SidebarItem: Hashable {
    case collection(String)
    case tool(Destination)
}

struct Sidebar: View {
    @Environment(AppModel.self) private var model

    private var selection: Binding<SidebarItem?> {
        Binding(get: {
            model.destination == .library ? .collection(model.libCollection) : .tool(model.destination)
        }, set: { item in
            switch item {
            case .collection(let id):
                model.libCollection = id
                model.destination = .library
            case .tool(let d):
                model.destination = d
            case nil:
                break
            }
        })
    }

    var body: some View {
        List(selection: selection) {
            Section("Library") {
                Label("All Colors", systemImage: "square.grid.3x3.fill")
                    .badge(model.library.swatches(in: .all).count)
                    .tag(SidebarItem.collection("all"))
                ForEach(model.library.collections) { c in
                    Label(c.name, systemImage: symbol(for: c.id))
                        .badge(c.count)
                        .tag(SidebarItem.collection(c.id))
                }
                Label("Favorites", systemImage: "star")
                    .badge(model.favorites.count)
                    .tag(SidebarItem.collection("fav"))
            }
            Section("Create") {
                tool(.builder)
                tool(.fusion)
                tool(.brand)
                tool(.match)
            }
            Section("Type") {
                tool(.fonts)
                tool(.pairing)
                tool(.scale)
            }
            Section("Collection") {
                tool(.saved).badge(model.palettes.count)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { CurrentPaletteCard().padding(10) }
    }

    private func tool(_ d: Destination) -> some View {
        Label(d.title, systemImage: d.symbol).tag(SidebarItem.tool(d))
    }

    private func symbol(for collection: String) -> String {
        switch collection {
        case "coated": "circle.lefthalf.filled"
        case "uncoated": "circle.dotted"
        case "tcx": "tshirt"
        case "metallic": "sparkle"
        case "pastel": "rays"
        case "coty": "calendar"
        case "skin": "hand.raised"
        default: "square.grid.2x2"
        }
    }
}

/// The palette being edited, always visible at the bottom of the sidebar.
struct CurrentPaletteCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(model.current.colors) { c in
                    Rectangle()
                        .fill(Color(hex: c.hex))
                        .frame(height: 28)
                        .contentShape(Rectangle())
                        .onTapGesture { model.inspect(c) }
                        .help(c.hex)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.current.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text("\(model.current.colors.count) colors · \(model.isSaved ? (model.isDirty ? "Edited" : "Saved") : "Not saved")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if model.destination != .builder {
                    Button("Open") { model.destination = .builder }
                        .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ToastView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let t = model.toast {
            HStack(spacing: 10) {
                if let s = t.swatch {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: s))
                        .frame(width: 16, height: 16)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.15)))
                }
                Text(t.message).font(.callout)
                if let title = t.actionTitle, let action = t.action {
                    Button(title) {
                        model.toast = nil
                        action()
                    }
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .padding(.bottom, 22)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(t.id)
        }
    }
}
