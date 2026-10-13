/* Colour maths: conversions, CIEDE2000 matching, harmony generation, image palette extraction. */
(function (root) {
  'use strict';

  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  const DEG = 180 / Math.PI;
  const RAD = Math.PI / 180;

  // ---------- Parsing & formatting ----------

  function parseHex(input) {
    if (typeof input !== 'string') return null;
    let h = input.trim().replace(/^#/, '');
    if (/^[0-9a-f]{3}$/i.test(h)) h = h.split('').map(c => c + c).join('');
    return /^[0-9a-f]{6}$/i.test(h) ? '#' + h.toUpperCase() : null;
  }

  function hexToRgb(hex) {
    const n = parseInt(hex.replace('#', ''), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }

  function rgbToHex(rgb) {
    return '#' + rgb.map(v => Math.round(clamp(v, 0, 255)).toString(16).padStart(2, '0')).join('').toUpperCase();
  }

  // ---------- sRGB <-> linear ----------

  const toLinear = c => { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
  const fromLinear = c => 255 * (c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055);

  // ---------- HSL ----------

  function rgbToHsl([r, g, b]) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    const l = (max + min) / 2;
    let h = 0, s = 0;
    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
      else if (max === g) h = (b - r) / d + 2;
      else h = (r - g) / d + 4;
      h *= 60;
    }
    return [h, s * 100, l * 100];
  }

  // ---------- CIE Lab (D65) ----------

  function rgbToLab(rgb) {
    const [r, g, b] = rgb.map(toLinear);
    const x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
    const y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b);
    const z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;
    const f = t => (t > 216 / 24389 ? Math.cbrt(t) : (24389 / 27 * t + 16) / 116);
    const fx = f(x), fy = f(y), fz = f(z);
    return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  function labToLch([L, a, b]) {
    return [L, Math.hypot(a, b), (Math.atan2(b, a) * DEG + 360) % 360];
  }

  // CIEDE2000 colour difference (Sharma, Wu & Dalal 2005).
  function deltaE([L1, a1, b1], [L2, a2, b2]) {
    const C1 = Math.hypot(a1, b1), C2 = Math.hypot(a2, b2);
    const Cb7 = Math.pow((C1 + C2) / 2, 7);
    const G = 0.5 * (1 - Math.sqrt(Cb7 / (Cb7 + 6103515625)));
    const a1p = (1 + G) * a1, a2p = (1 + G) * a2;
    const C1p = Math.hypot(a1p, b1), C2p = Math.hypot(a2p, b2);
    const h1p = (b1 === 0 && a1p === 0) ? 0 : (Math.atan2(b1, a1p) * DEG + 360) % 360;
    const h2p = (b2 === 0 && a2p === 0) ? 0 : (Math.atan2(b2, a2p) * DEG + 360) % 360;
    const dLp = L2 - L1, dCp = C2p - C1p;
    const prod = C1p * C2p;
    let dhp = 0;
    if (prod !== 0) {
      dhp = h2p - h1p;
      if (dhp > 180) dhp -= 360; else if (dhp < -180) dhp += 360;
    }
    const dHp = 2 * Math.sqrt(prod) * Math.sin(dhp * RAD / 2);
    const Lbp = (L1 + L2) / 2, Cbp = (C1p + C2p) / 2;
    let hbp = h1p + h2p;
    if (prod !== 0) {
      hbp = Math.abs(h1p - h2p) > 180
        ? (h1p + h2p < 360 ? (h1p + h2p + 360) / 2 : (h1p + h2p - 360) / 2)
        : (h1p + h2p) / 2;
    }
    const T = 1 - 0.17 * Math.cos((hbp - 30) * RAD) + 0.24 * Math.cos(2 * hbp * RAD)
      + 0.32 * Math.cos((3 * hbp + 6) * RAD) - 0.20 * Math.cos((4 * hbp - 63) * RAD);
    const dTheta = 30 * Math.exp(-Math.pow((hbp - 275) / 25, 2));
    const Cbp7 = Math.pow(Cbp, 7);
    const Rc = 2 * Math.sqrt(Cbp7 / (Cbp7 + 6103515625));
    const Lm = (Lbp - 50) * (Lbp - 50);
    const Sl = 1 + 0.015 * Lm / Math.sqrt(20 + Lm);
    const Sc = 1 + 0.045 * Cbp;
    const Sh = 1 + 0.015 * Cbp * T;
    const Rt = -Math.sin(2 * dTheta * RAD) * Rc;
    const l = dLp / Sl, c = dCp / Sc, h = dHp / Sh;
    return Math.sqrt(l * l + c * c + h * h + Rt * c * h);
  }

  function matchQuality(dE) {
    if (dE < 1) return 'Exact';
    if (dE < 2.5) return 'Very close';
    if (dE < 5) return 'Close';
    if (dE < 10) return 'Similar';
    return 'Distant';
  }

  // ---------- OKLab / OKLCH (used for generation & tints) ----------

  function rgbToOklch(rgb) {
    const [r, g, b] = rgb.map(toLinear);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    const L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    const A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    const B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    return [L, Math.hypot(A, B), (Math.atan2(B, A) * DEG + 360) % 360];
  }

  function oklchToLinear(L, C, H) {
    const a = C * Math.cos(H * RAD), b = C * Math.sin(H * RAD);
    const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
    const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
    const s = Math.pow(L - 0.0894841775 * a - 1.2914855480 * b, 3);
    return [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ];
  }

  // Reduces chroma until the colour fits in sRGB, keeping lightness and hue.
  function oklchToHex(L, C, H) {
    L = clamp(L, 0, 1);
    const inGamut = c => oklchToLinear(L, c, H).every(v => v >= -0.0001 && v <= 1.0001);
    if (!inGamut(C)) {
      let lo = 0, hi = C;
      for (let i = 0; i < 20; i++) { const mid = (lo + hi) / 2; if (inGamut(mid)) lo = mid; else hi = mid; }
      C = lo;
    }
    return rgbToHex(oklchToLinear(L, C, H).map(v => fromLinear(clamp(v, 0, 1))));
  }

  // ---------- Contrast (WCAG 2) ----------

  function luminance(rgb) {
    const [r, g, b] = rgb.map(toLinear);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  function contrast(rgb1, rgb2) {
    const a = luminance(rgb1), b = luminance(rgb2);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
  }

  const readableOn = rgb => (contrast(rgb, [255, 255, 255]) >= contrast(rgb, [17, 17, 17]) ? '#FFFFFF' : '#111111');

  // Naive device-independent conversion; real print values depend on press profile.
  function rgbToCmyk([r, g, b]) {
    r /= 255; g /= 255; b /= 255;
    const k = 1 - Math.max(r, g, b);
    if (k >= 1) return [0, 0, 0, 100];
    return [(1 - r - k) / (1 - k), (1 - g - k) / (1 - k), (1 - b - k) / (1 - k), k].map(v => Math.round(v * 100));
  }

  // ---------- Colour families (for filtering) ----------

  const FAMILIES = [
    ['red', 'Reds', '#D3343B'], ['orange', 'Oranges', '#EE7A2D'], ['yellow', 'Yellows', '#F2C531'],
    ['green', 'Greens', '#3E9C55'], ['teal', 'Teals', '#1C9A9A'], ['blue', 'Blues', '#2F62C4'],
    ['purple', 'Purples', '#7A4DBA'], ['pink', 'Pinks', '#E46AA6'], ['brown', 'Browns', '#8A5A3B'],
    ['neutral', 'Neutrals', '#9C9C9C'],
  ];

  function family(hsl, lch) {
    const h = hsl[0], L = lch[0], C = lch[1];
    if (C < 8) return 'neutral';
    if (h >= 12 && h < 50 && L < 55 && C < 45) return 'brown';
    if (h < 12 || h >= 345) return L > 72 ? 'pink' : 'red';
    if (h < 40) return 'orange';
    if (h < 66) return 'yellow';
    if (h < 165) return 'green';
    if (h < 195) return 'teal';
    if (h < 252) return 'blue';
    if (h < 292) return 'purple';
    return 'pink';
  }

  // ---------- Palette generation ----------

  const HARMONIES = {
    analogous: n => Array.from({ length: n }, (_, i) => (i - (n - 1) / 2) * (n > 1 ? 70 / (n - 1) : 0)),
    monochromatic: () => [0],
    complementary: () => [0, 180],
    split: () => [0, 150, 210],
    triadic: () => [0, 120, 240],
    tetradic: () => [0, 90, 180, 270],
  };

  const MOODS = {
    any:     { L: [0.35, 0.92], C: [0.05, 0.19] },
    pastel:  { L: [0.82, 0.95], C: [0.035, 0.10] },
    vibrant: { L: [0.55, 0.82], C: [0.17, 0.32] },
    muted:   { L: [0.42, 0.82], C: [0.025, 0.075] },
    earthy:  { L: [0.30, 0.78], C: [0.04, 0.12], hue: [20, 120] },
    dark:    { L: [0.22, 0.48], C: [0.04, 0.15] },
  };

  const rand = (a, b) => a + Math.random() * (b - a);
  function shuffle(arr) {
    for (let i = arr.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [arr[i], arr[j]] = [arr[j], arr[i]]; }
    return arr;
  }

  // Returns `n` hex colours. `baseHue` (OKLCH degrees) anchors the harmony, e.g. to a locked colour.
  function generate(n, { harmony = 'auto', mood = 'any', baseHue = null } = {}) {
    if (harmony === 'auto') harmony = shuffle(Object.keys(HARMONIES))[0];
    const m = MOODS[mood] || MOODS.any;
    const base = baseHue ?? (m.hue ? rand(m.hue[0], m.hue[1]) : rand(0, 360));
    const offsets = HARMONIES[harmony](n);
    const lights = shuffle(Array.from({ length: n }, (_, i) =>
      m.L[0] + (m.L[1] - m.L[0]) * (n > 1 ? i / (n - 1) : 0.5) + rand(-0.03, 0.03)));
    const out = [];
    for (let i = 0; i < n; i++) {
      const jitter = harmony === 'monochromatic' ? rand(-6, 6) : rand(-10, 10);
      const H = (base + offsets[i % offsets.length] + jitter + 360) % 360;
      out.push(oklchToHex(lights[i], rand(m.C[0], m.C[1]), H));
    }
    return out;
  }

  function tintsAndShades(hex, steps = 9) {
    const [, C, H] = rgbToOklch(hexToRgb(hex));
    return Array.from({ length: steps }, (_, i) => oklchToHex(0.96 - i * (0.82 / (steps - 1)), C * (1 - Math.abs(i - (steps - 1) / 2) / steps), H));
  }

  // ---------- Image palette extraction (k-means++ in Lab) ----------

  function extractPalette(pixels, k = 6) {
    const pts = pixels.map(rgbToLab);
    if (!pts.length) return [];
    k = Math.min(k, pts.length);
    const d2 = (p, q) => (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2;
    const centers = [pts[Math.floor(Math.random() * pts.length)].slice()];
    while (centers.length < k) {
      const dist = pts.map(p => Math.min(...centers.map(c => d2(p, c))));
      const total = dist.reduce((a, b) => a + b, 0);
      let r = Math.random() * total, i = 0;
      while (i < dist.length - 1 && (r -= dist[i]) > 0) i++;
      centers.push(pts[i].slice());
    }
    const assign = new Int32Array(pts.length);
    for (let iter = 0; iter < 14; iter++) {
      const sums = centers.map(() => [0, 0, 0, 0]);
      pts.forEach((p, i) => {
        let best = 0, bd = Infinity;
        centers.forEach((c, j) => { const d = d2(p, c); if (d < bd) { bd = d; best = j; } });
        assign[i] = best;
        const s = sums[best]; s[0] += p[0]; s[1] += p[1]; s[2] += p[2]; s[3]++;
      });
      sums.forEach((s, j) => { if (s[3]) centers[j] = [s[0] / s[3], s[1] / s[3], s[2] / s[3]]; });
    }
    const counts = new Array(k).fill(0);
    assign.forEach(a => counts[a]++);
    // Use the real pixel closest to each centre so results are colours actually in the image.
    const reps = centers.map(() => ({ d: Infinity, i: 0 }));
    pts.forEach((p, i) => { const a = assign[i], d = d2(p, centers[a]); if (d < reps[a].d) reps[a] = { d, i }; });
    return centers
      .map((_, j) => ({ hex: rgbToHex(pixels[reps[j].i]), share: counts[j] / pts.length }))
      .filter(c => c.share > 0)
      .sort((a, b) => b.share - a.share);
  }

  root.Color = {
    clamp, parseHex, hexToRgb, rgbToHex, rgbToHsl, rgbToLab, labToLch, rgbToOklch, oklchToHex,
    deltaE, matchQuality, luminance, contrast, readableOn, rgbToCmyk,
    FAMILIES, family, HARMONIES, MOODS, generate, tintsAndShades, extractPalette,
  };
})(typeof window !== 'undefined' ? window : globalThis);
