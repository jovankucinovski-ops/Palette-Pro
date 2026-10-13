import SwiftUI

/// One-page brand color guide, rendered to PDF.
struct BrandSheet: View {
    let kit: BrandKit
    let focus: ProjectFocus
    let traits: [Trait]
    /// When set (vector logos), logo positions are recorded instead of drawn, then drawn as vectors.
    var slots: VectorSlotCollector?

    static let size = CGSize(width: 1400, height: 990)
    private let ink = Color(hex: "#151515")
    private let muted = Color(hex: "#6A6964")

    var body: some View {
        let concept = kit.concept
        let type = BrandEngine.typeSuggestion(traits)
        let guidance = BrandEngine.guidance(concept, focus: focus, traits: traits, brandName: kit.name)
        VStack(alignment: .leading, spacing: 30) {
            HStack(alignment: .center) {
                LogoLockup(kit: kit, variant: .full, size: 54, slot: slots.map { ($0, "header") })
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Brand color guide").font(.system(size: 22, weight: .semibold)).foregroundStyle(ink)
                    Text("\(concept.name) · \(focus.title) · \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 13)).foregroundStyle(muted)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                ForEach(BrandRole.allCases) { r in roleColumn(r) }
            }

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    label("Logo")
                    HStack(spacing: 10) {
                        ForEach(LogoVariant.allCases) { v in
                            ZStack {
                                LogoPalette.make(kit, v).background
                                LogoLockup(kit: kit, variant: v, size: 26, slot: slots.map { ($0, "variant-\(v.rawValue)") })
                            }
                            .frame(width: 170, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.08)))
                        }
                    }
                    label("Balance").padding(.top, 8)
                    HStack(spacing: 2) {
                        ForEach([BrandRole.light, .primary, .secondary, .dark, .accent], id: \.self) { r in
                            Rectangle().fill(concept[r].color).frame(width: 710 * r.share - 2, height: 26)
                                .overlay(Text("\(Int(r.share * 100))%").font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(hex: ColorMath.readableOn(ColorMath.rgb(concept.hex(r))))))
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.black.opacity(0.08)))
                }
                VStack(alignment: .leading, spacing: 10) {
                    label("Typography")
                    Text(kit.name).font(kit.font(38, nil)).foregroundStyle(concept[.primary].color).lineLimit(1)
                    Text("Headlines: \(type.headline)   Body: \(type.body)").font(.system(size: 13, weight: .medium)).foregroundStyle(ink)
                    Text("Free on Google Fonts, chosen for \(type.why).").font(.system(size: 12)).foregroundStyle(muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    label(guidance.first?.title ?? "Guidance")
                    ForEach((guidance.first?.items ?? []).prefix(4), id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(concept[.accent].color).frame(width: 5, height: 5).offset(y: -2)
                            Text(LocalizedStringKey(item)).font(.system(size: 12)).foregroundStyle(ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(width: 700, alignment: .leading)
                HStack(spacing: 18) {
                    SocialPost(kit: kit).scaleEffect(0.62).frame(width: 180, height: 180)
                    PhoneApp(kit: kit).scaleEffect(0.5).frame(width: 95, height: 180)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
            Text("Made with Palette Pro. PANTONE® is a trademark of Pantone LLC. Values are screen approximations; approve print color against a physical Pantone guide.")
                .font(.system(size: 10))
                .foregroundStyle(muted)
        }
        .padding(48)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(.white)
        .environment(\.colorScheme, .light)
        .coordinateSpace(.named(VectorSlotCollector.space))
    }

    private func label(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.8).foregroundStyle(muted)
    }

    private func roleColumn(_ r: BrandRole) -> some View {
        let c = kit.concept[r], rgb = ColorMath.rgb(c.hex)
        return VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(c.color).frame(height: 150)
                .overlay(Rectangle().strokeBorder(.black.opacity(r == .light ? 0.08 : 0)))
            VStack(alignment: .leading, spacing: 4) {
                Text(r.title).font(.system(size: 15, weight: .semibold))
                Text(r.usage).font(.system(size: 10.5)).foregroundStyle(muted).lineLimit(2, reservesSpace: true)
                Group {
                    Text("HEX  \(c.hex)")
                    Text("RGB  \(rgb.ints.map(String.init).joined(separator: " "))")
                    Text("CMYK ≈ \(ColorMath.cmyk(rgb).map(String.init).joined(separator: " "))")
                    Text("\(BrandEngine.pantoneLabel(c))")
                    Text("\(BrandEngine.pantoneLabel(c, in: .uncoated))")
                }
                .font(.system(size: 11, design: .monospaced))
            }
            .foregroundStyle(ink)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor static func pdf(kit: BrandKit, brand: BrandModel) -> Data? {
        let slots = kit.vector != nil ? VectorSlotCollector() : nil
        let renderer = ImageRenderer(content: BrandSheet(kit: kit, focus: brand.focus, traits: brand.traits, slots: slots))
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var box = CGRect(origin: .zero, size: size)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        renderer.render { _, draw in
            ctx.beginPDFPage(nil)
            draw(ctx)
            slots?.draw(in: ctx, pageHeight: size.height)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }
}
