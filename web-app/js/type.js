/* Palette Pro: Fonts, Pairing, Type Scale and Fusion. Same catalogue and rules as the Mac app.
   The font list (js/fonts-data.js) loads the first time one of these sections opens, and each font
   loads from its official CDN (Fontsource on jsDelivr, or Fontshare) when it scrolls into view. */
(() => {
  'use strict';

  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => Array.from(el.querySelectorAll(s));
  const pp = () => window.PP;
  const esc = s => pp().esc(s);
  const icon = (n, s) => pp().icon(n, s);

  const CATS = { sans: 'Sans serif', serif: 'Serif', slab: 'Slab serif', display: 'Display', script: 'Script', mono: 'Monospace' };
  const GENERIC = { sans: 'sans-serif', serif: 'serif', slab: 'serif', display: 'sans-serif', script: 'cursive', mono: 'monospace' };
  const SOURCES = { google: 'Google Fonts', fontshare: 'Fontshare', open: 'Open source', local: 'On this computer' };
  const FILTERS = [['picks', 'Designer picks', 'sparkles'], ['all', 'All fonts'], ['google', 'Google Fonts'], ['fontshare', 'Fontshare'],
    ['open', 'Open source'], ['local', 'On this computer', 'monitor'], ['fav', 'Favorites', 'star']];
  const WEIGHT_NAMES = { 100: 'Thin', 200: 'Extra Light', 300: 'Light', 400: 'Regular', 500: 'Medium', 600: 'Semibold', 700: 'Bold', 800: 'Extra Bold', 900: 'Black' };
  const DEFAULT_SAMPLE = 'The quick brown fox jumps over the lazy dog';
  const BODY_SAMPLE = 'Good typography is almost invisible. It guides the eye, sets the tone and makes reading effortless, whether it’s a long article, a product page or a single label on a box.';

  // ---------- Catalogue ----------

  let FONTS = [], LOCAL = null;
  const BY_ID = new Map(), BY_NAME = new Map();
  let catalog = null;

  function loadCatalog() {
    if (catalog) return catalog;
    catalog = new Promise((resolve, reject) => {
      if (window.FONT_DATA) return resolve();
      const s = Object.assign(document.createElement('script'), { src: 'js/fonts-data.js?v=1.3', async: true });
      s.onload = resolve;
      s.onerror = () => { catalog = null; reject(new Error('Couldn’t load the font list.')); };
      document.head.append(s);
    }).then(() => {
      FONTS = window.FONT_DATA.map(([id, family, cat, src, weights, italic, variable, license, rank, designers, year, subset, slug, files, pick]) => ({
        id, family, cat, src, weights, italic: !!italic, variable: !!variable, license, rank, designers, year, subset, slug, files, pick: !!pick,
        text: `${family} ${designers} ${CATS[cat]} ${SOURCES[src]}`.toLowerCase(),
      }));
      FONTS.forEach(f => { BY_ID.set(f.id, f); BY_NAME.set(f.family.toLowerCase(), f); });
      $('#fontNames').innerHTML = FONTS.map(f => `<option value="${esc(f.family)}">`).join('');
    });
    return catalog;
  }

  const byId = id => BY_ID.get(id);
  const named = name => BY_NAME.get(String(name || '').trim().toLowerCase());
  const nearest = (f, w) => f.weights.reduce((a, b) => (Math.abs(b - w) < Math.abs(a - w) || (Math.abs(b - w) === Math.abs(a - w) && b > a) ? b : a), f.weights[0] || 400);
  const regular = f => nearest(f, 400);
  const headingW = f => (f.weights.includes(700) ? 700 : f.weights.includes(600) ? 600 : Math.max(...f.weights.filter(w => w <= 800), regular(f)));
  const styleCount = f => f.weights.length * (f.italic ? 2 : 1);
  const stack = f => `'${f.family}', ${GENERIC[f.cat]}`;

  /** Fonts on this computer (Chrome and Edge only, after the visitor allows it). */
  async function loadLocal() {
    if (LOCAL) return LOCAL;
    const list = await window.queryLocalFonts();
    const fams = new Map();
    for (const f of list) {
      const st = f.style.toLowerCase();
      const w = /thin|hairline/.test(st) ? 100 : /extra ?light|ultra ?light/.test(st) ? 200 : /light/.test(st) ? 300
        : /medium/.test(st) ? 500 : /semi ?bold|demi/.test(st) ? 600 : /extra ?bold|ultra ?bold/.test(st) ? 800
        : /black|heavy/.test(st) ? 900 : /bold/.test(st) ? 700 : 400;
      const fam = fams.get(f.family) || { weights: new Set(), italic: false };
      fam.weights.add(w);
      if (/italic|oblique/.test(st)) fam.italic = true;
      fams.set(f.family, fam);
    }
    LOCAL = [...fams].filter(([name]) => !name.startsWith('.') && !BY_NAME.has(name.toLowerCase())).map(([family, v]) => {
      const n = family.toLowerCase();
      const cat = /mono|courier|code/.test(n) ? 'mono' : /serif/.test(n) && !/sans/.test(n) ? 'serif' : /script|hand/.test(n) ? 'script' : 'sans';
      const f = { id: 'local-' + n.replace(/\s+/g, '-'), family, cat, src: 'local', weights: [...v.weights].sort((a, b) => a - b), italic: v.italic,
        variable: false, license: '', rank: 3000, designers: '', year: 0, subset: '', slug: '', files: {}, pick: false,
        text: `${family} ${CATS[cat]} on this computer`.toLowerCase() };
      BY_ID.set(f.id, f);
      return f;
    }).sort((a, b) => a.family.localeCompare(b.family));
    return LOCAL;
  }

  // ---------- Loading fonts ----------

  const faces = new Map();
  const alias = f => (f.src === 'local' ? f.family : 'pp-' + f.id);

  function fileURL(f, w, it) {
    if (f.src === 'google' || f.src === 'open') return `https://cdn.jsdelivr.net/fontsource/fonts/${f.id}@latest/${f.subset}-${w}-${it ? 'italic' : 'normal'}.woff2`;
    if (f.src === 'fontshare') { const k = f.files[`${w}${it ? 'i' : ''}`]; return k ? `https://cdn.fontshare.com/wf/${k}.woff2` : null; }
    return null;
  }

  /** Loads one style under a private name ("pp-<id>"), so it never clashes with installed fonts. */
  function loadFace(f, weight, italic) {
    if (f.src === 'local') return Promise.resolve(true);
    const w = nearest(f, weight), it = italic && f.italic, key = `${f.id}|${w}${it ? 'i' : ''}`;
    if (!faces.has(key)) {
      const url = fileURL(f, w, it);
      faces.set(key, !url ? Promise.resolve(false)
        : new FontFace(alias(f), `url(${url}) format('woff2')`, { weight: String(w), style: it ? 'italic' : 'normal', display: 'swap' })
          .load().then(face => { document.fonts.add(face); return true; }).catch(() => { faces.delete(key); return false; }));
    }
    return faces.get(key);
  }

  function css(f, w, it) {
    return `font-family:'${alias(f)}',${GENERIC[f.cat]};font-weight:${nearest(f, w)};font-style:${it && f.italic ? 'italic' : 'normal'}`;
  }

  /** Text set in a catalogue font; it fades in once the font has loaded. */
  function ff(f, text, size, w = regular(f), it = false, extra = '') {
    return `<span class="ff loading" data-font="${esc(f.id)}" data-w="${nearest(f, w)}" data-i="${it ? 1 : 0}" style="${css(f, w, it)};font-size:${size}px;${extra}">${esc(text)}</span>`;
  }

  const io = 'IntersectionObserver' in window ? new IntersectionObserver(entries => {
    entries.forEach(e => { if (e.isIntersecting) { io.unobserve(e.target); reveal(e.target); } });
  }, { rootMargin: '300px' }) : null;

  function reveal(el) {
    const f = byId(el.dataset.font);
    if (!f) return;
    loadFace(f, +el.dataset.w, el.dataset.i === '1').then(ok => {
      el.classList.remove('loading');
      if (!ok) { el.classList.add('failed'); el.title = 'This font couldn’t be loaded. Check your internet connection.'; }
    });
  }

  function hydrate(root) {
    $$('.ff.loading', root).forEach(el => (io ? io.observe(el) : reveal(el)));
  }

  // ---------- State ----------

  const saved = (() => { try { return pp().store.get('type', {}) || {}; } catch { return {}; } })();
  const st = {
    filter: saved.filter || 'picks', cat: saved.cat || null, sort: saved.sort || 'popular', q: '',
    sample: saved.sample || '', size: saved.size || 40, favs: new Set(saved.favs || []),
    headingId: saved.headingId || null, mood: saved.mood || 'any', headline: saved.headline || 'Design is how it works',
    pairings: saved.pairings || [], current: null,
    scale: Object.assign({ headingId: 'inter', bodyId: 'inter', base: 16, ratio: 1.25, lh: 1.5, unit: 'rem', format: 'css' }, saved.scale || {}),
  };
  const persist = () => pp().store.set('type', {
    filter: st.filter, cat: st.cat, sort: st.sort, sample: st.sample, size: st.size, favs: [...st.favs],
    headingId: st.headingId, mood: st.mood, headline: st.headline, pairings: st.pairings, scale: st.scale,
    fusion: { style: fx.style, locks: fx.locks, mood: fx.mood, tone: fx.tone, layout: fx.layout, snap: fx.snap, saved: fx.saved },
  });
  const sample = () => st.sample.trim() || DEFAULT_SAMPLE;

  // ---------- Fonts view ----------

  let results = [], shown = 0;
  const PAGE = 48;

  function query() {
    let list = st.filter === 'local' ? (LOCAL || [])
      : st.filter === 'fav' ? [...FONTS, ...(LOCAL || [])].filter(f => st.favs.has(f.id))
      : st.filter === 'picks' ? FONTS.filter(f => f.pick)
      : st.filter === 'all' ? [...FONTS, ...(LOCAL || [])]
      : FONTS.filter(f => f.src === st.filter);
    if (st.cat) list = list.filter(f => f.cat === st.cat);
    const q = st.q.trim().toLowerCase();
    if (q) { const tokens = q.split(/\s+/); list = list.filter(f => tokens.every(t => f.text.includes(t))); }
    const sorts = {
      popular: (a, b) => a.rank - b.rank || a.family.localeCompare(b.family),
      name: (a, b) => a.family.localeCompare(b.family),
      newest: (a, b) => b.year - a.year || a.rank - b.rank,
    };
    list = [...list].sort(sorts[st.sort] || sorts.popular);
    if (q) list = list.map((f, i) => [f, i]).sort((a, b) => ((a[0].family.toLowerCase().startsWith(q) ? 0 : 1) - (b[0].family.toLowerCase().startsWith(q) ? 0 : 1)) || a[1] - b[1]).map(x => x[0]);
    return list;
  }

  function renderFontChips() {
    $('#fontFilters').innerHTML = FILTERS.map(([id, name, ic]) =>
      `<button type="button" class="fchip" data-filter="${id}" aria-pressed="${st.filter === id}">${ic ? icon(ic, 14) : ''}${name}` +
      `${id === 'fav' && st.favs.size ? ` <span class="n">${st.favs.size}</span>` : ''}</button>`).join('');
    $('#fontCats').innerHTML = `<button type="button" class="fchip" data-cat="" aria-pressed="${!st.cat}">All styles</button>` +
      Object.entries(CATS).map(([id, name]) => `<button type="button" class="fchip" data-cat="${id}" aria-pressed="${st.cat === id}">${name}</button>`).join('');
  }

  function renderFonts() {
    results = query();
    shown = 0;
    $('#fontGrid').innerHTML = '';
    const localMsg = st.filter === 'local' && !LOCAL;
    $('#fontCount').textContent = localMsg ? '' : `${results.length.toLocaleString()} famil${results.length === 1 ? 'y' : 'ies'}`;
    $('#fontEmpty').hidden = results.length > 0 || localMsg;
    $('#fontLocal').hidden = !localMsg;
    fillFonts();
  }

  function fillFonts() {
    const grid = $('#fontGrid'), sentinel = $('#fontSentinel');
    for (let guard = 0; guard < 20 && shown < results.length && sentinel.getBoundingClientRect().top < innerHeight + 900; guard++) {
      const next = results.slice(shown, shown + PAGE);
      grid.insertAdjacentHTML('beforeend', next.map(cardHTML).join(''));
      shown += next.length;
      hydrate(grid);
    }
  }

  function cardHTML(f) {
    const fav = st.favs.has(f.id);
    const meta = [CATS[f.cat], `${styleCount(f)} style${styleCount(f) === 1 ? '' : 's'}`, f.variable ? 'Variable' : ''].filter(Boolean).join(' · ');
    return `<article class="font-card" data-id="${esc(f.id)}">` +
      `<header><b>${esc(f.family)}</b>${f.pick ? `<span class="pick" title="Designer pick">${icon('sparkles', 14)}</span>` : ''}` +
      `<button type="button" class="icon-btn fav" data-act="fav" aria-pressed="${fav}" title="${fav ? 'Remove from favorites' : 'Add to favorites'}">${icon(fav ? 'starFill' : 'star', 16)}</button></header>` +
      `<button type="button" class="fc-sample" data-act="open" aria-label="Show ${esc(f.family)}" style="height:${Math.round(st.size * 2.6)}px">${ff(f, sample(), st.size)}</button>` +
      `<footer><span>${meta}</span><span class="badge">${SOURCES[f.src]}</span></footer></article>`;
  }

  function toggleFav(id) {
    if (st.favs.has(id)) st.favs.delete(id); else st.favs.add(id);
    persist();
    renderFontChips();
    const card = $(`.font-card[data-id="${CSS.escape(id)}"]`);
    if (card) card.outerHTML = cardHTML(byId(id));
    hydrate($('#fontGrid'));
    if ($('#fontDlg').open) renderFontDetail(byId(id));
  }

  // ---------- Font detail ----------

  function pageURL(f) {
    if (f.src === 'google') return 'https://fonts.google.com/specimen/' + f.family.replace(/ /g, '+');
    if (f.src === 'open') return 'https://fontsource.org/fonts/' + f.id;
    if (f.src === 'fontshare') return 'https://www.fontshare.com/fonts/' + f.slug;
    return null;
  }

  function embed(f, weights) {
    const ws = [...new Set(weights.map(w => nearest(f, w)))].sort((a, b) => a - b);
    if (f.src === 'google') return `<link href="https://fonts.googleapis.com/css2?family=${f.family.replace(/ /g, '+')}:wght@${ws.join(';')}&display=swap" rel="stylesheet">`;
    if (f.src === 'fontshare') return `<link href="https://api.fontshare.com/v2/css?f[]=${f.slug}@${ws.join(',')}&display=swap" rel="stylesheet">`;
    if (f.src === 'open') return `npm install @fontsource/${f.id}   /* then: import '@fontsource/${f.id}'; */`;
    return null;
  }

  function licenseText(f) {
    const title = { 'OFL-1.1': 'SIL Open Font License', 'Apache-2.0': 'Apache License 2.0', 'ITF FFL': 'ITF Free Font License', 'UFL-1.0': 'Ubuntu Font Licence' }[f.license] || f.license || 'See the font’s own license';
    const note = f.src === 'local' ? 'Installed on this computer. Check its license before using it in client work.'
      : f.license === 'ITF FFL' ? 'Free for personal and commercial use. Download it from Fontshare; the files may not be redistributed.'
      : 'Free for personal and commercial use, including web, print and apps.';
    return [title, note];
  }

  function openFont(f) {
    renderFontDetail(f);
    const dlg = $('#fontDlg');
    if (!dlg.open) dlg.showModal();
    $('.font-detail', dlg).scrollTop = 0;
  }

  function renderFontDetail(f) {
    const [lic, licNote] = licenseText(f);
    const url = pageURL(f), code = embed(f, f.weights);
    const meta = [CATS[f.cat], `${styleCount(f)} styles`, f.variable ? 'variable' : '', f.designers ? 'by ' + f.designers : '', SOURCES[f.src]].filter(Boolean).join(' · ');
    const styles = f.weights.flatMap(w => [[w, false], ...(f.italic ? [[w, true]] : [])]).map(([w, it]) =>
      `<div class="fd-row"><span>${WEIGHT_NAMES[w] || w}${it ? ' Italic' : ''} · ${w}</span>${ff(f, sample(), 26, w, it)}</div>`).join('');
    const sizes = [12, 16, 24, 36, 64].map(s => `<div class="fd-row size"><span>${s}</span>${ff(f, sample(), s)}</div>`).join('');
    const chars = ['ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz', '0123456789 & @ # % ? ! € $ £ “ ” ( ) / – —', 'ÀÉÎÕÜ àéîõü ÆØÅ æøå ß Ç ç Ñ ñ']
      .map(t => `<div class="fd-chars">${ff(f, t, 26)}</div>`).join('');
    const fav = st.favs.has(f.id);
    $('#fontDlgTitle').textContent = f.family;
    $('#fontDetail').innerHTML =
      `<div class="fd-head">${ff(f, f.family, 52, headingW(f))}<p class="hint">${esc(meta)}</p></div>` +
      `<div class="fd-actions">` +
      `<button type="button" class="btn primary" data-act="pair">${icon('pair', 16)}<span>Find pairings</span></button>` +
      `<button type="button" class="btn" data-act="scale-h">${icon('scale', 16)}<span>Use for headings</span></button>` +
      `<button type="button" class="btn" data-act="scale-b">${icon('scale', 16)}<span>Use for body text</span></button>` +
      (code ? `<button type="button" class="btn" data-act="embed">${icon('code', 16)}<span>Copy embed code</span></button>` : '') +
      (url ? `<a class="btn" href="${url}" target="_blank" rel="noopener">${icon('external', 16)}<span>Get font</span></a>` : '') +
      `<button type="button" class="icon-btn fav" data-act="fav" aria-pressed="${fav}" title="Favorite">${icon(fav ? 'starFill' : 'star')}</button></div>` +
      `<section class="fd-sec"><h3>Styles</h3>${styles}</section>` +
      `<section class="fd-sec"><h3>Sizes</h3>${sizes}</section>` +
      `<section class="fd-sec"><h3>Characters</h3>${chars}</section>` +
      `<section class="fd-sec"><h3>License</h3><p><b>${esc(lic)}</b></p><p class="hint">${esc(licNote)}</p>` +
      (f.src !== 'local' ? '<p class="hint">Previews use the Latin character set. Use “Get font” for the complete family.</p>' : '') + '</section>';
    $('#fontDetail').dataset.id = f.id;
    $$('#fontDetail .ff.loading').forEach(reveal);
  }

  // ---------- Pairing engine ----------

  const KIND = {
    grotesque: 'neutral grotesque', geometric: 'geometric sans', humanist: 'humanist sans', transitional: 'crisp text serif',
    oldstyle: 'classic book serif', slab: 'slab serif', mono: 'monospace',
  };
  const isSerif = k => k === 'transitional' || k === 'oldstyle' || k === 'slab';
  const TEXT_FACES = [
    ['Inter', 'grotesque', 'modern corporate'], ['Satoshi', 'geometric', 'modern friendly'], ['General Sans', 'grotesque', 'modern bold'],
    ['Switzer', 'grotesque', 'modern corporate editorial'], ['Geist Sans', 'grotesque', 'modern'], ['Hanken Grotesk', 'grotesque', 'modern editorial'],
    ['Instrument Sans', 'grotesque', 'modern elegant'], ['Schibsted Grotesk', 'grotesque', 'editorial modern'], ['Public Sans', 'grotesque', 'corporate'],
    ['IBM Plex Sans', 'grotesque', 'corporate modern'], ['Work Sans', 'grotesque', 'modern editorial'], ['Libre Franklin', 'grotesque', 'editorial corporate'],
    ['Archivo', 'grotesque', 'bold modern'], ['Onest', 'grotesque', 'modern friendly'], ['Manrope', 'geometric', 'modern corporate'],
    ['DM Sans', 'geometric', 'friendly modern'], ['Plus Jakarta Sans', 'geometric', 'modern friendly'], ['Outfit', 'geometric', 'friendly bold'],
    ['Figtree', 'geometric', 'friendly'], ['Poppins', 'geometric', 'friendly bold'], ['Montserrat', 'geometric', 'bold corporate'],
    ['Albert Sans', 'geometric', 'modern elegant'], ['Source Sans 3', 'humanist', 'corporate editorial'], ['Lato', 'humanist', 'corporate friendly'],
    ['Open Sans', 'humanist', 'corporate friendly'], ['Fira Sans', 'humanist', 'modern editorial'], ['Nunito Sans', 'humanist', 'friendly'],
    ['Karla', 'humanist', 'friendly editorial'], ['Mulish', 'humanist', 'elegant friendly'],
    ['Source Serif 4', 'transitional', 'editorial corporate'], ['Literata', 'transitional', 'editorial'], ['Newsreader', 'transitional', 'editorial elegant'],
    ['Merriweather', 'transitional', 'editorial corporate'], ['PT Serif', 'transitional', 'corporate editorial'], ['IBM Plex Serif', 'transitional', 'corporate modern'],
    ['Gelasio', 'transitional', 'editorial'], ['Zodiak', 'transitional', 'elegant modern'], ['Sentient', 'transitional', 'editorial modern'],
    ['Erode', 'transitional', 'editorial friendly'], ['Lora', 'oldstyle', 'editorial friendly'], ['Crimson Pro', 'oldstyle', 'elegant editorial'],
    ['EB Garamond', 'oldstyle', 'elegant'], ['Libre Baskerville', 'oldstyle', 'elegant editorial'], ['Gambetta', 'oldstyle', 'elegant editorial'],
    ['Alegreya', 'oldstyle', 'editorial friendly'], ['Cardo', 'oldstyle', 'elegant'], ['Roboto Slab', 'slab', 'bold corporate'],
    ['Zilla Slab', 'slab', 'editorial bold'], ['IBM Plex Mono', 'mono', 'modern corporate'], ['JetBrains Mono', 'mono', 'modern'],
    ['Space Mono', 'mono', 'modern bold'], ['DM Mono', 'mono', 'modern friendly'],
  ].map(([family, kind, moods]) => ({ family, kind, moods: moods.split(' ') }));
  const HEADLINES = [
    ['Playfair Display', 'editorial elegant'], ['Fraunces', 'editorial friendly'], ['DM Serif Display', 'elegant editorial'], ['Instrument Serif', 'elegant modern'],
    ['Gloock', 'elegant bold'], ['Bodoni Moda', 'elegant'], ['Cormorant Garamond', 'elegant'], ['Young Serif', 'friendly editorial'],
    ['Zodiak', 'elegant editorial'], ['Boska', 'elegant editorial'], ['Gambetta', 'editorial'], ['Erode', 'editorial friendly'],
    ['Clash Display', 'bold modern'], ['Cabinet Grotesk', 'bold modern'], ['Satoshi', 'modern friendly'], ['General Sans', 'modern'],
    ['Space Grotesk', 'modern'], ['Syne', 'bold modern'], ['Unbounded', 'bold modern'], ['Bricolage Grotesque', 'friendly bold'],
    ['Sora', 'modern friendly'], ['Chillax', 'friendly modern'], ['Archivo', 'bold corporate'], ['Anton', 'bold'], ['Bebas Neue', 'bold'],
    ['Oswald', 'bold corporate'], ['Montserrat', 'corporate bold'], ['Manrope', 'corporate modern'], ['IBM Plex Sans', 'corporate'],
    ['Libre Baskerville', 'editorial corporate'], ['Merriweather', 'corporate editorial'], ['Panchang', 'bold'],
  ].map(([family, moods]) => ({ family, moods: moods.split(' ') }));
  const MOODS = { any: 'Any', editorial: 'Editorial', modern: 'Modern & tech', elegant: 'Elegant', friendly: 'Friendly', corporate: 'Corporate', bold: 'Bold' };

  const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const available = () => TEXT_FACES.map(t => [t, named(t.family)]).filter(x => x[1]);

  function score(h, t, f, mood) {
    let s = { serif: isSerif(t.kind) ? (mood === 'editorial' || mood === 'elegant' ? 1.5 : 0.5) : 3,
      slab: isSerif(t.kind) ? 0.5 : 3,
      sans: isSerif(t.kind) ? 2.5 : (t.kind === 'humanist' || t.kind === 'grotesque' ? 1.5 : 1),
      display: isSerif(t.kind) ? 2 : 3, script: 2.5, mono: isSerif(t.kind) ? 1.5 : 3 }[h.cat];
    if (t.kind === 'mono') s -= 1.5;
    if (mood !== 'any' && t.moods.includes(mood)) s += 2;
    if (f.rank < 60) s += 0.6; else if (f.rank < 200) s += 0.3;
    return s + Math.random() * 1.2;
  }

  function hWeight(h, mood) {
    if (h.cat === 'display' || h.cat === 'script' || h.weights.length <= 2) return regular(h);
    if (mood === 'elegant' && h.cat === 'serif') return nearest(h, 400);
    return h.cat === 'serif' ? nearest(h, 600) : headingW(h);
  }

  function title(h, t) {
    const serif = isSerif(t.kind);
    if ((h.cat === 'serif' || h.cat === 'slab') && !serif) return 'Classic contrast';
    if (h.cat === 'sans' && serif) return 'Reverse contrast';
    if (h.cat === 'display') return 'Statement + text';
    if (h.cat === 'script') return 'Script accent';
    if (h.cat === 'serif' || h.cat === 'slab') return 'Serif harmony';
    return t.kind === 'mono' ? 'Technical' : 'Clean and modern';
  }

  function rationale(h, t) {
    const head = `${h.family} (${CATS[h.cat].toLowerCase()})`, desc = `${t.family}, a ${KIND[t.kind]}`, serif = isSerif(t.kind);
    if ((h.cat === 'serif' || h.cat === 'slab') && !serif) return `${head} headlines over ${desc}. Serif against sans is the most reliable contrast: the headline has character, the text stays easy to read.`;
    if (h.cat === 'sans' && serif) return `${head} headlines with ${desc}, for long reading. The serif adds warmth and rhythm to paragraphs.`;
    if (h.cat === 'display') return `${head} is made for big sizes only. ${desc[0].toUpperCase() + desc.slice(1)}, carries the text quietly so the headline can shout.`;
    if (h.cat === 'script') return `${head} works as an accent for short headings. Keep everything else in ${desc}.`;
    if (h.cat === 'mono') return `${head} gives a technical, coded feel. ${desc[0].toUpperCase() + desc.slice(1)}, keeps longer text comfortable.`;
    if (h.cat === 'serif' || h.cat === 'slab') return `Two serifs: ${head} for headlines, ${t.family} for text. It works because they differ clearly in weight and contrast, which suits books and magazines.`;
    return `${head} with ${desc}. Two sans serifs pair well when one leads and the other stays neutral.`;
  }

  function make(ttl, h, hw, b, accent, why) {
    const a = accent || b;
    return { id: pp().uid(), title: ttl, headingId: h.id, headingWeight: hw, bodyId: b.id, bodyWeight: regular(b),
      accentId: a.id, accentWeight: a.cat === 'mono' ? regular(a) : nearest(a, 600), upper: a.cat !== 'mono', why };
  }

  function suggest(h, mood, count = 12) {
    if (h) {
      const scored = available().filter(([, f]) => f.id !== h.id).map(([t, f]) => [t, f, score(h, t, f, mood)]).sort((a, b) => b[2] - a[2]);
      const out = [];
      const headlineOnly = /display|poster|headline|title/i.test(h.family);
      if ((h.cat === 'sans' || h.cat === 'serif') && !headlineOnly && h.weights.length >= 4 && h.weights.includes(400)) {
        out.push(make('One family', h, headingW(h), h, null,
          `${h.family} on its own: bold for headlines, regular for reading. One family keeps everything consistent and loads fast.`));
      }
      let serifs = 0, sans = 0, monos = 0;
      for (const [t, f] of scored) {
        if (out.length >= count) break;
        if (t.kind === 'mono') { if (monos >= 1) continue; monos++; } else if (isSerif(t.kind)) { if (serifs >= 6) continue; serifs++; } else { if (sans >= 7) continue; sans++; }
        const monoAccent = mood === 'modern' && out.length % 4 === 3 ? shuffle(['IBM Plex Mono', 'JetBrains Mono', 'DM Mono', 'Space Mono'].map(named).filter(Boolean))[0] : null;
        out.push(make(title(h, t), h, hWeight(h, mood), f, t.kind === 'mono' ? f : monoAccent, rationale(h, t)));
      }
      return out.slice(0, count);
    }
    let heads = shuffle(HEADLINES.filter(x => mood === 'any' || x.moods.includes(mood)).map(x => named(x.family)).filter(Boolean));
    if (heads.length < count) heads = heads.concat(shuffle(HEADLINES.map(x => named(x.family)).filter(f => f && !heads.includes(f))));
    const used = new Set();
    return heads.slice(0, count).map(h => {
      const options = available().filter(([, f]) => f.id !== h.id && !used.has(f.id)).map(([t, f]) => [t, f, score(h, t, f, mood)]).sort((a, b) => b[2] - a[2]);
      const pick = options.slice(0, 3)[Math.floor(Math.random() * Math.min(3, options.length))];
      if (!pick) return null;
      used.add(pick[1].id);
      return make(title(h, pick[0]), h, hWeight(h, mood), pick[1], null, rationale(h, pick[0]));
    }).filter(Boolean);
  }

  // ---------- Pairing view ----------

  const validPairing = p => p && byId(p.headingId) && byId(p.bodyId) && byId(p.accentId);

  function newPairings() {
    st.pairings = suggest(st.headingId ? byId(st.headingId) : null, st.mood);
    persist();
    renderPairings();
  }

  function renderPairingControls() {
    const h = st.headingId && byId(st.headingId);
    $('#pairHeading').value = h ? h.family : '';
    $('#pairMood').value = st.mood;
    $('#pairHeadline').value = st.headline;
    $('#pairHint').textContent = h
      ? `${h.family} stays as the headline font; the ideas try different fonts for body text.`
      : 'Exploring: every idea starts from a different headline font. Type a font name to build around it.';
  }

  function pairCardHTML(p) {
    const h = byId(p.headingId), b = byId(p.bodyId), a = byId(p.accentId);
    return `<button type="button" class="pair-card" data-id="${p.id}">` +
      `<span class="paper">` +
      ff(a, p.upper ? 'FEATURE · 4 MIN READ' : 'feature · 4 min read', 10.5, p.accentWeight, false, `letter-spacing:${p.upper ? '.12em' : '0'};color:var(--paper-muted)`) +
      `<span class="pc-head">${ff(h, st.headline || 'Design is how it works', 30, p.headingWeight)}</span>` +
      `<span class="pc-body">${ff(b, BODY_SAMPLE, 13.5, p.bodyWeight)}</span></span>` +
      `<span class="pc-meta"><b>${esc([...new Set([h.family, b.family])].join(' + '))}</b><span>${esc(p.title)}</span></span></button>`;
  }

  function renderPairings() {
    st.pairings = st.pairings.filter(validPairing);
    if (!st.pairings.length) st.pairings = suggest(st.headingId ? byId(st.headingId) : null, st.mood);
    const h = st.headingId && byId(st.headingId);
    $('#pairIntro').textContent = h
      ? `${h.family} for headlines, with ${st.pairings.length} options for body text. Click one for a full page preview.`
      : `${st.pairings.length} pairings, each starting from a different headline font${st.mood === 'any' ? '' : ` with a ${MOODS[st.mood].toLowerCase()} feel`}. Click one for a full page preview.`;
    $('#pairGrid').innerHTML = st.pairings.map(pairCardHTML).join('');
    hydrate($('#pairGrid'));
  }

  function pairCSS(p) {
    const h = byId(p.headingId), b = byId(p.bodyId), a = byId(p.accentId);
    const lines = [embed(h, [p.headingWeight]), h === b ? null : embed(b, [p.bodyWeight, nearest(b, 700)])].filter(Boolean).map(x => `/* ${x} */`);
    lines.push(`h1, h2, h3 { font-family: ${stack(h)}; font-weight: ${p.headingWeight}; }`);
    lines.push(`body { font-family: ${stack(b)}; font-weight: ${p.bodyWeight}; }`);
    if (a !== b) lines.push(`.label, figcaption { font-family: ${stack(a)}; font-weight: ${p.accentWeight}; }`);
    return lines.join('\n');
  }

  function openPairing(p) {
    st.current = p;
    const h = byId(p.headingId), b = byId(p.bodyId), a = byId(p.accentId);
    const role = (label, f, w) => `<div class="pd-role"><div><span class="hint">${label}</span>${ff(f, f.family, 22, w)}` +
      `<span class="hint">Weight ${w} · ${CATS[f.cat]} · ${esc(licenseText(f)[0])}</span></div>` +
      `<button type="button" class="btn small" data-act="font" data-id="${esc(f.id)}">Details</button></div>`;
    const caption = (t, extra = '') => ff(a, p.upper ? t.toUpperCase() : t, 11, p.accentWeight, false, `letter-spacing:${p.upper ? '.14em' : '0'};color:var(--paper-muted);${extra}`);
    $('#pairDlgTitle').textContent = [...new Set([h.family, b.family])].join(' + ');
    $('#pairDetail').innerHTML =
      `<article class="paper article">${caption('Design notes · Issue 12')}` +
      `<h2>${ff(h, st.headline || 'Design is how it works', 52, p.headingWeight, false, 'line-height:1.05')}</h2>` +
      `<p class="deck">${ff(b, 'A short guide to choosing fonts that feel right, read easily and still look good in ten years.', 20, p.bodyWeight, true, 'color:var(--paper-muted)')}</p>` +
      `<hr><div class="cols"><div>` +
      `<p>${ff(b, BODY_SAMPLE, 16, p.bodyWeight, false, 'line-height:1.7')}</p>` +
      `<p>${ff(b, 'Start with the text face, because that’s what people read for minutes at a time. Then find a headline font with a clear difference in shape or weight, and let it carry the personality.', 16, p.bodyWeight, false, 'line-height:1.7')}</p></div>` +
      `<aside><i></i>${ff(h, '“Contrast creates hierarchy; consistency creates trust.”', 24, p.headingWeight, false, 'line-height:1.2')}${caption('Type director')}</aside></div></article>` +
      `<p class="pd-why">${esc(p.why)}</p>` +
      `<div class="pd-roles">${role('Headlines', h, p.headingWeight)}${role('Body text', b, p.bodyWeight)}${a !== b ? role('Labels & captions', a, p.accentWeight) : ''}</div>`;
    const dlg = $('#pairDlg');
    if (!dlg.open) dlg.showModal();
    $$('#pairDetail .ff.loading').forEach(reveal);
    $('#pairDetail').scrollTop = 0;
  }

  // ---------- Type scale ----------

  const RATIOS = [[1.067, 'Minor second'], [1.125, 'Major second'], [1.2, 'Minor third'], [1.25, 'Major third'],
    [1.333, 'Perfect fourth'], [1.414, 'Augmented fourth'], [1.5, 'Perfect fifth'], [1.618, 'Golden ratio']];
  const ADVICE = r => (r < 1.15 ? 'Subtle steps. Good for dense apps and dashboards.' : r < 1.3 ? 'Balanced. A safe choice for most websites and apps.'
    : r < 1.45 ? 'Clear hierarchy. Good for marketing pages and editorial.' : 'Dramatic. Big headlines; best for landing pages and posters.');
  const STEPS = [['display', 'Display', 6], ['h1', 'Heading 1', 5], ['h2', 'Heading 2', 4], ['h3', 'Heading 3', 3], ['h4', 'Heading 4', 2],
    ['h5', 'Heading 5', 1], ['body', 'Body', 0], ['small', 'Small', -1], ['caption', 'Caption', -2]];
  const fmt = v => String(+v.toFixed(4));

  const scaleHeading = () => byId(st.scale.headingId) || named('Inter');
  const scaleBody = () => byId(st.scale.bodyId) || named('Inter');

  function steps() {
    const { base, ratio, lh } = st.scale, h = scaleHeading(), b = scaleBody();
    const p = st.current && st.current.headingId === h.id ? st.current.headingWeight : (h.cat === 'display' ? regular(h) : headingW(h));
    return STEPS.map(([id, name, n]) => {
      const raw = n >= 0 ? base * ratio ** n : Math.max(11, base * ratio ** (n * 0.6));
      const size = Math.round(raw * 2) / 2;
      const line = n <= 0 ? lh + (n < 0 ? 0.05 : 0) : Math.max(1.05, Math.round((lh - 0.08 * n) * 20) / 20);
      const tracking = n >= 4 ? -0.02 : n >= 2 ? -0.01 : n < 0 ? 0.01 : 0;
      return { id, name, n, size, line, tracking, heading: n > 0, weight: n > 0 ? p : regular(b) };
    });
  }
  const unit = px => (st.scale.unit === 'px' ? `${fmt(px)}px` : `${fmt(px / 16)}rem`);

  function exportText(format) {
    const h = scaleHeading(), b = scaleBody(), ss = steps(), spec = st.scale;
    const header = `Type scale: ${h.family} + ${b.family}, base ${fmt(spec.base)}px, ratio ${spec.ratio}. Made with Palette Pro.`;
    const embeds = [embed(h, ss.filter(s => s.heading).map(s => s.weight)), h === b ? null : embed(b, [regular(b), nearest(b, 700)])].filter(Boolean);
    if (format === 'css') {
      const l = [`/* ${header} */`, ...embeds.map(e => `/* Load fonts: ${e} */`), ':root {', `  --font-heading: ${stack(h)};`, `  --font-body: ${stack(b)};`];
      ss.forEach(s => { l.push(`  --text-${s.id}: ${unit(s.size)};`, `  --leading-${s.id}: ${fmt(s.line)};`); if (s.tracking) l.push(`  --tracking-${s.id}: ${fmt(s.tracking)}em;`); });
      l.push('}', '', `body { font-family: var(--font-body); font-size: var(--text-body); line-height: var(--leading-body); font-weight: ${ss.find(s => s.id === 'body').weight}; }`);
      ss.filter(s => s.id !== 'body').forEach(s => {
        const sel = s.heading && s.id !== 'display' ? `${s.id}, .${s.id}` : `.${s.id}`;
        l.push(`${sel} { font-family: var(--font-${s.heading ? 'heading' : 'body'}); font-size: var(--text-${s.id}); line-height: var(--leading-${s.id}); font-weight: ${s.weight};${s.tracking ? ` letter-spacing: var(--tracking-${s.id});` : ''} }`);
      });
      return l.join('\n') + '\n';
    }
    if (format === 'scss') {
      return [`// ${header}`, `$font-heading: ${stack(h)};`, `$font-body: ${stack(b)};`, '', '$type-scale: (',
        ...ss.map(s => `  "${s.id}": (size: ${unit(s.size)}, line-height: ${fmt(s.line)}, letter-spacing: ${fmt(s.tracking)}em, weight: ${s.weight}),`),
        ');', '', '@mixin text($step) {', '  $s: map-get($type-scale, $step);', '  font-size: map-get($s, size);', '  line-height: map-get($s, line-height);',
        '  letter-spacing: map-get($s, letter-spacing);', '  font-weight: map-get($s, weight);', '}'].join('\n') + '\n';
    }
    if (format === 'tailwind') {
      return [`// ${header}`, '// tailwind.config.js (v3). For v4, use the CSS variables export in @theme.', 'module.exports = {', '  theme: {', '    extend: {',
        '      fontFamily: {', `        heading: ['${h.family}', '${GENERIC[h.cat]}'],`, `        body: ['${b.family}', '${GENERIC[b.cat]}'],`, '      },', '      fontSize: {',
        ...ss.map(s => `        '${s.id}': ['${unit(s.size)}', { lineHeight: '${fmt(s.line)}', letterSpacing: '${fmt(s.tracking)}em', fontWeight: '${s.weight}' }],`),
        '      },', '    },', '  },', '};'].join('\n') + '\n';
    }
    if (format === 'swiftui') {
      return [`// ${header}`, '// Add the font files to your app target and list them under UIAppFonts / ATSApplicationFontsPath.', 'import SwiftUI', '', 'extension Font {',
        ...ss.map(s => `    static let ${s.id} = Font.custom("${(s.heading ? h : b).family}", size: ${fmt(s.size)}, relativeTo: ${s.heading ? (s.n >= 4 ? '.largeTitle' : '.title') : (s.n < 0 ? '.caption' : '.body')})`),
        '}'].join('\n') + '\n';
    }
    const text = {};
    ss.forEach(s => {
      text[s.id] = { $type: 'typography', $value: { fontFamily: s.heading ? '{font.heading}' : '{font.body}', fontSize: unit(s.size), fontWeight: s.weight, lineHeight: s.line, letterSpacing: `${fmt(s.tracking)}em` } };
    });
    return JSON.stringify({ font: { heading: { $type: 'fontFamily', $value: [h.family, GENERIC[h.cat]] }, body: { $type: 'fontFamily', $value: [b.family, GENERIC[b.cat]] } }, text }, null, 2) + '\n';
  }
  const EXPORTS = [['css', 'CSS', 'css'], ['scss', 'SCSS', 'scss'], ['tailwind', 'Tailwind', 'js'], ['swiftui', 'SwiftUI', 'swift'], ['json', 'Tokens (JSON)', 'json']];

  function renderScaleControls() {
    $('#scaleHeading').value = scaleHeading().family;
    $('#scaleBody').value = scaleBody().family;
    $('#scaleBase').value = st.scale.base;
    $('#scaleRatio').innerHTML = RATIOS.map(([r, n]) => `<option value="${r}">${n} · ${r}</option>`).join('');
    $('#scaleRatio').value = String(st.scale.ratio);
    $('#scaleLh').value = st.scale.lh;
    $('#scaleLhOut').textContent = fmt(st.scale.lh);
    $('#scaleUnit').value = st.scale.unit;
    $('#scaleAdvice').textContent = `Each step is the one below multiplied by the ratio. ${ADVICE(st.scale.ratio)}`;
    const p = st.current;
    const btn = $('#scaleUsePair');
    btn.hidden = !p || (p.headingId === st.scale.headingId && p.bodyId === st.scale.bodyId);
    if (p && byId(p.headingId) && byId(p.bodyId)) btn.textContent = `Use pairing: ${[...new Set([byId(p.headingId).family, byId(p.bodyId).family])].join(' + ')}`;
  }

  function renderScale() {
    const h = scaleHeading(), b = scaleBody(), ss = steps();
    const headline = st.headline || 'Design is how it works';
    $('#scaleRows').innerHTML = ss.map(s => {
      const f = s.heading ? h : b;
      const text = s.n >= 4 ? headline : s.heading ? 'Clear hierarchy guides the eye' : 'Readable text for everyday reading, set at a comfortable size.';
      return `<div class="scale-row"><div class="sr-meta"><b>${s.name}</b><span>${unit(s.size)} · ${fmt(s.size)}px</span>` +
        `<span>lh ${fmt(s.line)}${s.tracking ? ` · ${fmt(s.tracking)}em` : ''} · ${s.weight}</span></div>` +
        `<div class="sr-sample">${ff(f, text, s.size, s.weight, false, `letter-spacing:${s.tracking}em;line-height:${s.line}`)}</div></div>`;
    }).join('');
    const by = id => ss.find(s => s.id === id);
    const t = (s, f, text, extra = '') => ff(f, text, s.size, s.weight, false, `letter-spacing:${s.tracking}em;line-height:${s.line};${extra}`);
    $('#scalePage').innerHTML =
      `${t(by('caption'), b, 'NEW · TYPE SCALE', 'letter-spacing:.08em;color:var(--paper-muted)')}` +
      `<h2>${t(by('h1'), h, headline)}</h2><p>${t(by('body'), b, 'A type scale gives every size a reason. Headings step up by the same ratio, so the page has a clear rhythm from the biggest headline to the smallest caption.')}</p>` +
      `<div class="sp-cols">${['Hierarchy', 'Rhythm', 'Consistency'].map(x => `<div>${t(by('h4'), h, x)}<p>${t(by('small'), b, 'Sizes come from one base and one ratio, so they always relate to each other.', 'color:var(--paper-muted)')}</p></div>`).join('')}</div>`;
    $('#scaleFormats').innerHTML = EXPORTS.map(([id, name]) => `<button type="button" class="fchip" data-format="${id}" aria-pressed="${st.scale.format === id}">${name}</button>`).join('');
    $('#scaleCode').textContent = exportText(st.scale.format);
    $('#scaleSub').textContent = `${h.family} + ${b.family} · ${fmt(st.scale.base)}px × ${st.scale.ratio}`;
    hydrate($('#view-scale'));
  }

  // ---------- Fusion: colors and fonts together (same rules as the Mac app) ----------

  const Col = window.Color;
  const ok = hex => Col.rgbToOklch(Col.hexToRgb(hex));
  const okHex = (L, Cc, H) => Col.oklchToHex(L, Math.max(0, Cc), ((H % 360) + 360) % 360);
  const ratio = (a, b) => Col.contrast(Col.hexToRgb(a), Col.hexToRgb(b));
  const rnd = (a, b) => a + Math.random() * (b - a);
  const pick = list => list[Math.floor(Math.random() * list.length)];
  const ROLES = [['background', 'Background', 'Page background'], ['text', 'Text', 'Headlines and body text'],
    ['accent', 'Accent', 'Buttons, links and highlights'], ['surface', 'Surface', 'Cards, panels and fields'],
    ['muted', 'Secondary text', 'Captions, metadata and hints'], ['onAccent', 'On accent', 'Text on accent buttons']];
  const LOCKABLE = ['background', 'text', 'accent'];
  const TONES = [['any', 'Any'], ['light', 'Light'], ['dark', 'Dark'], ['color', 'Colored']];
  const LAYOUTS = [['website', 'Website'], ['poster', 'Poster'], ['app', 'App']];
  const DESIGN = { website: [1000, 600], poster: [600, 800], app: [1000, 600] };
  const ACCENT = {
    editorial: [[0.45, 0.60], [0.08, 0.14]], modern: [[0.55, 0.68], [0.12, 0.20]], elegant: [[0.40, 0.62], [0.04, 0.10]],
    friendly: [[0.62, 0.75], [0.12, 0.18]], corporate: [[0.40, 0.55], [0.08, 0.15]], bold: [[0.55, 0.70], [0.16, 0.24]],
    any: [[0.45, 0.70], [0.08, 0.20]],
  };

  const fx = Object.assign({ style: null, locks: [], mood: 'any', tone: 'any', layout: 'website', snap: false, saved: [] }, saved.fusion || {});
  const fxHistory = { past: [], future: [] };
  const fxValid = s => !!(s && s.colors && byId(s.headingId) && byId(s.bodyId));

  /** Moves `hex` away from `bg` in lightness until it reaches the WCAG contrast ratio. */
  function pushFrom(hex, bg, target) {
    let [L, Cc, H] = ok(hex);
    const darker = ok(bg)[0] >= 0.55;
    let out = hex;
    for (let i = 0; i < 40 && ratio(out, bg) < target; i++) {
      L = Math.min(0.99, Math.max(0.02, L + (darker ? -0.02 : 0.02)));
      out = okHex(L, Cc, H);
      if (L <= 0.02 || L >= 0.99) break;
    }
    return out;
  }
  const surfaceFor = bg => { const [L, Cc, H] = ok(bg); return okHex(L + (L < 0.55 ? 0.05 : L > 0.975 ? -0.03 : 0.02), Cc, H); };
  const mutedFor = (text, bg) => { const t = ok(text), b = ok(bg); return pushFrom(okHex(t[0] + (b[0] - t[0]) * 0.38, t[1], t[2]), bg, 4.5); };
  const onAccentFor = accent => {
    const h = ok(accent)[2];
    return ratio('#FFFFFF', accent) >= ratio('#151517', accent) ? okHex(0.985, 0.008, h) : okHex(0.18, 0.02, h);
  };

  /** A new style; locked slots come from `cur`, everything else is generated around them. */
  function fxGenerate(cur, locks, mood, tone, snap) {
    const locked = s => !!cur && locks.includes(s);
    let accent;
    if (locked('accent')) accent = cur.colors.accent;
    else {
      const [Lr, Cr] = ACCENT[mood] || ACCENT.any;
      let hue = rnd(0, 360);
      if (mood === 'corporate' && Math.random() < 0.5) hue = rnd(225, 265);
      accent = okHex(rnd(...Lr), rnd(...Cr), hue);
    }
    const aHue = ok(accent)[2];

    let kind = tone;
    if (locked('background')) {
      const b = ok(cur.colors.background);
      kind = b[0] < 0.55 ? (b[1] > 0.05 ? 'color' : 'dark') : 'light';
    } else if (kind === 'any') {
      const colored = ['bold', 'friendly', 'modern', 'any'].includes(mood) ? 0.18 : 0.06;
      const r = Math.random();
      kind = r < colored ? 'color' : r < colored + 0.32 ? 'dark' : 'light';
      // A locked accent has to stay visible: bright accents need a dark page, deep ones a light page.
      if (locked('accent')) {
        const L = ok(accent)[0];
        if (L > 0.72 && kind === 'light') kind = Math.random() < 0.5 ? 'dark' : 'color';
        if (L < 0.42 && kind !== 'light') kind = 'light';
      }
    }

    let background;
    if (locked('background')) background = cur.colors.background;
    else if (kind === 'dark') background = okHex(rnd(0.14, 0.22), rnd(0.008, 0.03), aHue + rnd(-30, 30));
    else if (kind === 'color') background = okHex(rnd(0.24, 0.38), rnd(0.06, 0.12), aHue + (Math.random() < 0.5 ? 0 : rnd(150, 210)));
    else background = okHex(rnd(0.955, 0.99), rnd(0.004, 0.02), Math.random() < 0.4 ? 85 : aHue + rnd(-40, 40));
    const bg = ok(background), darkPage = bg[0] < 0.55;

    const text = locked('text') ? cur.colors.text
      : pushFrom(darkPage ? okHex(rnd(0.93, 0.97), rnd(0.005, 0.02), bg[2]) : okHex(rnd(0.16, 0.24), rnd(0.01, 0.03), bg[2]), background, 7);

    if (!locked('accent')) {
      if (kind === 'color') accent = okHex(rnd(0.78, 0.88), Math.max(0.10, ok(accent)[1]), aHue);
      accent = pushFrom(accent, background, 3);
      // Buttons need readable labels: white on a deeper accent for light pages, dark on a brighter one otherwise.
      accent = pushFrom(accent, darkPage ? okHex(0.18, 0.02, aHue) : okHex(0.985, 0.008, aHue), 4.6);
      if (snap) {
        const m = pp().nearest(accent, 1, 'coated')[0];
        if (m && ratio(m.s.hex, background) >= 3 && Math.max(ratio(m.s.hex, '#FFFFFF'), ratio(m.s.hex, '#151517')) >= 4.5) accent = m.s.hex;
      }
    }

    let h = locked('heading') ? byId(cur.headingId) : null, b = locked('body') ? byId(cur.bodyId) : null;
    let hw = cur ? cur.headingWeight : 700, bw = cur ? cur.bodyWeight : 400;
    if (!h && !b) {
      const p = pick(suggest(null, mood));
      if (p) { h = byId(p.headingId); hw = p.headingWeight; b = byId(p.bodyId); bw = p.bodyWeight; }
    } else if (h && !b) {
      const p = pick(suggest(h, mood).slice(0, 6));
      if (p) { b = byId(p.bodyId); bw = p.bodyWeight; }
    } else if (!h && b) {
      const pool = HEADLINES.filter(x => mood === 'any' || x.moods.includes(mood)).map(x => named(x.family)).filter(f => f && f.id !== b.id);
      h = pick(pool) || named('Inter');
      hw = hWeight(h, mood);
    }
    h = h || named('Inter');
    b = b || named('Inter');
    return {
      id: pp().uid(),
      colors: { background, surface: surfaceFor(background), text, muted: mutedFor(text, background), accent, onAccent: onAccentFor(accent) },
      headingId: h.id, headingWeight: nearest(h, hw), bodyId: b.id, bodyWeight: nearest(b, bw),
    };
  }

  /** Recomputes the colors that follow the others after a manual edit. */
  function fxDerive(s) {
    const c = { ...s.colors };
    c.surface = surfaceFor(c.background);
    c.muted = mutedFor(c.text, c.background);
    c.onAccent = onAccentFor(c.accent);
    return { ...s, colors: c };
  }

  const fxChecks = s => [
    ['Text on background', ratio(s.colors.text, s.colors.background), 4.5],
    ['Secondary text on background', ratio(s.colors.muted, s.colors.background), 4.5],
    ['Accent on background', ratio(s.colors.accent, s.colors.background), 3],
    ['Button text on accent', ratio(s.colors.onAccent, s.colors.accent), 4.5],
  ];
  const gradeOf = r => (r >= 7 ? 'AAA' : r >= 4.5 ? 'AA' : r >= 3 ? 'AA Large' : 'Fail');
  function fxName(s) {
    const m = pp().nearest(s.colors.accent, 1, 'tcx')[0], h = byId(s.headingId);
    return [m && m.s.name, h && h.family].filter(Boolean).join(' · ');
  }
  const fxFontsLabel = s => [...new Set([byId(s.headingId), byId(s.bodyId)].filter(Boolean).map(f => f.family))].join(' + ');
  const sameStyle = (a, b) => JSON.stringify(a.colors) === JSON.stringify(b.colors) && a.headingId === b.headingId && a.bodyId === b.bodyId;

  function fxCSS(s) {
    const h = byId(s.headingId), b = byId(s.bodyId);
    const lines = [`/* ${fxName(s)}, made with Palette Pro */`,
      ...[embed(h, [s.headingWeight]), h === b ? null : embed(b, [s.bodyWeight, nearest(b, 700)])].filter(Boolean).map(x => `/* ${x} */`), ':root {'];
    ROLES.forEach(([k, title]) => lines.push(`  --color-${title.toLowerCase().replace(/\s+/g, '-')}: ${s.colors[k]};`));
    lines.push(`  --font-heading: ${stack(h)};`, `  --font-body: ${stack(b)};`, '}',
      `body { background: var(--color-background); color: var(--color-text); font-family: var(--font-body); font-weight: ${s.bodyWeight}; }`,
      `h1, h2, h3 { font-family: var(--font-heading); font-weight: ${s.headingWeight}; }`,
      '.button { background: var(--color-accent); color: var(--color-on-accent); }');
    return lines.join('\n') + '\n';
  }

  // State changes

  function fxSet(next, record = true) {
    if (record && fx.style) {
      fxHistory.past.push(fx.style);
      if (fxHistory.past.length > 100) fxHistory.past.shift();
      fxHistory.future = [];
    }
    fx.style = next;
    persist();
    renderFusion();
  }
  const fxNew = () => fxSet(fxGenerate(fx.style, fx.locks, fx.mood, fx.tone, fx.snap));
  function fxStep(back) {
    const from = back ? fxHistory.past : fxHistory.future, to = back ? fxHistory.future : fxHistory.past;
    if (!from.length) return;
    to.push(fx.style);
    fx.style = from.pop();
    persist();
    renderFusion();
  }
  function fxToggleLock(slot) {
    fx.locks = fx.locks.includes(slot) ? fx.locks.filter(x => x !== slot) : [...fx.locks, slot];
    persist();
    renderFusionSlots();
  }
  function fxSetColor(role, hex) {
    if (!fx.locks.includes(role)) fx.locks = [...fx.locks, role];
    fxSet(fxDerive({ ...fx.style, colors: { ...fx.style.colors, [role]: hex } }));
  }
  function fxSetFont(heading, f) {
    const s = { ...fx.style };
    if (heading) { s.headingId = f.id; s.headingWeight = hWeight(f, fx.mood); } else { s.bodyId = f.id; s.bodyWeight = regular(f); }
    const slot = heading ? 'heading' : 'body';
    if (!fx.locks.includes(slot)) fx.locks = [...fx.locks, slot];
    fxSet(s);
  }

  // Example designs, built at a fixed size and scaled to fit.

  function fxDesign(s, layout) {
    const h = byId(s.headingId), b = byId(s.bodyId), hw = s.headingWeight, bw = s.bodyWeight, b6 = nearest(b, 600), b5 = nearest(b, 500);
    const T = (f, text, size, w, extra = '') => ff(f, text, size, w, false, extra);
    const pill = (text, cls, w = b6) => `<span class="fx-pill ${cls}">${T(b, text, 15, w)}</span>`;
    const c = s.colors;
    const vars = `--fx-bg:${c.background};--fx-surface:${c.surface};--fx-text:${c.text};--fx-muted:${c.muted};--fx-accent:${c.accent};--fx-on:${c.onAccent}`;
    const [W, H] = DESIGN[layout];
    const open = cls => `<div class="fx-design ${cls}" style="${vars};width:${W}px;height:${H}px">`;
    if (layout === 'poster') {
      return open('fx-poster') + '<i class="p1"></i><i class="p2"></i><div class="fx-poster-in">' +
        `<div class="fx-row">${T(b, 'VOL. 07', 14, b6, 'letter-spacing:2px')}${T(b, 'OCT 24 – 26', 14, b6, 'letter-spacing:2px')}</div>` +
        '<div class="fx-grow"></div>' +
        `<h2>${T(h, 'Form & Color', 104, hw, 'line-height:.98')}</h2>` +
        `<p>${T(b, 'A three-day festival of type, color and graphic design.', 21, bw, 'color:var(--fx-muted);line-height:1.4')}</p>` +
        '<i class="bar"></i><div class="fx-facts">' +
        [['Venue', 'Palais des Arts'], ['Talks', '28 speakers'], ['Tickets', 'formandcolor.fest']].map(([k, v]) =>
          `<div>${T(b, k.toUpperCase(), 11, b6, 'letter-spacing:1.6px;color:var(--fx-muted)')}${T(b, v, 16, b5)}</div>`).join('') +
        '</div></div></div>';
    }
    if (layout === 'app') {
      const tasks = [['Review color palette', '10:00'], ['Pick type pairing', '11:30'], ['Share with the team', '14:00']].map(([t, time]) =>
        `<div class="fx-task"><i></i>${T(b, t, 15, bw)}<span class="fx-grow"></span>${T(b, time, 13, bw, 'color:var(--fx-muted)')}</div>`).join('');
      return open('fx-app') +
        `<div class="fx-phone"><div class="fx-row">${T(b, '9:41', 14, b6)}<span class="fx-battery"></span></div>` +
        `${T(b, 'Tuesday, 14 October', 13, bw, 'color:var(--fx-muted)')}` +
        `<h3>${T(h, 'Good morning', 32, hw, 'line-height:1.1')}</h3>` +
        `<div class="fx-card"><div class="fx-row">${T(b, 'Today’s focus', 13, b6, 'color:var(--fx-muted)')}${T(b, '3 of 5', 13, b6, 'color:var(--fx-accent)')}</div>` +
        `<div class="fx-progress"><i></i></div>${T(h, 'Finish the brand guidelines', 18, hw, 'line-height:1.2')}</div>` +
        tasks + '<span class="fx-grow"></span>' +
        `<span class="fx-pill fill wide">${T(b, 'Add a task', 16, b6)}</span></div>` +
        `<div class="fx-app-copy">${T(b, 'NORTHWIND', 13, b6, 'letter-spacing:2px;color:var(--fx-accent)')}` +
        `<h2>${T(h, 'Plan less. Make more.', 52, hw, 'line-height:1.08')}</h2>` +
        `<p>${T(b, 'A calm daily planner for designers, with your tasks, files and feedback in one place.', 18, bw, 'color:var(--fx-muted);line-height:1.5')}</p>` +
        `<div class="fx-buttons">${pill('Download', 'fill')}${pill('Learn more', 'soft', b5)}</div></div></div>`;
    }
    return open('fx-web') +
      `<header class="fx-nav"><span class="fx-logo"><i></i>${T(h, 'Northwind', 21, hw)}</span>` +
      `<nav>${['Work', 'Studio', 'Journal', 'About'].map(x => T(b, x, 15, bw, 'color:var(--fx-muted)')).join('')}</nav>${pill('Contact', 'ink')}</header>` +
      '<div class="fx-hero"><div class="fx-copy">' +
      `${T(b, 'INDEPENDENT DESIGN STUDIO', 12.5, b6, 'letter-spacing:2px;color:var(--fx-accent)')}` +
      `<h2>${T(h, 'Ideas that look as good as they work', 58, hw, 'line-height:1.06')}</h2>` +
      `<p>${T(b, 'We help brands find their voice with identity, websites and products people enjoy using.', 18, bw, 'color:var(--fx-muted);line-height:1.5')}</p>` +
      `<div class="fx-buttons">${pill('Start a project', 'fill')}${pill('See our work', 'outline', b5)}</div></div>` +
      `<div class="fx-visual"><i class="c1"></i><i class="c2"></i><div class="fx-stat">${T(h, '120+', 46, hw)}${T(b, 'projects shipped since 2016', 14, bw, 'color:var(--fx-muted)')}</div></div></div>` +
      `<footer class="fx-logos">${T(b, 'Trusted by', 13, bw, 'color:var(--fx-muted)')}${['LUMEN', 'ATLAS', 'Kinfolk', 'Oberon'].map(x => T(h, x, 17, hw, 'color:var(--fx-muted)')).join('')}</footer></div>`;
  }

  function fitStage() {
    const stage = $('#fxStage'), inner = stage && $('.fx-scale', stage);
    if (!inner) return;
    const [W, H] = DESIGN[fx.layout];
    const maxW = stage.clientWidth;
    const scale = Math.min(maxW / W, fx.layout === 'poster' ? Math.min(760, innerHeight * 0.8) / H : 1.4);
    inner.style.transform = `scale(${scale})`;
    inner.style.left = `${Math.max(0, (maxW - W * scale) / 2)}px`;
    stage.style.height = `${Math.round(H * scale)}px`;
  }

  function renderStage(s) {
    const [W, H] = DESIGN[fx.layout];
    $('#fxStage').classList.toggle('poster', fx.layout === 'poster');
    $('#fxStage').innerHTML = `<div class="fx-scale" style="width:${W}px;height:${H}px">${fxDesign(s, fx.layout)}</div>`;
    fitStage();
    $$('#fxStage .ff.loading').forEach(reveal);
  }

  function renderFusion() {
    const s = fx.style;
    if (!fxValid(s)) return;
    renderStage(s);
    $('#fxName').textContent = fxName(s);
    $('#fxFonts').textContent = fxFontsLabel(s);
    $('#fxMood').value = fx.mood;
    $('#fxSnap').checked = fx.snap;
    $('#fxTones').innerHTML = TONES.map(([k, n]) => `<button type="button" class="fchip" data-tone="${k}" aria-pressed="${fx.tone === k}">${n}</button>`).join('');
    $('#fxLayouts').innerHTML = LAYOUTS.map(([k, n]) => `<button type="button" class="fchip" data-layout="${k}" aria-pressed="${fx.layout === k}">${n}</button>`).join('');
    $('#fxUndo').disabled = !fxHistory.past.length;
    $('#fxRedo').disabled = !fxHistory.future.length;
    const isSaved = fx.saved.some(x => sameStyle(x, s));
    $('#fxSave').innerHTML = icon(isSaved ? 'starFill' : 'star', 16) + `<span>${isSaved ? 'Saved' : 'Save style'}</span>`;
    $('#fxSave').disabled = isSaved;
    renderFusionSlots();
  }

  function renderFusionSlots() {
    const s = fx.style;
    if (!fxValid(s)) return;
    $('#fxSlots').innerHTML = ROLES.map(([role, title, usage]) => {
      const hex = s.colors[role], lockable = LOCKABLE.includes(role), locked = fx.locks.includes(role);
      const m = pp().nearest(hex, 1, 'coated')[0];
      return `<div class="fx-slot" title="${esc(usage)}">` +
        `<label class="fx-swatch" style="--c:${hex};--ink:${Col.readableOn(Col.hexToRgb(hex))}">` +
        (lockable ? `<input type="color" value="${hex.toLowerCase()}" data-role="${role}" aria-label="Change ${title}">` : '') +
        `<span class="mono">${hex}</span></label>` +
        (lockable ? `<button type="button" class="fx-lock" data-lock="${role}" aria-pressed="${locked}" title="${locked ? 'Locked: Generate keeps it. Click to unlock.' : 'Lock to keep it when generating'}">${icon(locked ? 'lock' : 'unlock', 14)}</button>` : '') +
        `<b>${title}</b>` +
        (lockable ? `<input class="fx-hex input mono" value="${hex}" data-role="${role}" maxlength="7" spellcheck="false" aria-label="${title} hex">`
          : '<span class="hint">Follows the others</span>') +
        `<span class="hint">${m && m.d < 0.5 ? '' : '≈ '}PANTONE ${esc(m ? m.s.code : '')}</span></div>`;
    }).join('');

    $('#fxFontSlots').innerHTML = [['heading', 'Heading font', s.headingId, s.headingWeight], ['body', 'Body font', s.bodyId, s.bodyWeight]].map(([slot, label, id, w]) => {
      const f = byId(id), locked = fx.locks.includes(slot);
      return `<div class="fx-font"><span class="fx-aa" style="background:${s.colors.background};color:${s.colors.text}">${ff(f, 'Aa', 40, w)}</span>` +
        `<div class="fx-font-info"><span class="hint">${label}</span>` +
        `<input class="input" list="fontNames" value="${esc(f.family)}" data-font="${slot}" spellcheck="false" autocomplete="off" aria-label="${label}">` +
        `<span class="hint">Weight ${w} · ${CATS[f.cat]} · ${SOURCES[f.src]}</span></div>` +
        `<button type="button" class="icon-btn fx-lock" data-lock="${slot}" aria-pressed="${locked}" title="${locked ? 'Locked: Generate keeps it. Click to unlock.' : 'Lock to keep it when generating'}">${icon(locked ? 'lock' : 'unlock', 16)}</button></div>`;
    }).join('');

    $('#fxChecks').innerHTML = fxChecks(s).map(([label, r, need]) =>
      `<div class="fx-check ${r >= need ? 'ok' : 'bad'}" title="${r >= need ? 'Readable' : `Below ${need}:1, hard to read for some people`}">` +
      `<span class="dot" aria-hidden="true">${r >= need ? '✓' : '!'}</span><div><span class="hint">${label}</span><b>${r.toFixed(1)} : 1 · ${gradeOf(r)}</b></div></div>`).join('');

    const list = fx.saved.filter(fxValid);
    $('#fxSavedWrap').hidden = !list.length;
    $('#fxSaved').innerHTML = list.map(x =>
      `<div class="fx-saved-card"><button type="button" data-open="${x.id}" aria-label="Open ${esc(fxName(x))}">` +
      `<span class="sw" style="background:${x.colors.background};color:${x.colors.text}">${ff(byId(x.headingId), 'Aa', 30, x.headingWeight)}<i style="background:${x.colors.accent}"></i></span>` +
      `<b>${esc(fxName(x))}</b><span class="hint">${esc(fxFontsLabel(x))}</span></button>` +
      `<button type="button" class="icon-btn del" data-del="${x.id}" title="Remove" aria-label="Remove saved style">${icon('x', 14)}</button></div>`).join('');
    $$('#fxFontSlots .ff.loading, #fxSaved .ff.loading').forEach(reveal);
  }

  async function showFusion() {
    $('#fxMood').innerHTML = Object.entries(MOODS).map(([k, n]) => `<option value="${k}">${n}</option>`).join('');
    $('#fxGenerate').innerHTML = `${icon('sparkles')}<span>Generate</span><kbd class="hide-sm">Space</kbd>`;
    $('#fxUndo').innerHTML = icon('undo');
    $('#fxRedo').innerHTML = icon('redo');
    $('#fxCss').innerHTML = icon('code', 16) + '<span>Copy CSS</span>';
    $('#fxPalette').innerHTML = icon('plus', 16) + '<span>Save colors as palette</span>';
    $('#fxScale').innerHTML = icon('scale', 16) + '<span>Use fonts in Type scale</span>';
    fx.saved = fx.saved.filter(fxValid);
    if (!fxValid(fx.style)) fxSet(fxGenerate(null, [], fx.mood, fx.tone, fx.snap), false);
    else renderFusion();
  }

  function fusionKey(action) {
    if (current !== 'fusion' || !FONTS.length || !fx.style) return;
    if (action === 'generate') fxNew();
    if (action === 'undo') fxStep(true);
    if (action === 'redo') fxStep(false);
  }

  function bindFusion() {
    $('#fxGenerate').addEventListener('click', fxNew);
    $('#fxMood').addEventListener('change', e => { fx.mood = e.target.value; fxNew(); });
    $('#fxSnap').addEventListener('change', e => { fx.snap = e.target.checked; fxNew(); });
    $('#fxTones').addEventListener('click', e => {
      const b = e.target.closest('[data-tone]');
      if (b) { fx.tone = b.dataset.tone; fxNew(); }
    });
    $('#fxLayouts').addEventListener('click', e => {
      const b = e.target.closest('[data-layout]');
      if (b) { fx.layout = b.dataset.layout; persist(); renderFusion(); }
    });
    $('#fxUndo').addEventListener('click', () => fxStep(true));
    $('#fxRedo').addEventListener('click', () => fxStep(false));
    addEventListener('resize', () => { if (current === 'fusion') fitStage(); });

    const slots = $('#fxSlots');
    slots.addEventListener('click', e => {
      const l = e.target.closest('[data-lock]');
      if (l) { e.preventDefault(); fxToggleLock(l.dataset.lock); }
    });
    // Live preview while the color picker is open; the change is kept when it closes.
    slots.addEventListener('input', e => {
      const t = e.target;
      if (t.type !== 'color') return;
      const preview = fxDerive({ ...fx.style, colors: { ...fx.style.colors, [t.dataset.role]: t.value.toUpperCase() } });
      renderStage(preview);
      t.closest('.fx-swatch').style.setProperty('--c', t.value);
    });
    slots.addEventListener('change', e => {
      const t = e.target;
      if (t.type === 'color') fxSetColor(t.dataset.role, t.value.toUpperCase());
      else if (t.classList.contains('fx-hex')) {
        const hex = Col.parseHex(t.value);
        if (hex) fxSetColor(t.dataset.role, hex.toUpperCase()); else t.value = fx.style.colors[t.dataset.role];
      }
    });
    $('#fxFontSlots').addEventListener('click', e => {
      const l = e.target.closest('[data-lock]');
      if (l) fxToggleLock(l.dataset.lock);
    });
    $('#fxFontSlots').addEventListener('change', e => {
      const t = e.target.closest('[data-font]');
      if (t && !chooseFont(t, f => fxSetFont(t.dataset.font === 'heading', f))) renderFusionSlots();
    });

    $('#fxSave').addEventListener('click', () => {
      if (!fx.style || fx.saved.some(x => sameStyle(x, fx.style))) return;
      fx.saved = [{ ...fx.style, id: pp().uid() }, ...fx.saved].slice(0, 40);
      persist();
      renderFusion();
      pp().toast('Saved this style below');
    });
    $('#fxCss').addEventListener('click', () => fx.style && pp().copyText(fxCSS(fx.style), 'CSS'));
    $('#fxPalette').addEventListener('click', () => {
      if (!fx.style) return;
      pp().addPalette(fxName(fx.style), ROLES.map(([k]) => {
        const m = pp().nearest(fx.style.colors[k], 1, 'coated')[0];
        return { hex: fx.style.colors[k], sid: m && m.d < 0.5 ? m.s.id : null };
      }));
    });
    $('#fxScale').addEventListener('click', () => {
      if (!fx.style) return;
      st.scale.headingId = fx.style.headingId;
      st.scale.bodyId = fx.style.bodyId;
      persist();
      pp().go('scale');
    });
    $('#fxSaved').addEventListener('click', e => {
      const del = e.target.closest('[data-del]');
      if (del) { fx.saved = fx.saved.filter(x => x.id !== del.dataset.del); persist(); renderFusion(); return; }
      const open = e.target.closest('[data-open]');
      const x = open && fx.saved.find(y => y.id === open.dataset.open);
      if (x) fxSet({ ...x });
    });
  }

  // ---------- Events ----------

  function chooseFont(input, apply) {
    const f = named(input.value);
    if (!f) { pp().toast(`“${input.value}” isn’t in the font list. Pick a name from the suggestions.`); return false; }
    apply(f);
    return true;
  }

  function useInScale(p) {
    st.scale.headingId = p.headingId;
    st.scale.bodyId = p.bodyId;
    st.current = p;
    persist();
    pp().go('scale');
  }

  let bound = false;
  function bind() {
    if (bound) return;
    bound = true;
    bindFusion();
    let timer = 0;
    $('#fontSearch').addEventListener('input', e => {
      clearTimeout(timer);
      timer = setTimeout(() => { st.q = e.target.value; renderFonts(); if (scrollY > 300) scrollTo(0, 0); }, 120);
    });
    $('#fontSort').addEventListener('change', e => { st.sort = e.target.value; persist(); renderFonts(); });
    $('#fontSample').addEventListener('input', e => {
      clearTimeout(timer);
      timer = setTimeout(() => { st.sample = e.target.value; persist(); renderFonts(); }, 200);
    });
    $('#fontSize').addEventListener('input', e => {
      st.size = +e.target.value;
      $('#fontSizeOut').textContent = `${st.size}px`;
      clearTimeout(timer);
      timer = setTimeout(() => { persist(); renderFonts(); }, 120);
    });
    $('#fontFilters').addEventListener('click', e => {
      const b = e.target.closest('[data-filter]');
      if (!b) return;
      st.filter = b.dataset.filter;
      persist();
      renderFontChips();
      renderFonts();
    });
    $('#fontCats').addEventListener('click', e => {
      const b = e.target.closest('[data-cat]');
      if (!b) return;
      st.cat = b.dataset.cat || null;
      persist();
      renderFontChips();
      renderFonts();
    });
    $('#fontLocalBtn').addEventListener('click', async () => {
      try { await loadLocal(); renderFonts(); }
      catch { pp().toast('The browser didn’t allow access to your fonts.'); }
    });
    $('#fontGrid').addEventListener('click', e => {
      const card = e.target.closest('.font-card');
      if (!card) return;
      const act = e.target.closest('[data-act]');
      if (act && act.dataset.act === 'fav') { toggleFav(card.dataset.id); return; }
      if (act) openFont(byId(card.dataset.id));
    });
    addEventListener('scroll', () => { if (current === 'fonts') fillFonts(); }, { passive: true });
    addEventListener('resize', () => { if (current === 'fonts') fillFonts(); });

    $('#fontDetail').addEventListener('click', e => {
      const b = e.target.closest('[data-act]');
      const f = byId($('#fontDetail').dataset.id);
      if (!b || !f) return;
      const act = b.dataset.act;
      if (act === 'fav') toggleFav(f.id);
      if (act === 'embed') pp().copyText(embed(f, f.weights), 'embed code');
      if (act === 'pair') { $('#fontDlg').close(); st.headingId = f.id; newPairings(); pp().go('pairing'); }
      if (act === 'scale-h' || act === 'scale-b') {
        $('#fontDlg').close();
        if (act === 'scale-h') st.scale.headingId = f.id; else st.scale.bodyId = f.id;
        persist();
        pp().go('scale');
      }
    });

    $('#pairHeading').addEventListener('change', e => {
      if (!e.target.value.trim()) { st.headingId = null; renderPairingControls(); newPairings(); return; }
      if (chooseFont(e.target, f => { st.headingId = f.id; })) { renderPairingControls(); newPairings(); }
      else renderPairingControls();
    });
    $('#pairExplore').addEventListener('click', () => { st.headingId = null; renderPairingControls(); newPairings(); });
    $('#pairMood').addEventListener('change', e => { st.mood = e.target.value; newPairings(); });
    $('#pairHeadline').addEventListener('input', e => {
      clearTimeout(timer);
      timer = setTimeout(() => { st.headline = e.target.value; persist(); renderPairings(); }, 200);
    });
    $('#pairNew').addEventListener('click', newPairings);
    $('#pairGrid').addEventListener('click', e => {
      const c = e.target.closest('.pair-card');
      const p = c && st.pairings.find(x => x.id === c.dataset.id);
      if (p) openPairing(p);
    });
    $('#pairDetail').addEventListener('click', e => {
      const b = e.target.closest('[data-act="font"]');
      if (b) { $('#pairDlg').close(); openFont(byId(b.dataset.id)); }
    });
    $('#pairCopy').addEventListener('click', () => st.current && pp().copyText(pairCSS(st.current), 'CSS'));
    $('#pairScale').addEventListener('click', () => { if (st.current) { $('#pairDlg').close(); useInScale(st.current); } });

    const scaleFont = (input, key) => input.addEventListener('change', () => {
      if (chooseFont(input, f => { st.scale[key] = f.id; })) { persist(); renderScaleControls(); renderScale(); } else renderScaleControls();
    });
    scaleFont($('#scaleHeading'), 'headingId');
    scaleFont($('#scaleBody'), 'bodyId');
    $('#scaleUsePair').addEventListener('click', () => { if (st.current) useInScale(st.current); renderScaleControls(); renderScale(); });
    $('#scaleBase').addEventListener('change', e => {
      st.scale.base = Math.min(24, Math.max(12, Math.round(+e.target.value || 16)));
      persist(); renderScaleControls(); renderScale();
    });
    $('#scaleRatio').addEventListener('change', e => { st.scale.ratio = +e.target.value; persist(); renderScaleControls(); renderScale(); });
    $('#scaleLh').addEventListener('input', e => { st.scale.lh = +e.target.value; $('#scaleLhOut').textContent = fmt(st.scale.lh); persist(); renderScale(); });
    $('#scaleUnit').addEventListener('change', e => { st.scale.unit = e.target.value; persist(); renderScale(); });
    $('#scaleFormats').addEventListener('click', e => {
      const b = e.target.closest('[data-format]');
      if (!b) return;
      st.scale.format = b.dataset.format;
      persist();
      renderScale();
    });
    $('#scaleCopy').addEventListener('click', () => pp().copyText(exportText(st.scale.format), `${EXPORTS.find(x => x[0] === st.scale.format)[1]} code`));
    $('#scaleDownload').addEventListener('click', () => {
      const [id, , ext] = EXPORTS.find(x => x[0] === st.scale.format);
      const name = id === 'tailwind' ? 'tailwind.config' : `type-scale-${(scaleHeading().family + '-' + scaleBody().family).toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;
      pp().downloadBlob(new Blob([exportText(id)], { type: 'text/plain' }), `${name}.${ext}`);
    });
  }

  // ---------- Entry point (called by the router in app.js) ----------

  let current = null;
  async function show(view) {
    current = view;
    const status = $(`#view-${view} .type-status`);
    if (!FONTS.length) {
      status.hidden = false;
      status.textContent = 'Loading fonts…';
      try { await loadCatalog(); }
      catch (err) { status.textContent = `${err.message} Check your internet connection and reload.`; return; }
      status.hidden = true;
    }
    bind();
    if (current !== view) return;
    if (view === 'fonts') {
      $('#fontSearch').value = st.q;
      $('#fontSort').value = st.sort;
      $('#fontSample').value = st.sample;
      $('#fontSize').value = st.size;
      $('#fontSizeOut').textContent = `${st.size}px`;
      $('#fontLocalBtn').hidden = !('queryLocalFonts' in window);
      $('#fontLocalNote').textContent = 'queryLocalFonts' in window
        ? 'Your browser asks for permission first. The list stays on this computer.'
        : 'Listing installed fonts needs Chrome or Edge. Safari and Firefox don’t allow it.';
      renderFontChips();
      renderFonts();
    }
    if (view === 'pairing') {
      $('#pairMood').innerHTML = Object.entries(MOODS).map(([k, n]) => `<option value="${k}">${n}</option>`).join('');
      renderPairingControls();
      renderPairings();
    }
    if (view === 'scale') {
      renderScaleControls();
      renderScale();
    }
    if (view === 'fusion') showFusion();
  }

  window.TypeStudio = { show, fusionKey };
})();
