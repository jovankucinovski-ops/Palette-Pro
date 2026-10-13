import SwiftUI
import UniformTypeIdentifiers

@main
struct PaletteProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Palette Pro", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 1000, minHeight: 640)
        }
        .defaultSize(width: 1400, height: 900)
        .commands { AppCommands(model: model) }

        Window("Palette Pro Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 760, height: 680)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (swift run); harmless inside the .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct AppCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Palette Pro") { showAbout() }
        }
        CommandGroup(replacing: .help) {
            Button("Palette Pro Help") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
        }
        CommandGroup(replacing: .newItem) {
            Button("New Palette") { model.newPalette() }
                .keyboardShortcut("n")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Palette") { model.savePalette() }
                .keyboardShortcut("s")
            Button("Export Palette…") { model.export(name: model.current.name, colors: model.current.colors) }
                .keyboardShortcut("e")
            Divider()
            Button("Import Colors…") { model.showImport = true }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Button("Back Up Library…") { model.runBackup() }
            Button("Restore Backup…") { model.runRestore() }
        }
        CommandMenu("Palette") {
            Button("Generate") { model.generate() }
                .keyboardShortcut("g")
            Button("Add Color") { model.addGeneratedColor() }
                .keyboardShortcut("n", modifiers: [.command, .option])
            Toggle("Snap to Pantone", isOn: Binding(get: { model.settings.snap }, set: { model.setSnap($0) }))
            Divider()
            Button("Add Palette to macOS Colors") { model.installInColorPicker(name: model.current.name, colors: model.current.colors) }
            Button("Open in Brand Studio") {
                model.brand.adopt(palette: model.current.colors.map(\.hex), name: model.current.name)
                model.destination = .brand
            }
        }
        CommandGroup(before: .sidebar) {
            ForEach(Array(Destination.allCases.enumerated()), id: \.element) { i, d in
                Button(d.title) { model.destination = d }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")))
            }
            Button(model.showInspector ? "Hide Inspector" : "Show Inspector") { model.showInspector.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
        }
    }
}

/// Standard About panel with a short description and credits that follow light and dark mode.
@MainActor
func showAbout() {
    let body = NSMutableParagraphStyle()
    body.alignment = .center
    body.paragraphSpacing = 6
    let text = NSMutableAttributedString(
        string: "Pantone-style color reference, palette editor, brand ideas and color matching for designers.\n",
        attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor, .paragraphStyle: body])
    text.append(NSAttributedString(
        string: "Color data: Pantoner (MIT) and pantone-colors. PANTONE® is a trademark of Pantone LLC; values are screen approximations.",
        attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: body]))
    NSApp.orderFrontStandardAboutPanel(options: [.credits: text])
    NSApp.activate(ignoringOtherApps: true)
}

extension AppModel {
    func runBackup() {
        let stamp = Date().formatted(.iso8601.year().month().day())
        if FilePanels.save(backupData(), suggestedName: "palette-pro-backup-\(stamp)", ext: "json") != nil {
            showToast("Backed up \(palettes.count) palettes and \(favorites.count) favorites")
        }
    }

    func runRestore() {
        guard let url = FilePanels.open(types: [.json]), let data = try? Data(contentsOf: url) else { return }
        guard let added = restore(data) else {
            showToast("That file isn’t a Palette Pro backup or palette.")
            return
        }
        showToast(added > 0 ? "Imported \(added) palette\(added == 1 ? "" : "s")" : "You already have every palette in that file.")
        if added > 0 { destination = .saved }
    }
}
