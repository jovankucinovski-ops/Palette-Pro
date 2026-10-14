import AppKit
import SwiftUI

/// Fusion checks: generation rules, locks, contrast, saving, CSS export, and screens.
extension SnapshotRunner {
    static func fusionPass(_ model: AppModel, _ dir: URL) async {
        let f = model.fusion
        var report: [String] = []
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

        // Contrast across many generated styles, for every mood and page tone.
        var fails: [String: Int] = [:], total = 0, kinds: [String: Int] = [:], examples: [String] = []
        for mood in PairMood.allCases {
            for tone in FusionTone.allCases {
                for _ in 0..<12 {
                    let s = FusionEngine.generate(from: nil, locks: [], mood: mood, tone: tone, snapAccent: false)
                    total += 1
                    for c in FusionEngine.checks(s) where c.ratio < c.needed {
                        fails[c.label, default: 0] += 1
                        if examples.count < 6 { examples.append("\(c.label) \(String(format: "%.2f", c.ratio)) bg=\(s[.background]) accent=\(s[.accent]) on=\(s[.onAccent]) text=\(s[.text]) \(mood.rawValue)/\(tone.rawValue)") }
                    }
                    let bg = ColorMath.oklch(hex: s[.background])
                    kinds[bg.x < 0.55 ? (bg.y > 0.05 ? "color" : "dark") : "light", default: 0] += 1
                    if tone == .dark && bg.x >= 0.55 { fails["dark tone gave light page", default: 0] += 1 }
                    if tone == .light && bg.x < 0.55 { fails["light tone gave dark page", default: 0] += 1 }
                }
            }
        }
        report += examples
        report.append("generated=\(total) pages=\(kinds.sorted { $0.key < $1.key }) contrastFails=\(fails.sorted { $0.key < $1.key })")

        // Locks keep what they lock.
        f.mood = .any; f.tone = .any; f.locks = []
        f.generate()
        guard let first = f.style else { report.append("no style"); return }
        f.locks = [.heading, .accent]
        var keptHeading = true, keptAccent = true, changedBody = 0
        for _ in 0..<10 {
            let before = f.style!
            f.generate()
            if f.style!.headingID != first.headingID { keptHeading = false }
            if f.style![.accent] != first[.accent] { keptAccent = false }
            if f.style!.bodyID != before.bodyID { changedBody += 1 }
        }
        report.append("locks heading=\(keptHeading) accent=\(keptAccent) bodyChanged=\(changedBody)/10")
        f.locks = [.background, .text]
        let pinned = f.style!
        f.generate()
        report.append("locks background=\(f.style![.background] == pinned[.background]) text=\(f.style![.text] == pinned[.text])")

        // Manual edits lock and re-derive.
        f.locks = []
        f.setColor(.accent, "#0F4C81")
        report.append("edit accent: value=\(f.style![.accent]) locked=\(f.locks.contains(.accent)) onAccent=\(f.style![.onAccent]) contrast=\(String(format: "%.1f", f.style!.contrast(.onAccent, on: .accent)))")
        if let playfair = FontCatalog.shared.named("Playfair Display") {
            f.setFont(heading: true, playfair.id)
            report.append("edit heading: \(f.style!.heading?.family ?? "-") weight=\(f.style!.headingWeight) locked=\(f.locks.contains(.heading))")
        }

        // Save and persistence.
        f.save(); f.save()
        let data = try? AppModel.encoder.encode(f.settings)
        let back = data.flatMap { try? AppModel.decoder.decode(FusionSettings.self, from: $0) }
        report.append("saved=\(f.saved.count) persist=\(back == f.settings) tolerant=\((try? AppModel.decoder.decode(FusionSettings.self, from: Data(#"{"tone":"weird","mood":"bold"}"#.utf8))).map { "\($0.tone.rawValue)/\($0.mood.rawValue)" } ?? "-")")

        if let s = f.style {
            try? f.css(s).write(to: dir.appendingPathComponent("fusion.css"), atomically: true, encoding: .utf8)
        }

        // Undo goes back to the previous style.
        let beforeUndo = f.style
        f.undoManager?.undo()
        report.append("undo changed=\(f.style != beforeUndo)")

        // Screens
        model.destination = .fusion
        f.locks = []
        f.mood = .modern; f.tone = .light
        f.generate()
        for layout in FusionLayout.allCases {
            f.layout = layout
            await wait(layout == .website ? 6 : 3)
            await shot("40-fusion-\(layout.rawValue)", dir)
        }
        f.layout = .website
        f.tone = .dark; f.mood = .elegant
        f.generate()
        await wait(5)
        await shot("41-fusion-dark-elegant", dir)
        f.tone = .color; f.mood = .bold
        f.generate()
        await wait(5)
        await shot("42-fusion-colored-bold", dir)
        f.save()
        f.locks = [.accent, .heading]
        f.tone = .light; f.mood = .editorial
        f.generate()
        await wait(5)
        scrollToBottom()
        await wait(1.5)
        await shot("43-fusion-slots", dir)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        await wait(2)
        scrollToBottom()
        await shot("44-fusion-slots-dark", dir)
        NSApp.appearance = nil

        try? report.joined(separator: "\n").write(to: dir.appendingPathComponent("fusion.txt"), atomically: true, encoding: .utf8)
    }

    /// Scrolls the detail area's scroll view to the end (SwiftUI scroll views are NSScrollViews on the Mac).
    private static func scrollToBottom() {
        guard let root = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain })?.contentView else { return }
        func all(_ v: NSView) -> [NSView] { [v] + v.subviews.flatMap(all) }
        let scrolls = all(root).compactMap { $0 as? NSScrollView }.filter { ($0.documentView?.frame.height ?? 0) > $0.contentView.bounds.height + 50 }
        guard let main = scrolls.max(by: { $0.frame.width < $1.frame.width }), let doc = main.documentView else { return }
        let y = doc.isFlipped ? doc.frame.height - main.contentView.bounds.height : 0
        main.contentView.scroll(to: NSPoint(x: 0, y: y))
        main.reflectScrolledClipView(main.contentView)
    }
}
