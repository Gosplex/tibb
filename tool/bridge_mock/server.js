// Mock of the phone's Bridge API, for working on assets/bridge/ without a phone:
//   node tool/bridge_mock/server.js   →   http://localhost:8787  (code 123456)
// It mirrors lib/features/bridge/bridge_server.dart's routes and JSON shapes.
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '../..');
const PORT = Number(process.env.PORT || 8787);
const CODE = '123456';
const PHONE = 'phone-device';
let token = null;
let seq = 1;
const waiters = [];
const blobs = new Map();
const devices = { [PHONE]: 'iPhone' };
const boxes = [
  { id: 'b1', name: 'Personal', emoji: '📦', color: 'saffron', locked: false, sortOrder: 0 },
  { id: 'b2', name: 'Work', emoji: '💼', color: 'ocean', locked: false, sortOrder: 1 },
  { id: 'b3', name: 'Private', emoji: '🔒', color: 'plum', locked: true, sortOrder: 2 },
];
const now = Date.now();
const items = [
  { id: 'i1', boxId: 'b1', type: 'text', text: 'This is your box. Anything you save lands here.', origin: PHONE, createdAt: now - 86400000 * 2, reviewed: true },
  { id: 'i2', boxId: 'b1', type: 'link', text: 'https://example.com/boarding-pass', origin: PHONE, createdAt: now - 3600000, reviewed: true },
  { id: 'i3', boxId: 'b1', type: 'text', text: 'Wifi password: saffron-lid-42', origin: PHONE, createdAt: now - 60000, reviewed: false },
];
let clipboard = null;
let wa = null;
function waPreview() {
  const d = wa.dayFirst;
  return { state: 'ready', fileName: 'WhatsApp Chat with Me.zip', messages: 42, first: now - 3e10, last: now - 1e9, senders: ['Me', 'Priya'], dayFirst: d, certain: false, textCount: 38, mediaCount: 4, isPro: false,
    samples: [{ time: d ? new Date(2024, 2, 4).getTime() : new Date(2024, 3, 3).getTime(), text: 'Flight PNR 7QX2LM' }, { time: now - 2e10, text: 'https://example.com/recipe' }] };
}

const STATIC = {
  '/': ['assets/bridge/index.html', 'text/html; charset=utf-8'],
  '/app.css': ['assets/bridge/app.css', 'text/css'],
  '/app.js': ['assets/bridge/app.js', 'text/javascript'],
  '/mark.png': ['assets/brand/tibb_mark.png', 'image/png'],
  '/fonts/Figtree.ttf': ['assets/fonts/Figtree-Variable.ttf', 'font/ttf'],
  '/fonts/Fraunces.ttf': ['assets/fonts/Fraunces-Variable.ttf', 'font/ttf'],
  '/fonts/JetBrainsMono.ttf': ['assets/fonts/JetBrainsMono-Variable.ttf', 'font/ttf'],
};

function bump() { seq++; waiters.splice(0).forEach((w) => w()); }
function json(res, body, status = 200) { res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(body)); }
function readBody(req) { return new Promise((r) => { const c = []; req.on('data', (d) => c.push(d)); req.on('end', () => r(Buffer.concat(c))); }); }
function view(i) { return { ...i, fromPhone: i.origin === PHONE, originName: devices[i.origin] || 'Another device', pinned: !!i.pinned }; }

http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  const p = url.pathname;
  if (!p.startsWith('/api/')) {
    const s = STATIC[p];
    if (!s) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': s[1], 'Content-Security-Policy': "default-src 'self'; img-src 'self' blob: data:; media-src 'self'; font-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'" });
    return res.end(fs.readFileSync(path.join(ROOT, s[0])));
  }
  if (p === '/api/pair') {
    const b = JSON.parse((await readBody(req)).toString() || '{}');
    if (b.code !== CODE) return json(res, { error: 'wrong_code' }, 403);
    token = crypto.randomBytes(32).toString('hex');
    devices[b.deviceId] = devices[b.deviceId] || 'Chrome on Mac';
    return json(res, { token, deviceId: b.deviceId, deviceName: devices[b.deviceId], phoneName: 'iPhone' });
  }
  const auth = (req.headers.authorization || '').replace('Bearer ', '') || url.searchParams.get('t');
  if (!token || auth !== token) return json(res, { error: 'unauthorized' }, 401);
  const deviceId = Object.keys(devices).find((d) => d !== PHONE);

  if (p === '/api/state') {
    return json(res, {
      phoneName: 'iPhone', seq, defaultBoxId: 'b1', clipboard,
      boxes: boxes.map((b) => ({ ...b, hidden: b.locked, unreviewed: items.filter((i) => i.boxId === b.id && !i.reviewed).length, preview: b.locked ? null : (items.filter((i) => i.boxId === b.id).slice(-1)[0] || {}).text || null })),
    });
  }
  if (p === '/api/items' && req.method === 'GET') {
    const box = boxes.find((b) => b.id === url.searchParams.get('box'));
    if (!box) return json(res, { error: 'not_found' }, 404);
    if (box.locked) return json(res, { error: 'locked' }, 403);
    const arch = url.searchParams.get('archived') === '1';
    return json(res, { items: items.filter((i) => i.boxId === box.id && !!i.archived === arch).sort((a, b) => b.createdAt - a.createdAt).map(view) });
  }
  if (p === '/api/search') {
    const q = (url.searchParams.get('q') || '').toLowerCase();
    return json(res, { results: items.filter((i) => (i.text || i.fileName || '').toLowerCase().includes(q) && !boxes.find((b) => b.id === i.boxId).locked).map((i) => { const b = boxes.find((x) => x.id === i.boxId); return { ...view(i), boxName: b.name, boxEmoji: b.emoji }; }) });
  }
  if (p === '/api/items' && req.method === 'POST') {
    const b = JSON.parse((await readBody(req)).toString());
    const it = { id: crypto.randomUUID(), boxId: b.boxId, type: /^https?:\/\/\S+$/.test(b.text) ? 'link' : 'text', text: b.text, origin: deviceId, createdAt: Date.now(), reviewed: false };
    items.push(it); bump(); return json(res, { item: view(it) });
  }
  if (p === '/api/clipboard') {
    const b = JSON.parse((await readBody(req)).toString());
    clipboard = view({ id: crypto.randomUUID(), type: 'clipboard', text: b.text, origin: deviceId, createdAt: Date.now() });
    bump(); return json(res, { item: clipboard });
  }
  if (p === '/api/upload') {
    const data = await readBody(req);
    const hash = crypto.createHash('sha256').update(data).digest('hex');
    const mime = req.headers['content-type'] || 'application/octet-stream';
    blobs.set(hash, { data, mime });
    const type = mime.startsWith('image/') ? 'image' : mime.startsWith('video/') ? 'video' : mime.startsWith('audio/') ? 'voice' : 'file';
    const it = { id: crypto.randomUUID(), boxId: url.searchParams.get('box'), type, blobHash: hash, mime, fileName: url.searchParams.get('name'), size: data.length, origin: deviceId, createdAt: Date.now(), reviewed: false };
    items.push(it); bump(); return json(res, { item: view(it) });
  }
  if (p.startsWith('/api/blob/')) {
    const b = blobs.get(p.slice('/api/blob/'.length));
    if (!b) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': b.mime }); return res.end(b.data);
  }
  if (p === '/api/device') { const b = JSON.parse((await readBody(req)).toString()); devices[deviceId] = b.name; return json(res, { ok: true }); }
  if (p === '/api/events') {
    const since = Number(url.searchParams.get('since') || 0);
    if (seq > since) return json(res, { seq });
    const t = setTimeout(() => json(res, { seq }), 25000);
    waiters.push(() => { clearTimeout(t); json(res, { seq }); });
    return;
  }
  if (p === '/api/items/update') {
    const b = JSON.parse((await readBody(req)).toString());
    const it = items.find((i) => i.id === b.id);
    if (!it) return json(res, { error: 'not_found' }, 404);
    if (b.archived !== undefined) it.archived = b.archived;
    if (b.pinned !== undefined) it.pinned = b.pinned;
    bump(); return json(res, { item: view(it) });
  }
  // WhatsApp import (mirrors the phone's shapes; parsing is faked).
  if (p === '/api/import/whatsapp' && req.method === 'POST') {
    const data = await readBody(req);
    if (!data.length) return json(res, { error: 'notWhatsApp', message: "This doesn't look like a WhatsApp export." }, 422);
    wa = { state: 'ready', dayFirst: true, done: 0, total: 0 };
    return json(res, waPreview());
  }
  if (p === '/api/import/whatsapp/order') { const b = JSON.parse((await readBody(req)).toString()); wa.dayFirst = b.dayFirst !== false; return json(res, waPreview()); }
  if (p === '/api/import/whatsapp/commit') {
    wa.state = 'running'; wa.total = 40; wa.done = 0;
    const tick = setInterval(() => {
      wa.done += 8;
      if (wa.done >= wa.total) {
        clearInterval(tick);
        for (let k = 0; k < 3; k++) items.push({ id: crypto.randomUUID(), boxId: 'b1', type: 'text', text: `Imported note ${k + 1}`, origin: PHONE, createdAt: Date.now() - 1e9 + k, reviewed: true, archived: true, source: 'whatsapp' });
        wa.state = 'done'; wa.summary = { created: 40, duplicates: 2, missingMedia: 0, boxId: 'b1', boxName: 'Personal', archived: true }; bump();
      }
    }, 200);
    return json(res, { ok: true });
  }
  if (p === '/api/import/whatsapp/status') return json(res, { state: wa ? wa.state : 'idle', done: wa ? wa.done : 0, total: wa ? wa.total : 0, summary: wa && wa.summary });
  if (p === '/api/import/whatsapp' && req.method === 'DELETE') { wa = null; return json(res, { ok: true }); }
  if (p === '/api/session') { token = null; return json(res, { ok: true }); }
  return json(res, { error: 'not_found' }, 404);
}).listen(PORT, () => console.log(`Tibb Bridge mock on http://localhost:${PORT} — code ${CODE}`));

// Simulate the phone saving something now and then, to exercise live updates.
if (process.env.SIMULATE_PHONE) setTimeout(() => { items.push({ id: 'phone-late', boxId: 'b1', type: 'text', text: 'Saved on the phone just now', origin: PHONE, createdAt: Date.now(), reviewed: false }); bump(); }, 4000);
