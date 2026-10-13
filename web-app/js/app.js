/* Palette Pro: library browser, palette builder, saved palettes and colour matching. */
(() => {
  'use strict';

  const C = window.Color, X = window.Exporters, DATA = window.SWATCH_DATA;
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => Array.from(el.querySelectorAll(s));
  const esc = s => String(s ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  const plural = (n, word) => `${n.toLocaleString()} ${word}${n === 1 ? '' : 's'}`;
  const MAX_COLORS = 12;
  const DEFAULT_NAME = 'Untitled palette';

  // ---------- Icons ----------

  const ICONS = {
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    copy: '<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
    lock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    unlock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 7.75-1.4"/>',
    trash: '<path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6M10 11v6M14 11v6"/>',
    star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
    starFill: '<path fill="currentColor" d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
    grip: '<circle cx="9" cy="6" r="1"/><circle cx="15" cy="6" r="1"/><circle cx="9" cy="12" r="1"/><circle cx="15" cy="12" r="1"/><circle cx="9" cy="18" r="1"/><circle cx="15" cy="18" r="1"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 16v-5M12 8h.01"/>',
    droplet: '<path d="M12 2.7s6 6.2 6 11.1a6 6 0 0 1-12 0c0-4.9 6-11.1 6-11.1z"/>',
    pipette: '<path d="m2 22 1-1h3l9-9"/><path d="M3 21v-3l9-9"/><path d="m15 6 3.4-3.4a2.1 2.1 0 1 1 3 3L18 9l.4.4a2.1 2.1 0 1 1-3 3l-3.8-3.8a2.1 2.1 0 1 1 3-3z"/>',
    download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>',
    upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/>',
    refresh: '<path d="M21 12a9 9 0 1 1-2.6-6.4L21 8"/><path d="M21 3v5h-5"/>',
    sparkles: '<path d="m12 3 1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z"/><path d="m19 15 .8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
    undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/>',
    redo: '<path d="m15 14 5-5-5-5"/><path d="M20 9H9a5 5 0 0 0 0 10h3"/>',
    save: '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><path d="M17 21v-8H7v8M7 3v5h8"/>',
    image: '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    moon: '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
    monitor: '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/>',
  };
  const icon = (name, size = 18) =>
    `<svg class="i" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name]}</svg>`;
  const setBtn = (sel, ic, label) => { $(sel).innerHTML = icon(ic) + (label ? `<span>${label}</span>` : ''); };

  // ---------- Swatch library ----------

  const COLLS = DATA.collections;
  const COLL = Object.fromEntries(COLLS.map(c => [c.id, c]));
  const SWATCHES = DATA.colors.map(([ci, code, name, hex, note = ''], order) => {
    const coll = COLLS[ci].id;
    const rgb = C.hexToRgb(hex), lab = C.rgbToLab(rgb), lch = C.labToLch(lab), hsl = C.rgbToHsl(rgb);
    const family = C.family(hsl, lch);
    // Hue sort: 30 hue bands, light to dark inside each band, neutrals last.
    const hueKey = family === 'neutral' ? 10000 - lch[0] : Math.floor(((hsl[0] + 8) % 360) / 12) * 200 + (100 - lch[0]);
    return {
      id: `${coll}/${code}`, coll, code, name, note, hex: '#' + hex, rgb, lab, lch, family, hueKey, order,
      text: `${code} ${name} ${hex} ${note} ${COLLS[ci].name}`.toLowerCase(),
    };
  });
  const BY_ID = new Map(SWATCHES.map(s => [s.id, s]));
  COLLS.forEach(c => { c.count = SWATCHES.filter(s => s.coll === c.id).length; });

  // For pasted Pantone numbers: "185 c", "19-4052 tcx", "19-4052", "cool gray 11 c".
  const BY_CODE = new Map();
  SWATCHES.forEach(s => {
    if (s.coll === 'coty') return;
    const k = s.code.toLowerCase();
    if (!BY_CODE.has(k)) BY_CODE.set(k, s);
    if (s.coll === 'tcx') BY_CODE.set(k.replace(/ tcx$/, ''), s);
  });

  const MATCH_LIBS = [
    ['coated', 'Solid Coated'], ['uncoated', 'Solid Uncoated'], ['tcx', 'Fashion, Home + Interiors'],
    ['metallic', 'Metallics'], ['pastel', 'Pastels & Neons'], ['all', 'All collections'],
  ];
  const libCache = {};
  // Colour of the Year entries duplicate TCX colours, so "all" leaves them out.
  const libFor = key => (libCache[key] ||= SWATCHES.filter(s => (key === 'all' ? s.coll !== 'coty' : s.coll === key)));

  function nearest(hex, k = 1, libKey = state.settings.matchLib, exclude = null) {
    const lab = C.rgbToLab(C.hexToRgb(hex));
    const top = [];
    for (const s of libFor(libKey)) {
      if (exclude && exclude.has(s.id)) continue;
      const d = C.deltaE(lab, s.lab);
      if (top.length < k || d < top[top.length - 1].d) {
        let i = top.length;
        while (i > 0 && top[i - 1].d > d) i--;
        top.splice(i, 0, { s, d });
        if (top.length > k) top.pop();
      }
    }
    return top;
  }

  const nearestCache = new Map();
  function nearest1(hex) {
    const key = state.settings.matchLib + hex;
    if (!nearestCache.has(key)) nearestCache.set(key, nearest(hex, 1)[0]);
    return nearestCache.get(key);
  }

  // The exact library colour a palette entry came from, or its nearest match.
  function pantoneFor(c) {
    const sw = c.sid && BY_ID.get(c.sid);
    if (sw) return { s: sw, d: 0, exact: true };
    const m = nearest1(c.hex);
    return { ...m, exact: m.d < 0.05 };
  }

  // ---------- Storage ----------

  const store = {
    warned: false,
    get(key, fallback) {
      // Keys keep the app's original name (Swatchbook) so existing saved data still loads.
      try { const v = localStorage.getItem('swatchbook.' + key); return v == null ? fallback : JSON.parse(v); }
      catch { return fallback; }
    },
    set(key, value) {
      try { localStorage.setItem('swatchbook.' + key, JSON.stringify(value)); }
      catch {
        if (!store.warned) {
          store.warned = true;
          toast('This browser is blocking storage, so changes won’t be kept. Use “Back up all” to save a copy.');
        }
      }
    },
  };

  const cleanColors = arr => (Array.isArray(arr) ? arr : []).map(c => {
    const hex = C.parseHex(c && (c.hex || c));
    if (!hex) return null;
    const sw = c.sid && BY_ID.get(c.sid);
    return { hex, locked: !!c.locked, sid: sw && sw.hex === hex ? sw.id : null };
  }).filter(Boolean).slice(0, MAX_COLORS);

  function cleanPalette(p) {
    if (!p || typeof p !== 'object') return null;
    const colors = cleanColors(p.colors).map(({ hex, sid }) => ({ hex, sid }));
    if (!colors.length) return null;
    return {
      id: typeof p.id === 'string' ? p.id : uid(),
      name: String(p.name || DEFAULT_NAME).slice(0, 60),
      colors,
      createdAt: +p.createdAt || Date.now(),
      updatedAt: +p.updatedAt || Date.now(),
    };
  }

  const DEFAULTS = { theme: 'system', matchLib: 'coated', harmony: 'auto', mood: 'any', snap: false, exportFormat: 'css' };
  const state = {
    view: null,
    settings: { ...DEFAULTS, ...store.get('settings', {}) },
    favorites: new Set((store.get('favorites', []) || []).filter(id => BY_ID.has(id))),
    palettes: (store.get('palettes', []) || []).map(cleanPalette).filter(Boolean),
    current: null,
    lib: { q: '', coll: 'all', family: 'all', sort: 'book', ...store.get('libFilters', {}) },
    match: { hex: C.parseHex(store.get('matchHex', '')) || '#0F4C81', extracted: [] },
  };
  if (!MATCH_LIBS.some(([k]) => k === state.settings.matchLib)) state.settings.matchLib = 'coated';
  if (!['all', 'fav', ...COLLS.map(c => c.id)].includes(state.lib.coll)) state.lib.coll = 'all';
  if (!['all', ...C.FAMILIES.map(f => f[0])].includes(state.lib.family)) state.lib.family = 'all';
  state.current = loadCurrent();

  function loadCurrent() {
    const c = store.get('current', null);
    const colors = c && cleanColors(c.colors);
    if (colors && colors.length) {
      return { id: typeof c.id === 'string' ? c.id : null, name: String(c.name || DEFAULT_NAME).slice(0, 60), colors };
    }
    return { id: null, name: DEFAULT_NAME, colors: C.generate(5, { harmony: 'analogous' }).map(hex => ({ hex, locked: false, sid: null })) };
  }

  const saveSettings = () => store.set('settings', state.settings);
  const saveCurrent = () => store.set('current', state.current);
  const saveFavorites = () => store.set('favorites', [...state.favorites]);
  const saveLibFilters = () => { const { coll, family, sort } = state.lib; store.set('libFilters', { coll, family, sort }); };
  function savePalettes() { store.set('palettes', state.palettes); renderSavedCount(); }

  // ---------- Small UI helpers ----------

  let toastTimer = 0;
  function toast(msg, opts = {}) {
    const el = $('#toast');
    if (el.parentElement !== host()) host().append(el); // stay above an open modal dialog
    el.innerHTML = (opts.swatch ? `<span class="sw" style="--c:${opts.swatch}"></span>` : '') +
      `<span>${esc(msg)}</span>` + (opts.action ? `<button type="button">${esc(opts.action.label)}</button>` : '');
    if (opts.action) $('button', el).onclick = () => { el.classList.remove('show'); opts.action.fn(); };
    el.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), opts.action ? 6000 : 2400);
  }

  // Elements outside an open modal dialog are inert, so helpers attach to it when one is open.
  const host = () => document.querySelector('dialog[open]') || document.body;

  async function copyText(text, what) {
    let ok = false;
    try { await navigator.clipboard.writeText(text); ok = true; }
    catch {
      const ta = Object.assign(document.createElement('textarea'), { value: text });
      ta.style.cssText = 'position:fixed;top:0;opacity:0';
      host().append(ta);
      ta.select();
      try { ok = document.execCommand('copy'); } catch { ok = false; }
      ta.remove();
    }
    const hex = C.parseHex(text);
    toast(ok ? `Copied ${what || text}` : 'Couldn’t copy. The browser blocked clipboard access.', hex ? { swatch: hex } : {});
  }

  function downloadBlob(blob, filename) {
    const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(blob), download: filename });
    host().append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 5000);
  }

  function openColor(c) {
    if (c.sid) openDetail({ id: c.sid }); else openDetail({ hex: c.hex });
  }

  // ---------- Routing ----------

  const VIEWS = ['library', 'builder', 'saved', 'match'];
  const scrollPos = {};

  function route() {
    const h = location.hash.slice(1);
    if (!VIEWS.includes(h) && state.view) return; // in-page anchors such as the skip link
    const v = VIEWS.includes(h) ? h : 'library';
    if (v === state.view) return;
    if (state.view) scrollPos[state.view] = window.scrollY;
    state.view = v;
    document.body.dataset.view = v;
    VIEWS.forEach(x => { $('#view-' + x).hidden = x !== v; });
    $$('.tabs a').forEach(a => (a.dataset.view === v ? a.setAttribute('aria-current', 'page') : a.removeAttribute('aria-current')));
    if (v === 'library') { if (libRendered) fillLibrary(); else renderLibrary(); }
    if (v === 'builder') renderBuilder();
    if (v === 'saved') renderSaved();
    if (v === 'match') renderMatch();
    renderTray();
    window.scrollTo(0, scrollPos[v] || 0);
  }

  function go(view) {
    if (location.hash !== '#' + view) location.hash = '#' + view;
    route();
  }

  // ---------- Library ----------

  const SORTS = {
    book: (a, b) => a.order - b.order,
    hue: (a, b) => a.hueKey - b.hueKey,
    light: (a, b) => b.lch[0] - a.lch[0],
    name: (a, b) => (a.name || a.code).localeCompare(b.name || b.code, undefined, { numeric: true }),
  };
  const PAGE = 160;
  let libResults = [], libShown = 0, libDe = null, libRendered = false, libStale = false;

  function queryLibrary() {
    const { coll, family, sort } = state.lib;
    const q = state.lib.q.trim().toLowerCase().replace(/®/g, '').replace(/^pantone\s*/, '');
    let list = coll === 'fav' ? SWATCHES.filter(s => state.favorites.has(s.id))
      : coll === 'all' ? libFor('all') : SWATCHES.filter(s => s.coll === coll);
    if (family !== 'all') list = list.filter(s => s.family === family);

    const hexQ = /^#[0-9a-f]{3}$|^#?[0-9a-f]{6}$/.test(q) ? C.parseHex(q) : null;
    if (hexQ) {
      const lab = C.rgbToLab(C.hexToRgb(hexQ));
      const ranked = list.map(s => ({ s, d: C.deltaE(lab, s.lab) })).sort((a, b) => a.d - b.d).slice(0, 120);
      return { list: ranked.map(r => r.s), de: new Map(ranked.map(r => [r.s.id, r.d])), hexQ };
    }
    if (q) {
      const toks = q.split(/\s+/);
      list = list.filter(s => toks.every(t => s.text.includes(t)));
    }
    list = list.slice().sort(SORTS[sort] || SORTS.book);
    if (q) {
      const rank = s => {
        const code = s.code.toLowerCase(), name = s.name.toLowerCase();
        if (code === q || code.split(' ')[0] === q) return 0;
        if (code.startsWith(q)) return 1;
        return name.startsWith(q) ? 2 : 3;
      };
      list = list.map((s, i) => [rank(s), i, s]).sort((a, b) => a[0] - b[0] || a[1] - b[1]).map(x => x[2]);
    }
    return { list };
  }

  function renderLibrary() {
    libRendered = true;
    libStale = false;
    const { list, de, hexQ } = queryLibrary();
    libResults = list;
    libDe = de || null;
    libShown = 0;
    $('#libGrid').innerHTML = '';
    $('#libCount').innerHTML = hexQ
      ? `Closest Pantone colors to <b class="mono">${hexQ}</b>, best match first`
      : plural(list.length, 'color');
    $('#libCount').hidden = !list.length;
    $('#libEmpty').hidden = list.length > 0;
    fillLibrary();
  }

  // Renders more chips while the end of the grid is near the viewport.
  function fillLibrary() {
    if (state.view !== 'library') return;
    const grid = $('#libGrid'), sentinel = $('#libSentinel');
    for (let guard = 0; guard < 40 && libShown < libResults.length && sentinel.getBoundingClientRect().top < innerHeight + 1200; guard++) {
      const next = libResults.slice(libShown, libShown + PAGE);
      grid.insertAdjacentHTML('beforeend', next.map(chipHTML).join(''));
      libShown += next.length;
    }
  }

  function chipHTML(s) {
    const de = libDe && libDe.get(s.id);
    const sub = [s.name, s.coll === 'coty' ? s.note : ''].filter(Boolean).join(' · ') || COLL[s.coll].name;
    const badge = de != null ? `<span class="chip-de">ΔE ${de.toFixed(1)}</span>`
      : state.favorites.has(s.id) ? `<span class="chip-fav${C.readableOn(s.rgb) === '#111111' ? ' dark' : ''}">${icon('starFill', 15)}</span>` : '';
    return `<div class="chip" data-id="${esc(s.id)}" style="--c:${s.hex}">` +
      `<button class="chip-main" type="button" data-act="open" aria-label="PANTONE ${esc(s.code)}${s.name ? ', ' + esc(s.name) : ''}">` +
      `<span class="chip-color"></span><span class="chip-label"><span class="chip-brand">PANTONE<sup>®</sup></span>` +
      `<span class="chip-code">${esc(s.code)}</span><span class="chip-name">${esc(sub)}</span></span></button>` +
      `<button class="chip-add" type="button" data-act="add" title="Add to palette" aria-label="Add PANTONE ${esc(s.code)} to palette">${icon('plus', 16)}</button>` +
      badge + '</div>';
  }

  function renderCollChips() {
    const items = [['all', 'All', libFor('all').length], ...COLLS.map(c => [c.id, c.name, c.count]), ['fav', 'Favorites', state.favorites.size]];
    $('#collChips').innerHTML = items.map(([id, name, n]) =>
      `<button type="button" class="fchip" data-coll="${id}" aria-pressed="${state.lib.coll === id}">` +
      `${id === 'fav' ? icon('star', 14) : ''}${esc(name)} <span class="n">${n.toLocaleString()}</span></button>`).join('');
  }

  function renderFamilyChips() {
    $('#familyChips').innerHTML =
      `<button type="button" class="fchip" data-family="all" aria-pressed="${state.lib.family === 'all'}">All hues</button>` +
      C.FAMILIES.map(([id, name, hex]) =>
        `<button type="button" class="fchip" data-family="${id}" aria-pressed="${state.lib.family === id}"><span class="dot" style="--c:${hex}"></span>${name}</button>`).join('');
  }

  function toggleFav(id) {
    const s = BY_ID.get(id);
    if (state.favorites.has(id)) state.favorites.delete(id); else state.favorites.add(id);
    saveFavorites();
    toast(state.favorites.has(id) ? `Added PANTONE ${s.code} to favorites` : `Removed PANTONE ${s.code} from favorites`, { swatch: s.hex });
    const chip = $(`#libGrid .chip[data-id="${CSS.escape(id)}"]`);
    if (chip) chip.outerHTML = chipHTML(s);
    renderCollChips();
    if (state.lib.coll === 'fav') libStale = true;
  }

  // ---------- Detail sheet ----------

  let detailCtx = null;
  const grade = r => (r >= 7 ? 'AAA' : r >= 4.5 ? 'AA' : r >= 3 ? 'AA Large' : 'Fail');

  function openDetail(ctx) {
    detailCtx = ctx;
    const sw = ctx.id ? BY_ID.get(ctx.id) : null;
    const hex = sw ? sw.hex : ctx.hex;
    const rgb = C.hexToRgb(hex), [h, sat, l] = C.rgbToHsl(rgb), lab = C.rgbToLab(rgb);
    const fg = C.readableOn(rgb);
    const values = [
      ['HEX', hex], ['RGB', rgb.join(', ')],
      ['HSL', `${Math.round(h)}°, ${Math.round(sat)}%, ${Math.round(l)}%`],
      ['Lab', lab.map(v => v.toFixed(1)).join(', ')], ['CMYK ≈', C.rgbToCmyk(rgb).join(', ')],
    ];
    const cw = C.contrast(rgb, [255, 255, 255]), cb = C.contrast(rgb, [17, 17, 17]);
    const similar = nearest(hex, 10, sw ? 'all' : state.settings.matchLib, sw ? new Set([sw.id]) : null);
    const fav = sw && state.favorites.has(sw.id);
    const top = similar[0];

    const title = sw
      ? `<p class="eyebrow">PANTONE®</p><h2>${esc(sw.code)}</h2>` +
        (sw.name ? `<p class="d-name">${esc(sw.name)}${sw.coll === 'coty' ? ` · Color of the Year ${esc(sw.note)}` : ''}</p>` : '')
      : `<p class="eyebrow">CUSTOM COLOR</p><h2 class="mono">${hex}</h2>` +
        `<p class="d-name">Closest: PANTONE ${esc(top.s.code)}${top.s.name ? ' ' + esc(top.s.name) : ''} (ΔE ${top.d.toFixed(1)}, ${C.matchQuality(top.d).toLowerCase()})</p>`;

    $('#detailBody').innerHTML = `
      <div class="d-swatch" style="--c:${hex};--fg:${fg}">
        <span>${sw ? esc(COLL[sw.coll].name) : 'Custom color'}</span><span class="mono">${hex}</span>
      </div>
      <div class="d-main">
        <div class="d-title">${title}</div>
        <div class="d-actions">
          <button class="btn primary" type="button" data-act="add">${icon('plus')}<span>Add to palette</span></button>
          ${sw ? `<button class="btn" type="button" data-act="fav" aria-pressed="${fav}">${icon('star')}<span>${fav ? 'Favorited' : 'Favorite'}</span></button>` : ''}
          <button class="btn" type="button" data-act="match" title="Find the nearest colors in another collection">${icon('pipette')}<span>Match</span></button>
        </div>
        <dl class="d-values">${values.map(([k, v]) =>
          `<div><dt>${k}</dt><dd>${esc(v)}</dd><button class="icon-btn" type="button" data-copy="${esc(v)}" title="Copy" aria-label="Copy ${k} value">${icon('copy', 16)}</button></div>`).join('')}</dl>
        <div class="d-sec"><h3>Text contrast</h3><div class="d-contrast">
          <div style="--c:${hex};--tc:#FFFFFF"><b>Aa</b><span>white ${cw.toFixed(2)}:1 · ${grade(cw)}</span></div>
          <div style="--c:${hex};--tc:#111111"><b>Aa</b><span>black ${cb.toFixed(2)}:1 · ${grade(cb)}</span></div>
        </div></div>
        <div class="d-sec"><h3>Tints &amp; shades</h3><div class="d-scale">${C.tintsAndShades(hex).map(t =>
          `<button type="button" style="--c:${t}" data-hex="${t}" title="${t}" aria-label="Open ${t}"></button>`).join('')}</div></div>
        <div class="d-sec"><h3>${sw ? 'Similar colors' : 'Nearest Pantone colors'}</h3><div class="d-similar">${similar.map(({ s, d }) =>
          `<button type="button" class="mini" data-id="${esc(s.id)}" style="--c:${s.hex}"><i></i><span><b>${esc(s.code)}</b><em>${esc(s.name || COLL[s.coll].name)}</em><em>ΔE ${d.toFixed(1)}</em></span></button>`).join('')}</div></div>
      </div>`;
    const dlg = $('#detailDlg');
    dlg.style.setProperty('--fg', fg);
    if (!dlg.open) dlg.showModal();
    dlg.scrollTop = 0;
  }

  // ---------- Current palette & history ----------

  const history = { past: [], future: [] };
  const snapshot = () => JSON.stringify(state.current.colors);

  function commit(mutate) {
    history.past.push(snapshot());
    if (history.past.length > 200) history.past.shift();
    history.future.length = 0;
    mutate(state.current);
    paletteChanged();
  }
  function undo() {
    if (!history.past.length) return;
    history.future.push(snapshot());
    state.current.colors = JSON.parse(history.past.pop());
    paletteChanged();
  }
  function redo() {
    if (!history.future.length) return;
    history.past.push(snapshot());
    state.current.colors = JSON.parse(history.future.pop());
    paletteChanged();
  }
  function paletteChanged() {
    saveCurrent();
    if (state.view === 'builder') renderBuilder();
    renderTray();
  }

  function isDirty() {
    const cur = state.current, p = cur.id && state.palettes.find(x => x.id === cur.id);
    if (!p) return true;
    return p.name !== cur.name || p.colors.length !== cur.colors.length || p.colors.some((c, i) => c.hex !== cur.colors[i].hex);
  }

  // Swaps in a different palette; offers Undo when unsaved work would be lost.
  function replaceCurrent(next, msg) {
    const prev = structuredClone(state.current);
    const prevHistory = { past: [...history.past], future: [...history.future] };
    const lostWork = isDirty();
    state.current = next;
    history.past = [];
    history.future = [];
    paletteChanged();
    if (msg) {
      toast(msg, lostWork ? {
        action: {
          label: 'Undo', fn: () => {
            state.current = prev;
            Object.assign(history, prevHistory);
            paletteChanged();
          },
        },
      } : {});
    }
  }

  function snapColor(c, used) {
    if (!state.settings.snap || c.sid) return c;
    const m = nearest(c.hex, 1, state.settings.matchLib, used)[0];
    if (!m) return c;
    if (used) used.add(m.s.id);
    return { ...c, hex: m.s.hex, sid: m.s.id };
  }

  function addToPalette(hex, sid = null) {
    const cur = state.current;
    if (cur.colors.length >= MAX_COLORS) { toast(`A palette holds up to ${MAX_COLORS} colors. Remove one first.`); return; }
    commit(p => p.colors.push({ hex, locked: false, sid }));
    const s = sid && BY_ID.get(sid);
    toast(`Added ${s ? 'PANTONE ' + s.code : hex} to “${cur.name}”`, {
      swatch: hex,
      action: state.view === 'builder' ? null : { label: 'Open', fn: () => { $('#detailDlg').close(); go('builder'); } },
    });
    const last = $('#traySwatches button:last-child');
    if (last) last.classList.add('pop');
  }

  function generatePalette() {
    const cur = state.current, set = state.settings;
    if (!cur.colors.some(c => !c.locked)) { toast('Every color is locked. Unlock one to generate.'); return; }
    const anchor = cur.colors.find(c => c.locked);
    const baseHue = anchor ? C.rgbToOklch(C.hexToRgb(anchor.hex))[2] : null;
    const fresh = C.generate(cur.colors.length, { harmony: set.harmony, mood: set.mood, baseHue });
    commit(p => {
      const used = new Set(p.colors.filter(c => c.locked && c.sid).map(c => c.sid));
      let k = 0;
      p.colors = p.colors.map(c => (c.locked ? c : snapColor({ hex: fresh[k++], locked: false, sid: null }, used)));
    });
  }

  function addGeneratedColor() {
    const cur = state.current;
    if (cur.colors.length >= MAX_COLORS) { toast(`A palette holds up to ${MAX_COLORS} colors.`); return; }
    const last = cur.colors[cur.colors.length - 1];
    const baseHue = last ? C.rgbToOklch(C.hexToRgb(last.hex))[2] + (Math.random() * 60 - 30) : null;
    const [hex] = C.generate(1, { harmony: 'monochromatic', mood: state.settings.mood, baseHue });
    const used = new Set(cur.colors.map(c => c.sid).filter(Boolean));
    commit(p => p.colors.push(snapColor({ hex, locked: false, sid: null }, used)));
  }

  function moveColor(from, to) {
    if (to < 0 || to >= state.current.colors.length || from === to) return false;
    commit(p => { const [c] = p.colors.splice(from, 1); p.colors.splice(to, 0, c); });
    return true;
  }

  function setColor(i, hex) {
    if (hex === state.current.colors[i].hex) return;
    commit(p => { p.colors[i] = { ...p.colors[i], hex, sid: null }; });
  }

  function savePalette() {
    const cur = state.current;
    cur.name = cur.name.trim() || DEFAULT_NAME;
    const data = { name: cur.name, colors: cur.colors.map(({ hex, sid }) => ({ hex, sid })), updatedAt: Date.now() };
    let p = cur.id && state.palettes.find(x => x.id === cur.id);
    if (p) Object.assign(p, data);
    else { p = { id: uid(), createdAt: Date.now(), ...data }; cur.id = p.id; }
    state.palettes = [p, ...state.palettes.filter(x => x !== p)];
    savePalettes();
    saveCurrent();
    if (state.view === 'builder') renderBuilder();
    renderTray();
    toast(`Saved “${p.name}”`, { action: { label: 'View all', fn: () => go('saved') } });
  }

  function newPalette() {
    const used = new Set();
    const colors = C.generate(5, { harmony: state.settings.harmony, mood: state.settings.mood })
      .map(hex => snapColor({ hex, locked: false, sid: null }, used));
    replaceCurrent({ id: null, name: DEFAULT_NAME, colors }, 'Started a new palette');
    go('builder');
    $('#palName').select();
  }

  function openSaved(id) {
    const p = state.palettes.find(x => x.id === id);
    if (!p) return;
    if (state.current.id !== id || isDirty()) {
      replaceCurrent({ id: p.id, name: p.name, colors: p.colors.map(c => ({ ...c, locked: false })) }, `Opened “${p.name}”`);
    }
    go('builder');
  }

  // ---------- Builder view ----------

  function renderBuilder() {
    const cur = state.current;
    const nameEl = $('#palName');
    if (document.activeElement !== nameEl) nameEl.value = cur.name;
    sizeNameInput();
    renderSaveState();
    $('#undoBtn').disabled = !history.past.length;
    $('#redoBtn').disabled = !history.future.length;
    $('#addColorBtn').disabled = cur.colors.length >= MAX_COLORS;
    $('#harmony').value = state.settings.harmony;
    $('#mood').value = state.settings.mood;
    $('#snap').checked = state.settings.snap;
    renderColumns();
    renderContrast();
  }

  const measureCtx = document.createElement('canvas').getContext('2d');
  function sizeNameInput() {
    const el = $('#palName'), cs = getComputedStyle(el);
    measureCtx.font = `${cs.fontWeight} ${cs.fontSize} ${cs.fontFamily}`;
    el.style.width = Math.ceil(measureCtx.measureText(el.value || 'M').width + 20) + 'px';
  }

  function renderSaveState() {
    const cur = state.current, saved = !!cur.id && state.palettes.some(p => p.id === cur.id), dirty = isDirty();
    const el = $('#saveState');
    el.textContent = !saved ? 'Not saved' : dirty ? 'Unsaved changes' : 'Saved';
    el.classList.toggle('saved', saved && !dirty);
  }

  function renderColumns() {
    const cols = state.current.colors, n = cols.length;
    const el = $('#columns');
    el.classList.toggle('dense', n > 7);
    el.innerHTML = cols.map((c, i) => {
      const fg = C.readableOn(C.hexToRgb(c.hex)), m = pantoneFor(c), k = i + 1;
      return `<div class="col${c.locked ? ' locked' : ''}" data-i="${i}" style="--c:${c.hex};--fg:${fg}">
        ${c.locked ? `<span class="col-lock-badge" aria-hidden="true">${icon('lock', 16)}</span>` : ''}
        <div class="col-tools">
          <button class="icon-btn" type="button" data-act="remove" title="Remove" aria-label="Remove color ${k}"${n <= 1 ? ' disabled' : ''}>${icon('x')}</button>
          <button class="icon-btn" type="button" data-act="details" title="Details" aria-label="Details for color ${k}">${icon('info')}</button>
          <label class="icon-btn" title="Color picker">${icon('droplet')}<input type="color" data-act="picker" value="${c.hex.toLowerCase()}" aria-label="Color picker for color ${k}"></label>
          <button class="icon-btn" type="button" data-act="copy" title="Copy hex" aria-label="Copy ${c.hex}">${icon('copy')}</button>
          <button class="icon-btn handle" type="button" data-act="handle" title="Drag to reorder" aria-label="Move color ${k}. Use the arrow keys.">${icon('grip')}</button>
          <button class="icon-btn lock" type="button" data-act="lock" aria-pressed="${c.locked}" title="${c.locked ? 'Unlock' : 'Lock'}" aria-label="${c.locked ? 'Unlock' : 'Lock'} color ${k}">${icon(c.locked ? 'lock' : 'unlock')}</button>
        </div>
        <div class="col-info">
          <input class="col-hex" data-act="hex" value="${c.hex.slice(1)}" maxlength="7" spellcheck="false" autocomplete="off" aria-label="Hex value of color ${k}">
          <button class="col-pantone" type="button" data-act="pantone" title="${m.exact ? 'Exact Pantone color. Click for details.' : `Nearest Pantone, ΔE ${m.d.toFixed(1)}. Click to snap to it.`}">
            <span class="pc">${m.exact ? '' : '≈ '}PANTONE ${esc(m.s.code)}</span>
            ${m.s.name ? `<span>${esc(m.s.name)}</span>` : ''}
            ${m.exact ? '' : `<span class="de">ΔE ${m.d.toFixed(1)}</span>`}
          </button>
        </div>
      </div>`;
    }).join('');
  }

  function renderContrast() {
    const bgs = state.current.colors.map(c => c.hex);
    const fgs = [...new Set([...bgs, '#FFFFFF', '#111111'])];
    let html = '<table class="contrast-table"><thead><tr><th></th>' +
      fgs.map(f => `<th scope="col"><span class="hdr-sw" style="--c:${f}" title="Text ${f}"></span></th>`).join('') + '</tr></thead><tbody>';
    bgs.forEach(bg => {
      const brgb = C.hexToRgb(bg), meta = C.readableOn(brgb);
      html += `<tr><th scope="row"><span class="row-sw" style="--c:${bg}" title="Background ${bg}"></span></th>`;
      fgs.forEach(fg => {
        if (fg === bg) { html += '<td class="self"></td>'; return; }
        const r = C.contrast(brgb, C.hexToRgb(fg)), g = grade(r);
        html += `<td class="${g === 'Fail' ? 'fail' : ''}" style="--bgc:${bg};--fgc:${fg};--meta:${meta}" title="${fg} text on ${bg}: ${r.toFixed(2)}:1 (${g})">` +
          `<span class="aa">Aa</span><span class="meta">${r.toFixed(1)} ${g === 'AA Large' ? 'AA lg' : g}</span></td>`;
      });
      html += '</tr>';
    });
    $('#contrastGrid').innerHTML = html + '</tbody></table>';
  }

  function focusCol(i, act) {
    const el = $(`#columns .col[data-i="${i}"] [data-act="${act}"]`);
    if (el) el.focus();
  }

  // ---------- Saved view ----------

  function renderSavedCount() { $('#savedCount').textContent = state.palettes.length || ''; }

  const fmtDate = t => {
    const d = new Date(t);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: d.getFullYear() === new Date().getFullYear() ? undefined : 'numeric' });
  };

  function renderSaved() {
    $('#savedEmpty').hidden = state.palettes.length > 0;
    $('#palGrid').innerHTML = state.palettes.map(p => `
      <article class="pal-card" data-id="${esc(p.id)}">
        <button class="pal-stripes" type="button" data-act="open" aria-label="Open ${esc(p.name)} in the palette editor">${p.colors.map(c => `<span style="--c:${c.hex}" title="${c.hex}"></span>`).join('')}</button>
        <div class="pal-meta">
          <input class="pal-title" data-act="rename" value="${esc(p.name)}" maxlength="60" spellcheck="false" aria-label="Palette name">
          <p>${plural(p.colors.length, 'color')} · ${fmtDate(p.updatedAt)}${state.current.id === p.id ? ' · <span class="is-current">open now</span>' : ''}</p>
        </div>
        <div class="pal-actions">
          <button class="icon-btn" type="button" data-act="export" title="Export" aria-label="Export ${esc(p.name)}">${icon('download')}</button>
          <button class="icon-btn" type="button" data-act="duplicate" title="Duplicate" aria-label="Duplicate ${esc(p.name)}">${icon('copy')}</button>
          <button class="icon-btn" type="button" data-act="delete" title="Delete" aria-label="Delete ${esc(p.name)}">${icon('trash')}</button>
        </div>
      </article>`).join('');
  }

  // ---------- Export ----------

  let exportCtx = null, exportUrl = null;

  function entriesFor(colors) {
    return colors.map(c => {
      const m = pantoneFor(c);
      return { hex: c.hex, rgb: C.hexToRgb(c.hex), pantone: m.s.code, name: m.s.name, exact: m.exact || m.d < 0.5, deltaE: m.d };
    });
  }

  function openExport(palette) {
    exportCtx = { name: palette.name || DEFAULT_NAME, entries: entriesFor(palette.colors) };
    $('#exportTitle').textContent = `Export “${exportCtx.name}”`;
    renderExport();
    $('#exportDlg').showModal();
  }

  const currentFormat = () => X.FORMATS.find(f => f.id === state.settings.exportFormat) || X.FORMATS[0];

  function renderExport() {
    const fmt = currentFormat();
    $('#fmtTabs').innerHTML = X.FORMATS.map(f =>
      `<button type="button" class="fchip" role="tab" data-fmt="${f.id}" aria-selected="${f === fmt}" aria-pressed="${f === fmt}">${esc(f.name)}</button>`).join('');
    if (exportUrl) { URL.revokeObjectURL(exportUrl); exportUrl = null; }
    const body = $('#exportBody');
    if (fmt.id === 'png') {
      body.innerHTML = `<p class="hint">${esc(fmt.note)}</p><img alt="Preview of the exported palette image">`;
      X.toBlob('png', exportCtx.name, exportCtx.entries, C.readableOn).then(blob => {
        exportUrl = URL.createObjectURL(blob);
        const img = $('img', body);
        if (img) img.src = exportUrl;
      });
    } else if (fmt.id === 'ase') {
      body.innerHTML = `<p class="hint">${esc(fmt.note)}</p><div class="ase-list">${exportCtx.entries.map(e =>
        `<span><i style="--c:${e.hex}"></i>${e.exact ? '' : '≈ '}PANTONE ${esc(e.pantone)}</span>`).join('')}</div>`;
    } else {
      body.innerHTML = `<pre><code>${esc(X.text[fmt.id](exportCtx.name, exportCtx.entries))}</code></pre>`;
    }
    $('#exportCopy').hidden = fmt.id === 'ase';
    $('#exportCopy').innerHTML = icon('copy') + `<span>${fmt.id === 'png' ? 'Copy image' : 'Copy'}</span>`;
    $('#exportDownload').innerHTML = icon('download') + `<span>Download .${fmt.ext}</span>`;
  }

  // ---------- Import ----------

  function parseColorList(text) {
    const colors = [], missed = [];
    for (const raw of text.split(/[\n,;]+/)) {
      const line = raw.trim();
      if (!line) continue;
      const hexes = [...line.matchAll(/#([0-9a-f]{6}|[0-9a-f]{3})\b|\b([0-9a-f]{6})\b/gi)];
      if (hexes.length) { hexes.forEach(m => colors.push({ hex: C.parseHex(m[1] || m[2]), sid: null })); continue; }
      const key = line.toLowerCase().replace(/^pantone[®\s]*/, '').replace(/\s+/g, ' ').replace(/(\d)([cu])$/, '$1 $2').trim();
      const s = BY_CODE.get(key) || BY_CODE.get(key.replace(/ (tcx|tpx|tpg)$/, ''));
      if (s) colors.push({ hex: s.hex, sid: s.id }); else missed.push(line);
    }
    return { colors, missed };
  }

  function updatePasteInfo() {
    const text = $('#pasteText').value;
    if (!text.trim()) { $('#pasteInfo').textContent = ''; return; }
    const { colors, missed } = parseColorList(text);
    $('#pasteInfo').textContent = `Found ${plural(colors.length, 'color')}` +
      (colors.length > MAX_COLORS ? ` (the first ${MAX_COLORS} will be used)` : '') +
      (missed.length ? `. Couldn’t read: ${missed.slice(0, 4).join(', ')}${missed.length > 4 ? '…' : ''}` : '');
  }

  // ---------- Match view ----------

  function setMatchHex(hex) {
    hex = C.parseHex(hex);
    if (!hex) return;
    state.match.hex = hex;
    store.set('matchHex', hex);
    if (state.view === 'match') renderMatch();
  }

  function renderMatch() {
    const hex = state.match.hex;
    $('#matchSwatch').style.setProperty('--c', hex);
    if (document.activeElement !== $('#matchHex')) $('#matchHex').value = hex;
    $('#matchPicker').value = hex.toLowerCase();
    $('#matchList').innerHTML = nearest(hex, 12).map(({ s, d }) => {
      const q = C.matchQuality(d);
      return `<li class="match-row" data-id="${esc(s.id)}">
        <button class="match-sw" type="button" data-act="open" style="--c:${s.hex}" aria-label="Details for PANTONE ${esc(s.code)}"></button>
        <button class="match-txt" type="button" data-act="open"><strong>PANTONE ${esc(s.code)}</strong><span>${esc([s.name, COLL[s.coll].name].filter(Boolean).join(' · '))} · ${s.hex}</span></button>
        <span class="de-pill">ΔE ${d.toFixed(2)}<small class="q-${q.split(' ')[0]}">${q}</small></span>
        <button class="icon-btn add-btn" type="button" data-act="add" title="Add to palette" aria-label="Add PANTONE ${esc(s.code)} to palette">${icon('plus')}</button>
      </li>`;
    }).join('');
    renderExtract();
  }

  let imgBitmap = null;

  async function loadImageFile(file) {
    if (!file || !file.type.startsWith('image/')) { toast('Please choose an image file.'); return; }
    try {
      // ImageBitmaps from local files never taint the canvas, even when the page runs from file://.
      imgBitmap = await createImageBitmap(file);
    } catch {
      toast('Couldn’t read that image.');
      return;
    }
    const cv = $('#imgCanvas'), scale = Math.min(1, 1400 / Math.max(imgBitmap.width, imgBitmap.height));
    cv.width = Math.round(imgBitmap.width * scale);
    cv.height = Math.round(imgBitmap.height * scale);
    cv.getContext('2d').drawImage(imgBitmap, 0, 0, cv.width, cv.height);
    $('#imgWrap').hidden = false;
    $('#extractBar').hidden = false;
    $('#dropzone').classList.add('compact');
    extractColors();
  }

  function extractColors() {
    if (!imgBitmap) return;
    const s = Math.min(1, 120 / Math.max(imgBitmap.width, imgBitmap.height));
    const w = Math.max(1, Math.round(imgBitmap.width * s)), h = Math.max(1, Math.round(imgBitmap.height * s));
    const cv = Object.assign(document.createElement('canvas'), { width: w, height: h });
    const g = cv.getContext('2d', { willReadFrequently: true });
    g.drawImage(imgBitmap, 0, 0, w, h);
    const d = g.getImageData(0, 0, w, h).data, px = [];
    for (let i = 0; i < d.length; i += 4) if (d[i + 3] >= 128) px.push([d[i], d[i + 1], d[i + 2]]);
    state.match.extracted = C.extractPalette(px, +$('#kSelect').value);
    renderExtract();
  }

  function renderExtract() {
    const ex = state.match.extracted, el = $('#extract');
    if (!ex.length) { el.innerHTML = ''; return; }
    el.innerHTML =
      `<div class="extract-strip">${ex.map(c =>
        `<button type="button" style="--c:${c.hex};--w:${Math.max(c.share, 0.04).toFixed(3)}" data-hex="${c.hex}" title="${c.hex} · ${Math.round(c.share * 100)}%" aria-label="Match ${c.hex}"></button>`).join('')}</div>` +
      `<div class="extract-list">${ex.map(c => {
        const m = nearest1(c.hex);
        return `<button type="button" class="extract-item" data-hex="${c.hex}"><i style="--c:${c.hex}"></i><span><b>${c.hex}</b>` +
          `<span>≈ ${esc(m.s.code)}${m.s.name ? ' ' + esc(m.s.name) : ''}</span><span>${Math.round(c.share * 100)}% of image</span></span></button>`;
      }).join('')}</div>`;
  }

  function paletteFromImage(snapIt) {
    const ex = state.match.extracted.slice(0, MAX_COLORS);
    if (!ex.length) return;
    const used = new Set();
    const colors = ex.map(c => {
      if (!snapIt) return { hex: c.hex, locked: false, sid: null };
      const m = nearest(c.hex, 1, state.settings.matchLib, used)[0];
      used.add(m.s.id);
      return { hex: m.s.hex, locked: false, sid: m.s.id };
    });
    replaceCurrent({ id: null, name: 'From image', colors }, 'Made a palette from your image');
    go('builder');
  }

  // ---------- Tray ----------

  function renderTray() {
    const cur = state.current;
    $('#traySwatches').innerHTML = cur.colors.map((c, i) =>
      `<button type="button" style="--c:${c.hex}" data-i="${i}" title="${c.hex}" aria-label="Color ${i + 1}: ${c.hex}"></button>`).join('');
    $('#trayName').textContent = cur.name || DEFAULT_NAME;
    const saved = cur.id && state.palettes.some(p => p.id === cur.id);
    $('#trayCount').textContent = plural(cur.colors.length, 'color') + (saved && isDirty() ? ' · unsaved changes' : !saved ? ' · not saved' : '');
  }

  // ---------- Theme ----------

  const THEMES = { system: ['monitor', 'Theme: match system'], light: ['sun', 'Theme: light'], dark: ['moon', 'Theme: dark'] };
  function applyTheme() {
    const t = THEMES[state.settings.theme] ? state.settings.theme : 'system';
    if (t === 'system') delete document.documentElement.dataset.theme;
    else document.documentElement.dataset.theme = t;
    const [ic, label] = THEMES[t];
    const btn = $('#themeBtn');
    btn.innerHTML = icon(ic);
    btn.title = label + ' (click to change)';
    btn.setAttribute('aria-label', label);
  }

  // ---------- Events ----------

  function bindEvents() {
    window.addEventListener('hashchange', route);

    $('#themeBtn').addEventListener('click', () => {
      const order = ['system', 'light', 'dark'];
      state.settings.theme = order[(order.indexOf(state.settings.theme) + 1) % order.length];
      saveSettings();
      applyTheme();
      toast(THEMES[state.settings.theme][1]);
    });

    // Library
    let searchTimer = 0;
    $('#libSearch').value = state.lib.q;
    $('#libSearch').addEventListener('input', e => {
      clearTimeout(searchTimer);
      searchTimer = setTimeout(() => {
        state.lib.q = e.target.value;
        renderLibrary();
        if (window.scrollY > 300) window.scrollTo(0, 0);
      }, 120);
    });
    $('#libSort').addEventListener('change', e => { state.lib.sort = e.target.value; saveLibFilters(); renderLibrary(); });
    $('#collChips').addEventListener('click', e => {
      const b = e.target.closest('[data-coll]');
      if (!b) return;
      state.lib.coll = b.dataset.coll;
      saveLibFilters();
      renderCollChips();
      renderLibrary();
    });
    $('#familyChips').addEventListener('click', e => {
      const b = e.target.closest('[data-family]');
      if (!b) return;
      state.lib.family = b.dataset.family;
      saveLibFilters();
      renderFamilyChips();
      renderLibrary();
    });
    $('#libClear').addEventListener('click', () => {
      Object.assign(state.lib, { q: '', coll: 'all', family: 'all' });
      $('#libSearch').value = '';
      saveLibFilters();
      renderCollChips();
      renderFamilyChips();
      renderLibrary();
    });
    $('#libGrid').addEventListener('click', e => {
      const b = e.target.closest('[data-act]');
      if (!b) return;
      const s = BY_ID.get(b.closest('.chip').dataset.id);
      if (b.dataset.act === 'add') addToPalette(s.hex, s.id); else openDetail({ id: s.id });
    });
    new IntersectionObserver(es => { if (es.some(x => x.isIntersecting)) fillLibrary(); }, { rootMargin: '1200px 0px' })
      .observe($('#libSentinel'));
    window.addEventListener('scroll', () => $('.lib-controls').classList.toggle('stuck', window.scrollY > 4), { passive: true });

    // Dialogs: close buttons and backdrop clicks
    $$('dialog').forEach(d => d.addEventListener('click', e => {
      if (e.target === d || e.target.closest('[data-close]')) d.close();
    }));

    $('#detailDlg').addEventListener('click', e => {
      const t = e.target.closest('button');
      if (!t || t.dataset.close != null) return;
      if (t.dataset.copy) { copyText(t.dataset.copy); return; }
      if (t.dataset.hex) { openDetail({ hex: t.dataset.hex }); return; }
      if (t.dataset.id) { openDetail({ id: t.dataset.id }); return; }
      const sw = detailCtx.id && BY_ID.get(detailCtx.id), hex = sw ? sw.hex : detailCtx.hex;
      if (t.dataset.act === 'add') addToPalette(hex, sw ? sw.id : null);
      if (t.dataset.act === 'fav') { toggleFav(sw.id); openDetail(detailCtx); }
      if (t.dataset.act === 'match') { $('#detailDlg').close(); setMatchHex(hex); go('match'); }
    });
    $('#detailDlg').addEventListener('close', () => { if (libStale && state.view === 'library') renderLibrary(); });

    // Builder header
    const nameEl = $('#palName');
    nameEl.addEventListener('input', () => { state.current.name = nameEl.value.slice(0, 60); sizeNameInput(); saveCurrent(); renderSaveState(); renderTray(); });
    nameEl.addEventListener('change', () => {
      if (!nameEl.value.trim()) { state.current.name = DEFAULT_NAME; nameEl.value = DEFAULT_NAME; sizeNameInput(); saveCurrent(); renderTray(); }
    });
    nameEl.addEventListener('keydown', e => { if (e.key === 'Enter') nameEl.blur(); });
    $('#undoBtn').addEventListener('click', undo);
    $('#redoBtn').addEventListener('click', redo);
    $('#newBtn').addEventListener('click', newPalette);
    $('#saveBtn').addEventListener('click', savePalette);
    $('#exportBtn').addEventListener('click', () => openExport(state.current));
    $('#genBtn').addEventListener('click', generatePalette);
    $('#addColorBtn').addEventListener('click', addGeneratedColor);
    $('#harmony').addEventListener('change', e => { state.settings.harmony = e.target.value; saveSettings(); generatePalette(); });
    $('#mood').addEventListener('change', e => { state.settings.mood = e.target.value; saveSettings(); generatePalette(); });
    $('#snap').addEventListener('change', e => {
      state.settings.snap = e.target.checked;
      saveSettings();
      if (state.settings.snap && state.current.colors.some(c => !c.locked && !c.sid)) {
        commit(p => {
          const used = new Set(p.colors.map(c => c.sid).filter(Boolean));
          p.colors = p.colors.map(c => (c.locked ? c : snapColor(c, used)));
        });
        toast('Snapped your colors to the nearest Pantone', { action: { label: 'Undo', fn: undo } });
      }
    });
    $$('[data-match-lib]').forEach(sel => sel.addEventListener('change', e => {
      state.settings.matchLib = e.target.value;
      saveSettings();
      $$('[data-match-lib]').forEach(s => { s.value = e.target.value; });
      if (state.view === 'builder') renderBuilder();
      if (state.view === 'match') renderMatch();
    }));

    // Builder columns
    const colsEl = $('#columns');
    colsEl.addEventListener('click', e => {
      const t = e.target.closest('[data-act]');
      if (!t) return;
      const i = +t.closest('.col').dataset.i, c = state.current.colors[i];
      switch (t.dataset.act) {
        case 'remove':
          if (state.current.colors.length > 1) commit(p => p.colors.splice(i, 1));
          break;
        case 'lock':
          c.locked = !c.locked;
          saveCurrent();
          renderColumns();
          focusCol(i, 'lock');
          break;
        case 'copy': copyText(c.hex); break;
        case 'details': openColor(c); break;
        case 'pantone': {
          const m = pantoneFor(c);
          if (m.exact) { openDetail({ id: m.s.id }); break; }
          commit(p => { p.colors[i] = { ...c, hex: m.s.hex, sid: m.s.id }; });
          toast(`Snapped to PANTONE ${m.s.code}`, { swatch: m.s.hex, action: { label: 'Undo', fn: undo } });
          break;
        }
      }
    });
    colsEl.addEventListener('input', e => {
      if (e.target.dataset.act !== 'picker') return;
      const col = e.target.closest('.col'), hex = C.parseHex(e.target.value);
      col.style.setProperty('--c', hex);
      col.style.setProperty('--fg', C.readableOn(C.hexToRgb(hex)));
      $('.col-hex', col).value = hex.slice(1);
    });
    colsEl.addEventListener('change', e => {
      const t = e.target, col = t.closest('.col');
      if (!col) return;
      const i = +col.dataset.i, hex = C.parseHex(t.value);
      if (t.dataset.act === 'hex' && !hex) {
        t.value = state.current.colors[i].hex.slice(1);
        toast('That isn’t a valid hex color. Try something like F6EB61.');
        return;
      }
      if ((t.dataset.act === 'hex' || t.dataset.act === 'picker') && hex) setColor(i, hex);
    });
    colsEl.addEventListener('keydown', e => {
      const t = e.target;
      if (t.dataset.act === 'hex') {
        if (e.key === 'Enter') t.blur();
        if (e.key === 'Escape') { t.value = state.current.colors[+t.closest('.col').dataset.i].hex.slice(1); t.blur(); }
      }
      if (t.dataset.act === 'handle') {
        const dir = { ArrowLeft: -1, ArrowUp: -1, ArrowRight: 1, ArrowDown: 1 }[e.key];
        if (!dir) return;
        e.preventDefault();
        const i = +t.closest('.col').dataset.i;
        if (moveColor(i, i + dir)) focusCol(i + dir, 'handle');
      }
    });

    // Drag to reorder (only from the handle, so text in the hex field stays selectable)
    let dragFrom = null;
    const clearDrag = () => $$('.col', colsEl).forEach(c => { c.draggable = false; c.classList.remove('dragging', 'drop-before', 'drop-after'); });
    colsEl.addEventListener('pointerdown', e => {
      const h = e.target.closest('[data-act="handle"]');
      if (h) h.closest('.col').draggable = true;
    });
    colsEl.addEventListener('pointerup', () => { if (dragFrom == null) clearDrag(); });
    colsEl.addEventListener('dragstart', e => {
      const col = e.target.closest && e.target.closest('.col');
      if (!col || !col.draggable) { e.preventDefault(); return; }
      dragFrom = +col.dataset.i;
      col.classList.add('dragging');
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', state.current.colors[dragFrom].hex);
    });
    colsEl.addEventListener('dragover', e => {
      if (dragFrom == null) return;
      e.preventDefault();
      const col = e.target.closest('.col');
      $$('.col', colsEl).forEach(c => c.classList.remove('drop-before', 'drop-after'));
      if (!col) return;
      const r = col.getBoundingClientRect(), vertical = getComputedStyle(colsEl).flexDirection === 'column';
      const after = vertical ? e.clientY > r.top + r.height / 2 : e.clientX > r.left + r.width / 2;
      col.classList.add(after ? 'drop-after' : 'drop-before');
    });
    colsEl.addEventListener('drop', e => {
      e.preventDefault();
      const col = $('.drop-before, .drop-after', colsEl);
      if (dragFrom == null || !col) return;
      let to = +col.dataset.i + (col.classList.contains('drop-after') ? 1 : 0);
      if (to > dragFrom) to--;
      const from = dragFrom;
      dragFrom = null;
      clearDrag();
      moveColor(from, to);
    });
    colsEl.addEventListener('dragend', () => { dragFrom = null; clearDrag(); });

    // Tray
    $('#traySwatches').addEventListener('click', e => {
      const b = e.target.closest('button');
      if (b) openColor(state.current.colors[+b.dataset.i]);
    });

    // Saved palettes
    $('#newPalBtn').addEventListener('click', newPalette);
    $('#palGrid').addEventListener('click', e => {
      const t = e.target.closest('[data-act]');
      if (!t || t.dataset.act === 'rename') return;
      const id = t.closest('.pal-card').dataset.id, idx = state.palettes.findIndex(p => p.id === id), p = state.palettes[idx];
      if (!p) return;
      if (t.dataset.act === 'open') openSaved(id);
      if (t.dataset.act === 'export') openExport(p);
      if (t.dataset.act === 'duplicate') {
        const copy = { ...structuredClone(p), id: uid(), name: (p.name + ' copy').slice(0, 60), createdAt: Date.now(), updatedAt: Date.now() };
        state.palettes.splice(idx + 1, 0, copy);
        savePalettes();
        renderSaved();
        toast(`Duplicated “${p.name}”`);
      }
      if (t.dataset.act === 'delete') {
        state.palettes.splice(idx, 1);
        savePalettes();
        renderSaved();
        renderTray();
        toast(`Deleted “${p.name}”`, {
          action: { label: 'Undo', fn: () => { state.palettes.splice(idx, 0, p); savePalettes(); renderSaved(); renderTray(); } },
        });
      }
    });
    $('#palGrid').addEventListener('change', e => {
      if (e.target.dataset.act !== 'rename') return;
      const p = state.palettes.find(x => x.id === e.target.closest('.pal-card').dataset.id);
      if (!p) return;
      const name = e.target.value.trim().slice(0, 60) || DEFAULT_NAME;
      e.target.value = name;
      if (state.current.id === p.id && !isDirty()) { state.current.name = name; saveCurrent(); }
      p.name = name;
      p.updatedAt = Date.now();
      savePalettes();
      renderTray();
    });
    $('#palGrid').addEventListener('keydown', e => { if (e.key === 'Enter' && e.target.dataset.act === 'rename') e.target.blur(); });
    $('#backupBtn').addEventListener('click', () => {
      const data = { app: 'Palette Pro', version: 1, exportedAt: new Date().toISOString(), palettes: state.palettes, favorites: [...state.favorites] };
      downloadBlob(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }), `palette-pro-backup-${new Date().toISOString().slice(0, 10)}.json`);
      toast(`Backed up ${plural(state.palettes.length, 'palette')} and ${plural(state.favorites.size, 'favorite')}`);
    });

    // Export dialog
    $('#fmtTabs').addEventListener('click', e => {
      const b = e.target.closest('[data-fmt]');
      if (!b) return;
      state.settings.exportFormat = b.dataset.fmt;
      saveSettings();
      renderExport();
    });
    $('#exportCopy').addEventListener('click', async () => {
      const fmt = currentFormat();
      if (fmt.id === 'png') {
        try {
          const blob = await X.toBlob('png', exportCtx.name, exportCtx.entries, C.readableOn);
          await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
          toast('Copied the image');
        } catch { toast('This browser can’t copy images. Use Download instead.'); }
        return;
      }
      copyText(X.text[fmt.id](exportCtx.name, exportCtx.entries), fmt.name);
    });
    $('#exportDownload').addEventListener('click', async () => {
      const fmt = currentFormat(), file = `${X.slug(exportCtx.name)}.${fmt.ext}`;
      downloadBlob(await X.toBlob(fmt.id, exportCtx.name, exportCtx.entries, C.readableOn), file);
      toast(`Downloaded ${file}`);
    });
    $('#exportDlg').addEventListener('close', () => { if (exportUrl) { URL.revokeObjectURL(exportUrl); exportUrl = null; } });

    // Import dialog
    $('#importBtn').addEventListener('click', () => { updatePasteInfo(); $('#importDlg').showModal(); });
    $('#pasteText').addEventListener('input', updatePasteInfo);
    $('#pasteCreate').addEventListener('click', () => {
      const { colors } = parseColorList($('#pasteText').value);
      if (!colors.length) {
        $('#pasteInfo').textContent = 'No colors found. Use hex codes like #F6EB61 or Pantone numbers like 185 C.';
        return;
      }
      const name = $('#pasteName').value.trim() || 'Imported palette';
      const p = { id: uid(), name, colors: colors.slice(0, MAX_COLORS), createdAt: Date.now(), updatedAt: Date.now() };
      state.palettes.unshift(p);
      savePalettes();
      $('#importDlg').close();
      $('#pasteText').value = '';
      $('#pasteName').value = '';
      renderSaved();
      toast(`Created “${name}” with ${plural(p.colors.length, 'color')}`, { action: { label: 'Open', fn: () => openSaved(p.id) } });
    });
    $('#backupFile').addEventListener('change', async e => {
      const file = e.target.files[0];
      e.target.value = '';
      if (!file) return;
      let data;
      try { data = JSON.parse(await file.text()); } catch { toast('That file isn’t valid JSON.'); return; }
      const incoming = Array.isArray(data && data.palettes) ? data.palettes
        : Array.isArray(data && data.colors) ? [{ name: data.name, colors: data.colors }] : [];
      const have = new Set(state.palettes.map(p => p.id));
      const added = incoming.map(cleanPalette).filter(p => p && !have.has(p.id));
      state.palettes = [...added, ...state.palettes];
      savePalettes();
      (Array.isArray(data && data.favorites) ? data.favorites : []).forEach(id => { if (BY_ID.has(id)) state.favorites.add(id); });
      saveFavorites();
      renderCollChips();
      $('#importDlg').close();
      renderSaved();
      toast(added.length ? `Imported ${plural(added.length, 'palette')}` : (incoming.length ? 'You already have every palette in that file.' : 'No palettes found in that file.'));
    });

    // Match view
    $('#matchHex').addEventListener('input', e => { const hex = C.parseHex(e.target.value); if (hex) setMatchHex(hex); });
    $('#matchHex').addEventListener('blur', e => { e.target.value = state.match.hex; });
    $('#matchPicker').addEventListener('input', e => setMatchHex(e.target.value));
    if ('EyeDropper' in window) {
      $('#eyeBtn').hidden = false;
      $('#eyeBtn').addEventListener('click', async () => {
        try {
          const { sRGBHex } = await new window.EyeDropper().open();
          const nums = /^rgba?\(/.test(sRGBHex) ? sRGBHex.match(/\d+/g).slice(0, 3).map(Number) : null;
          setMatchHex(nums ? C.rgbToHex(nums) : sRGBHex);
        } catch { /* cancelled */ }
      });
    }
    $('#matchList').addEventListener('click', e => {
      const t = e.target.closest('[data-act]');
      if (!t) return;
      const s = BY_ID.get(t.closest('.match-row').dataset.id);
      if (t.dataset.act === 'add') addToPalette(s.hex, s.id); else openDetail({ id: s.id });
    });
    $('#extract').addEventListener('click', e => {
      const b = e.target.closest('[data-hex]');
      if (!b) return;
      setMatchHex(b.dataset.hex);
      $('#matchTitle').scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
    $('#imgInput').addEventListener('change', e => { loadImageFile(e.target.files[0]); e.target.value = ''; });
    const dz = $('#dropzone');
    dz.addEventListener('dragover', e => { e.preventDefault(); dz.classList.add('over'); });
    dz.addEventListener('dragleave', () => dz.classList.remove('over'));
    dz.addEventListener('drop', e => { e.preventDefault(); dz.classList.remove('over'); loadImageFile(e.dataTransfer.files[0]); });
    // Dropped files anywhere else would otherwise make the browser navigate away.
    window.addEventListener('dragover', e => { if (e.dataTransfer && [...e.dataTransfer.types].includes('Files')) e.preventDefault(); });
    window.addEventListener('drop', e => {
      if (!e.dataTransfer || !e.dataTransfer.files.length) return;
      e.preventDefault();
      if (state.view === 'match') loadImageFile(e.dataTransfer.files[0]);
    });
    document.addEventListener('paste', e => {
      if (state.view !== 'match' || $('dialog[open]')) return;
      const f = [...((e.clipboardData && e.clipboardData.files) || [])].find(x => x.type.startsWith('image/'));
      if (f) { e.preventDefault(); loadImageFile(f); }
    });
    $('#imgCanvas').addEventListener('click', e => {
      const cv = e.currentTarget, r = cv.getBoundingClientRect();
      const x = Math.min(cv.width - 1, Math.floor((e.clientX - r.left) * cv.width / r.width));
      const y = Math.min(cv.height - 1, Math.floor((e.clientY - r.top) * cv.height / r.height));
      const [R, G, B] = cv.getContext('2d').getImageData(x, y, 1, 1).data;
      const hex = C.rgbToHex([R, G, B]);
      setMatchHex(hex);
      toast(`Sampled ${hex}`, { swatch: hex });
      if (window.innerWidth <= 1000) $('#matchTitle').scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
    $('#kSelect').addEventListener('change', extractColors);
    $('#reextractBtn').addEventListener('click', extractColors);
    $('#useRawBtn').addEventListener('click', () => paletteFromImage(false));
    $('#usePantoneBtn').addEventListener('click', () => paletteFromImage(true));

    // Keyboard shortcuts
    document.addEventListener('keydown', e => {
      if ($('dialog[open]')) return;
      const t = e.target;
      const typing = t.closest && t.closest('input:not([type="checkbox"]):not([type="color"]):not([type="file"]), textarea, select, [contenteditable="true"]');
      const mod = e.metaKey || e.ctrlKey, k = e.key.toLowerCase();
      if (e.key === '/' && !typing && !mod) {
        e.preventDefault();
        go('library');
        $('#libSearch').focus();
        return;
      }
      if (state.view !== 'builder') return;
      if (mod && k === 's') { e.preventDefault(); savePalette(); return; }
      if (typing || t.type === 'checkbox') return;
      if (e.code === 'Space' && !mod) { e.preventDefault(); generatePalette(); }
      else if (mod && k === 'z') { e.preventDefault(); if (e.shiftKey) redo(); else undo(); }
      else if (mod && k === 'y') { e.preventDefault(); redo(); }
    });

    // Keep tabs in sync if the app is open twice.
    window.addEventListener('storage', e => {
      if (e.key === 'swatchbook.palettes') {
        state.palettes = (store.get('palettes', []) || []).map(cleanPalette).filter(Boolean);
        renderSavedCount();
        if (state.view === 'saved') renderSaved();
        renderTray();
      }
    });
  }

  // ---------- Init ----------

  function init() {
    $$('[data-icon]').forEach(el => { el.innerHTML = icon(el.dataset.icon); });
    $$('dialog [data-close]').forEach(b => { b.innerHTML = icon('x'); });
    setBtn('#undoBtn', 'undo');
    setBtn('#redoBtn', 'redo');
    setBtn('#newBtn', 'plus', 'New');
    setBtn('#exportBtn', 'download', 'Export');
    setBtn('#saveBtn', 'save', 'Save');
    $('#genBtn').innerHTML = `${icon('sparkles')}<span>Generate</span><kbd class="hide-sm">Space</kbd>`;
    setBtn('#addColorBtn', 'plus', 'Add color');
    setBtn('#importBtn', 'upload', 'Import');
    setBtn('#backupBtn', 'download', 'Back up all');
    setBtn('#newPalBtn', 'plus', 'New palette');
    setBtn('#eyeBtn', 'pipette', 'Pick from screen');
    setBtn('#reextractBtn', 'refresh', 'Re-extract');
    $$('[data-match-lib]').forEach(sel => {
      sel.innerHTML = MATCH_LIBS.map(([k, n]) => `<option value="${k}">${n}</option>`).join('');
      sel.value = state.settings.matchLib;
    });
    $('#libSort').value = state.lib.sort;
    applyTheme();
    renderCollChips();
    renderFamilyChips();
    renderSavedCount();
    bindEvents();
    route();
  }

  init();
})();
