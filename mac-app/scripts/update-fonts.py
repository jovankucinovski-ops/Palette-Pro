#!/usr/bin/env python3
"""Builds the bundled font catalogue (Sources/PalettePro/Type/FontData.swift).

Sources, all free and without an API key:
  - Fontsource (api.fontsource.org): every Google Font plus other open-source families,
    with font files on the jsDelivr CDN.
  - Google Fonts metadata (fonts.google.com/metadata/fonts): popularity, designers, dates.
  - Fontshare (api.fontshare.com): Indian Type Foundry's free fonts (ITF Free Font License).

Only metadata is bundled; the app downloads a font file the first time it's previewed.
Run it now and then to pick up new fonts:  python3 mac-app/scripts/update-fonts.py
"""
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Sources", "PalettePro", "Type", "FontData.swift")

# Families that working designers reach for. They get a "Designer picks" filter in the library.
PICKS = """
Satoshi, General Sans, Clash Display, Clash Grotesk, Cabinet Grotesk, Switzer, Supreme, Chillax, Zodiak, Erode,
Gambetta, Boska, Sentient, Synonym, Author, Bespoke Serif, Panchang, Tanker, Telma, Excon, Ranade, Plein,
Inter, Inter Tight, Geist Sans, Manrope, DM Sans, Plus Jakarta Sans, Space Grotesk, Syne, Unbounded, Sora, Outfit,
Bricolage Grotesque, Familjen Grotesk, Hanken Grotesk, Instrument Sans, Onest, Figtree, Schibsted Grotesk, Archivo,
Uncut Sans, Apfel Grotezk, Bagnard, Redaction, Hauora Sans, Open Runde,
Fraunces, Instrument Serif, Young Serif, Newsreader, Playfair Display, DM Serif Display, Gloock, Bodoni Moda,
Cormorant, Cormorant Garamond, EB Garamond, Libre Caslon Text, Literata, Source Serif 4, Lora, Crimson Pro,
IBM Plex Sans, IBM Plex Serif, IBM Plex Mono, JetBrains Mono, Space Mono, Monaspace Neon, Commit Mono,
Anton, Bebas Neue, Oswald, Big Shoulders Display, Tilt Warp, Rubik Mono One
"""
PICKS = {p.strip() for p in PICKS.replace("\n", ",").split(",") if p.strip()}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "PalettePro-font-catalogue/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        raw = r.read().decode("utf-8")
    return json.loads(raw[4:] if raw.startswith(")]}'") else raw)


def main():
    fontsource = get("https://api.fontsource.org/v1/fonts")
    google = {f["family"]: f for f in get("https://fonts.google.com/metadata/fonts")["familyMetadataList"]}
    fontshare = []
    offset = 0
    while True:
        page = get(f"https://api.fontshare.com/v2/fonts?limit=100&offset={offset}")
        fontshare += page["fonts"]
        if not page.get("has_more"):
            break
        offset += 100

    families = []
    names = set()

    for f in fontsource:
        if "latin" not in f["subsets"] or f["category"] in ("icons", "other"):
            continue
        g = google.get(f["family"], {})
        if g.get("primaryScript"):  # e.g. Noto Sans Adlam: Latin is only a fallback there
            continue
        category = {"sans-serif": "sans", "serif": "serif", "display": "display",
                    "handwriting": "script", "monospace": "mono"}[f["category"]]
        if category == "serif" and "Slab" in (g.get("stroke") or ""):
            category = "slab"
        families.append({
            "id": f["id"],
            "family": f["family"],
            "category": category,
            "source": "google" if f["type"] == "google" else "open",
            "weights": sorted(f["weights"]),
            "italic": "italic" in f["styles"],
            "variable": bool(f["variable"]),
            "license": f["license"].upper() if f["license"].lower() == "mit" else f["license"],
            "rank": g.get("popularity") or 5000,
            "designers": ", ".join(g.get("designers") or []),
            "year": int((g.get("dateAdded") or f["lastModified"] or "2000")[:4]),
            "subset": f["defSubset"] if f["defSubset"] in f["subsets"] else "latin",
        })
        names.add(f["family"].lower())

    # Fontshare: skip the open-source families that Fontsource already has.
    by_views = sorted(fontshare, key=lambda f: -(f.get("views") or 0))
    view_rank = {f["slug"]: i for i, f in enumerate(by_views)}
    for f in fontshare:
        if f["name"].lower() in names or f.get("script") != "latin":
            continue
        cat = f["category"].lower()
        if "mono" in f["name"].lower():
            category = "mono"
        elif "script" in cat or "handwritten" in cat:
            category = "script"
        elif "display" in cat or "blackletter" in cat:
            category = "display"
        elif "slab" in cat:
            category = "slab"
        elif "serif" in cat and "sans" not in cat:
            category = "serif"
        else:
            category = "sans"
        files = {}
        for s in f["styles"]:
            if s.get("is_variable"):
                continue
            key = f'{s["weight"]["weight"]}{"i" if s["is_italic"] else ""}'
            files[key] = re.sub(r"^(https?:)?//cdn\.fontshare\.com/wf/", "", s["file"])
        if not files:
            continue
        weights = sorted({int(k.rstrip("i")) for k in files})
        families.append({
            "id": "fontshare-" + f["slug"],
            "family": f["name"],
            "category": category,
            "source": "fontshare",
            "weights": weights,
            "italic": any(k.endswith("i") for k in files),
            "variable": any(s.get("is_variable") for s in f["styles"]),
            "license": "ITF FFL" if f["license_type"] == "itf_ffl" else "OFL-1.1",
            # Fontshare's most viewed families rank among Google's top fonts.
            "rank": 20 + view_rank[f["slug"]] * 6,
            "designers": ", ".join(d["name"] for d in (f.get("designers") or []) if d.get("name")),
            "year": int((f.get("inserted_at") or "2020")[:4]),
            "slug": f["slug"],
            "files": files,
        })

    for fam in families:
        if fam["family"] in PICKS:
            fam["pick"] = True
    missing = sorted(PICKS - {f["family"] for f in families})
    if missing:
        print("Not in the catalogue (check spelling):", ", ".join(missing), file=sys.stderr)

    families.sort(key=lambda f: (f["rank"], f["family"]))
    data = json.dumps(families, separators=(",", ":"), ensure_ascii=False)
    counts = {}
    for f in families:
        counts[f["source"]] = counts.get(f["source"], 0) + 1
    with open(OUT, "w", encoding="utf-8") as out:
        out.write("// Generated by scripts/update-fonts.py. Do not edit by hand.\n")
        out.write("// Metadata from Fontsource (api.fontsource.org), Google Fonts and Fontshare (api.fontshare.com).\n")
        out.write("// Font files are downloaded on demand from their official CDNs.\n\n")
        out.write('let fontCatalogJSON = #"""\n' + data + '\n"""#\n')
    print(f"Wrote {len(families)} families {counts} to {os.path.relpath(OUT)} ({len(data) // 1024} KB)")


if __name__ == "__main__":
    main()
