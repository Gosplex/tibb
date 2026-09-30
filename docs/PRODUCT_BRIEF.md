# Tibb — Hackathon Brief

**RevenueCat Shipaton 2026 · Next Gen Award (student track)**
**Version H2.** This replaces the first hackathon brief (H1). It is derived from Product Brief v2, which remains the long-term roadmap. Anything cut here is *deferred*, not abandoned.

> **Status legend**
> **HERO** — a "wow" feature. Must appear in the demo video.
> **CORE** — must ship for the app to be coherent.
> **STRETCH** — build only once HERO and CORE work end to end.
> **DECIDED** — do not reopen during the hackathon.
> **RECOMMENDED** — proposed default; change only for a concrete reason.
> **OPEN** — needs a decision before that piece is built.

---

## 1. The Product in One Line

A private inbox you message yourself, where saved notes, links, screenshots, files and voice memos move between your phone and your computer **over your own Wi-Fi**, never through anyone's cloud.

---

## 2. The Winning Plan

### Strategy — DECIDED

Put every hour into the things judges will *see and remember*, and nothing into infrastructure they won't.

1. **A polished Flutter mobile app** (Android first, iOS second). This is the product.
2. **Tibb Bridge** as the centerpiece. The phone serves a lightweight web page straight to the computer's browser over Wi-Fi. You drag a file on the laptop and it lands on the phone. This is the moment judges remember.
3. **Deep, visible RevenueCat use**: a hand-built Flutter paywall driven by RevenueCat offerings, intent-based triggers, lifetime + yearly, restore, and instant unlock.
4. **A simple static landing site** at Tibb's domain for web presence, the demo link and the privacy explanation.

### What changed from H1

| H1 | H2 | Why |
|---|---|---|
| Full Tibb Web (Flutter compiled to web, standalone library in the browser) | **Removed.** Replaced by a static landing site. | Needed drift-on-web, conditional imports and web-safe versions of every feature. That is a lot of work for a separate copy of Tibb that doesn't talk to the phone. |
| Bridge served the Flutter web build from the phone | **Bridge serves one hand-written HTML/JS page** | Much smaller, faster to load, no web-compatibility work in the Flutter app, and no engine bundle to ship inside the app. |
| Custom Flutter paywall | **Custom Flutter paywall — kept** (DECIDED) | Full control over design and animation, and it matches Tibb's look exactly. No dashboard-built paywalls. |
| Tibb ID to share Pro between phone and web | **Removed** | Bridge is gated on the phone, so the browser never needs its own entitlement. |

### Deferred from Product Brief v2

Encrypted Google Drive sync, the Drive-based web client, on-device OCR, encrypted share links, the integrity sweep, log compaction, widgets, Siri/Shortcuts and Watch.

### Kept — every wow feature

- **Tibb Bridge**: phone ↔ PC, live and two-way, over Wi-Fi, with no cloud.
- **Clipboard Bridge**: copy on the PC, paste on the phone seconds later.
- **WhatsApp self-chat import**: years of saves pulled into Tibb in one step.
- **Locked boxes** with fingerprint / Face ID.
- **Password-encrypted export** of the whole library.
- Share-into-app, triage (archive / unreviewed), notes, pins, box colors and icons, dark mode.
- The **change-log data model**, so Drive sync can be added later without a rewrite.

---

## 3. Product Thesis (condensed from v2)

**Problem.** People use WhatsApp, Telegram and email as a personal scratch inbox. Their saves end up on third-party servers, scattered across apps, unstructured, and stuck on the phone.

**Insight.** The chat metaphor makes capture effortless because it demands no filing decision. A chat app, though, is the wrong *container* for private data, and a phone alone is the wrong *scope*. Tibb keeps the interaction, replaces the container, and reaches the computer.

**Promise.** Save anything instantly. Get it on your computer without a cable, email or cloud. No account. Works offline. Take everything with you any time.

**Why it's defensible.** Big platforms can copy a capture flow. They cannot credibly copy "no server ever sees your stuff," because their business depends on seeing it.

---

## 4. Target User

A mobile-first person who messages themselves daily and also works at a Windows PC or Mac, and who is privacy-conscious enough that "nothing leaves your devices" is a reason to choose an app. The privacy motivation is ASSUMED and unvalidated.

**Jobs to be done**
- When I find something worth keeping, let me stash it in one tap without losing my train of thought.
- When I need something off my camera roll, give it a home that isn't browsable by whoever picks up my phone.
- When I need something I saved, let me find it without remembering which app I sent it to.
- When I'm at my desk, let me get my phone's stuff onto my computer, and back, right now.

---

## 5. Core Loop

```
TRIGGER   → Something worth keeping appears, on phone or computer
ACTION    → Share / type / drop it into Tibb
RESPONSE  → Appears instantly, saved locally, no network, no spinner
VALUE     → Mind offloaded now; findable later; reachable from the computer
REPEAT    → Trust in the container makes it the default next time
```

**Activation moments**
1. The first successful *retrieval*: finding something again.
2. The first file dragged in on the PC that appears on the phone. This is the moment Tibb stops being an app and becomes infrastructure.

---

## 6. The Pieces — DECIDED

| Piece | What it is | Built with |
|---|---|---|
| **Tibb Mobile** | The app. All data lives here: SQLite + files on the phone. | Flutter (Android CORE, iOS CORE with some STRETCH features) |
| **Tibb Bridge page** | One lightweight web page the phone serves to a browser on the same Wi-Fi. A live window into the phone's library, with two-way capture. | Plain HTML + CSS + vanilla JavaScript, bundled inside the app. No frameworks, no CDN, no build step. |
| **Landing site** | Static marketing page at Tibb's root domain: what Tibb is, how Bridge works, the privacy promise, the demo video, and the download/repo link. | Static HTML on free hosting. It never receives user content. |

**Why the Bridge page is plain HTML/JS (DECIDED).**
- It loads instantly from a phone.
- It has zero dependencies, so it works even if the PC has no internet.
- It keeps the Flutter app free of any web-build concerns.
- The page and its API come from the same origin (the phone), which avoids the browser's mixed-content and private-network blocks. Those blocks would stop an `https://` website from talking to `http://192.168.x.x`.

---

## 7. Features

### 7.1 Capture — CORE

**Behavior.** Type, record, attach or share in. The item is written locally and appears immediately, with no network call and no spinner.

**Supported types (DECIDED):** text, links, photos, videos, voice memos, PDFs, arbitrary files.

**Details**
- Links are detected in text and rendered as tappable link items. There is no remote preview fetch in this version, so Tibb never contacts third-party servers silently.
- Each item shows a timestamp and its **origin device** (e.g. "Pixel 8", "Chrome on Windows").
- Media is stored as files named by **SHA-256 content hash**, so identical content is saved once.

**Edge cases.** Storage full → clear error, never a silent failure. Very large videos → copy by streaming, never load fully into memory. Duplicate content → deduplicated by hash, but still shown as a new item in the thread.

---

### 7.2 Share-Into-App — CORE (Android) · STRETCH (iOS)

**Behavior.** User taps the OS share button in any app → Tibb → optionally picks a box → saved. A confirmation appears.

- **Android (CORE):** intent filters for text, URLs, images, video, audio and files, including multiple items at once.
- **iOS (STRETCH):** Share Extension writing to an App Group container that the main app ingests on next launch. It is memory-constrained and the fiddliest piece of client work. Do not let the Android implementation shape its design.

**RECOMMENDED package:** `share_handler`, which covers both platforms. `receive_sharing_intent` is the fallback.

**Edge cases.** App cold-started by a share. Share while a locked box is the active box → save to the default box instead, never prompt biometrics inside a share flow. Unsupported MIME type → saved as a generic file.

---

### 7.3 Boxes — CORE

Independent threads that keep work, personal and topic saves apart.

- **Free:** one box. **Pro:** unlimited.
- Rename, emoji icon, and accent color. These are cheap to build and look great in the demo.
- Move items between boxes.
- Deleting a box requires explicit confirmation and is recorded as a **tombstone** in the change log.

---

### 7.4 Locked Boxes — HERO · Pro

Contents are gated behind device biometrics: Face ID / Touch ID on iOS, BiometricPrompt on Android. The `local_auth` package handles both.

**Rules (DECIDED)**

| Question | Decision |
|---|---|
| Do locked items appear in search? | **No**, unless the box has been unlocked in the current session. |
| Do locked boxes appear in the box list? | **Yes**, with a lock icon and no preview text. |
| Can the PC (Bridge) see locked boxes? | **No, by default.** The phone owner can tap "Show on PC for this session" and confirm with biometrics. Access ends when the Bridge session ends. |
| No biometrics enrolled? | Fall back to the device passcode through `local_auth`. If there is no device lock at all, locking is unavailable and the app says why. |
| Re-lock timing | Re-locks when the app goes to the background, or after 60 seconds idle. |

---

### 7.5 Search — CORE

Searches item text, link URLs, file names, item notes, and voice transcripts if the transcription stretch goal ships. Results are grouped by box. Archived items are included but ranked below active ones. Locked content follows 7.4. The Bridge page searches through the phone's API, so there is one search engine for both.

**Implementation (RECOMMENDED):** SQLite FTS5 via `drift`.

---

### 7.6 Triage — Archive & Unreviewed — CORE

The feature that makes Tibb an inbox rather than a junk drawer. It is the clearest structural difference from a notes app.

- New items are **unreviewed**. Swiping an item archives it: it leaves the main thread but stays searchable.
- A small unreviewed count per box.
- **The count is never pushed as a notification and can be hidden entirely** (DECIDED). It must never become guilt.
- Bulk "archive all older than…" for big imported libraries.

---

### 7.7 Item Actions — CORE

Edit text, delete (tombstone), pin to the top of a box, move to a box, add a **note** explaining why you saved it, and copy or open or re-share outward.

---

### 7.8 Voice Memos — CORE · Live Transcription — STRETCH

- **CORE:** hold to record, with a waveform while recording. Playback happens inline in the thread. Uses `record` and `just_audio`. Voice memos also play in the Bridge page.
- **STRETCH:** live on-device transcription while recording (`speech_to_text` with on-device recognition requested). The transcript is stored with the memo, indexed for search, and marked as machine-generated and editable.
- **Rule (DECIDED):** if the device cannot do on-device recognition, the feature is simply unavailable. It **never** falls back to cloud recognition.

---

### 7.9 Tibb Bridge — HERO · Pro

**The centerpiece of the demo.** The computer becomes a real Tibb client over local Wi-Fi, with no cloud, no account and no cable.

**Flow**
1. On the phone, the user taps **"Open on computer."** Free users see the paywall at this point, the highest-intent trigger in the app.
2. The phone starts a local HTTP server (`shelf`) and shows, in large type, an address such as `192.168.1.42:8080`, a 6-digit pairing code, and a copy button.
3. On the PC, the user types the address into any browser. **The Bridge page loads directly from the phone.**
4. The user enters the pairing code. The browser gets a session token, and the library appears.
5. From the PC the user can:
   - browse boxes and threads, and search;
   - view images, play voice memos and video, and download any file;
   - **drag files onto the page** to save them to the phone;
   - type or paste new text and links;
   - use Clipboard Bridge (7.10).
6. Items created on the PC are written into the phone's change log with the browser as their origin device (e.g. "Chrome on Windows"). In the thread they appear **left-aligned and labeled**; phone items are right-aligned.
7. The phone shows a persistent banner, **"PC connected — tap to stop,"** and fires a local notification: *"Saved from Chrome on Windows."*
8. New phone saves appear on the PC within about a second, via long-polling, with an insert animation.

**The Bridge page (DECIDED)**
- It lives in `assets/bridge/`: `index.html`, `app.css`, `app.js`. It uses vanilla JS only, with no external requests of any kind.
- The layout follows the app: box list on the left, thread on the right, and a composer at the bottom with a large drop zone.
- It follows the system light/dark theme (`prefers-color-scheme`) and uses Tibb's box accent colors.
- The session token is held **in memory only**. Closing the tab ends access on that browser (DECIDED — safe on shared computers).
- It shows "Phone disconnected — check Tibb is open" rather than a blank page when the phone goes away.

**Bridge API (RECOMMENDED shape)**
```
GET  /                         → Bridge page (index.html, app.css, app.js from app assets)
POST /api/pair       {code}    → {token, phoneName}
GET  /api/boxes                → list of boxes (locked ones redacted unless shared for session)
GET  /api/items?box=&before=   → items, paged, newest first
GET  /api/search?q=            → search results via FTS5
GET  /api/blob/<hash>          → media, streamed, with HTTP Range support (video seeking)
POST /api/items                → new text/link item
POST /api/upload               → multipart file upload, streamed to disk, hashed
POST /api/clipboard            → Clipboard Bridge item
GET  /api/events?since=<seq>   → long-poll; returns new change-log events for live updates
DELETE /api/session            → end session
```
Every `/api/*` call except `/pair` requires the session token (`Authorization: Bearer`).

**Session rules (DECIDED)**
- The pairing code is single-use and expires after 5 minutes. Five wrong attempts regenerate it.
- The session ends when the user taps Stop, the app is closed, or after 30 minutes with no requests.
- Only one PC may be paired at a time.
- The server binds to the Wi-Fi interface only. Port 8080 is tried first, then a random free port.

**Platform asymmetry — disclose, do not disguise (DECIDED)**
- **Android:** the session survives with the app minimized, via a foreground service with a persistent notification (`flutter_foreground_task`).
- **iOS:** the app must stay open and on screen. The UI says so plainly. It also requires the iOS Local Network permission prompt, which is shown only when the user first starts Bridge.

**Honest security note (DECIDED — must be stated in-app).** Bridge traffic stays on the user's local network and never touches the internet. It is **plain HTTP**, however, not TLS, so the in-app copy recommends using Bridge on **home or trusted Wi-Fi**. It also notes that café, hotel and campus networks often block device-to-device traffic entirely (client isolation).

**Post-hackathon:** app-layer encryption of Bridge traffic using a key derived from a longer pairing secret.

**Edge cases.** Phone and PC on different networks → the page never loads, so the phone screen shows troubleshooting tips ("Same Wi-Fi? Try your phone's hotspot"). The IP changes between sessions, so the UI says the address can't be bookmarked. Large uploads must stream to disk, never buffer in memory. Uploading a 1 GB video must not freeze the phone UI.

---

### 7.10 Clipboard Bridge — HERO · Pro

The single most common self-message is a short piece of text needed on the other device *right now*: an OTP, a link, an address.

- **PC → phone:** paste into the Bridge page's clipboard box (or press Ctrl/Cmd+V anywhere on the page). It appears pinned at the top of the phone's thread with a one-tap **Copy** button, plus a notification.
- **Phone → PC:** tap **"Send clipboard."** It appears pinned on the Bridge page with a Copy button.
- **Rules (DECIDED):**
  - Clipboard reads are always user-initiated, never automatic, for platform compliance and because silent clipboard access is exactly what a privacy product must never do.
  - Clipboard items **auto-expire after 24 hours** by default (configurable) and are excluded from long-term search.

---

### 7.11 Export & Import — CORE · never paywalled

**Behavior.** "Export everything" produces one `.tibb` archive: a zip containing `manifest.json`, the change log as JSON Lines, and all media named by hash. "Import" restores it.

- **Password-encrypted export (HERO):** optional. When a password is set, the archive is encrypted with AES-256-GCM using a key derived from the password with Argon2id (`cryptography` package). Only standard constructions; nothing invented (DECIDED).
- **Format is identical on Android and iOS (DECIDED)**, so moving between phones is one file.
- **Stream, never build in memory.** A truncated or corrupt archive must **fail loudly and import nothing**, never import partially.
- Import merges by item ID and content hash, so importing the same archive twice creates no duplicates.
- **Available in every payment state**, including free, lapsed and refunded (DECIDED). No payment state may ever trap user content.

---

### 7.12 Import from WhatsApp Self-Chat — HERO · Free

Users already have years of saves trapped in a "message yourself" chat. This feature brings them into Tibb in one step, which solves the empty-state problem and removes the incumbent's main reason to stay.

**Flow.** In WhatsApp: *Chat → More → Export chat → Include media → share to Tibb*. Tibb receives the zip via share intent (or the file picker), parses `_chat.txt`, matches attachments, and creates a new box named "WhatsApp import" with the original timestamps.

**Edge cases**
- The date/time format of `_chat.txt` **varies by phone locale** (12h/24h, DD/MM vs MM/DD). The parser must detect the format and let the user confirm it with a preview of the first few messages.
- Multi-line messages, system lines ("Messages are end-to-end encrypted…"), deleted-message placeholders, and missing media files.
- Imported items start as **archived** so the main thread isn't flooded. The user can unarchive them.

**Tier.** Free. It is an acquisition feature. Imported *media* needs Pro to open, which makes it a natural upgrade trigger (see 9.3).

---

### 7.13 Onboarding & First Run — CORE

In a product sold on trust, the first screen does most of the persuading.

1. **No account, no permissions, no questions.** The user lands in an open, empty box.
2. **One seeded item** showing the format. It's a real item the user can delete, not a tutorial card.
3. **The empty state teaches the one action that matters:** how to share into Tibb from another app.
4. **The privacy claim appears once, after the first save**, at the moment it is verifiable: *"That was saved on this phone. Nothing left it."*
5. **Nothing else is asked for.** Notification and local-network permissions are requested only when Bridge is first started. There is no rating prompt.
6. A secondary link, **"Coming from WhatsApp?"**, goes to the import flow (7.12).

---

### 7.14 Notifications — CORE

Local notifications only (`flutter_local_notifications`). There is no push service, because that would require a server.

**Governing rule (DECIDED): notify about events, never about absence.**

| Event | Notification |
|---|---|
| Item saved from the PC via Bridge | "Saved from Chrome on Windows" |
| Clipboard item received | "Clipboard from your PC — tap to copy" |
| Bridge still running in background (Android) | Persistent: "PC connected — tap to stop" |
| Import finished | "Imported 1,284 items from WhatsApp" |
| ❌ Never | "You haven't saved anything in 3 days" or any streak or nudge |

---

### 7.15 Look & Feel — CORE

Light and dark themes that follow the system setting. Box accent colors. Chat-style bubbles, with phone items on the right and PC items on the left, labeled. Smooth insert animation when an item lands, which is especially visible when it arrives *from the PC* during the demo.

**Rule (DECIDED from v2):** the UI must never imply a server or an observer. No online dots, no presence indicators, no placeholder people.

---

### 7.16 Landing Site — CORE (small)

A single static page at Tibb's root domain. It is web presence, a demo destination, and the place the privacy promise is written down in full.

**Content:** a hero line and a looping screen recording of Bridge; the three promises (no account, no cloud, export forever); "How Bridge works" in three steps; the privacy statement (section 11); links to the demo video and the GitHub repo.

**Rules (DECIDED)**
- Plain HTML/CSS. No analytics, no trackers, no third-party embeds (the video is linked, not embedded).
- The site never receives user content.

**Domain:** OPEN. **Hosting (RECOMMENDED):** GitHub Pages or Cloudflare Pages. Both are free.

---

## 8. Data Model — The Change Log — CORE · DECIDED

The foundation that lets Drive sync be added after the hackathon without a rewrite. It is also one of the strongest "thoughtful technical choices" to show judges, and it is what powers Bridge's live updates: the PC simply long-polls for new change-log events.

**Principles**
1. Every mutation is an **append-only event** in a change log, and the current state is derived from the log.
2. **Deletes are tombstones**, never removals.
3. **Media is addressed by SHA-256 content hash.**
4. Each client has a stable **device ID** (UUID) and a per-device **logical counter** alongside the wall-clock timestamp, which protects against clock skew later.
5. Edits resolve **last-write-wins** per field, by (timestamp, counter, device ID).

**Tables (RECOMMENDED, via `drift`)**
```
devices    (id, name, platform, created_at)          -- the phone + each paired browser
boxes      (id, name, emoji, color, locked, sort_order, deleted_at)
items      (id, box_id, type, text, blob_hash, mime, file_name, size,
            note, transcript, pinned, archived, reviewed,
            origin_device_id, created_at, updated_at, deleted_at, expires_at)
blobs      (hash, path, mime, size, created_at)
changes    (seq, device_id, counter, ts, entity, entity_id, op, payload_json)
items_fts  (FTS5 over text, note, transcript, file_name)
```

**Event ops:** `box.create`, `box.update`, `box.delete`, `item.create`, `item.update`, `item.move`, `item.archive`, `item.delete`.

**Where writes come from**
- **The phone:** its own device ID.
- **The Bridge page:** each paired browser is registered as a device ("Chrome on Windows"), and its actions become events in the phone's log under that device ID.
- **Export** is simply the log plus blobs, which is why moving phones is one file.

---

## 9. Monetization — RevenueCat

### 9.1 Free vs Pro

| | Free | Pro |
|---|---|---|
| Saves | **Unlimited** (DECIDED: no save cap) | Unlimited |
| Boxes | 1 | Unlimited |
| Content types | Text and links | + photos, videos, voice, PDFs, files |
| Search | Text | Text + notes + transcripts |
| Locked boxes | — | ✅ |
| **Tibb Bridge** (phone ↔ PC) | — | ✅ |
| **Clipboard Bridge** | — | ✅ |
| WhatsApp import | ✅ (text; media opens with Pro) | ✅ |
| Export / import | ✅ **forever free** | ✅ |
| Encrypted export | ✅ | ✅ |

### 9.2 Pricing & Products — DECIDED (from v2)

| Product | Price | Type | Identifier (RECOMMENDED) |
|---|---|---|---|
| Lifetime (launch price) | **$14.99** | Non-consumable | `tibb_lifetime` → package `$rc_lifetime` |
| Yearly | **$9.99 / year** | Auto-renewable subscription | `tibb_yearly` → package `$rc_annual` |

- **Entitlement:** `pro`. **Offering:** `default`, containing both packages.
- Yearly exists mainly as a **price anchor** so lifetime reads as obvious value (accepted trade-off from v2).
- Regional pricing is set manually for India, Brazil, Indonesia, Turkey and Nigeria when real store products are created (post-hackathon).
- **Why lifetime works:** there is no per-user server cost. Storage is the user's device and transfer is the user's Wi-Fi. A lifetime customer creates no ongoing liability.

### 9.3 Paywall — DECIDED

- **Never on first open.**
- **Hard triggers**, each at a moment of real desire:
  - tapping **"Open on computer"** (Bridge), expected to be the highest-intent trigger;
  - creating a second box;
  - saving a photo, video, voice note or file;
  - locking a box;
  - opening imported WhatsApp media.
- **One soft prompt:** a dismissible banner after about 15 saves, **shown once**, never again if dismissed.
- **Trigger-aware context.** Each trigger passes its reason (`PaywallReason.bridge`, `.secondBox`, `.media`, `.lock`, `.whatsappMedia`, `.softPrompt`), so the paywall leads with the relevant benefit, e.g. "Open Tibb on your computer" when triggered from Bridge. The headline and hero illustration change per reason; the products and price stay the same.
- **Content:** header *"Unlock Tibb."* Subhead *"One payment. No account. Your stuff stays yours."* Lifetime pre-selected and visually dominant. The primary button names the price. A value list of at most six lines. **Restore Purchases** is always present. Terms and privacy links are shown.
- **No fake countdowns or manufactured urgency.** "Launch price" may be stated as fact.

**Implementation (DECIDED) — built from scratch in Flutter**
- **No dashboard-built paywalls and no `purchases_ui_flutter`.** The paywall is a Flutter screen designed and animated to match Tibb. The RevenueCat dashboard is used only for the required product, entitlement and offering setup.
- **Data comes from RevenueCat, never hardcoded.** On open, the paywall calls `Purchases.getOfferings()` and reads `offerings.current`. It builds the two option cards from `current.lifetime` and `current.annual`, and shows `storeProduct.priceString`, so localized prices are correct automatically.
- **Purchase:** tapping the primary button calls `Purchases.purchasePackage(selectedPackage)`. On success, check `customerInfo.entitlements.active['pro']` and close the paywall with a short success animation ("Welcome to Tibb Pro").
- **States the screen must handle:**
  - loading: skeleton cards, never a blank screen;
  - offerings failed to load: "Couldn't load prices" with Retry;
  - purchasing: button shows a spinner and all controls are disabled, to prevent double taps;
  - user cancelled: return quietly, with no error message;
  - error: a plain-language message, and the paywall stays open;
  - already Pro: the paywall is never shown; the gated action just proceeds.
- **Restore Purchases:** a visible button calling `Purchases.restorePurchases()`, followed by "Pro restored" or "No purchases found for this account."
- **Customer-info listener** (`Purchases.addCustomerInfoUpdateListener`) drives a single `isProProvider`. Pro unlocks instantly everywhere after purchase, with no restart. The Bridge screen, second-box button and media buttons all react live.
- **Settings → Tibb Pro:** shows current status (Lifetime / Yearly with renewal date / Free), a Restore button, and for yearly subscribers a "Manage subscription" link opening `customerInfo.managementURL`. It also includes a short "Why Tibb is one payment" note.
- **Terms and privacy links** are shown on the paywall, as the stores require.

### 9.4 Testing Purchases for the Hackathon — DECIDED

- Use **RevenueCat Test Store** for the demo. It needs no Apple or Google developer account, test purchases update entitlements like real ones, and it requires `purchases_flutter` 9.8.0 or later.
- API keys are selected by build configuration (`--dart-define=RC_API_KEY=...`): Test Store key for demo builds, platform keys for real store builds later.
- **Never ship a store build configured with a Test Store key.**
- **Never commit keys.** Keep them in `--dart-define` / an untracked env file, with a checked-in `.env.example`.

### 9.5 Blocking Requirement — DECIDED

**No payment state may ever trap user content.** If Pro lapses or is refunded, Pro-only content remains *viewable and exportable*. Only the *creation* of new Pro-only content is gated.

---

## 10. Technical Architecture

### Stack — DECIDED

- **Flutter** (stable channel), targeting **Android and iOS**. There is no Flutter web build.
- **Bridge page:** plain HTML + CSS + vanilla JS, bundled as app assets.
- **Landing site:** static HTML.
- **No backend.** The only developer-controlled infrastructure is static hosting for the landing site.

### Packages — RECOMMENDED (verify current versions at build time)

| Need | Package |
|---|---|
| Local database + FTS5 | `drift`, `sqlite3_flutter_libs` |
| File paths | `path_provider` |
| Pick files / photos | `file_picker`, `image_picker` |
| Voice record / playback | `record`, `just_audio` |
| Video playback | `video_player` |
| Live transcription (stretch) | `speech_to_text` |
| Share into app | `share_handler` (fallback `receive_sharing_intent`) |
| Share out | `share_plus` |
| Biometrics | `local_auth` |
| Bridge HTTP server | `shelf`, `shelf_router` |
| Local IP address | `network_info_plus` |
| Android background session | `flutter_foreground_task` |
| Local notifications | `flutter_local_notifications` |
| Hashing | `crypto` (SHA-256) |
| Encrypted export | `cryptography` (AES-GCM, Argon2id) |
| Zip archives | `archive` |
| Purchases | `purchases_flutter` (≥ 9.8.0) |
| State management | `flutter_riverpod` |
| Routing | `go_router` |
| Open links | `url_launcher` |

### Project Structure — RECOMMENDED

```
tibb/
├── lib/
│   ├── main.dart
│   ├── app/                 # theme, router, app shell
│   ├── core/
│   │   ├── db/              # drift schema, DAOs, FTS
│   │   ├── changelog/       # event types, append, replay, LWW merge
│   │   ├── blobs/           # content-hash file storage
│   │   └── device/          # device ID, name, logical counter
│   ├── features/
│   │   ├── thread/          # the box thread, bubbles, composer
│   │   ├── boxes/
│   │   ├── capture/         # text, media, voice
│   │   ├── share_in/
│   │   ├── search/
│   │   ├── triage/
│   │   ├── locked/
│   │   ├── bridge/          # shelf server, pairing, API routes, session
│   │   ├── clipboard/
│   │   ├── export_import/
│   │   ├── whatsapp_import/
│   │   ├── onboarding/
│   │   └── paywall/         # custom paywall UI, RevenueCat service, entitlement gate, triggers
│   └── l10n/
├── assets/
│   └── bridge/              # index.html, app.css, app.js — the Bridge page
├── site/                    # landing site (static HTML)
├── test/                    # changelog merge, WhatsApp parser, archive round-trip, bridge API
├── LICENSE
└── README.md
```

### Key Technical Notes

- **One repository layer.** The Flutter UI and the Bridge API call the same repository and change-log code, so an item saved from the PC goes through exactly the same path as one saved on the phone.
- **Streaming everywhere.** Uploads are streamed to a temp file while hashing, then renamed to the hash. Downloads are streamed with Range support.
- **Live updates.** The Bridge page long-polls `/api/events?since=<seq>`. The server holds the request for up to 25 seconds and answers immediately when a new change-log event is written.
- **Device name for browsers** is derived from the User-Agent (e.g. "Chrome on Windows"). The phone owner can rename it.

---

## 11. Data & Privacy

### Precise Claim — DECIDED wording

> "Tibb has no account and no server that receives your content. Everything you save stays on your phone. When you open Tibb on your computer, it travels directly over your own Wi-Fi."

### What Leaves the Device

| Data | Goes to | Why |
|---|---|---|
| Saved content | **Nowhere**, except over the LAN to a PC the user paired via Bridge | — |
| Anonymous RevenueCat app user ID + purchase records | RevenueCat, and Apple or Google for payments | Purchases and entitlements |
| Page request for the landing site | Static host | Viewing the website itself |

**RevenueCat must be disclosed** in the privacy policy and store privacy labels (DECIDED). The privacy claim is about *content*, and it must stay accurate.

**Analytics: none** in the hackathon build (DECIDED).

---

## 12. Explicitly Not Building (hackathon)

- ❌ Any server that receives content (unchanged from v2)
- ❌ Flutter web / standalone browser version of Tibb
- ❌ Google Drive sync and Drive-based web client (deferred)
- ❌ OCR (deferred)
- ❌ Encrypted share links (deferred; needs crypto review)
- ❌ Accounts or logins of any kind
- ❌ QR pairing (from v2; the computer has no camera). A QR code linking to the download is fine.
- ❌ Automatic screenshot capture (platform-impossible, and would be spyware)
- ❌ Cloud transcription or cloud AI of any kind
- ❌ Save-count caps, paywalled export, fake urgency
- ❌ Streaks, gamification, absence notifications
- ❌ Social features, profiles, feeds

---

## 13. Build Order

**Phase 0 — Foundation.** Flutter project (Android + iOS). Drift schema, change-log append/replay, device ID, blob store. Unit tests for replay and last-write-wins.

**Phase 1 — The Thread.** Box thread UI, composer, text/link capture, bubbles with origin labels, triage swipe, item actions, dark mode.

**Phase 2 — Media & Boxes.** Photos, videos, files, voice record and playback, multiple boxes with emoji and color, search (FTS5).

**Phase 3 — RevenueCat.** Test Store products, `pro` entitlement, `default` offering. Custom Flutter paywall built on `getOfferings()` with all states, all triggers with context, Restore, the Settings → Tibb Pro screen, customer-info listener.

**Phase 4 — Tibb Bridge (HERO).** Shelf server, pairing, sessions, API, the Bridge page (browse, search, media, downloads), drag-and-drop upload, live long-poll updates, notifications, Android foreground service.

**Phase 5 — Clipboard Bridge (HERO).** Both directions, pinning, expiry.

**Phase 6 — Share-In & Locked Boxes.** Android share intents, biometric boxes, and the Bridge session-sharing rule.

**Phase 7 — Portability.** Export/import (plain and encrypted), round-trip tests, WhatsApp import with locale detection.

**Phase 8 — Onboarding, Polish & Site.** First run, empty states, privacy moment, insert animations, app icon, screenshots, landing site.

**Stretch.** iOS Share Extension, live voice transcription.

---

## 14. Next Gen Submission Plan

### Repository — required by the rules

- **Public** GitHub repo containing all source, assets, and **setup instructions** needed to run the project.
- **Open-source license file** detectable in the repo's About section.
  - **License — RECOMMENDED: AGPL-3.0.** It deters closed-source clones of a product you intend to sell, and as the sole copyright holder you can still ship store builds under your own terms. Accept outside contributions only with a contributor agreement. MIT is the simpler alternative if openness matters more than protection.
- **README** covering:
  - what Tibb is, with screenshots and a Bridge GIF;
  - an architecture diagram (phone app + change log + Bridge page);
  - exactly how RevenueCat is used;
  - how to run with the Test Store key via `--dart-define`;
  - honest known limitations (Bridge is HTTP on LAN; iOS Bridge needs the app in the foreground; Drive sync is on the roadmap).
- **No keys committed.** Provide `.env.example`.

### Demo Video — under 2 minutes, public on YouTube or Vimeo, real device

| Time | Shot |
|---|---|
| 0:00–0:12 | The problem: a messy WhatsApp "message yourself" chat |
| 0:12–0:30 | Install → straight into a box. Type, share a link from Chrome, record a voice memo. "Nothing left this phone." |
| 0:30–0:42 | WhatsApp import: years of self-chat land in Tibb in one go |
| 0:42–1:00 | Tap "Open on computer" → **RevenueCat paywall** → Test Store purchase → Pro unlocks instantly |
| 1:00–1:35 | **Bridge:** type the address on the laptop and the library appears. Drag a PDF onto the browser and it lands on the phone with a notification. Copy an OTP on the laptop and paste it on the phone. |
| 1:35–1:50 | Lock a box with a fingerprint and show it's hidden from search and from the laptop |
| 1:50–2:00 | Export everything, encrypted. "No account. No cloud. Yours." |

Record the Bridge section on home Wi-Fi or a phone hotspot. Use split-screen (phone + laptop) so both sides of every transfer are visible. No copyrighted music; use royalty-free tracks or none.

### Text Description — mapped to the four judging criteria

1. **Idea:** self-messaging is a universal, unserved behavior. Tibb moves an existing habit into a tool built for it.
2. **Working app:** list what is fully functional, and be honest about what's stretch or deferred.
3. **RevenueCat:**
   - `pro` entitlement, lifetime + yearly offering;
   - a hand-built paywall driven entirely by RevenueCat offerings, shown at intent-based moments with trigger-specific context;
   - Restore, subscription management, and instant unlock via the customer-info listener;
   - *why* lifetime pricing is sustainable: there are no server costs per user.
4. **Technical choices & product thinking:** no-server architecture, append-only change log with tombstones, content-hash media, a zero-dependency Bridge page served from the phone, honest disclosure of platform and security limits, and export that is never paywalled.

### Assets

- 1024×1024 app icon.
- At least one screenshot at 1179×2556 with no device frame.

### Eligibility Checklist

- Academic email on Devpost, verified with the domain checker.
- If under 18: the parent/guardian consent form is completed **before** submitting.

---

## 15. Risks

| Risk | Level | Mitigation |
|---|---|---|
| Bridge blocked by client isolation on campus/café Wi-Fi | High (for the demo) | Record on home Wi-Fi or a phone hotspot with the laptop connected to it |
| Large uploads freezing the phone UI | Medium | Stream uploads to disk in the server isolate; hash while streaming |
| Android killing the Bridge server in background | Medium | Foreground service with a persistent notification |
| Offerings fail to load during the demo | Low | Retry state on the paywall; test the full purchase flow on the demo device right before recording |
| iOS Share Extension complexity | Medium | Stretch only; Android share is CORE |
| WhatsApp export format differences by locale | Medium | Format detection plus a user-confirmed preview; tests with sample exports in several locales |
| Scope creep | High | Build strictly in phase order; stretch items only once Phases 0–8 work end to end |

---

## 16. Open Questions

1. **License:** AGPL-3.0 (recommended) or MIT?
2. **Domain name** for the landing site.

---

## 17. The Wow Moments (checklist for the demo)

- [ ] Saved with no account, no network, instantly
- [ ] Years of WhatsApp self-chat imported in one step
- [ ] Paywall appears exactly when you reach for Bridge; Pro unlocks instantly
- [ ] Phone's library opens in a laptop browser, straight from the phone, over Wi-Fi
- [ ] File dragged on the laptop lands on the phone, with a notification
- [ ] OTP copied on the laptop, pasted on the phone seconds later
- [ ] Fingerprint-locked box invisible to search and to the laptop
- [ ] Whole library exported as one password-encrypted file

---

## 18. The One Line to Remember

**Tibb keeps the ease of messaging yourself, gives it a container you own, and reaches your computer without ever touching a cloud.**