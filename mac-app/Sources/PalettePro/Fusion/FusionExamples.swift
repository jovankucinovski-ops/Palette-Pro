import SwiftUI

/// Lays out a fixed-size design (in points) scaled to fit the width it's given.
struct ScaledDesign<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / size.width, geo.size.height / size.height)
            content
                .frame(width: size.width, height: size.height)
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: size.width * s, height: size.height * s, alignment: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
    }
}

/// The current style applied to a real-looking design.
struct FusionExample: View {
    let style: FusionStyle
    let layout: FusionLayout
    var brand = "Northwind"

    var body: some View {
        if let h = style.heading, let b = style.body {
            switch layout {
            case .website: FusionWebsite(s: style, h: h, b: b, brand: brand)
            case .poster: FusionPoster(s: style, h: h, b: b)
            case .app: FusionApp(s: style, h: h, b: b, brand: brand)
            }
        }
    }
}

private func c(_ hex: String) -> Color { Color(hex: hex) }

private struct Pill: View {
    let text: String
    let font: FontFamily
    let weight: Int
    let fill: String?
    let ink: String
    var stroke: String?

    var body: some View {
        FontText(family: font, text: text, size: 15, weight: weight)
            .foregroundStyle(c(ink))
            .padding(.horizontal, 22)
            .frame(height: 46)
            // Circular ends: the continuous style leaves small spikes on thin outlines at full radius.
            .background(Capsule(style: .circular).fill(fill.map(c) ?? .clear))
            .overlay {
                if let stroke { Capsule(style: .circular).strokeBorder(c(stroke), lineWidth: 1.5) }
            }
    }
}

struct FusionWebsite: View {
    let s: FusionStyle
    let h: FontFamily
    let b: FontFamily
    let brand: String

    var body: some View {
        ScaledDesign(size: CGSize(width: 1000, height: 600)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 28) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 7).fill(c(s[.accent])).frame(width: 26, height: 26)
                        FontText(family: h, text: brand, size: 21, weight: s.headingWeight).foregroundStyle(c(s[.text]))
                    }
                    Spacer()
                    ForEach(["Work", "Studio", "Journal", "About"], id: \.self) {
                        FontText(family: b, text: $0, size: 15, weight: s.bodyWeight).foregroundStyle(c(s[.muted]))
                    }
                    Pill(text: "Contact", font: b, weight: b.nearest(600), fill: s[.text], ink: s[.background])
                }
                .padding(.horizontal, 56)
                .frame(height: 84)

                HStack(alignment: .top, spacing: 48) {
                    VStack(alignment: .leading, spacing: 22) {
                        FontText(family: b, text: "INDEPENDENT DESIGN STUDIO", size: 12.5, weight: b.nearest(600))
                            .tracking(2)
                            .foregroundStyle(c(s[.accent]))
                        FontText(family: h, text: "Ideas that look as good as they work", size: 58, weight: s.headingWeight)
                            .lineSpacing(-6)
                            .foregroundStyle(c(s[.text]))
                            .fixedSize(horizontal: false, vertical: true)
                        FontText(family: b, text: "We help brands find their voice with identity, websites and products people enjoy using.",
                                 size: 18, weight: s.bodyWeight)
                            .lineSpacing(5)
                            .foregroundStyle(c(s[.muted]))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 12) {
                            Pill(text: "Start a project", font: b, weight: b.nearest(600), fill: s[.accent], ink: s[.onAccent])
                            Pill(text: "See our work", font: b, weight: b.nearest(500), fill: nil, ink: s[.text], stroke: s[.muted])
                        }
                        .padding(.top, 6)
                    }
                    .frame(width: 500, alignment: .leading)

                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 28, style: .continuous).fill(c(s[.surface]))
                        Circle().fill(c(s[.accent])).frame(width: 230, height: 230).offset(x: 150, y: -150)
                        Circle().fill(c(s[.accent]).opacity(0.35)).frame(width: 120, height: 120).offset(x: 40, y: -60)
                        VStack(alignment: .leading, spacing: 4) {
                            FontText(family: h, text: "120+", size: 46, weight: s.headingWeight).foregroundStyle(c(s[.text]))
                            FontText(family: b, text: "projects shipped since 2016", size: 14, weight: s.bodyWeight).foregroundStyle(c(s[.muted]))
                        }
                        .padding(26)
                    }
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .padding(.horizontal, 56)
                .padding(.top, 30)

                Spacer(minLength: 0)
                HStack(spacing: 34) {
                    FontText(family: b, text: "Trusted by", size: 13, weight: s.bodyWeight).foregroundStyle(c(s[.muted]))
                    ForEach(["LUMEN", "ATLAS", "Kinfolk", "Oberon"], id: \.self) {
                        FontText(family: h, text: $0, size: 17, weight: s.headingWeight).foregroundStyle(c(s[.muted]))
                    }
                }
                .padding(.horizontal, 56)
                .padding(.bottom, 30)
            }
            .background(c(s[.background]))
        }
    }
}

struct FusionPoster: View {
    let s: FusionStyle
    let h: FontFamily
    let b: FontFamily

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            ScaledDesign(size: CGSize(width: 600, height: 800)) {
                ZStack(alignment: .topTrailing) {
                    c(s[.background])
                    Circle().fill(c(s[.accent])).frame(width: 380, height: 380).offset(x: 120, y: 150)
                    Circle().strokeBorder(c(s[.text]).opacity(0.85), lineWidth: 2).frame(width: 200, height: 200).offset(x: -150, y: 400)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            FontText(family: b, text: "VOL. 07", size: 14, weight: b.nearest(600)).tracking(2)
                            Spacer()
                            FontText(family: b, text: "OCT 24 – 26", size: 14, weight: b.nearest(600)).tracking(2)
                        }
                        .foregroundStyle(c(s[.text]))
                        Spacer()
                        FontText(family: h, text: "Form & Color", size: 104, weight: s.headingWeight)
                            .lineSpacing(-14)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(c(s[.text]))
                            .fixedSize(horizontal: false, vertical: true)
                        FontText(family: b, text: "A three-day festival of type, color and graphic design.", size: 21, weight: s.bodyWeight)
                            .foregroundStyle(c(s[.muted]))
                            .padding(.top, 16)
                            .fixedSize(horizontal: false, vertical: true)
                        Rectangle().fill(c(s[.accent])).frame(width: 90, height: 5).padding(.vertical, 28)
                        HStack(alignment: .top, spacing: 44) {
                            ForEach([("Venue", "Palais des Arts"), ("Talks", "28 speakers"), ("Tickets", "formandcolor.fest")], id: \.0) { k, v in
                                VStack(alignment: .leading, spacing: 4) {
                                    FontText(family: b, text: k.uppercased(), size: 11, weight: b.nearest(600)).tracking(1.6).foregroundStyle(c(s[.muted]))
                                    FontText(family: b, text: v, size: 16, weight: b.nearest(500)).foregroundStyle(c(s[.text]))
                                }
                            }
                        }
                    }
                    .padding(48)
                }
                .clipped()
            }
            .frame(maxWidth: 460)
            Spacer(minLength: 0)
        }
    }
}

struct FusionApp: View {
    let s: FusionStyle
    let h: FontFamily
    let b: FontFamily
    let brand: String

    var body: some View {
        ScaledDesign(size: CGSize(width: 1000, height: 600)) {
            HStack(spacing: 60) {
                phone {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            FontText(family: b, text: "9:41", size: 14, weight: b.nearest(600))
                            Spacer()
                            Image(systemName: "battery.75percent").font(.system(size: 14))
                        }
                        .foregroundStyle(c(s[.text]))
                        FontText(family: b, text: "Tuesday, 14 October", size: 13, weight: s.bodyWeight).foregroundStyle(c(s[.muted]))
                        FontText(family: h, text: "Good morning", size: 32, weight: s.headingWeight).foregroundStyle(c(s[.text]))
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                FontText(family: b, text: "Today’s focus", size: 13, weight: b.nearest(600)).foregroundStyle(c(s[.muted]))
                                Spacer()
                                FontText(family: b, text: "3 of 5", size: 13, weight: b.nearest(600)).foregroundStyle(c(s[.accent]))
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(c(s[.background]))
                                    Capsule().fill(c(s[.accent])).frame(width: g.size.width * 0.6)
                                }
                            }
                            .frame(height: 8)
                            FontText(family: h, text: "Finish the brand guidelines", size: 18, weight: s.headingWeight).foregroundStyle(c(s[.text]))
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(c(s[.surface])))
                        ForEach([("Review color palette", "10:00"), ("Pick type pairing", "11:30"), ("Share with the team", "14:00")], id: \.0) { t, time in
                            HStack {
                                Circle().strokeBorder(c(s[.accent]), lineWidth: 2).frame(width: 18, height: 18)
                                FontText(family: b, text: t, size: 15, weight: s.bodyWeight).foregroundStyle(c(s[.text]))
                                Spacer()
                                FontText(family: b, text: time, size: 13, weight: s.bodyWeight).foregroundStyle(c(s[.muted]))
                            }
                        }
                        Spacer(minLength: 0)
                        FontText(family: b, text: "Add a task", size: 16, weight: b.nearest(600))
                            .foregroundStyle(c(s[.onAccent]))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Capsule().fill(c(s[.accent])))
                    }
                }
                VStack(alignment: .leading, spacing: 18) {
                    FontText(family: b, text: brand.uppercased(), size: 13, weight: b.nearest(600)).tracking(2).foregroundStyle(c(s[.accent]))
                    FontText(family: h, text: "Plan less. Make more.", size: 52, weight: s.headingWeight)
                        .foregroundStyle(c(s[.text]))
                        .fixedSize(horizontal: false, vertical: true)
                    FontText(family: b, text: "A calm daily planner for designers, with your tasks, files and feedback in one place.", size: 18, weight: s.bodyWeight)
                        .lineSpacing(5)
                        .foregroundStyle(c(s[.muted]))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Pill(text: "Download", font: b, weight: b.nearest(600), fill: s[.accent], ink: s[.onAccent])
                        Pill(text: "Learn more", font: b, weight: b.nearest(500), fill: s[.surface], ink: s[.text])
                    }
                }
                .frame(width: 420)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(c(s[.background]))
        }
    }

    private func phone<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
            .frame(width: 300, height: 540)
            .background(c(s[.background]))
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous).strokeBorder(c(s[.text]).opacity(0.85), lineWidth: 6))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
    }
}
