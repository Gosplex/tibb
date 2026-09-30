// Tibb Bridge page — "Tibb on a computer".
// Vanilla JS, zero dependencies, no external requests. Everything comes from
// the phone over the local Wi-Fi. The session token lives in memory only:
// closing the tab ends access on this computer.
'use strict';

(() => {
  const $ = (id) => document.getElementById(id);
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const state = {
    token: null,
    deviceId: loadDeviceId(),
    deviceName: '',
    phoneName: 'your phone',
    boxes: [],
    boxId: null,
    archived: false,
    seq: 0,
    items: [],
    knownIds: new Set(),
    loadedBoxKey: null,
    clipboard: null,
    clipOpen: false,
    query: '',
    polling: false,
    offline: false,
  };

  // ------------------------------------------------------------ helpers
  function loadDeviceId() {
    // Only a random id is remembered, so this browser keeps the name you gave it.
    try {
      let id = localStorage.getItem('tibb_device_id');
      if (!id) {
        id = crypto.randomUUID ? crypto.randomUUID() : fallbackUuid();
        localStorage.setItem('tibb_device_id', id);
      }
      return id;
    } catch (_) {
      return fallbackUuid();
    }
  }
  function fallbackUuid() {
    const b = new Uint8Array(16);
    crypto.getRandomValues(b);
    b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
    const h = [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
    return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
  }

  /** Creates an element. Text is always set with textContent — never innerHTML. */
  function el(tag, cls, text) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }
  const SVG = 'http://www.w3.org/2000/svg';
  function icon(name, cls) {
    const s = document.createElementNS(SVG, 'svg');
    s.setAttribute('class', `icon${cls ? ` ${cls}` : ''}`);
    s.setAttribute('aria-hidden', 'true');
    const u = document.createElementNS(SVG, 'use');
    u.setAttribute('href', `#i-${name}`);
    s.append(u);
    return s;
  }
  function iconButton(name, label, onClick) {
    const b = el('button', 'icon-btn');
    b.type = 'button';
    b.setAttribute('aria-label', label);
    b.dataset.tip = label;
    b.append(icon(name));
    b.addEventListener('click', (e) => { e.stopPropagation(); onClick(e); });
    return b;
  }
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  function toast(msg, opts = {}) {
    const region = $('toasts');
    const t = el('div', 'toast');
    t.append(el('span', null, msg));
    if (opts.action) {
      const b = el('button', null, opts.action.label);
      b.type = 'button';
      b.addEventListener('click', () => { opts.action.run(); dismiss(); });
      t.append(b);
    }
    region.append(t);
    while (region.children.length > 3) region.firstChild.remove();
    const dismiss = () => { t.classList.add('out'); setTimeout(() => t.remove(), 200); };
    setTimeout(dismiss, opts.action ? 8000 : 4000);
  }
  function announce(msg) { const l = $('live'); l.textContent = ''; setTimeout(() => { l.textContent = msg; }, 30); }

  class Unauthorized extends Error {}

  async function api(path, opts = {}) {
    const headers = Object.assign({}, opts.headers || {});
    if (state.token) headers.Authorization = `Bearer ${state.token}`;
    let body = opts.body;
    if (opts.json !== undefined) { headers['Content-Type'] = 'application/json'; body = JSON.stringify(opts.json); }
    const res = await fetch(path, { method: opts.method || 'GET', headers, body, signal: opts.signal, cache: 'no-store' });
    if (res.status === 401) throw new Unauthorized();
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { const e = new Error(data.error || `http_${res.status}`); e.status = res.status; e.data = data; throw e; }
    return data;
  }

  function blobUrl(item, download) {
    const q = new URLSearchParams({ t: state.token });
    if (download) { q.set('dl', '1'); q.set('name', item.fileName || 'tibb-file'); }
    return `/api/blob/${item.blobHash}?${q.toString()}`;
  }

  function copyText(text) {
    // navigator.clipboard needs a secure context; Bridge is plain HTTP on the LAN.
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).then(() => true, () => legacyCopy(text));
    }
    return Promise.resolve(legacyCopy(text));
  }
  function legacyCopy(text) {
    const ta = el('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.className = 'visually-hidden';
    document.body.append(ta);
    ta.select();
    let ok = false;
    try { ok = document.execCommand('copy'); } catch (_) { ok = false; }
    ta.remove();
    return ok;
  }
  async function copyAndSay(text) {
    toast((await copyText(text)) ? 'Copied' : 'Select the text and press Ctrl+C to copy it');
  }

  const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  function fmtTime(ms) {
    const d = new Date(ms);
    const h = d.getHours() % 12 || 12;
    return `${h}:${String(d.getMinutes()).padStart(2, '0')} ${d.getHours() < 12 ? 'AM' : 'PM'}`;
  }
  function fmtDay(ms) {
    const d = new Date(ms); const now = new Date();
    const day = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const diff = Math.round((today - day) / 86400000);
    if (diff === 0) return 'Today';
    if (diff === 1) return 'Yesterday';
    if (d.getFullYear() !== now.getFullYear()) return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
    return diff < 7 ? `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]}` : `${d.getDate()} ${MONTHS[d.getMonth()]}`;
  }
  function fmtDate(ms) { const d = new Date(ms); return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`; }
  function fmtBytes(n) {
    if (n == null) return '';
    if (n < 1024) return `${n} B`;
    const u = ['KB', 'MB', 'GB']; let v = n / 1024; let i = 0;
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
    return `${v.toFixed(v < 10 ? 1 : 0)} ${u[i]}`;
  }
  function fmtDuration(ms) {
    const s = Math.max(0, Math.round((ms || 0) / 1000));
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  }
  const fmtCount = (n) => Number(n || 0).toLocaleString('en-US');
  const plural = (n, one, many) => `${fmtCount(n)} ${n === 1 ? one : (many || `${one}s`)}`;

  const ACCENTS = { saffron: '#F5B324', coral: '#E8664F', rose: '#D9477E', plum: '#7B5CE6', ocean: '#2F7DD6', teal: '#13A08C', leaf: '#4E9A3A', slate: '#6E7580' };
  const ACCENTS_DARK = { saffron: '#F2B33D', coral: '#F08A76', rose: '#EE7AA3', plum: '#A796FF', ocean: '#7FB2F5', teal: '#3CC7B3', leaf: '#86C96F', slate: '#A4ABB6' };
  const dark = window.matchMedia('(prefers-color-scheme: dark)');
  function accentOf(color) { return (dark.matches ? ACCENTS_DARK : ACCENTS)[color] || ACCENTS.saffron; }
  function paintTile(node, box) {
    node.textContent = box ? box.emoji : '📦';
    node.style.setProperty('--accent', accentOf(box ? box.color : 'saffron'));
  }

  // Tooltips for icon-only buttons (design §9.8: 500 ms hover).
  let tipTimer;
  document.addEventListener('mouseover', (e) => {
    const t = e.target.closest && e.target.closest('[data-tip]');
    clearTimeout(tipTimer);
    const tip = $('tip');
    if (!t) { tip.hidden = true; return; }
    tipTimer = setTimeout(() => {
      tip.textContent = t.dataset.tip;
      tip.hidden = false;
      const r = t.getBoundingClientRect();
      const w = tip.offsetWidth;
      tip.style.left = `${Math.max(8, Math.min(window.innerWidth - w - 8, r.left + r.width / 2 - w / 2))}px`;
      tip.style.top = `${r.bottom + 6}px`;
    }, 500);
  });
  document.addEventListener('mousedown', () => { clearTimeout(tipTimer); $('tip').hidden = true; });

  // ------------------------------------------------------------ pairing
  const otpForm = $('pair-form');
  const otpInputs = [...otpForm.querySelectorAll('input')];
  otpInputs.forEach((i) => { i.placeholder = ' '; });

  function showPair(message) {
    state.token = null;
    closeWa(true);
    $('app').hidden = true;
    $('offline').hidden = true;
    $('viewer').hidden = true;
    $('pair').hidden = false;
    otpForm.classList.remove('success', 'invalid', 'shake');
    otpInputs.forEach((i) => { i.value = ''; i.disabled = false; });
    setPairError(message);
    otpInputs[0].focus();
  }
  function setPairError(message) {
    const err = $('pair-error');
    err.hidden = !message;
    err.querySelector('span').textContent = message || '';
  }

  otpInputs.forEach((input, idx) => {
    input.addEventListener('input', () => {
      input.value = input.value.replace(/\D/g, '').slice(-1);
      if (input.value && idx < otpInputs.length - 1) otpInputs[idx + 1].focus();
      otpForm.classList.remove('invalid');
      maybeSubmitCode();
    });
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Backspace' && !input.value && idx > 0) { otpInputs[idx - 1].focus(); otpInputs[idx - 1].value = ''; e.preventDefault(); }
      if (e.key === 'ArrowLeft' && idx > 0) otpInputs[idx - 1].focus();
      if (e.key === 'ArrowRight' && idx < 5) otpInputs[idx + 1].focus();
    });
    input.addEventListener('paste', (e) => {
      const digits = (e.clipboardData.getData('text') || '').replace(/\D/g, '').slice(0, 6);
      if (!digits) return;
      e.preventDefault();
      digits.split('').forEach((d, i) => { if (otpInputs[i]) otpInputs[i].value = d; });
      otpInputs[Math.min(digits.length, 5)].focus();
      maybeSubmitCode();
    });
  });
  otpForm.addEventListener('submit', (e) => e.preventDefault());

  let pairing = false;
  async function maybeSubmitCode() {
    const code = otpInputs.map((i) => i.value).join('');
    if (code.length !== 6 || pairing) return;
    pairing = true;
    otpForm.classList.remove('invalid', 'shake');
    try {
      const r = await api('/api/pair', { method: 'POST', json: { code, deviceId: state.deviceId } });
      state.token = r.token;
      state.deviceId = r.deviceId;
      state.deviceName = r.deviceName;
      state.phoneName = r.phoneName;
      setPairError(null);
      // Pairing success (design §10.4): the boxes collapse into a check, then the library opens.
      otpInputs.forEach((i) => { i.disabled = true; });
      otpForm.classList.add('success');
      await sleep(reduceMotion ? 120 : 620);
      await enterApp();
    } catch (e) {
      otpForm.classList.add('invalid');
      if (!reduceMotion) { void otpForm.offsetWidth; otpForm.classList.add('shake'); }
      const msg = e.message === 'expired' ? 'That code expired. Your phone is showing a new one.'
        : e.message === 'busy' ? 'Tibb is already connected to another computer. Disconnect it on your phone first.'
          : e.message === 'wrong_code' ? "That code didn't match. Check your phone for the current one."
            : "Couldn't reach your phone. Make sure Tibb is open and on the same Wi-Fi.";
      setPairError(msg);
      otpInputs.forEach((i) => { i.value = ''; });
      otpInputs[0].focus();
    } finally {
      pairing = false;
    }
  }

  async function enterApp() {
    $('pair').hidden = true;
    $('app').hidden = false;
    renderSkeleton();
    try {
      await refreshState({ first: true });
    } catch (e) {
      if (e instanceof Unauthorized) { showPair('Your session ended. Enter the new code from your phone.'); return; }
      setOffline(true);
    }
    startPolling();
    $('composer-input').focus();
    toast(`Connected to ${state.phoneName}`);
  }

  // ------------------------------------------------------------ data
  async function refreshState(opts = {}) {
    const s = await api('/api/state');
    const prevClip = state.clipboard && state.clipboard.id;
    state.boxes = s.boxes;
    state.phoneName = s.phoneName;
    state.clipboard = s.clipboard;
    state.seq = s.seq;
    const visible = state.boxes.filter((b) => !b.hidden);
    if (!state.boxId || !visible.some((b) => b.id === state.boxId)) {
      state.boxId = (visible.find((b) => b.id === s.defaultBoxId) || visible[0] || {}).id || null;
      state.archived = false;
    }
    renderRail();
    renderHeader();
    renderClipboard(!opts.first && state.clipboard && state.clipboard.id !== prevClip);
    if (state.query) await runSearch(state.query); else await loadItems();
  }

  async function loadItems() {
    const key = `${state.boxId}|${state.archived}`;
    if (!state.boxId) { state.items = []; renderThread(); return; }
    const q = new URLSearchParams({ box: state.boxId });
    if (state.archived) q.set('archived', '1');
    const r = await api(`/api/items?${q.toString()}`);
    const sameView = state.loadedBoxKey === key;
    const fresh = new Set();
    if (sameView) for (const it of r.items) if (!state.knownIds.has(it.id)) fresh.add(it.id);
    state.items = r.items;
    state.knownIds = new Set(r.items.map((i) => i.id));
    state.loadedBoxKey = key;
    renderThread(fresh, !sameView);
    const arrivals = r.items.filter((i) => fresh.has(i.id) && i.fromPhone);
    if (arrivals.length) announce(arrivals.length === 1 ? `New from ${state.phoneName}` : `${arrivals.length} new from ${state.phoneName}`);
  }

  async function startPolling() {
    if (state.polling) return;
    state.polling = true;
    let backoff = 1000;
    while (state.token) {
      try {
        const r = await api(`/api/events?since=${state.seq}`);
        if (state.offline) setOffline(false);
        backoff = 1000;
        if (r.seq > state.seq) await refreshState();
      } catch (e) {
        if (e instanceof Unauthorized) { state.polling = false; showPair('Your session ended. Enter the new code from your phone.'); return; }
        setOffline(true);
        await sleep(backoff);
        backoff = Math.min(backoff * 2, 10000);
      }
    }
    state.polling = false;
  }

  function setOffline(v) {
    if (state.offline === v) return;
    state.offline = v;
    $('offline').hidden = !v;
    $('conn').hidden = false;
    $('conn-text').textContent = v ? 'Looking for your phone…' : `Connected to ${state.phoneName}`;
    if (!v) toast(`Back in touch with ${state.phoneName}`);
  }

  // ------------------------------------------------------------ render: rail
  function currentBox() { return state.boxes.find((b) => b.id === state.boxId); }

  function renderRail() {
    const list = $('boxes');
    list.replaceChildren();
    const select = $('box-select');
    select.replaceChildren();
    for (const b of state.boxes) {
      const li = el('li');
      const btn = el('button', `rail-row${b.hidden ? ' locked' : ''}`);
      btn.type = 'button';
      btn.dataset.boxId = b.id;
      btn.dataset.tip = b.hidden ? `${b.name} (locked)` : b.name;
      if (b.id === state.boxId && !state.query) btn.setAttribute('aria-current', 'true');
      const tile = el('span', `box-tile${b.hidden ? ' locked' : ''}`);
      if (b.hidden) tile.append(icon('lock')); else paintTile(tile, b);
      const text = el('span', 'rail-text');
      const preview = el('span', 'preview');
      if (b.hidden) { preview.append(icon('lock', 'icon-sm'), document.createTextNode('Locked on your phone')); }
      else preview.textContent = b.preview || 'Nothing here yet';
      text.append(el('span', 'name', b.name), preview);
      btn.append(tile, text);
      if (!b.hidden && b.unreviewed > 0) btn.append(el('span', 'count', String(b.unreviewed)));
      btn.disabled = b.hidden;
      btn.setAttribute('aria-label', b.hidden ? `${b.name}, locked on your phone` : `${b.name}${b.unreviewed ? `, ${b.unreviewed} new` : ''}`);
      btn.addEventListener('click', () => openBox(b.id));
      li.append(btn);
      list.append(li);

      if (!b.hidden) {
        const opt = el('option', null, `${b.emoji}  ${b.name}`);
        opt.value = b.id;
        if (b.id === state.boxId) opt.selected = true;
        select.append(opt);
      }
    }
    $('rename').textContent = state.deviceName || 'Name this computer';
    $('conn-text').textContent = state.offline ? 'Looking for your phone…' : `Connected to ${state.phoneName}`;
  }

  async function openBox(id, highlightId) {
    const changed = id !== state.boxId || state.query || state.archived;
    state.boxId = id; state.query = ''; state.archived = false;
    $('search').value = ''; $('search-2').value = '';
    closeDrawer();
    renderRail(); renderHeader(true);
    if (changed) renderSkeleton();
    try { await loadItems(); } catch (e) { handleError(e); }
    if (highlightId) {
      const row = document.querySelector(`.row[data-id="${CSS.escape(highlightId)}"]`);
      if (row) {
        row.scrollIntoView({ block: 'center', behavior: reduceMotion ? 'auto' : 'smooth' });
        row.classList.add('highlight');
        setTimeout(() => row.classList.remove('highlight'), 1400);
      }
    }
  }

  function renderHeader(switching) {
    const b = currentBox();
    const title = $('box-name');
    const sub = $('box-sub');
    const tile = $('box-tile');
    if (state.query) {
      title.textContent = `Results for “${state.query}”`;
      sub.textContent = 'Across all your boxes. Locked boxes aren’t searched.';
      tile.textContent = '🔎';
      tile.style.setProperty('--accent', accentOf('slate'));
    } else {
      title.textContent = state.archived ? `Archived in ${b ? b.name : 'this box'}` : (b ? b.name : 'Tibb');
      const n = state.items.length;
      sub.textContent = state.archived ? 'Still searchable. Unarchive anything to bring it back.'
        : b && b.unreviewed ? `${b.unreviewed} new since you last looked` : `On ${state.phoneName}`;
      if (!state.items.length && state.loadedBoxKey) sub.textContent = state.archived ? 'Nothing archived here.' : `On ${state.phoneName}`;
      paintTile(tile, b);
      void n;
    }
    const arch = $('toggle-archive');
    arch.setAttribute('aria-pressed', String(state.archived));
    arch.hidden = !!state.query;
    $('drop-box-name').textContent = b ? `into ${b.name}` : '';
    if (switching && !reduceMotion) {
      const t = document.querySelector('.header-title');
      t.classList.remove('switching'); void t.offsetWidth; t.classList.add('switching');
    }
  }

  // ------------------------------------------------------------ render: clipboard
  function renderClipboard(arrived) {
    const card = $('clip-card');
    const c = state.clipboard;
    const entry = $('clip-entry');
    entry.classList.toggle('has-clip', !!c);
    $('clip-entry-sub').textContent = c ? (c.text || '').replace(/\s+/g, ' ') : 'Paste anywhere to send';
    card.replaceChildren();
    if (!c && !state.clipOpen) { card.hidden = true; return; }
    card.hidden = false;
    if (c) {
      const inner = el('div', 'clip-inner');
      const from = c.fromPhone ? state.phoneName : (c.originName || 'this computer');
      const left = c.expiresAt ? Math.max(0, Math.round((c.expiresAt - Date.now()) / 3600000)) : null;
      const body = el('div');
      body.append(
        el('div', 'caption tertiary', `Clipboard from ${from}${left != null ? ` · clears in ${left} h` : ''}`),
        el('div', 'clip-text', c.text || ''),
      );
      const actions = el('div', 'clip-actions');
      const copy = el('button', 'btn btn-sm btn-primary');
      copy.type = 'button';
      copy.append(icon('copy', 'icon-sm'), el('span', null, 'Copy'));
      copy.addEventListener('click', () => copyAndSay(c.text || ''));
      actions.append(copy);
      inner.append(el('span', 'clip-icon'), body, actions);
      inner.firstChild.append(icon('clip'));
      if (!arrived) inner.style.animation = 'none';
      card.append(inner);
    }
    if (state.clipOpen) {
      const form = el('form', 'clip-send');
      const input = el('input');
      input.id = 'clip-input';
      input.placeholder = 'Paste text to send to your phone’s clipboard';
      input.setAttribute('aria-label', 'Text to send to your phone’s clipboard');
      const send = el('button', 'btn btn-md btn-secondary', 'Send to phone');
      send.type = 'submit';
      form.append(input, send);
      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const text = input.value.trim();
        if (!text) return;
        if (await sendClipboard(text)) { input.value = ''; state.clipOpen = false; renderClipboard(); }
      });
      card.append(form);
    }
    if (arrived && c && c.fromPhone) toast(`Clipboard from ${state.phoneName} — ready to copy`);
  }

  async function sendClipboard(text) {
    try {
      await api('/api/clipboard', { method: 'POST', json: { text } });
      toast('Sent to your phone’s clipboard');
      return true;
    } catch (e) { handleError(e, "Couldn't send — check your phone is still connected."); return false; }
  }

  $('clip-entry').addEventListener('click', () => {
    state.clipOpen = !state.clipOpen || !state.clipboard;
    closeDrawer();
    renderClipboard();
    const input = $('clip-input');
    if (input) input.focus();
  });

  // ------------------------------------------------------------ render: thread
  function renderSkeleton() {
    const inner = $('thread-inner');
    inner.replaceChildren();
    const widths = [[46, 'r'], [62, ''], [38, 'r'], [54, 'r'], [30, '']];
    for (const [w, side] of widths) {
      const row = el('div', `skeleton-row ${side}`);
      const sk = el('div', 'skeleton');
      sk.style.width = `${w}%`;
      row.append(sk);
      inner.append(row);
    }
  }

  function artOpenBox() {
    const s = document.createElementNS(SVG, 'svg');
    s.setAttribute('class', 'art'); s.setAttribute('viewBox', '0 0 160 120'); s.setAttribute('aria-hidden', 'true');
    const shapes = [
      ['ellipse', { class: 'art-ground', cx: 80, cy: 109, rx: 52, ry: 5 }],
      ['rect', { class: 'art-saffron', x: 64, y: 30, width: 32, height: 38, rx: 4, transform: 'rotate(6 80 52)' }],
      ['rect', { class: 'art-paper', x: 40, y: 58, width: 80, height: 46, rx: 10 }],
      ['path', { class: 'art-line', d: 'M40 70h80M72 82h16' }],
      ['rect', { class: 'art-paper', x: 36, y: 42, width: 88, height: 14, rx: 6, transform: 'rotate(-14 36 56)' }],
    ];
    for (const [tag, attrs] of shapes) {
      const n = document.createElementNS(SVG, tag);
      for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, String(v));
      s.append(n);
    }
    return s;
  }

  function emptyState(headline, body, action) {
    const e = el('div', 'empty');
    e.append(artOpenBox(), el('h2', null, headline), el('p', 'body-md secondary', body));
    if (action) e.append(action);
    return e;
  }

  const sameGroup = (a, b) => a && b && a.origin === b.origin && Math.abs(b.createdAt - a.createdAt) < 120000 && fmtDay(a.createdAt) === fmtDay(b.createdAt);

  function renderThread(fresh = new Set(), jump = true) {
    const thread = $('thread');
    const inner = $('thread-inner');
    const nearBottom = thread.scrollHeight - thread.scrollTop - thread.clientHeight < 120;
    inner.replaceChildren();
    renderHeader();
    if (!state.items.length) {
      if (state.archived) {
        inner.append(emptyState('Nothing archived.', 'Archive items from here or your phone to tidy them away. They stay searchable.'));
      } else {
        const btn = el('button', 'btn btn-md btn-secondary');
        btn.type = 'button';
        btn.append(icon('attach', 'icon-sm'), el('span', null, 'Choose files'));
        btn.addEventListener('click', () => $('file-input').click());
        inner.append(emptyState('Nothing here yet.', 'Drop a file anywhere, paste something, or type below. It lands on your phone in a second.', btn));
      }
      return;
    }
    // Items arrive newest-first; the newest sits at the bottom.
    const ordered = [...state.items].sort((a, b) => a.createdAt - b.createdAt);
    const pinned = ordered.filter((i) => i.pinned);
    const rest = ordered.filter((i) => !i.pinned);
    if (pinned.length && !state.archived) {
      inner.append(el('div', 'overline results-head', `Pinned · ${pinned.length}`));
      pinned.forEach((it, i) => inner.append(rowFor(it, { tail: !sameGroup(it, pinned[i + 1]), fresh: fresh.has(it.id) })));
    }
    const list = state.archived ? ordered : rest;
    let lastDay = null; let prev = null; let dividerShown = false;
    list.forEach((item, i) => {
      const day = fmtDay(item.createdAt);
      if (day !== lastDay) { inner.append(el('div', 'day caption', day)); lastDay = day; prev = null; }
      if (!state.archived && !item.reviewed && !dividerShown && i > 0) { inner.append(el('div', 'unreviewed-divider caption', 'New since you last looked')); dividerShown = true; }
      if (!item.fromPhone && !sameGroup(prev, item)) {
        const o = el('div', `origin${fresh.has(item.id) ? ' fresh' : ''}`);
        o.append(icon('desktop', 'icon-sm'), el('span', null, item.originName || 'A computer'));
        inner.append(o);
      }
      inner.append(rowFor(item, { tail: !sameGroup(item, list[i + 1]), fresh: fresh.has(item.id) }));
      prev = item;
    });
    if (jump || nearBottom || fresh.size) {
      requestAnimationFrame(() => { thread.scrollTop = thread.scrollHeight; });
    }
  }

  function rowFor(item, { tail, fresh, query }) {
    const row = el('div', `row ${item.fromPhone ? 'self' : 'other'}${tail ? ' tail' : ''}`);
    row.dataset.id = item.id;
    row.append(bubbleFor(item, fresh, query), actionsFor(item));
    return row;
  }

  function actionsFor(item) {
    const a = el('div', 'actions');
    if (item.text && item.type !== 'image') a.append(iconButton('copy', 'Copy', () => copyAndSay(item.text)));
    if (item.blobHash) {
      const d = iconButton('download', 'Download', () => { location.href = blobUrl(item, true); });
      a.append(d);
    }
    if (state.query) {
      a.append(iconButton('open', 'Show in box', () => openBox(item.boxId, item.id)));
      return a;
    }
    a.append(iconButton('pin', item.pinned ? 'Unpin' : 'Pin', () => updateItem(item, { pinned: !item.pinned })));
    a.append(iconButton(item.archived ? 'unarchive' : 'archive', item.archived ? 'Unarchive' : 'Archive',
      () => updateItem(item, { archived: !item.archived })));
    return a;
  }

  async function updateItem(item, patch) {
    const row = document.querySelector(`.row[data-id="${CSS.escape(item.id)}"]`);
    if ('archived' in patch && row && !reduceMotion) { row.style.maxHeight = `${row.offsetHeight}px`; row.classList.add('leaving'); }
    try {
      await api('/api/items/update', { method: 'POST', json: Object.assign({ id: item.id }, patch) });
      if ('archived' in patch) {
        toast(patch.archived ? 'Archived' : 'Back in the box', {
          action: { label: 'Undo', run: () => updateItem(Object.assign({}, item, patch), { archived: !patch.archived }) },
        });
      } else toast(patch.pinned ? 'Pinned' : 'Unpinned');
      await loadItems();
    } catch (e) {
      if (row) { row.classList.remove('leaving'); row.style.maxHeight = ''; }
      handleError(e, "Couldn't change that — check your phone is still connected.");
    }
  }

  function highlight(parent, text, query) {
    const terms = (query || '').trim().split(/\s+/).filter(Boolean).map((t) => t.toLowerCase());
    if (!terms.length) { parent.append(document.createTextNode(text)); return; }
    const lower = text.toLowerCase();
    let i = 0;
    while (i < text.length) {
      let best = -1; let len = 0;
      for (const t of terms) {
        const at = lower.indexOf(t, i);
        if (at !== -1 && (best === -1 || at < best)) { best = at; len = t.length; }
      }
      if (best === -1) { parent.append(document.createTextNode(text.slice(i))); break; }
      if (best > i) parent.append(document.createTextNode(text.slice(i, best)));
      parent.append(el('mark', null, text.slice(best, best + len)));
      i = best + len;
    }
  }

  function linkify(parent, text, query) {
    const re = /https?:\/\/[^\s<>"]+/gi;
    let last = 0; let m;
    while ((m = re.exec(text)) !== null) {
      if (m.index > last) highlight(parent, text.slice(last, m.index), query);
      const a = el('a', null, m[0]);
      a.href = m[0]; a.target = '_blank'; a.rel = 'noopener noreferrer';
      parent.append(a);
      last = m.index + m[0].length;
    }
    if (last < text.length) highlight(parent, text.slice(last), query);
  }

  function hashBars(seed, n) {
    let h = 2166136261;
    for (let i = 0; i < seed.length; i++) { h ^= seed.charCodeAt(i); h = Math.imul(h, 16777619); }
    const bars = [];
    for (let i = 0; i < n; i++) { h ^= h << 13; h ^= h >>> 17; h ^= h << 5; bars.push(0.25 + ((h >>> 0) % 1000) / 1333); }
    return bars;
  }

  function voicePlayer(item) {
    const wrap = el('div', 'voice');
    const btn = el('button', 'voice-play');
    btn.type = 'button';
    btn.setAttribute('aria-label', 'Play voice memo');
    btn.append(icon('play', 'i-play'));
    const wave = el('div', 'wave');
    wave.setAttribute('role', 'slider');
    wave.setAttribute('aria-label', 'Seek');
    const bars = hashBars(item.id, 28).map((v) => { const b = el('i'); b.style.height = `${Math.round(v * 24)}px`; wave.append(b); return b; });
    const time = el('span', 'voice-time', fmtDuration(item.durationMs));
    const audio = el('audio');
    audio.preload = 'none';
    audio.src = blobUrl(item);
    const paint = () => {
      const d = audio.duration && isFinite(audio.duration) ? audio.duration : (item.durationMs || 1) / 1000;
      const p = audio.currentTime / d;
      bars.forEach((b, i) => b.classList.toggle('on', i / bars.length < p));
      time.textContent = audio.paused && audio.currentTime === 0 ? fmtDuration(item.durationMs) : fmtDuration(audio.currentTime * 1000);
    };
    const setIcon = (name) => { btn.replaceChildren(icon(name, name === 'play' ? 'i-play' : '')); btn.setAttribute('aria-label', name === 'play' ? 'Play voice memo' : 'Pause'); };
    btn.addEventListener('click', () => {
      if (audio.paused) {
        document.querySelectorAll('audio').forEach((a) => { if (a !== audio) a.pause(); });
        audio.play().catch(() => toast("Couldn't play this memo in the browser. Download it instead."));
      } else audio.pause();
    });
    audio.addEventListener('play', () => setIcon('pause'));
    audio.addEventListener('pause', () => setIcon('play'));
    audio.addEventListener('ended', () => { audio.currentTime = 0; paint(); });
    audio.addEventListener('timeupdate', paint);
    wave.addEventListener('click', (e) => {
      const r = wave.getBoundingClientRect();
      const d = audio.duration && isFinite(audio.duration) ? audio.duration : (item.durationMs || 0) / 1000;
      if (!d) return;
      audio.currentTime = ((e.clientX - r.left) / r.width) * d;
      if (audio.paused) audio.play().catch(() => {});
    });
    wrap.append(btn, wave, time, audio);
    return wrap;
  }

  function fileIconLabel(item) {
    const name = item.fileName || '';
    const ext = name.includes('.') ? name.split('.').pop().slice(0, 4).toUpperCase() : 'FILE';
    return ext || 'FILE';
  }
  function middleEllipsis(name, max = 44) {
    if (!name || name.length <= max) return name || 'File';
    const dot = name.lastIndexOf('.');
    const ext = dot > 0 && name.length - dot <= 6 ? name.slice(dot) : '';
    const keep = max - ext.length - 1;
    return `${name.slice(0, Math.ceil(keep * 0.7))}…${name.slice(name.length - ext.length - Math.floor(keep * 0.3))}`;
  }

  function bubbleFor(item, fresh, query) {
    const bubble = el('div', `bubble${fresh ? ' fresh' : ''}`);
    switch (item.type) {
      case 'image':
      case 'video': {
        bubble.classList.add('media');
        const thumb = el('button', 'thumb');
        thumb.type = 'button';
        thumb.setAttribute('aria-label', item.type === 'image' ? `Open photo${item.fileName ? `, ${item.fileName}` : ''}` : 'Play video');
        if (item.type === 'image') {
          const img = el('img');
          img.loading = 'lazy'; img.decoding = 'async'; img.alt = '';
          img.addEventListener('load', () => img.classList.add('loaded'));
          img.addEventListener('error', () => { img.classList.add('loaded'); thumb.classList.add('broken'); });
          img.src = blobUrl(item);
          thumb.append(img);
        } else {
          const v = el('video');
          v.preload = 'metadata'; v.muted = true;
          v.addEventListener('loadeddata', () => v.classList.add('loaded'));
          v.src = `${blobUrl(item)}#t=0.1`;
          const badge = el('span', 'play-badge');
          badge.append(icon('play'));
          thumb.append(v, badge);
        }
        thumb.addEventListener('click', () => openViewer(item));
        bubble.append(thumb);
        break;
      }
      case 'voice':
        bubble.append(voicePlayer(item));
        break;
      case 'file': {
        const a = el('a', 'file');
        const isPdf = (item.mime || '') === 'application/pdf';
        a.href = isPdf ? blobUrl(item) : blobUrl(item, true);
        if (isPdf) { a.target = '_blank'; a.rel = 'noopener'; }
        a.title = item.fileName || '';
        const tile = el('span', 'file-tile', fileIconLabel(item));
        tile.style.setProperty('--accent', accentOf((currentBox() || {}).color));
        const info = el('span', 'file-info');
        const nm = el('span', 'file-name');
        highlight(nm, middleEllipsis(item.fileName), query);
        info.append(nm, el('span', 'file-meta', `${fmtBytes(item.size)} · ${isPdf ? 'PDF — opens in a tab' : 'click to download'}`));
        a.append(tile, info);
        bubble.append(a);
        break;
      }
      case 'link': {
        const url = item.text || '';
        let domain = url;
        try { domain = new URL(url).hostname.replace(/^www\./, ''); } catch (_) { /* keep raw */ }
        const a = el('a', 'linkcard');
        a.href = url; a.target = '_blank'; a.rel = 'noopener noreferrer';
        const u = el('span', 'url');
        highlight(u, url, query);
        a.append(icon('link'), el('span', 'domain', domain), u);
        bubble.append(a);
        break;
      }
      default: {
        const t = el('div', 'text');
        linkify(t, item.text || '', query);
        bubble.append(t);
      }
    }
    if (item.note) {
      const n = el('div', 'note');
      n.append(icon('note'));
      const span = el('span');
      highlight(span, item.note, query);
      n.append(span);
      bubble.append(n);
    }
    const meta = el('div', 'meta');
    if (item.source === 'whatsapp') meta.append(el('span', 'tag', 'WhatsApp'));
    if (item.pinned) meta.append(icon('pin'));
    meta.append(el('span', null, state.query ? `${fmtDay(item.createdAt)}, ${fmtTime(item.createdAt)}` : fmtTime(item.createdAt)));
    bubble.append(meta);
    return bubble;
  }

  // ------------------------------------------------------------ viewer
  let viewerReturn = null;
  function openViewer(item) {
    viewerReturn = document.activeElement;
    const stage = $('viewer-stage');
    stage.replaceChildren();
    if (item.type === 'image') {
      const img = el('img'); img.alt = item.fileName || 'Photo'; img.src = blobUrl(item);
      stage.append(img);
    } else {
      const v = el('video'); v.controls = true; v.autoplay = false; v.src = blobUrl(item); v.preload = 'metadata';
      stage.append(v);
    }
    $('viewer-name').textContent = item.fileName || (item.type === 'image' ? 'Photo' : 'Video');
    $('viewer-sub').textContent = `${item.fromPhone ? `From ${state.phoneName}` : `From ${item.originName || 'a computer'}`} · ${fmtDay(item.createdAt)}, ${fmtTime(item.createdAt)}${item.size ? ` · ${fmtBytes(item.size)}` : ''}`;
    const dl = $('viewer-download');
    dl.href = blobUrl(item, true);
    $('viewer').hidden = false;
    $('viewer-close').focus();
  }
  function closeViewer() {
    if ($('viewer').hidden) return;
    $('viewer').hidden = true;
    $('viewer-stage').replaceChildren();
    if (viewerReturn && viewerReturn.focus) viewerReturn.focus();
  }
  $('viewer-close').addEventListener('click', closeViewer);
  $('viewer-stage').addEventListener('click', (e) => { if (e.target === e.currentTarget) closeViewer(); });

  // ------------------------------------------------------------ search
  let searchTimer;
  function onSearchInput(e) {
    clearTimeout(searchTimer);
    const q = e.target.value.trim();
    const other = e.target.id === 'search' ? $('search-2') : $('search');
    other.value = e.target.value;
    searchTimer = setTimeout(async () => {
      state.query = q;
      renderRail(); renderHeader();
      try { if (q) await runSearch(q); else { state.loadedBoxKey = null; await loadItems(); } } catch (err) { handleError(err); }
    }, 220);
  }
  $('search').addEventListener('input', onSearchInput);
  $('search-2').addEventListener('input', onSearchInput);

  async function runSearch(q) {
    const r = await api(`/api/search?q=${encodeURIComponent(q)}`);
    if (state.query !== q) return;
    const inner = $('thread-inner');
    inner.replaceChildren();
    renderHeader();
    if (!r.results.length) {
      inner.append(emptyState(`Nothing matches “${q}”.`, 'Try fewer words, or part of a word. Archived items are included; locked boxes aren’t searched.'));
      return;
    }
    inner.append(el('p', 'caption tertiary results-head', plural(r.results.length, 'result')));
    // Group by box (brief §7.5).
    const groups = new Map();
    for (const it of r.results) { if (!groups.has(it.boxId)) groups.set(it.boxId, []); groups.get(it.boxId).push(it); }
    for (const [boxId, items] of groups) {
      const b = state.boxes.find((x) => x.id === boxId) || { emoji: items[0].boxEmoji, name: items[0].boxName, color: 'saffron' };
      const head = el('div', 'result-box');
      const tile = el('span', 'box-tile'); paintTile(tile, b);
      head.append(tile, el('span', 'title-sm', b.name));
      inner.append(head);
      for (const it of items) inner.append(rowFor(it, { tail: true, fresh: false, query: q }));
    }
    $('thread').scrollTop = 0;
  }

  // ------------------------------------------------------------ composer
  const composerInput = $('composer-input');
  const sendBtn = $('send');
  function autosize() {
    composerInput.style.height = 'auto';
    composerInput.style.height = `${Math.min(composerInput.scrollHeight, 160)}px`;
    sendBtn.disabled = !composerInput.value.trim();
  }
  composerInput.addEventListener('input', autosize);
  composerInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); $('composer').requestSubmit(); }
  });
  $('composer').addEventListener('submit', async (e) => {
    e.preventDefault();
    const text = composerInput.value.trim();
    if (!text) return;
    composerInput.value = ''; autosize();
    const ok = await saveText(text);
    if (!ok) { composerInput.value = text; autosize(); }
  });

  async function saveText(text) {
    try {
      await api('/api/items', { method: 'POST', json: { boxId: state.boxId, text } });
      toast('Saved to your phone');
      if (state.archived || state.query) await openBox(state.boxId); else await loadItems();
      return true;
    } catch (e) {
      handleError(e, "Couldn't save — check your phone is still connected. Your text is still here.");
      return false;
    }
  }

  function handleError(e, msg) {
    if (e instanceof Unauthorized) { showPair('Your session ended. Enter the new code from your phone.'); return; }
    if (e && e.message === 'box_unavailable') { toast('That box is locked on your phone.'); return; }
    toast(msg || "Couldn't reach your phone right now.");
  }

  // ------------------------------------------------------------ uploads
  $('attach').addEventListener('click', () => $('file-input').click());
  $('attach-top').addEventListener('click', () => $('file-input').click());
  $('file-input').addEventListener('change', (e) => { uploadFiles([...e.target.files]); e.target.value = ''; });

  const uploads = { active: 0, done: 0, failed: 0 };
  function uploadFiles(files) {
    if (!files.length || !state.token) return;
    const tray = $('tray');
    const list = $('tray-list');
    if (!uploads.active) { list.replaceChildren(); uploads.done = 0; uploads.failed = 0; }
    tray.hidden = false;
    $('tray-title').textContent = 'Sending to your phone';
    const box = currentBox();
    for (const file of files) {
      uploads.active++;
      const row = el('div', 'transfer');
      const name = el('span', 'name', file.name);
      name.title = file.name;
      const xhr = new XMLHttpRequest();
      const cancel = iconButton('close', 'Cancel', () => xhr.abort());
      const bar = el('div', 'progress'); const fill = el('span'); bar.append(fill);
      const meta = el('span', 'meta', `0 / ${fmtBytes(file.size)}`);
      row.append(name, cancel, bar, meta);
      list.append(row);

      const q = new URLSearchParams({ box: state.boxId || '', name: file.name });
      xhr.open('POST', `/api/upload?${q.toString()}`);
      xhr.setRequestHeader('Authorization', `Bearer ${state.token}`);
      xhr.setRequestHeader('Content-Type', file.type || 'application/octet-stream');
      xhr.upload.onprogress = (ev) => {
        if (!ev.lengthComputable) return;
        fill.style.width = `${(ev.loaded / ev.total) * 100}%`;
        meta.textContent = `${fmtBytes(ev.loaded)} / ${fmtBytes(ev.total)}`;
        if (ev.loaded === ev.total) meta.textContent = 'Saving on your phone…';
      };
      const finish = (ok, text) => {
        uploads.active--;
        cancel.remove();
        row.classList.add(ok ? 'done' : 'failed');
        meta.textContent = text;
        if (ok) { uploads.done++; fill.style.width = '100%'; } else uploads.failed++;
        finishTray(box);
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) finish(true, `Saved · ${fmtBytes(file.size)}`);
        else if (xhr.status === 401) { finish(false, 'Session ended'); showPair('Your session ended.'); }
        else if (xhr.status === 403) finish(false, 'That box is locked on your phone');
        else finish(false, "Couldn't save this file — your phone may be out of space");
      };
      xhr.onerror = () => finish(false, 'Connection lost — try again');
      xhr.onabort = () => finish(false, 'Cancelled');
      xhr.send(file);
    }
  }
  let trayTimer;
  function finishTray(box) {
    if (uploads.active > 0) return;
    const tray = $('tray');
    clearTimeout(trayTimer);
    if (uploads.done) {
      $('tray-title').textContent = `${plural(uploads.done, 'file')} saved to your phone${box ? ` · ${box.name}` : ''}`;
      announce(`${plural(uploads.done, 'file')} saved to your phone`);
    } else {
      $('tray-title').textContent = 'Nothing was sent';
    }
    trayTimer = setTimeout(() => { if (uploads.active === 0) { tray.hidden = true; $('tray-list').replaceChildren(); } }, uploads.failed ? 8000 : 4000);
  }

  // Drag & drop anywhere (design §9.9)
  let dragDepth = 0;
  const hasFiles = (e) => e.dataTransfer && [...e.dataTransfer.types].includes('Files');
  window.addEventListener('dragenter', (e) => {
    if (!state.token || !hasFiles(e)) return;
    e.preventDefault();
    dragDepth++;
    if ($('wa').open) return; // the import dialog has its own drop zone
    $('drop').hidden = false;
  });
  window.addEventListener('dragover', (e) => {
    if (!hasFiles(e)) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
    $('drop').classList.toggle('over', !!(e.target.closest && e.target.closest('.drop-box')));
  });
  window.addEventListener('dragleave', () => { dragDepth = Math.max(0, dragDepth - 1); if (!dragDepth) $('drop').hidden = true; });
  window.addEventListener('drop', (e) => {
    if (!hasFiles(e)) return;
    e.preventDefault();
    dragDepth = 0; $('drop').hidden = true; $('drop').classList.remove('over');
    if (!state.token) return;
    const files = [...e.dataTransfer.files];
    if ($('wa').open) { waUpload(files[0]); return; }
    const wa = files.length === 1 && /whatsapp.*\.zip$/i.test(files[0].name);
    if (wa) {
      toast('That looks like a WhatsApp export.', { action: { label: 'Import it instead', run: () => { openWa(); waUpload(files[0]); } } });
    }
    uploadFiles(files);
  });

  // Paste anywhere outside a field: files are saved, text goes to the phone's
  // clipboard card (brief §7.10, Clipboard Bridge).
  document.addEventListener('paste', (e) => {
    if (!state.token || !$('pair').hidden) return;
    const t = e.target;
    const inField = t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA');
    const files = [...(e.clipboardData.files || [])];
    if (files.length) { e.preventDefault(); uploadFiles(files); return; }
    if (inField) return;
    const text = (e.clipboardData.getData('text') || '').trim();
    if (text) { e.preventDefault(); sendClipboard(text); }
  });

  // ------------------------------------------------------------ keyboard
  document.addEventListener('keydown', (e) => {
    const t = e.target;
    const typing = t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.tagName === 'SELECT');
    if (e.key === '/' && !typing && state.token && $('pair').hidden) {
      e.preventDefault();
      const s = getComputedStyle($('search').closest('.search')).display !== 'none' ? $('search') : $('search-2');
      s.focus();
    }
    if (e.key === 'Escape') {
      $('drop').hidden = true; dragDepth = 0;
      if (!$('viewer').hidden) { closeViewer(); return; }
      if (document.querySelector('.rail.open')) { closeDrawer(); return; }
      if (t && (t.id === 'search' || t.id === 'search-2') && t.value) { t.value = ''; t.dispatchEvent(new Event('input')); }
    }
    if ((e.key === 'ArrowDown' || e.key === 'ArrowUp') && t && t.classList && t.classList.contains('rail-row') && t.dataset.boxId) {
      e.preventDefault();
      const rows = [...document.querySelectorAll('#boxes .rail-row:not(:disabled)')];
      const i = rows.indexOf(t);
      const next = rows[i + (e.key === 'ArrowDown' ? 1 : -1)];
      if (next) next.focus();
    }
    if ((e.key === 'c' || e.key === 'C') && !typing && !e.ctrlKey && !e.metaKey && t && t.closest && t.closest('#clip-card') && state.clipboard) {
      copyAndSay(state.clipboard.text || '');
    }
  });

  $('thread').addEventListener('scroll', () => {
    const th = $('thread');
    document.querySelector('.main-header').classList.toggle('scrolled', th.scrollTop < th.scrollHeight - th.clientHeight - 4);
  }, { passive: true });

  // ------------------------------------------------------------ header + drawer
  $('toggle-archive').addEventListener('click', async () => {
    state.archived = !state.archived;
    renderSkeleton();
    renderHeader(true);
    try { await loadItems(); } catch (e) { handleError(e); }
  });
  $('box-select').addEventListener('change', (e) => openBox(e.target.value));
  function closeDrawer() {
    document.querySelector('.rail').classList.remove('open');
    $('rail-scrim').classList.remove('open');
    $('menu').setAttribute('aria-expanded', 'false');
  }
  $('menu').addEventListener('click', () => {
    const rail = document.querySelector('.rail');
    const open = !rail.classList.contains('open');
    rail.classList.toggle('open', open);
    $('rail-scrim').classList.toggle('open', open);
    $('menu').setAttribute('aria-expanded', String(open));
  });
  $('rail-scrim').addEventListener('click', closeDrawer);

  // ------------------------------------------------------------ rename / disconnect
  document.querySelectorAll('dialog [data-close]').forEach((b) => b.addEventListener('click', () => b.closest('dialog').close()));
  $('rename').addEventListener('click', () => {
    $('rename-input').value = state.deviceName || '';
    $('rename-dialog').showModal();
    $('rename-input').select();
  });
  $('rename-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = $('rename-input').value.trim().slice(0, 40);
    if (!name) return;
    try {
      await api('/api/device', { method: 'POST', json: { name } });
      state.deviceName = name;
      renderRail();
      $('rename-dialog').close();
      toast(`Your phone now calls this computer “${name}”`);
    } catch (err) { handleError(err, "Couldn't rename right now."); }
  });

  $('disconnect').addEventListener('click', async () => {
    try { await api('/api/session', { method: 'DELETE' }); } catch (_) { /* already gone */ }
    showPair('Disconnected. Enter a new code from your phone to connect again.');
  });

  $('reconnect').addEventListener('click', async () => {
    const b = $('reconnect');
    b.disabled = true;
    try { await refreshState(); setOffline(false); startPolling(); } catch (e) {
      if (e instanceof Unauthorized) showPair('Your session ended. Enter the new code from your phone.');
      else toast('Still can’t reach your phone. Is Tibb open, on the same Wi-Fi?');
    } finally { b.disabled = false; }
  });

  // ------------------------------------------------------------ WhatsApp import (from the computer)
  const wa = { preview: null, senders: new Set(), includeMedia: true, polling: false, xhr: null };
  $('wa-open').addEventListener('click', () => { closeDrawer(); openWa(); });
  $('wa').addEventListener('close', () => { if (wa.xhr) wa.xhr.abort(); });

  function openWa() {
    if (!$('wa').open) $('wa').showModal();
    if (!wa.polling) waIntro();
  }
  function closeWa(silent) {
    if ($('wa').open) $('wa').close();
    if (silent) wa.preview = null;
  }
  function waBody(...nodes) { $('wa-body').replaceChildren(...nodes); }
  function infoCard(kind, title, body) {
    const c = el('div', `info-card${kind ? ` ${kind}` : ''}`);
    const t = el('div');
    t.append(el('p', 'title-sm', title));
    if (body) t.append(el('p', 'body-sm secondary', body));
    c.append(icon(kind === 'error' ? 'warn' : kind === 'success' ? 'check' : 'box'), t);
    return c;
  }

  function waIntro(error) {
    const steps = el('ol', 'wa-steps');
    for (const s of [
      'On your phone, open WhatsApp and the chat you message yourself in.',
      'Tap the chat name (iPhone) or ⋮ → More (Android), then Export chat → Include media.',
      'Send the .zip to this computer — or save it — then drop it below.',
    ]) steps.append(el('li', 'body-md', s));
    const drop = el('button', 'wa-drop');
    drop.type = 'button';
    drop.append(icon('download', 'icon-lg'), el('span', 'title-sm', 'Drop the exported .zip here'), el('span', 'body-sm secondary', 'or click to choose it'));
    const input = el('input');
    input.type = 'file'; input.accept = '.zip,.txt'; input.hidden = true;
    input.addEventListener('change', () => { if (input.files[0]) waUpload(input.files[0]); });
    drop.addEventListener('click', () => input.click());
    drop.addEventListener('dragover', (e) => { e.preventDefault(); drop.classList.add('over'); });
    drop.addEventListener('dragleave', () => drop.classList.remove('over'));
    drop.addEventListener('drop', (e) => { e.preventDefault(); e.stopPropagation(); drop.classList.remove('over'); dragDepth = 0; if (e.dataTransfer.files[0]) waUpload(e.dataTransfer.files[0]); });
    const nodes = [el('p', 'body-md secondary', 'Bring years of notes-to-self into Tibb. The export goes straight to your phone and is read there — nothing touches the internet.'), steps];
    if (error) nodes.push(infoCard('error', "That file didn't work", error));
    nodes.push(drop, input);
    waBody(...nodes);
  }

  function waUpload(file) {
    if (!file) return;
    const bar = el('div', 'progress'); const fill = el('span'); bar.append(fill);
    const meta = el('p', 'caption tertiary', `0 / ${fmtBytes(file.size)}`);
    waBody(el('p', 'title-sm', `Sending “${file.name}” to your phone…`), bar, meta);
    const xhr = new XMLHttpRequest();
    wa.xhr = xhr;
    xhr.open('POST', `/api/import/whatsapp?${new URLSearchParams({ name: file.name }).toString()}`);
    xhr.setRequestHeader('Authorization', `Bearer ${state.token}`);
    xhr.setRequestHeader('Content-Type', 'application/octet-stream');
    xhr.upload.onprogress = (ev) => {
      if (!ev.lengthComputable) return;
      fill.style.width = `${(ev.loaded / ev.total) * 100}%`;
      meta.textContent = ev.loaded === ev.total ? 'Reading the chat on your phone…' : `${fmtBytes(ev.loaded)} / ${fmtBytes(ev.total)}`;
      if (ev.loaded === ev.total) bar.classList.add('indeterminate');
    };
    xhr.onload = () => {
      wa.xhr = null;
      let data = {};
      try { data = JSON.parse(xhr.responseText || '{}'); } catch (_) { data = {}; }
      if (xhr.status === 401) { showPair('Your session ended.'); return; }
      if (xhr.status >= 200 && xhr.status < 300) {
        wa.preview = data;
        wa.senders = new Set(data.senders);
        wa.includeMedia = true;
        waPreview();
      } else if (xhr.status === 409) {
        waIntro('An import is already running on your phone. Wait for it to finish.');
      } else {
        waIntro(data.message || "This doesn't look like a WhatsApp export. Export the chat again with “Include media” and choose the .zip.");
      }
    };
    xhr.onerror = () => { wa.xhr = null; waIntro('The connection to your phone dropped. Try again.'); };
    xhr.onabort = () => { wa.xhr = null; };
    xhr.send(file);
  }

  function segmented(options, value, onChange) {
    const seg = el('div', 'segmented');
    seg.setAttribute('role', 'group');
    const thumb = el('span', 'thumb');
    thumb.style.width = `calc((100% - 4px) / ${options.length})`;
    seg.append(thumb);
    options.forEach(([v, label], i) => {
      const b = el('button', null, label);
      b.type = 'button';
      b.setAttribute('aria-pressed', String(v === value));
      if (v === value) thumb.style.transform = `translateX(${i * 100}%)`;
      b.addEventListener('click', () => { if (v !== value) onChange(v); });
      seg.append(b);
    });
    return seg;
  }

  function waPreview(busy) {
    const p = wa.preview;
    const stats = el('div', 'wa-stats');
    const stat = (n, label) => { const s = el('div', 'stat'); s.append(el('b', null, fmtCount(n)), el('span', 'caption tertiary', label)); return s; };
    stats.append(stat(p.messages, 'messages'), stat(p.mediaCount, 'photos & files'), stat(p.senders.length, p.senders.length === 1 ? 'person' : 'people'));

    const range = el('p', 'body-sm secondary', `${fmtDate(p.first)} – ${fmtDate(p.last)} · ${p.fileName}`);
    const q = el('p', 'title-sm', p.certain ? 'Dates look right?' : 'Which way are the dates written?');
    const seg = segmented([[true, 'Day / Month'], [false, 'Month / Day']], p.dayFirst, async (v) => {
      waPreview(true);
      try { wa.preview = await api('/api/import/whatsapp/order', { method: 'POST', json: { dayFirst: v } }); waPreview(); } catch (e) { handleError(e); waPreview(); }
    });
    const samples = el('div', 'samples');
    for (const s of p.samples) {
      const row = el('div', 'body-sm');
      row.append(el('span', 'mono tertiary', fmtDate(s.time)), el('span', null, (s.text || '').replace(/\s+/g, ' ')));
      samples.append(row);
    }
    if (busy) samples.style.opacity = '0.4';

    const nodes = [stats, range, q, seg, samples];
    if (p.senders.length > 1) {
      const chips = el('div', 'chips');
      for (const name of p.senders) {
        const c = el('button', 'chip');
        c.type = 'button';
        c.setAttribute('aria-pressed', String(wa.senders.has(name)));
        if (wa.senders.has(name)) c.append(icon('check', 'icon-sm'));
        c.append(document.createTextNode(name));
        c.addEventListener('click', () => { if (wa.senders.has(name)) wa.senders.delete(name); else wa.senders.add(name); waPreview(); });
        chips.append(c);
      }
      nodes.push(el('p', 'title-sm', 'Whose messages?'), chips);
    }
    if (p.mediaCount > 0) {
      const row = el('label', 'check-row');
      const cb = el('input'); cb.type = 'checkbox'; cb.checked = wa.includeMedia;
      cb.addEventListener('change', () => { wa.includeMedia = cb.checked; });
      const txt = el('span');
      txt.append(el('span', 'title-sm', `Include ${plural(p.mediaCount, 'photo, video and file', 'photos, videos and files')}`));
      row.append(cb, txt);
      nodes.push(row);
    }
    nodes.push(infoCard(null, p.isPro ? 'Goes into a “WhatsApp import” box on your phone' : 'Goes into your box’s archive',
      'Original dates are kept. Importing the same export again skips what’s already there.'));
    const actions = el('div', 'dialog-actions');
    const other = el('button', 'btn btn-md btn-ghost', 'Choose another file');
    other.type = 'button';
    other.addEventListener('click', async () => { try { await api('/api/import/whatsapp', { method: 'DELETE' }); } catch (_) { /* fine */ } waIntro(); });
    const go = el('button', 'btn btn-md btn-primary', wa.senders.size ? 'Import to phone' : 'Pick at least one name');
    go.type = 'button';
    go.disabled = !wa.senders.size || !!busy;
    go.addEventListener('click', waCommit);
    actions.append(other, go);
    nodes.push(actions);
    waBody(...nodes);
  }

  async function waCommit() {
    try {
      await api('/api/import/whatsapp/commit', { method: 'POST', json: { senders: [...wa.senders], includeMedia: wa.includeMedia } });
    } catch (e) { handleError(e, "Couldn't start the import. Try again."); return; }
    const bar = el('div', 'progress'); const fill = el('span'); bar.append(fill);
    const meta = el('p', 'caption tertiary', 'Starting…');
    const stop = el('button', 'btn btn-sm btn-tertiary', 'Stop import');
    stop.type = 'button';
    stop.addEventListener('click', async () => { stop.disabled = true; try { await api('/api/import/whatsapp', { method: 'DELETE' }); } catch (_) { /* fine */ } });
    waBody(el('p', 'title-md', 'Tucking everything away on your phone…'), el('p', 'body-sm secondary', 'You can keep working — this runs on your phone.'), bar, meta, stop);
    wa.polling = true;
    while (wa.polling && state.token) {
      await sleep(500);
      let s;
      try { s = await api('/api/import/whatsapp/status'); } catch (e) { if (e instanceof Unauthorized) { wa.polling = false; return; } continue; }
      if (s.total) { fill.style.width = `${(s.done / s.total) * 100}%`; meta.textContent = `${fmtCount(s.done)} of ${fmtCount(s.total)}`; }
      if (s.state === 'done') { wa.polling = false; waDone(s.summary); }
      else if (s.state === 'error') { wa.polling = false; waIntro(s.error); }
      else if (s.state === 'idle') { wa.polling = false; waIntro(); }
    }
  }

  function waDone(sum) {
    const d = el('div', 'wa-done');
    d.append(el('span', 'big', fmtCount(sum.created)), el('p', 'title-sm secondary', sum.created === 1 ? 'item imported to your phone' : 'items imported to your phone'));
    d.append(el('p', 'body-md secondary', sum.archived ? 'They’re archived so your box stays tidy — still searchable.' : `They’re in “${sum.boxName}”, with their original dates.`));
    if (sum.duplicates) d.append(el('p', 'body-sm tertiary', `${fmtCount(sum.duplicates)} already in Tibb were skipped.`));
    if (sum.missingMedia) d.append(el('p', 'body-sm tertiary', `${fmtCount(sum.missingMedia)} attachments weren’t in the export.`));
    const actions = el('div', 'dialog-actions');
    const open = el('button', 'btn btn-md btn-primary', sum.archived ? 'Show the archive' : `Open ${sum.boxName}`);
    open.type = 'button';
    open.addEventListener('click', async () => {
      closeWa(true);
      await refreshState().catch(handleError);
      await openBox(sum.boxId);
      if (sum.archived) $('toggle-archive').click();
    });
    actions.append(open);
    waBody(d, actions);
    toast(`Imported ${plural(sum.created, 'item')} from WhatsApp`);
  }

  dark.addEventListener && dark.addEventListener('change', () => { if (state.token) { renderRail(); renderHeader(); } });

  showPair();
})();
