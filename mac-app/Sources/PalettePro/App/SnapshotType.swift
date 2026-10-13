import AppKit
import SwiftUI

/// Fonts, Pairing and Type Scale part of the snapshot pass. Fonts download from the internet,
/// so each screen waits a little longer before its screenshot.
extension SnapshotRunner {
    static func typePass(_ model: AppModel, _ dir: URL) async {
        let t = model.typography
        let catalog = FontCatalog.shared
        var report: [String] = []
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

        report.append("catalog online=\(catalog.online.count) installed=\(catalog.installed.count) picks=\(catalog.online.filter(\.pick).count) "
                      + "bySource=\(Dictionary(grouping: catalog.all, by: \.source.rawValue).mapValues(\.count).sorted { $0.key < $1.key })")
        report.append("categories=\(Dictionary(grouping: catalog.all, by: \.category.rawValue).mapValues(\.count).sorted { $0.key < $1.key })")

        // Library
        t.filter = .picks; t.category = nil; t.query = ""; t.sampleText = ""; t.sampleSize = 40
        model.destination = .fonts
        await wait(6)
        await shot("30-fonts-picks", dir)
        let picks = t.fonts().prefix(12)
        report.append("picks first 12: \(picks.map(\.family)) loaded=\(picks.filter { FontStore.shared.postScriptName($0, weight: $0.regular) != nil }.count) failed=\(picks.filter { FontStore.shared.hasFailed($0, weight: $0.regular) }.map(\.family))")

        t.filter = .all; t.category = .serif; t.sampleText = "Quiet, confident type"; t.sampleSize = 34
        await wait(5)
        await shot("31-fonts-serif", dir)
        t.category = nil; t.sampleText = ""

        if let satoshi = catalog.named("Satoshi") {
            t.detail = satoshi
            await wait(5)
            await shot("32-font-detail", dir)
            t.detail = nil
            await wait(0.5)
        }
        t.filter = .installed
        await wait(2)
        await shot("33-fonts-mac", dir)
        t.query = "grotesk"; t.filter = .all
        report.append("search 'grotesk': \(t.fonts().prefix(8).map(\.family))")
        t.query = ""; t.filter = .picks

        // Pairing: explore, then built around a chosen headline font.
        t.pairHeadingID = nil; t.mood = .any; t.headline = "Design is how it works"
        t.suggestPairings()
        model.destination = .pairing
        t.pairTab = .ideas
        await wait(6)
        await shot("34-pairing-explore", dir)
        report.append("explore: \(t.pairings.map { "\($0.subtitle) [\($0.title)]" })")
        t.pairTab = .details
        await wait(4)
        await shot("35-pairing-detail", dir)

        if let playfair = catalog.named("Playfair Display") {
            t.mood = .editorial
            t.pair(with: playfair)
            t.pairTab = .ideas
            await wait(6)
            await shot("36-pairing-playfair", dir)
            report.append("playfair editorial: \(t.pairings.map { "\($0.body?.family ?? "?")/\($0.title)" })")
        }
        for mood in PairMood.allCases {
            let sample = PairingEngine.suggest(heading: catalog.named("Clash Display"), mood: mood)
            report.append("clash \(mood.rawValue): n=\(sample.count) bodies=\(sample.prefix(5).map { $0.body?.family ?? "?" })")
        }

        // Type scale with the chosen pairing.
        if let p = t.selectedPairing { t.useInScale(p) }
        t.scale = TypeScaleSpec(base: 16, ratio: .majorThird, bodyLineHeight: 1.5, unit: .rem)
        model.destination = .scale
        await wait(5)
        await shot("37-type-scale", dir)
        report.append("scale: " + t.steps.map { "\($0.id)=\(fmt($0.size))/\(fmt($0.lineHeight))/\(fmt($0.tracking))" }.joined(separator: " "))
        for f in TypeExportFormat.allCases {
            let text = TypeExporter.text(f, heading: t.scaleHeading, body: t.scaleBody, steps: t.steps, spec: t.scale)
            try? text.write(to: dir.appendingPathComponent("type-scale.\(f.rawValue).\(f.ext)"), atomically: true, encoding: .utf8)
        }

        NSApp.appearance = NSAppearance(named: .darkAqua)
        model.destination = .fonts
        await wait(3)
        await shot("38-fonts-dark", dir)
        model.destination = .pairing
        t.pairTab = .details
        await wait(3)
        await shot("39-pairing-dark", dir)
        NSApp.appearance = nil

        let data = try? AppModel.encoder.encode(t.settings)
        let back = data.flatMap { try? AppModel.decoder.decode(TypeSettings.self, from: $0) }
        report.append("persist=\(back == t.settings) bytes=\(data?.count ?? 0) cache=\(ByteCountFormatter.string(fromByteCount: Int64(FontStore.cacheSize()), countStyle: .file))")
        let tolerant = try? AppModel.decoder.decode(TypeSettings.self, from: Data(#"{"filter":"nope","sampleSize":30,"scale":{"base":18}}"#.utf8))
        report.append("tolerant filter=\(tolerant?.filter.rawValue ?? "-") size=\(tolerant?.sampleSize ?? 0) scale=\(tolerant.map { "\($0.scale.base)/\($0.scale.ratio.rawValue)" } ?? "-")")
        try? report.joined(separator: "\n").write(to: dir.appendingPathComponent("type.txt"), atomically: true, encoding: .utf8)
    }
}
