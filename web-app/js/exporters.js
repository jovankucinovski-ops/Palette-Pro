/* Palette export formats. Each entry: { hex, rgb, pantone, exact, deltaE, name }. */
(function (root) {
  'use strict';

  const slug = s => (s || '').toLowerCase().normalize('NFKD').replace(/[^\w\s-]/g, '').trim().replace(/[\s_]+/g, '-').replace(/-+/g, '-') || 'palette';
  const label = e => (e.pantone ? (e.exact ? '' : '≈ ') + 'PANTONE ' + e.pantone + (e.name ? ' ' + e.name : '') : '');
  const comment = e => (label(e) ? ` /* ${label(e)} */` : '');

  const text = {
    css(name, entries) {
      const p = slug(name);
      return `/* ${name} — exported from Palette Pro */\n:root {\n` +
        entries.map((e, i) => `  --${p}-${i + 1}: ${e.hex};${comment(e)}`).join('\n') + '\n}\n';
    },
    scss(name, entries) {
      const p = slug(name);
      return `// ${name} — exported from Palette Pro\n` +
        entries.map((e, i) => `$${p}-${i + 1}: ${e.hex};${label(e) ? ' // ' + label(e) : ''}`).join('\n') +
        `\n\n$${p}: (\n` + entries.map((e, i) => `  ${i + 1}: $${p}-${i + 1},`).join('\n') + '\n);\n';
    },
    tailwind4(name, entries) {
      const p = slug(name);
      return `/* ${name} — Tailwind CSS v4: add to your main CSS file */\n@theme {\n` +
        entries.map((e, i) => `  --color-${p}-${i + 1}: ${e.hex};${comment(e)}`).join('\n') + '\n}\n';
    },
    tailwind3(name, entries) {
      const p = slug(name);
      return `// ${name} — Tailwind CSS v3: merge into tailwind.config.js\nmodule.exports = {\n  theme: {\n    extend: {\n      colors: {\n` +
        `        '${p}': {\n` + entries.map((e, i) => `          ${i + 1}: '${e.hex}',${label(e) ? ' // ' + label(e) : ''}`).join('\n') +
        '\n        },\n      },\n    },\n  },\n};\n';
    },
    json(name, entries) {
      return JSON.stringify({
        name,
        colors: entries.map(e => ({
          hex: e.hex, rgb: `rgb(${e.rgb.join(", ")})`,
          pantone: e.pantone ? 'PANTONE ' + e.pantone : null,
          pantoneName: e.name || null,
          match: e.pantone ? (e.exact ? 'exact' : `nearest (ΔE ${e.deltaE.toFixed(1)})`) : null,
        })),
      }, null, 2) + '\n';
    },
    gpl(name, entries) {
      return `GIMP Palette\nName: ${name}\nColumns: ${entries.length}\n#\n` +
        entries.map(e => e.rgb.map(v => String(v).padStart(3)).join(' ') + '\t' + (label(e) || e.hex)).join('\n') + '\n';
    },
    hex(name, entries) {
      return entries.map(e => e.hex).join('\n') + '\n';
    },
  };

  // Adobe Swatch Exchange: works in Illustrator, Photoshop, InDesign, Affinity, Procreate.
  function ase(name, entries) {
    const parts = [];
    const u16 = v => { const b = new Uint8Array(2); new DataView(b.buffer).setUint16(0, v); return b; };
    const u32 = v => { const b = new Uint8Array(4); new DataView(b.buffer).setUint32(0, v); return b; };
    const f32 = v => { const b = new Uint8Array(4); new DataView(b.buffer).setFloat32(0, v); return b; };
    const utf16 = s => {
      const str = s + '\0', b = new Uint8Array(str.length * 2);
      for (let i = 0; i < str.length; i++) { const c = str.charCodeAt(i); b[2 * i] = c >> 8; b[2 * i + 1] = c & 255; }
      return [u16(str.length), b];
    };
    const block = (type, body) => {
      const len = body.reduce((n, b) => n + b.length, 0);
      parts.push(u16(type), u32(len), ...body);
    };
    parts.push(new TextEncoder().encode('ASEF'), u16(1), u16(0), u32(entries.length + 2));
    block(0xC001, utf16(name));
    entries.forEach(e => {
      // Only exact matches carry a Pantone name, so approximations aren't mistaken for the real ink.
      block(0x0001, [...utf16(e.exact ? label(e) : e.hex), new TextEncoder().encode('RGB '),
        ...e.rgb.map(v => f32(v / 255)), u16(2)]);
    });
    block(0xC002, []);
    return new Blob(parts, { type: 'application/octet-stream' });
  }

  // Pantone-chip style image of the palette.
  function png(name, entries, readableOn) {
    const W = 1600, H = 900, pad = 56, gap = 20, top = 130;
    const n = entries.length;
    const cw = (W - pad * 2 - gap * (n - 1)) / n, ch = H - top - pad;
    const cv = document.createElement('canvas');
    cv.width = W; cv.height = H;
    const g = cv.getContext('2d');
    const font = (w, s) => `${w} ${s}px -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif`;
    g.fillStyle = '#F4F3EF'; g.fillRect(0, 0, W, H);
    g.fillStyle = '#111'; g.font = font(700, 40); g.textBaseline = 'alphabetic';
    g.fillText(name, pad, 84);
    entries.forEach((e, i) => {
      const x = pad + i * (cw + gap), labelH = Math.min(170, ch * 0.3);
      g.save();
      g.shadowColor = 'rgba(0,0,0,.14)'; g.shadowBlur = 18; g.shadowOffsetY = 6;
      g.fillStyle = '#FFF'; g.fillRect(x, top, cw, ch);
      g.restore();
      g.fillStyle = e.hex; g.fillRect(x, top, cw, ch - labelH);
      g.fillStyle = '#111';
      const fit = (t, w, s) => { g.font = font(w, s); while (s > 10 && g.measureText(t).width > cw - 32) g.font = font(w, --s); return s; };
      let y = top + ch - labelH + 40;
      if (e.pantone) {
        fit('PANTONE®', 800, 20); g.fillText('PANTONE®', x + 16, y); y += 34;
        fit(e.pantone, 700, 26); g.fillText((e.exact ? '' : '≈ ') + e.pantone, x + 16, y); y += 30;
        if (e.name) { g.fillStyle = '#555'; fit(e.name, 400, 20); g.fillText(e.name, x + 16, y); }
      }
      g.fillStyle = readableOn(e.rgb) === '#FFFFFF' ? 'rgba(255,255,255,.92)' : 'rgba(0,0,0,.78)';
      fit(e.hex, 600, 22);
      g.fillText(e.hex, x + 16, top + 40);
    });
    return new Promise(res => cv.toBlob(res, 'image/png'));
  }

  const FORMATS = [
    { id: 'css', name: 'CSS variables', ext: 'css' },
    { id: 'scss', name: 'SCSS', ext: 'scss' },
    { id: 'tailwind4', name: 'Tailwind v4', ext: 'css' },
    { id: 'tailwind3', name: 'Tailwind v3', ext: 'js' },
    { id: 'json', name: 'JSON', ext: 'json' },
    { id: 'hex', name: 'Hex list', ext: 'txt' },
    { id: 'gpl', name: 'GIMP / Inkscape / Krita', ext: 'gpl' },
    { id: 'ase', name: 'Adobe swatches (.ase)', ext: 'ase', binary: true, note: 'Import into Illustrator, Photoshop, InDesign, Affinity or Procreate via the Swatches panel.' },
    { id: 'png', name: 'PNG image', ext: 'png', binary: true, note: 'A Pantone-chip style image of the palette, for sharing or moodboards.' },
  ];

  async function toBlob(format, name, entries, readableOn) {
    if (format === 'ase') return ase(name, entries);
    if (format === 'png') return png(name, entries, readableOn);
    return new Blob([text[format](name, entries)], { type: 'text/plain;charset=utf-8' });
  }

  root.Exporters = { FORMATS, text, toBlob, slug };
})(window);
