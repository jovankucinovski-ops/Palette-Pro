# Palette Pro (web)

A personal color library: browse Pantone-style swatches, build and save palettes, and match any color to its nearest Pantone. It runs in your browser with no install, no account and no internet connection.

## Open it

Double-click `index.html`. Chrome, Edge, Safari and Firefox all work.

Your palettes and favorites are saved in the browser you open it with. Use **My palettes → Back up all** now and then to keep a copy as a file, or to move your data to another browser or computer (restore it with **Import**).

## What's inside

**Library**: 5,500+ colors in Pantone-chip style.
- Solid Coated, Solid Uncoated, Fashion + Home (TCX), Metallics, Pastels & Neons, Skin Tones, and every Color of the Year from 2000 to 2026
- Search by name, code or hex. Typing a hex like `#0F4C81` lists the closest Pantones in order.
- Filter by color family, sort by hue or lightness, and star favorites

**Palette builder**
- `Space` generates a palette. Pick a harmony (analogous, complementary, triadic…) and a mood (pastel, vibrant, muted, earthy, dark).
- Lock the colors you like, drag to reorder, and edit any hex directly.
- Every color shows its nearest Pantone and ΔE. **Snap to Pantone** keeps a palette 100% Pantone.
- The contrast checker shows WCAG AA/AAA for every text/background pair.
- Undo/redo (`⌘Z` / `⇧⌘Z`), save (`⌘S`)

**Export**: CSS variables, SCSS, Tailwind v3/v4, JSON, hex list, GIMP/Inkscape/Krita `.gpl`, Adobe `.ase` (Illustrator, Photoshop, InDesign, Affinity, Procreate), and a PNG image of the palette.

**Match**
- Nearest Pantones for any color, ranked by CIEDE2000 ΔE (under 1 ≈ identical, under 2.5 = very close)
- Pick a color from anywhere on screen (Chrome/Edge)
- Drop, choose or paste an image to extract its palette. Click the image to sample a pixel.

**Import**: paste a list of hex codes or Pantone numbers (`185 C`, `19-4052 TCX`, `Cool Gray 11 C`) to make a palette.

## Shortcuts

| Key | Action |
| --- | --- |
| `/` | Search the library |
| `Space` | Generate (Palette tab) |
| `⌘Z` / `⇧⌘Z` | Undo / redo |
| `⌘S` | Save palette |
| Arrow keys on the ⠿ handle | Move a color |

## Notes

- PANTONE® is a trademark of Pantone LLC. The hex values here are screen approximations from public sources, fine for digital design and reference. For print, always check against a physical Pantone guide.
- Color data comes from [bconglet/Pantoner](https://github.com/bconglet/Pantoner) (MIT) and [Margaret2/pantone-colors](https://github.com/Margaret2/pantone-colors), plus recent Color of the Year values.
- CMYK values are a simple conversion, not a press profile.

## Files

```
index.html        the app
css/styles.css    styling (light + dark)
js/data.js        color library
js/color.js       color math: conversions, ΔE 2000, generation, image extraction
js/exporters.js   export formats
js/app.js         the interface
```
