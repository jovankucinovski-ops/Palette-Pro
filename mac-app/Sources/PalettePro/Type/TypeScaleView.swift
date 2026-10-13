import SwiftUI

struct TypeScaleView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.typography
        HSplitView {
            TypeScaleControls()
                .frame(minWidth: 280, idealWidth: 300, maxWidth: 360)
            TypeScaleResults()
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Type Scale")
        .navigationSubtitle("\(t.scaleHeading.family) + \(t.scaleBody.family) · \(fmt(t.scale.base))px × \(String(format: "%.3g", t.scale.ratio.rawValue))")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.copy(css(), label: "CSS") } label: { Label("Copy CSS", systemImage: "doc.on.doc") }
                    .help("Copy the scale as CSS variables")
                Menu {
                    ForEach(TypeExportFormat.allCases) { f in
                        Button(f.title + "…") { export(f) }
                    }
                } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    .help("Save the scale as CSS, SCSS, Tailwind, SwiftUI or design tokens")
            }
        }
    }

    private func css() -> String {
        let t = model.typography
        return TypeExporter.text(.css, heading: t.scaleHeading, body: t.scaleBody, steps: t.steps, spec: t.scale)
    }

    private func export(_ f: TypeExportFormat) {
        let t = model.typography
        let text = TypeExporter.text(f, heading: t.scaleHeading, body: t.scaleBody, steps: t.steps, spec: t.scale)
        let name = "type-scale-" + Exporter.slug(t.scaleHeading.family + "-" + t.scaleBody.family)
        if let url = FilePanels.save(Data(text.utf8), suggestedName: f == .tailwind ? "tailwind.config" : name, ext: f.ext) {
            model.showToast("Saved \(url.lastPathComponent)", actionTitle: "Show") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
    }
}

struct TypeScaleControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var t = model.typography
        Form {
            Section {
                LabeledContent("Headings") {
                    FontPickerButton(selection: Binding(get: { t.scaleHeadingID }, set: { t.scaleHeadingID = $0 ?? t.scaleHeadingID }))
                }
                LabeledContent("Body text") {
                    FontPickerButton(selection: Binding(get: { t.scaleBodyID }, set: { t.scaleBodyID = $0 ?? t.scaleBodyID }))
                }
                if let p = t.selectedPairing, p.headingID != t.scaleHeadingID || p.bodyID != t.scaleBodyID {
                    Button("Use Pairing: \(p.subtitle)") { t.useInScale(p) }
                }
            } header: {
                Text("Fonts")
            }
            Section {
                LabeledContent("Base size") {
                    Stepper("\(fmt(t.scale.base)) px", value: $t.scale.base, in: 12...24, step: 1)
                }
                Picker("Ratio", selection: $t.scale.ratio) {
                    ForEach(ScaleRatio.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Scale")
            } footer: {
                Text("Each step is the one below multiplied by the ratio. \(t.scale.ratio.advice)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                LabeledContent("Line height") {
                    HStack {
                        Slider(value: $t.scale.bodyLineHeight, in: 1.3...1.8, step: 0.05)
                        Text(fmt(t.scale.bodyLineHeight)).monospacedDigit().frame(width: 34, alignment: .trailing)
                    }
                }
                Picker("Units", selection: $t.scale.unit) {
                    ForEach(ScaleUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Text")
            } footer: {
                Text("Body text reads best at 1.4–1.6 line height. Headings get tighter line height and letter spacing as they grow. rem values assume a 16px root.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
    }
}

struct TypeScaleResults: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.typography
        let steps = t.steps
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(steps) { s in
                        ScaleRow(step: s, family: s.isHeading ? t.scaleHeading : t.scaleBody, spec: t.scale,
                                 text: s.exponent >= 4 ? (t.headline.isEmpty ? "Design is how it works" : t.headline)
                                     : s.isHeading ? "Clear hierarchy guides the eye" : "Readable text for everyday reading, set at a comfortable size.")
                        if s.id != steps.last?.id { Divider() }
                    }
                }
                .card(padding: 0)

                SectionTitle(title: "Sample page")
                ScalePage(heading: t.scaleHeading, bodyFont: t.scaleBody, steps: steps, headline: t.headline)
            }
            .padding(22)
        }
    }
}

struct ScaleRow: View {
    let step: ScaleStep
    let family: FontFamily
    let spec: TypeScaleSpec
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.name).font(.callout.weight(.semibold))
                Text("\(spec.css(step.size)) · \(fmt(step.size))px").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Text("lh \(fmt(step.lineHeight))\(step.tracking != 0 ? " · \(fmt(step.tracking))em" : "") · \(step.weight)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
            }
            .frame(width: 130, alignment: .leading)
            FontText(family: family, text: text, size: step.size, weight: step.weight)
                .tracking(step.tracking * step.size)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            Button("Copy Size (\(spec.css(step.size)))") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(spec.css(step.size), forType: .string) }
        }
    }
}

/// The scale applied to a simple landing-page section.
struct ScalePage: View {
    let heading: FontFamily
    let bodyFont: FontFamily
    let steps: [ScaleStep]
    let headline: String

    private func s(_ id: String) -> ScaleStep { steps.first { $0.id == id }! }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            text(s("caption"), bodyFont, "NEW · TYPE SCALE", tracking: 0.08)
                .foregroundStyle(Paper.muted)
                .padding(.bottom, 12)
            text(s("h1"), heading, headline.isEmpty ? "Design is how it works" : headline)
                .foregroundStyle(Paper.ink)
                .padding(.bottom, 16)
            text(s("body"), bodyFont, "A type scale gives every size a reason. Headings step up by the same ratio, so the page has a clear rhythm from the biggest headline to the smallest caption.")
                .foregroundStyle(Paper.ink.opacity(0.85))
                .padding(.bottom, 28)
            HStack(alignment: .top, spacing: 28) {
                ForEach(["Hierarchy", "Rhythm", "Consistency"], id: \.self) { title in
                    VStack(alignment: .leading, spacing: 8) {
                        text(s("h4"), heading, title).foregroundStyle(Paper.ink)
                        text(s("small"), bodyFont, "Sizes come from one base and one ratio, so they always relate to each other.")
                            .foregroundStyle(Paper.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(36)
        .frame(maxWidth: 860, alignment: .leading)
        .background(Paper.page, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.08)))
    }

    private func text(_ step: ScaleStep, _ f: FontFamily, _ string: String, tracking: Double? = nil) -> some View {
        FontText(family: f, text: string, size: step.size, weight: step.weight)
            .tracking((tracking ?? step.tracking) * step.size)
            .lineSpacing(max(0, (step.lineHeight - 1.2) * step.size))
            .fixedSize(horizontal: false, vertical: true)
    }
}
