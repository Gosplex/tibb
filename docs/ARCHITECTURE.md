# Architecture

## Principles
1. **Local-first, no server.** The phone is the only source of truth. Nothing Tibb does needs the internet except RevenueCat.
2. **One write path.** `LibraryRepository` is the only thing that writes data. The Flutter UI, the Bridge HTTP server, import and WhatsApp import all call it.
3. **Append-only change log.** Every mutation is a `ChangeEvent`; `boxes`/`items` are a materialized view.
4. **Content-addressed media.** Files are stored as `<sha256><ext>`, streamed to disk while hashed.
5. **Design tokens are law.** Every visual value comes from `lib/design/tokens.dart` / `theme.dart`.

## Layers
```
UI (features/*)  ──►  LibraryRepository  ──►  ChangeLog ──► SQLite (tables + FTS5)
      ▲                    │   ▲                          
      │ ChangeNotifier     │   └── BlobStore (files by hash)
      │ + changes stream   ▼
  BridgeServer (dart:io HttpServer) ◄──► browser (assets/bridge/*)
```

- **State management:** plain `ChangeNotifier` services held in `AppScope` (an `InheritedWidget`) and read with `ListenableBuilder`. No state package — five services, no codegen.
- **Services:** `LibraryRepository` (data), `ProService` (RevenueCat), `LockService` (Face ID session), `BridgeServer` (LAN server), `SettingsController` (theme, counts).

## Data model (SQLite)
| table | purpose |
|---|---|
| `meta` | device id, counters, settings, one-time flags |
| `devices` | this phone + every paired browser (name shown on bubbles) |
| `boxes` | id, name, emoji, color, locked, sort order, tombstone |
| `items` | text/link/image/video/voice/file/clipboard, note, pinned, archived, reviewed, origin device, tombstone, expiry |
| `blobs` | hash → mime, size |
| `changes` | the log: event id (unique), device, counter, ts, entity, op, JSON payload |
| `items_fts` | FTS5 index of text + note + file name (clipboard items excluded) |

### Change log rules (`core/changelog/change_log.dart`)
- Ops: `device.register`, `box.create/update/delete/markReviewed`, `item.create/update/delete/restore`.
- **Idempotent:** an event whose id is already in `changes` is ignored → re-import is a no-op.
- **Tombstones:** deletes set `deleted_at`; nothing is physically removed.
- **Conflicts:** last-write-wins per entity by event timestamp (documented simplification; per-field LWW is future work).

## Bridge (`features/bridge/bridge_server.dart`)
- Binds to the Wi-Fi (`en0`) or Personal Hotspot (`bridge*`) IPv4, port 8080 (fallback: any free port).
- Pairing: 6 random digits, 5-minute life, 5 attempts, single use; then a 32-byte bearer token held only in the browser tab's memory. One session at a time, 30-minute idle expiry.
- Endpoints: `POST /api/pair`, `GET /api/state|items|search|events|blob/<hash>`, `POST /api/items|upload|clipboard|device`, `DELETE /api/session`.
- Live updates: long-poll `GET /api/events?since=<seq>` (answers on the next change or after 25 s).
- Uploads stream the raw request body into the BlobStore; downloads support HTTP Range (video scrubbing). Only media and PDFs render inline; everything else is `Content-Disposition: attachment` so an uploaded HTML/SVG can't run script on the Bridge origin. The page has a strict same-origin CSP.
- Locked boxes appear as "Locked on your phone" with no content unless the owner shares them for this session with Face ID.
- iOS: the Local Network prompt is triggered by one UDP datagram when Bridge starts; the screen is kept awake (wakelock) while it runs.

## Export format (`features/export_import/`)
Plain POSIX tar (`.tibb`): `manifest.json`, `changes.jsonl`, `blobs/<hash><ext>`. Encrypted exports wrap the tar:
`TIBBENC1 | salt(16) | memKiB | iterations | chunkSize`, then 1 MiB AES-256-GCM chunks whose AAD binds the header, chunk index and a last-chunk flag (reordering/truncation detected). Key: Argon2id (19 MiB, t=2, p=1) in a background isolate.
Import verifies every blob hash and the presence of every referenced blob **before** applying events in one transaction — all or nothing.

## Monetization (`features/paywall/`)
Entitlement `pro`; offering `default` with `$rc_lifetime` and `$rc_annual`. `ensurePro(context, reason)` is the single gate. The custom paywall reads `offerings.current`, shows context-specific copy, pre-selects lifetime, never treats cancel as an error, and always offers Restore.
