import SwiftUI

/// Printed-page colors for type previews, so fonts are judged as they'll be read.
enum Paper {
    static let page = Color(hex: "#FBFAF7")
    static let ink = Color(hex: "#1B1B1E")
    static let muted = Color(hex: "#5D5D63")
    static let rule = Color(hex: "#E4E1DA")
}

private let bodySample = "Good typography is almost invisible. It guides the eye, sets the tone and makes reading effortless, whether it’s a long article, a product page or a single label on a box."

struct PairingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.typography
        HSplitView {
            PairingControls()
                .frame(minWidth: 280, idealWidth: 300, maxWidth: 360)
            Group {
                if let p = t.selectedPairing {
                    PairingResults(pairing: p)
                } else {
                    ContentUnavailableView("No Pairings Yet", systemImage: "textformat",
                                           description: Text("Choose a heading font or explore, then press New Ideas."))
                }
            }
            .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Pairing")
        .navigationSubtitle(t.selectedPairing?.subtitle ?? "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { t.suggestPairings() } label: { Label("More Ideas", systemImage: "arrow.triangle.2.circlepath") }
                    .keyboardShortcut("r")
                    .help("New pairing ideas (⌘R)")
                Button {
                    guard let p = t.selectedPairing else { return }
                    t.useInScale(p)
                    model.destination = .scale
                } label: { Label("Use in Type Scale", systemImage: "textformat.size") }
                    .disabled(t.selectedPairing == nil)
                    .help("Build a type scale with this pairing")
            }
        }
        .onAppear { if t.pairings.isEmpty { t.suggestPairings() } }
    }
}

struct PairingControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var t = model.typography
        Form {
            Section {
                LabeledContent("Heading") {
                    FontPickerButton(selection: $t.pairHeadingID, anyTitle: "Explore")
                }
            } header: {
                Text("Start from")
            } footer: {
                Text(t.pairHeadingID == nil
                     ? "Exploring: every idea starts from a different headline font. Pick a font to keep it and find the best text faces for it."
                     : "Ideas keep this headline font and try different fonts for body text.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section("Feel") {
                Picker("Mood", selection: $t.mood) {
                    ForEach(PairMood.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Preview") {
                TextField("Headline", text: $t.headline)
            }
            Section {
                Button { t.suggestPairings() } label: {
                    Label("New Ideas", systemImage: "sparkles").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .formStyle(.grouped)
        .onChange(of: t.pairHeadingID) { t.suggestPairings() }
        .onChange(of: t.mood) { t.suggestPairings() }
    }
}

struct PairingResults: View {
    @Environment(AppModel.self) private var model
    let pairing: FontPairing

    var body: some View {
        @Bindable var t = model.typography
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("View", selection: $t.pairTab) {
                    ForEach(PairTab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)

                switch t.pairTab {
                case .ideas: PairingGrid()
                case .details: PairingDetail(pairing: pairing)
                }
            }
            .padding(22)
        }
    }
}

struct PairingGrid: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.typography
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pairing ideas").font(.title2.weight(.semibold))
                    Text(intro(t)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button { t.suggestPairings() } label: { Label("More Ideas", systemImage: "arrow.triangle.2.circlepath") }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 440), spacing: 16)], spacing: 18) {
                ForEach(t.pairings) { p in
                    PairingCard(pairing: p, headline: t.headline, selected: p.id == t.selectedPairing?.id)
                        .onTapGesture(count: 2) { t.selectedPairingID = p.id; t.pairTab = .details }
                        .onTapGesture { t.selectedPairingID = p.id }
                        .contextMenu {
                            Button("Show Details", systemImage: "info.circle") { t.selectedPairingID = p.id; t.pairTab = .details }
                            Button("Use in Type Scale", systemImage: "textformat.size") { t.useInScale(p); model.destination = .scale }
                            Divider()
                            if let h = p.heading { Button("Pair \(h.family) Instead", systemImage: "arrow.triangle.branch") { t.pair(with: h) } }
                            Button("Copy CSS", systemImage: "doc.on.doc") { model.copy(PairingDetail.css(p), label: "CSS") }
                        }
                }
            }
        }
    }

    private func intro(_ t: TypeModel) -> String {
        if let h = t.pairHeading { return "\(h.family) for headlines, with \(t.pairings.count) options for body text. Click one to choose it, double-click for a full page preview." }
        return "\(t.pairings.count) pairings, each starting from a different headline font\(t.mood == .any ? "" : " with a \(t.mood.title.lowercased()) feel"). Click one to choose it, double-click for a full page preview."
    }
}

struct PairingCard: View {
    let pairing: FontPairing
    let headline: String
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let h = pairing.heading, let b = pairing.body, let a = pairing.accent {
                VStack(alignment: .leading, spacing: 10) {
                    FontText(family: a, text: pairing.accentUppercase ? "FEATURE · 4 MIN READ" : "feature · 4 min read", size: 10.5, weight: pairing.accentWeight)
                        .tracking(pairing.accentUppercase ? 1.2 : 0)
                        .foregroundStyle(Paper.muted)
                    FontText(family: h, text: headline.isEmpty ? "Design is how it works" : headline, size: 30, weight: pairing.headingWeight)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Paper.ink)
                    FontText(family: b, text: bodySample, size: 13.5, weight: pairing.bodyWeight)
                        .lineSpacing(4)
                        .lineLimit(4)
                        .foregroundStyle(Paper.ink.opacity(0.8))
                }
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: 236, maxHeight: 236, alignment: .topLeading)
                .clipped()
                .background(Paper.page)
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(pairing.subtitle).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(pairing.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor).font(.title3) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(selected ? Color.accentColor : .primary.opacity(hovering ? 0.18 : 0.08), lineWidth: selected ? 2.5 : 1))
        .compositingGroup()
        .shadow(color: .black.opacity(hovering ? 0.14 : 0.05), radius: hovering ? 10 : 3, y: hovering ? 5 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .help("Click to choose this pairing. Double-click for a page preview.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pairing.subtitle), \(pairing.title)\(selected ? ", selected" : "")")
        .accessibilityAddTraits(.isButton)
    }
}

struct PairingDetail: View {
    @Environment(AppModel.self) private var model
    let pairing: FontPairing

    var body: some View {
        let t = model.typography
        if let h = pairing.heading, let b = pairing.body, let a = pairing.accent {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pairing.subtitle).font(.title2.weight(.semibold))
                        Text(pairing.title).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { model.copy(Self.css(pairing), label: "CSS") } label: { Label("Copy CSS", systemImage: "doc.on.doc") }
                    Button { t.useInScale(pairing); model.destination = .scale } label: { Label("Use in Type Scale", systemImage: "textformat.size") }
                        .buttonStyle(.borderedProminent)
                }

                ArticlePreview(heading: h, headingWeight: pairing.headingWeight, bodyFont: b, bodyWeight: pairing.bodyWeight,
                               accent: a, accentWeight: pairing.accentWeight, uppercase: pairing.accentUppercase, headline: t.headline)

                Text(pairing.rationale)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                VStack(alignment: .leading, spacing: 0) {
                    roleRow("Headlines", h, pairing.headingWeight)
                    Divider()
                    roleRow("Body text", b, pairing.bodyWeight)
                    if a != b {
                        Divider()
                        roleRow("Labels & captions", a, pairing.accentWeight)
                    }
                }
                .card(padding: 0)
            }
        }
    }

    private func roleRow(_ role: String, _ f: FontFamily, _ weight: Int) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(role).font(.caption).foregroundStyle(.secondary)
                FontText(family: f, text: f.family, size: 22, weight: weight).lineLimit(1)
                Text("Weight \(weight) · \(f.category.title) · \(f.licenseTitle)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Details") { model.typography.detail = f }
            if let url = f.pageURL {
                Button { NSWorkspace.shared.open(url) } label: { Label("Get Font", systemImage: "arrow.down.circle") }
            }
        }
        .padding(14)
    }

    static func css(_ p: FontPairing) -> String {
        guard let h = p.heading, let b = p.body else { return "" }
        var lines: [String] = []
        let embeds = [h.cssEmbed(weights: [p.headingWeight]), h == b ? nil : b.cssEmbed(weights: [p.bodyWeight, b.nearest(700)])].compactMap { $0 }
        lines += embeds.map { "/* \($0) */" }
        lines.append("h1, h2, h3 { font-family: \(h.cssStack); font-weight: \(p.headingWeight); }")
        lines.append("body { font-family: \(b.cssStack); font-weight: \(p.bodyWeight); }")
        if let a = p.accent, a != b {
            lines.append(".label, figcaption { font-family: \(a.cssStack); font-weight: \(p.accentWeight); }")
        }
        return lines.joined(separator: "\n")
    }
}

/// A magazine-style page set in the pairing.
struct ArticlePreview: View {
    let heading: FontFamily
    let headingWeight: Int
    let bodyFont: FontFamily
    let bodyWeight: Int
    let accent: FontFamily
    let accentWeight: Int
    let uppercase: Bool
    let headline: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FontText(family: accent, text: uppercase ? "DESIGN NOTES · ISSUE 12" : "design notes · issue 12", size: 11, weight: accentWeight)
                .tracking(uppercase ? 1.6 : 0)
                .foregroundStyle(Paper.muted)
            FontText(family: heading, text: headline.isEmpty ? "Design is how it works" : headline, size: 52, weight: headingWeight)
                .lineSpacing(-4)
                .foregroundStyle(Paper.ink)
                .fixedSize(horizontal: false, vertical: true)
            FontText(family: bodyFont, text: "A short guide to choosing fonts that feel right, read easily and still look good in ten years.",
                     size: 20, weight: bodyWeight, italic: true)
                .foregroundStyle(Paper.muted)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Paper.rule).frame(height: 1)
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    FontText(family: bodyFont, text: bodySample, size: 16, weight: bodyWeight)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                    FontText(family: bodyFont, text: "Start with the text face, because that’s what people read for minutes at a time. Then find a headline font with a clear difference in shape or weight, and let it carry the personality.",
                             size: 16, weight: bodyWeight)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle().fill(Paper.ink).frame(width: 36, height: 3)
                    FontText(family: heading, text: "“Contrast creates hierarchy; consistency creates trust.”", size: 24, weight: headingWeight)
                        .foregroundStyle(Paper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    FontText(family: accent, text: uppercase ? "TYPE DIRECTOR" : "type director", size: 10.5, weight: accentWeight)
                        .tracking(uppercase ? 1.4 : 0)
                        .foregroundStyle(Paper.muted)
                }
                .frame(width: 230)
            }
            .foregroundStyle(Paper.ink.opacity(0.85))
        }
        .padding(36)
        .frame(maxWidth: 820, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Paper.page)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.08)))
    }
}
