import SwiftUI

/// Everything a mockup needs: colours, name and typography.
struct BrandKit {
    let concept: BrandConcept
    let name: String
    let tagline: String
    let initial: String
    let logoStyle: LogoStyle
    let font: (CGFloat, Font.Weight?) -> Font
    /// The imported logo, when "My logo" is the selected mark.
    let logo: NSImage?
    let logoMask: NSImage?
    /// The vector original, when the logo was imported as SVG.
    let vector: VectorLogo?
    /// The full-color logo in this concept's colors (or its original colors if recoloring is off).
    let logoFull: NSImage?
    let recolored: Bool
    let logoAspect: CGFloat
    let logoMainHex: String?
    let showName: Bool

    var usesLogo: Bool { logo != nil }

    func c(_ r: BrandRole) -> Color { concept[r].color }
    func hex(_ r: BrandRole) -> String { concept.hex(r) }
    /// Light or dark neutral, whichever reads better on the role colour.
    func on(_ r: BrandRole) -> Color {
        Color(hex: BrandEngine.bestText(on: hex(r), from: [hex(.light), hex(.dark)]).hex)
    }

    @MainActor init(_ brand: BrandModel, concept: BrandConcept) {
        self.concept = concept
        name = brand.brandName.isEmpty ? "Brand" : brand.brandName
        tagline = brand.tagline
        initial = brand.initial
        logoStyle = brand.logoStyle
        logo = brand.usesLogoImage ? brand.logo : nil
        logoMask = brand.usesLogoImage ? brand.logoMask : nil
        vector = brand.usesLogoImage ? brand.logoVector : nil
        logoFull = brand.usesLogoImage ? brand.logoArt(for: concept) : nil
        recolored = brand.recolorLogo
        logoAspect = brand.logoAspect
        logoMainHex = brand.logoMainHex
        showName = brand.showNameWithLogo
        let f = brand.font
        font = { size, weight in .system(size: size, weight: weight ?? f.weight, design: f.design).width(f.width) }
    }
}

// MARK: - Logo

enum LogoVariant: String, CaseIterable, Identifiable {
    case full, reversed, monoDark, monoLight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .full: "Full color"
        case .reversed: "Reversed"
        case .monoDark: "One color"
        case .monoLight: "One color, knocked out"
        }
    }
}

struct LogoPalette {
    let variant: LogoVariant
    let background: Color, mark1: Color, mark2: Color, mark3: Color, text: Color, letter: Color
    let bgHex: String, mainHex: String

    /// Hex of the single color used by one-color versions.
    var markHex: String { mainHex }

    static func make(_ kit: BrandKit, _ v: LogoVariant) -> LogoPalette {
        let p = kit.c(.primary), s = kit.c(.secondary), a = kit.c(.accent), d = kit.c(.dark), l = kit.c(.light)
        switch v {
        case .full:
            if kit.usesLogo, let main = kit.recolored ? kit.hex(.primary) : kit.logoMainHex {
                // A light or white logo would vanish on the light neutral, so show it on the dark one.
                let onDark = ColorMath.contrast(main, kit.hex(.light)) < 1.6
                return LogoPalette(variant: v, background: onDark ? d : l, mark1: p, mark2: s, mark3: a, text: onDark ? l : (kit.recolored ? p : d),
                                   letter: kit.on(.primary), bgHex: kit.hex(onDark ? .dark : .light), mainHex: main)
            }
            return LogoPalette(variant: v, background: l, mark1: p, mark2: s, mark3: a, text: p, letter: kit.on(.primary), bgHex: kit.hex(.light), mainHex: kit.hex(.primary))
        case .reversed:
            let accentWorks = ColorMath.contrast(kit.hex(.accent), kit.hex(.primary)) >= 2.2
            return LogoPalette(variant: v, background: p, mark1: l, mark2: l.opacity(0.55), mark3: accentWorks ? a : l, text: l, letter: p, bgHex: kit.hex(.primary), mainHex: kit.hex(.light))
        case .monoDark:
            return LogoPalette(variant: v, background: l, mark1: d, mark2: d, mark3: d, text: d, letter: l, bgHex: kit.hex(.light), mainHex: kit.hex(.dark))
        case .monoLight:
            return LogoPalette(variant: v, background: d, mark1: l, mark2: l, mark3: l, text: l, letter: d, bgHex: kit.hex(.dark), mainHex: kit.hex(.light))
        }
    }
}

struct Star4: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2, ri = R * 0.36
        var p = Path()
        for i in 0..<8 {
            let a = Double(i) * .pi / 4 - .pi / 2
            let rad = i.isMultiple(of: 2) ? R : ri
            let pt = CGPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct LogoMark: View {
    let kit: BrandKit
    let palette: LogoPalette
    let size: CGFloat
    /// Fit the logo inside a size×size square (app icons); otherwise wide logos keep their width.
    var fitSquare = false
    /// On the brand sheet: record where the vector logo goes so it can be drawn into the PDF as vectors.
    var slot: (collector: VectorSlotCollector, id: String)?

    var body: some View {
        if let image = kit.logo {
            imported(image)
        } else {
            generated
        }
    }

    /// The imported logo: as-is in full color, otherwise its shape filled with one color.
    private func imported(_ image: NSImage) -> some View {
        Group {
            if let vector = kit.vector {
                let art = palette.variant == .full ? (kit.logoFull ?? vector.full) : vector.oneColor(palette.markHex, on: palette.bgHex)
                if let slot {
                    GeometryReader { geo in
                        let _ = slot.collector.record(slot.id, geo.frame(in: .named(VectorSlotCollector.space)), art)
                        Color.clear
                    }
                } else {
                    Image(nsImage: art).resizable().interpolation(.high).scaledToFit()
                }
            } else if palette.variant == .full {
                Image(nsImage: kit.logoFull ?? image).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(nsImage: kit.logoMask ?? image).renderingMode(.template).resizable().interpolation(.high).scaledToFit()
                    .foregroundStyle(palette.mark1)
            }
        }
        .frame(width: fitSquare ? size : size * min(max(kit.logoAspect, 0.5), 4), height: size)
    }

    private var generated: some View {
        let s = size
        return Group {
            switch kit.logoStyle {
            case .monogram, .wordmark:
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: s * 0.28, style: .continuous).fill(palette.mark1)
                        .overlay(Text(kit.initial).font(kit.font(s * 0.56, .bold)).foregroundStyle(palette.letter))
                    Circle().fill(palette.mark3).frame(width: s * 0.22, height: s * 0.22)
                        .overlay(Circle().strokeBorder(palette.background, lineWidth: s * 0.04))
                        .offset(x: s * 0.06, y: -s * 0.06)
                }
            case .orbit:
                ZStack {
                    Circle().stroke(palette.mark2, lineWidth: s * 0.08).frame(width: s * 0.92, height: s * 0.92)
                    Circle().fill(palette.mark1).frame(width: s * 0.6, height: s * 0.6)
                    Circle().fill(palette.mark3).frame(width: s * 0.22, height: s * 0.22).offset(x: s * 0.33, y: -s * 0.33)
                }
            case .stack:
                VStack(alignment: .leading, spacing: s * 0.09) {
                    Capsule().fill(palette.mark1).frame(width: s * 0.92, height: s * 0.24)
                    Capsule().fill(palette.mark2).frame(width: s * 0.68, height: s * 0.24).padding(.leading, s * 0.12)
                    Capsule().fill(palette.mark3).frame(width: s * 0.42, height: s * 0.24)
                }
            case .petal:
                ZStack {
                    Ellipse().fill(palette.mark1).frame(width: s * 0.46, height: s * 0.92).rotationEffect(.degrees(40)).offset(x: -s * 0.13)
                    Ellipse().fill(palette.mark2).frame(width: s * 0.46, height: s * 0.92).rotationEffect(.degrees(-40)).offset(x: s * 0.13).opacity(0.9)
                    Circle().fill(palette.mark3).frame(width: s * 0.2, height: s * 0.2).offset(y: s * 0.04)
                }
            case .spark:
                ZStack {
                    Star4().fill(palette.mark1)
                    Circle().fill(palette.mark3).frame(width: s * 0.22, height: s * 0.22).offset(x: s * 0.3, y: s * 0.3)
                }
            case .custom:
                // "My logo" without an image (it was removed): fall back to a monogram.
                RoundedRectangle(cornerRadius: s * 0.28, style: .continuous).fill(palette.mark1)
                    .overlay(Text(kit.initial).font(kit.font(s * 0.56, .bold)).foregroundStyle(palette.letter))
            }
        }
        .frame(width: s, height: s)
    }
}

struct LogoLockup: View {
    let kit: BrandKit
    let variant: LogoVariant
    var size: CGFloat = 44
    var stacked = false
    var slot: (collector: VectorSlotCollector, id: String)?

    var body: some View {
        let pal = LogoPalette.make(kit, variant)
        let word = Group {
            if kit.logoStyle == .wordmark {
                Text(kit.name).foregroundStyle(pal.text) + Text(".").foregroundStyle(pal.mark3)
            } else {
                Text(kit.name).foregroundStyle(pal.text)
            }
        }
        .font(kit.font(size * (kit.logoStyle == .wordmark ? 0.95 : 0.62), nil))
        .lineLimit(1)
        .fixedSize()

        if kit.usesLogo {
            if kit.showName {
                HStack(spacing: size * 0.28) {
                    LogoMark(kit: kit, palette: pal, size: size, slot: slot)
                    word
                }
            } else {
                // Most logos already include the name, so they stand alone a little larger.
                LogoMark(kit: kit, palette: pal, size: size * 1.25, slot: slot)
            }
        } else if kit.logoStyle == .wordmark {
            word
        } else if stacked {
            VStack(spacing: size * 0.22) {
                LogoMark(kit: kit, palette: pal, size: size)
                word
            }
        } else {
            HStack(spacing: size * 0.28) {
                LogoMark(kit: kit, palette: pal, size: size)
                word
            }
        }
    }
}

struct LogoVariantCard: View {
    let kit: BrandKit
    let variant: LogoVariant

    var body: some View {
        let pal = LogoPalette.make(kit, variant)
        let ratio = ColorMath.contrast(pal.mainHex, pal.bgHex)
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                pal.background
                LogoLockup(kit: kit, variant: variant, size: 52)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.08)))
            HStack {
                Text(variant.title).font(.callout.weight(.medium))
                Spacer()
                Text(String(format: "%.1f:1 · %@", ratio, ColorMath.grade(ratio)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ratio >= 3 ? Color.secondary : Color.orange)
            }
        }
    }
}

// MARK: - Mockups

struct MockupFrame<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Color(nsColor: .windowBackgroundColor).opacity(0.6)
                content.shadow(color: .black.opacity(0.18), radius: 14, y: 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.07)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct BusinessCards: View {
    let kit: BrandKit

    var body: some View {
        ZStack {
            back.rotationEffect(.degrees(-6)).offset(x: -40, y: 50)
            front.rotationEffect(.degrees(4)).offset(x: 40, y: -50)
        }
    }

    private var front: some View {
        ZStack {
            kit.c(.primary)
            LogoLockup(kit: kit, variant: .reversed, size: 38)
        }
        .frame(width: 300, height: 172)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var back: some View {
        HStack(spacing: 0) {
            kit.c(.accent).frame(width: 7)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Spacer()
                    LogoMark(kit: kit, palette: LogoPalette.make(kit, .full), size: 24)
                }
                Spacer()
                Text("Alex Morgan").font(kit.font(17, nil)).foregroundStyle(kit.c(.dark))
                Text("Founder").font(.system(size: 10.5, weight: .medium)).foregroundStyle(kit.c(.primary))
                Spacer().frame(height: 8)
                Group {
                    Text("hello@\(kit.name.lowercased().filter { $0.isLetter || $0.isNumber }).com")
                    Text("+1 (555) 014 2290")
                }
                .font(.system(size: 9.5))
                .foregroundStyle(kit.c(.dark).opacity(0.7))
            }
            .padding(16)
        }
        .frame(width: 300, height: 172)
        .background(kit.c(.light))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct WebsiteHero: View {
    let kit: BrandKit

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(["#FF5F57", "#FEBC2E", "#28C840"], id: \.self) { Circle().fill(Color(hex: $0)).frame(width: 8, height: 8) }
                Spacer()
                Capsule().fill(.black.opacity(0.06)).frame(width: 180, height: 14)
                    .overlay(Text("\(kit.name.lowercased().filter { $0.isLetter }).com").font(.system(size: 8)).foregroundStyle(.black.opacity(0.45)))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color(hex: "#ECECEC"))

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    LogoLockup(kit: kit, variant: .full, size: 18)
                    Spacer()
                    ForEach(["Product", "Pricing", "About"], id: \.self) { Text($0).font(.system(size: 9, weight: .medium)).foregroundStyle(kit.c(.dark).opacity(0.65)) }
                    Text("Get started").font(.system(size: 9, weight: .semibold)).foregroundStyle(kit.on(.primary))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(kit.c(.primary), in: Capsule())
                }
                .padding(.bottom, 26)

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("NEW").font(.system(size: 8, weight: .bold)).foregroundStyle(kit.on(.accent))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(kit.c(.accent), in: Capsule())
                        Text(kit.tagline.isEmpty ? "Make every day brighter." : kit.tagline)
                            .font(kit.font(26, nil))
                            .foregroundStyle(kit.c(.dark))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Everything you need, thoughtfully designed and ready when you are.")
                            .font(.system(size: 10))
                            .foregroundStyle(kit.c(.dark).opacity(0.65))
                        HStack(spacing: 8) {
                            Text("Start free").font(.system(size: 10, weight: .semibold)).foregroundStyle(kit.on(.primary))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(kit.c(.primary), in: RoundedRectangle(cornerRadius: 6))
                            Text("Learn more").font(.system(size: 10, weight: .semibold)).foregroundStyle(kit.c(.dark))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(kit.c(.dark).opacity(0.25)))
                        }
                        .padding(.top, 4)
                    }
                    .frame(width: 230, alignment: .leading)
                    Spacer()
                    ZStack {
                        Circle().fill(kit.c(.secondary)).frame(width: 150, height: 150).offset(x: 20, y: -6)
                        RoundedRectangle(cornerRadius: 22, style: .continuous).fill(kit.c(.primary)).frame(width: 96, height: 120).rotationEffect(.degrees(-10)).offset(x: -24, y: 16)
                        Circle().fill(kit.c(.accent)).frame(width: 40, height: 40).offset(x: 60, y: 54)
                    }
                    .frame(width: 180, height: 180)
                }
            }
            .padding(18)
            .frame(width: 500, height: 300, alignment: .topLeading)
            .background(kit.c(.light))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PhoneApp: View {
    let kit: BrandKit

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("9:41").font(.system(size: 9, weight: .semibold))
                    Spacer()
                    Image(systemName: "battery.75percent").font(.system(size: 9))
                }
                .padding(.bottom, 10)
                LogoMark(kit: kit, palette: LogoPalette.make(kit, .reversed), size: 22)
                Text("Good morning").font(kit.font(20, nil))
                Text("3 things planned today").font(.system(size: 10)).opacity(0.8)
            }
            .foregroundStyle(kit.on(.primary))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(kit.c(.primary))

            VStack(spacing: 8) {
                ForEach(0..<3) { i in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 7).fill(i == 0 ? kit.c(.secondary) : kit.c(.secondary).opacity(0.35)).frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(kit.c(.dark).opacity(0.8)).frame(width: [90, 70, 110][i], height: 6)
                            Capsule().fill(kit.c(.dark).opacity(0.1)).frame(height: 4)
                                .overlay(alignment: .leading) { Capsule().fill(kit.c(.accent)).frame(width: [60, 30, 85][i], height: 4) }
                        }
                    }
                    .padding(10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(kit.c(.light))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(kit.on(.accent))
                    .frame(width: 38, height: 38).background(kit.c(.accent), in: Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .padding(.bottom, 48).padding(.trailing, 14)
            }

            HStack {
                ForEach(["house.fill", "calendar", "chart.bar", "person"], id: \.self) { s in
                    Image(systemName: s).font(.system(size: 13))
                        .foregroundStyle(s == "house.fill" ? kit.c(.primary) : kit.c(.dark).opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 40)
            .background(.white)
        }
        .frame(width: 190, height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color(hex: "#1C1C1E"), lineWidth: 6))
    }
}

struct SocialPost: View {
    let kit: BrandKit

    var body: some View {
        ZStack(alignment: .topLeading) {
            kit.c(.primary)
            Circle().fill(kit.c(.secondary).opacity(0.9)).frame(width: 210, height: 210).offset(x: 160, y: 150)
            Circle().fill(kit.c(.accent)).frame(width: 56, height: 56).offset(x: 196, y: 40)
            VStack(alignment: .leading, spacing: 12) {
                Text("TIP OF THE WEEK").font(.system(size: 9, weight: .bold)).tracking(1.2).opacity(0.8)
                Text("Small steps,\nbright days.").font(kit.font(30, nil)).lineSpacing(-2)
                Spacer()
                LogoLockup(kit: kit, variant: .reversed, size: 18)
            }
            .foregroundStyle(kit.on(.primary))
            .padding(22)
        }
        .frame(width: 290, height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct PackagingPouch: View {
    let kit: BrandKit

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(kit.c(.dark).opacity(0.12)).frame(height: 16)
                    .overlay(HStack(spacing: 3) { ForEach(0..<30, id: \.self) { _ in Rectangle().fill(.black.opacity(0.06)).frame(width: 1) } })
                VStack(spacing: 14) {
                    LogoMark(kit: kit, palette: LogoPalette.make(kit, .full), size: 40).padding(.top, 22)
                    Text(kit.name.uppercased()).font(kit.font(20, nil)).tracking(2).foregroundStyle(kit.c(.dark))
                    Rectangle().fill(kit.c(.primary)).frame(height: 70)
                        .overlay(VStack(spacing: 2) {
                            Text("Morning Blend").font(kit.font(17, nil))
                            Text("Whole bean · 250 g").font(.system(size: 9, weight: .medium)).opacity(0.85)
                        }.foregroundStyle(kit.on(.primary)))
                    Text("Small batch · Thoughtfully sourced").font(.system(size: 8.5)).foregroundStyle(kit.c(.dark).opacity(0.6))
                    Spacer()
                }
            }
            .frame(width: 210, height: 320)
            .background(kit.c(.light))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 4))

            Text("NEW").font(.system(size: 11, weight: .black)).foregroundStyle(kit.on(.accent))
                .frame(width: 50, height: 50)
                .background(Star4().fill(kit.c(.accent)).scaleEffect(1.35))
                .rotationEffect(.degrees(12))
                .offset(x: 88, y: 20)
        }
    }
}

struct Letterhead: View {
    let kit: BrandKit

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                LogoLockup(kit: kit, variant: .full, size: 20)
                Spacer()
                Text("12 Market St.\nSpringfield").font(.system(size: 6.5)).multilineTextAlignment(.trailing).foregroundStyle(kit.c(.dark).opacity(0.6))
            }
            .padding(.bottom, 10)
            Rectangle().fill(kit.c(.accent)).frame(width: 34, height: 3).padding(.bottom, 18)
            Text("Dear Jordan,").font(kit.font(10, .semibold)).foregroundStyle(kit.c(.dark)).padding(.bottom, 8)
            ForEach(0..<9, id: \.self) { i in
                Capsule().fill(kit.c(.dark).opacity(0.14)).frame(width: i % 4 == 3 ? 120 : 190, height: 3.5).padding(.bottom, 6)
            }
            Spacer()
            Rectangle().fill(kit.c(.primary)).frame(height: 10).padding(.horizontal, -22).padding(.bottom, -22)
        }
        .padding(22)
        .frame(width: 240, height: 330)
        .background(.white)
    }
}
