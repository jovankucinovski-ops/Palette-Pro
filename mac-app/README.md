<img src="Resources/AppIcon.png" width="128" alt="Palette Pro icon">

# Palette Pro for Mac

A native macOS color and type app built in SwiftUI. Use it to browse 5,500+ Pantone-style swatches, build and save palettes, match any color to its nearest Pantone, design brand color systems with logo and mockup previews, and find free fonts, pairings and type scales.

## Install

The easiest way is the disk image on the [Releases page](../../../releases/latest); see the [main README](../README.md#install-on-a-mac).

To build it yourself, run this from the repository folder:

```bash
mac-app/scripts/build-app.sh --install
```

The script works from any folder. It builds `Palette Pro.app` and copies it to `~/Applications`, where you can open it from Spotlight or Launchpad.

Build files go to `~/Library/Caches/PalettePro-build`, not the project folder. Documents may be synced by iCloud, which would upload the 400 MB build cache and add file tags that make code signing fail. Without `--install`, the built app stays in that cache folder.

### Installer for another Mac

```bash
mac-app/scripts/make-dmg.sh
```

This builds `Palette Pro 1.0.dmg` (about 3.5 MB) with the usual drag-to-Applications shortcut and shows it in Finder. The app is ad-hoc signed, not notarized. On another Mac, open it once, then click **Open Anyway** in **System Settings › Privacy & Security** (on macOS 14, right-click › Open also works). Skipping that step for everyone needs an Apple Developer ID and notarization.

### Help

**Help › Palette Pro Help** (⌘?) has a quick guide to every section and all keyboard shortcuts. **Palette Pro › About Palette Pro** shows the version and credits.

It needs macOS 14 or later. The Command Line Tools are enough; you don't need full Xcode. The script picks a compatible SDK automatically.

## What's inside

**Library** (sidebar): All Colors, Solid Coated, Solid Uncoated, Fashion + Home (TCX), Metallics, Pastels & Neons, Color of the Year (2000–2026), Skin Tones and Favorites.
- Search by name, code or hex. A hex like `#0F4C81` lists the closest Pantones.
- Filter by hue and sort by hue or lightness from the toolbar.
- Click a chip for the inspector: values, contrast, tints and shades, and similar colors.
- Drag chips into the palette editor, or into any other app as hex text.

**Palette editor**
- `Space` generates a palette (choose a harmony and mood). Lock the colors you want to keep.
- Edit a hex directly, use the system color picker, and drag colors to reorder.
- Every color shows its nearest Pantone and ΔE. Turn on "Snap to Pantone" to keep a palette all-Pantone.
- A contrast table shows the WCAG rating for every text/background pair.
- Undo/redo work through the Edit menu (`⌘Z` / `⇧⌘Z`).

**Brand Studio**: enter a brand name, project type (logo, identity, website & app, packaging, social, print), industry and up to three personality traits. You get:
- **Ideas**: 12 palettes, each previewing your logo, or your typed name and tagline, on the palette's light, primary and dark colors. Previews update as you type.
  - Your logo is repainted in each palette: main color → Primary, second color → Accent, dark text → Dark neutral, white → Light neutral. Its original colors are always the first card.
  - The first ideas follow your industry; the rest explore the whole color wheel, with softer and deeper versions.
  - Click an idea to use it everywhere, double-click for details, and use **More Ideas** (⌘R) for new ones.
  - **Recolor logo with palette** can be turned off to keep the logo's own colors, and **Keep ideas close to my logo's colors** limits ideas to your logo's hue.
- Each palette has defined roles: Primary, Secondary, Accent, and dark and light neutrals. Each role is snapped to Pantone Coated with its Uncoated equivalent.
- **Why these colors**: color psychology, industry conventions and contrast facts.
- **Implementation guidance** for the project type you picked, for example logo production specs, UI tokens and button states, spot versus process printing for packaging, or social post templates.
- Typography pairings (free Google Fonts) matched to the personality.
- **Your own logo**: drop in an SVG or PNG (JPEG, HEIC and PDF also work), choose a file, or paste one, including SVG copied from Figma or Illustrator. It replaces the generated mark in every variant, mockup and the brand sheet, and it's saved for next time.
  - **SVG stays vector**: it's sharp at every size, and the logos on the brand-sheet PDF are true vectors. Empty margins are cropped by adjusting the viewBox.
  - One-color and reversed versions use the logo's shape, with white areas such as letter holes cut out. For SVGs this is done by recoloring the artwork, so it stays vector.
  - For PNGs, a solid white (or other plain) background is removed automatically, and margins are trimmed.
  - **Your logo's colors** lists each color with HEX, nearest Pantone C and U, and CMYK.
  - **Base palettes on my logo** builds the brand palettes from those colors.
  - **Export Logo Files…** writes a folder with color, dark and white versions as SVG, PDF and PNG (PNG only for bitmap logos), a PNG reversed on the primary color, and a README with the color specs. One-color SVGs keep white details as vector cut-outs (masks); one-color PDFs of such logos draw them from a high-resolution mask.
- Logo variants (full color, reversed, one color, knocked out) with contrast checks, plus app icon and favicon previews.
- Mockups: business cards, website, mobile app, social post, packaging and letterhead.
- Specs: HEX, RGB, CMYK, Pantone C and U, 50–900 tint ramps for UI, and accessible color pairings.
- Export a one-page **brand sheet PDF**, design tokens, or swatches.

**Fonts** (sidebar › Type)
- 1,500+ free font families: Google Fonts, Fontshare and independent open-source fonts, plus everything installed on your Mac.
- Collections: Designer Picks, Google Fonts, Fontshare, Open Source, On This Mac and Favorite Fonts. Filter by style (sans, serif, slab, display, script, mono), search by name or designer, sort by popularity, name or newest.
- Type your own preview text and set the size. Click a font for every weight and italic, a size waterfall, the character set and its license.
- A font file downloads the first time it's shown and is cached in `~/Library/Caches/Palette Pro/Fonts`, used only inside the app. **Settings › Fonts** shows the cache size and can clear it. **Get Font** opens the official page for the full family.

**Pairing**
- 12 heading and body pairings with a short reason for each: contrast (serif with sans), one family, statement headline with quiet text, and more.
- Explore (every idea starts from a different headline font) or pick a heading font and get the best text faces for it. Choose a mood to steer the choice.
- Double-click a pairing for a full page preview. **Copy CSS** gives the font stacks and embed links.

**Type Scale**
- Pick heading and body fonts (or use the selected pairing), a base size and a ratio from minor second to golden ratio.
- Every step from Display to Caption with size, line height, letter spacing and weight, plus a sample page.
- Export CSS variables, SCSS, a Tailwind config, a SwiftUI `Font` extension or design tokens (JSON).

**Match**
- Find the nearest Pantones to any color (CIEDE2000).
- **Pick from Screen** samples any pixel on your display.
- Drop, choose or paste (`⌘V`) an image to extract its palette. Click the image to sample a pixel.

**Export**: CSS variables, SCSS, Tailwind v3/v4, SwiftUI `Color` extension, JSON, hex list, GIMP/Inkscape/Krita `.gpl`, Adobe `.ase`, Apple `.clr` and PNG.
**Add to macOS Colors** installs a palette into the system color picker, so it appears in Pages, Keynote, Pixelmator and every other app that uses the standard Colors panel.

**Import**: paste hex codes or Pantone numbers (`185 C`, `19-4052 TCX`, `Cool Gray 11 C`). You can also restore a backup from this app or from the Palette Pro web app.

## Shortcuts

| Keys | Action |
| --- | --- |
| `⌘1`–`⌘5` | Library, Palette, Brand Studio, My Palettes, Match |
| `⌘6`–`⌘8` | Fonts, Pairing, Type Scale |
| `Space` / `⌘G` | Generate (Palette) |
| `⌥⌘N` | Add a color |
| `⌘S` / `⌘E` | Save / Export palette |
| `⇧⌘I` | Import colors |
| `⌘R` | New ideas in Brand Studio and Pairing |
| `⌥⌘I` | Show or hide the inspector |

## Your data

Palettes, favorites and settings live in `~/Library/Application Support/Palette Pro/library.json`. Data saved before the app was renamed (in a `Swatchbook` folder) is moved there automatically on first launch. Use **File → Back Up Library…** to keep a copy. **Settings → Show Data in Finder** opens the folder.

## Notes

- PANTONE® is a trademark of Pantone LLC. The hex values are screen approximations from public sources ([Pantoner](https://github.com/bconglet/Pantoner), MIT; [pantone-colors](https://github.com/Margaret2/pantone-colors)). For print, always approve color against a physical Pantone guide. CMYK values are simple conversions, not a press profile.
- Development: running the binary with `PALETTE_PRO_SNAPSHOTS=<dir>` steps through every screen, saves screenshots and sample exports, then quits. `PALETTE_PRO_DATA_DIR=<dir>` keeps that run away from your real library.

## Project layout

```
Package.swift
Sources/PalettePro/
  App/      app entry, menus, snapshot runner
  Model/    color math, library data, palettes, exporters
  Views/    library, inspector, palette editor, My Palettes, Match, sheets
  Brand/    Brand Studio engine, mockups, brand sheet PDF
  Type/     font catalogue and downloads, pairing engine, type scale, Fonts/Pairing/Type Scale views
scripts/    build-app.sh, make-dmg.sh, make-icon.swift (draws the icon at every size),
            update-fonts.py (refreshes the bundled font catalogue)
Resources/  Info.plist, AppIcon.png (icon preview)
```
