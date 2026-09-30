# PROJECT STATE — Tibb

**Last updated:** 2026-09-28
**Hackathon deadline:** Sep 30, 2026, 11:45 PM PDT (Oct 1, 12:15 PM IST)

## Status in one paragraph
- All planned features for the hackathon build are **written**.
- **None of the Flutter code has been compiled or run yet.** The environment it was written in had no Flutter SDK or pub access.
- **What was verified:**
  - every Dart file parses (tree-sitter Dart grammar, 0 errors);
  - the Bridge web page passes a full walk-through in headless Chrome against a mock server;
  - icon names and the RevenueCat, cryptography and archive APIs were checked against package source;
  - the setup script's Android edits were exercised (bash version, since ported to Dart).
- Type errors and small API mismatches are still possible. Expect a short fix-up pass on the first `flutter run`.

**Overall progress:** code about 90% written; **verified-on-device: 0%**.

## CURRENT PHASE
Phase 6 — first build on a real Android phone.

## NEXT TASK
1. `dart run tool/setup.dart`, then `flutter analyze`, then fix any errors.
2. `flutter test`, then fix failures.
3. `flutter run --dart-define-from-file=env.json` on the Android phone.
4. Walk the demo path in order:
   - save text;
   - paywall → Test Store purchase → "You're in.";
   - photo;
   - voice memo;
   - a second box;
   - lock a box;
   - Bridge from a laptop (drag a file in, send to the clipboard card);
   - export, then import.

## STATUS KEY
`[x]` done and verified · `[~]` written, not verified on device · `[ ]` not started · `[!]` blocked

## FEATURES
**Foundation**
- [~] Design tokens, light and dark themes, typography (bundled fonts), icons, shared components.
- [~] SQLite schema, change log (idempotent, tombstones, last-write-wins), blob store, repository. Unit tests written, not run.

**Core**
- [~] Thread:
  - day separators, grouping and tucked corners;
  - unreviewed dots and the "New since you last looked" divider;
  - swipe to archive or pin, with undo;
  - pinned strip and clipboard card;
  - toasts for items arriving from the computer.
- [~] Composer: text, the + sheet (photos/videos, camera, files, paste), hold-to-record voice with slide-to-cancel.
- [~] Viewers: image (zoom, swipe down to close), video, voice playback, files via the share sheet.
- [~] Item actions: copy, share, pin, note, move, edit, archive, delete with undo.
- [~] Boxes: switcher, editor (emoji, color, lock), delete with confirmation.
- [~] Search (FTS5, filters, highlighted matches, "Show in box") and Archive (plus "archive older than 30 days").

**Differentiators**
- [~] Tibb Bridge, phone side: server, pairing, sessions, streaming upload and download, Range support, long-poll updates, the phone screen, troubleshooting page.
- [~] Tibb Bridge web page: **passes the Playwright walk-through against `tool/bridge_mock`**. Not yet tested against the real phone server.
- [~] Locked boxes: fingerprint or Face ID, screen-lock fallback; re-locks on background or after 60 s idle; optional sharing with Bridge for one session.
- [~] Export and import: tar format, optional AES-256-GCM with an Argon2id key, all-or-nothing import. Tests written, not run.
- [~] WhatsApp import: Android and iPhone formats. Text is free; media needs Pro. Parser tests written, not run.

**Monetization (RevenueCat)**
- [~] ProService:
  - configure, entitlement `pro`, restore, management URL;
  - per-trigger **placements** that fall back to `offerings.current`;
  - **custom paywall impression tracking**.
- [~] Custom paywall: 8 triggers with their own opening lines; loading, failed, not-configured, purchasing and success states; lifetime pre-selected; Restore always visible.
- [~] Tibb Pro status screen.
- [ ] RevenueCat dashboard configured: products, entitlement `pro`, offering `default`, optional placements. **Owner action**; steps are in the README.

**Settings, docs, packaging**
- [~] Settings (theme, hide counts, export, import, WhatsApp, privacy, about) and the Privacy screen.
- [x] README, ARCHITECTURE, DECISION_LOG, CHANGELOG, LICENSE (AGPL-3.0).
- [~] `tool/setup.dart`. Not run against a real `flutter create` output.

## ADDED IN 0.2.0 (written, not yet compiled on device)
- [~] Share into Tibb on Android (native, `MainActivity.kt`) + share-in sheet.
- [~] Native notifications + Bridge foreground service (Android).
- [~] WhatsApp importer shared by phone and Bridge; date-order confirmation; dedupe; import from the computer.
- [x] Bridge web page redesign — **verified** with `tool/bridge_mock/e2e.py` (light/dark, 1360/900/600 px).
- [~] Bridge phone sheet, paywall S16/S17, illustrations, empty states.

**First things to check on device:** share a photo from Gallery to Tibb; share a WhatsApp export zip; start Bridge, minimize Tibb, drop a file from the computer (notification should appear); tap Stop in the notification.

## NOT STARTED / DEFERRED
- [ ] iOS Share Extension (needs Xcode + App Group). Android share-in is done.
- [ ] Google Drive sync (brief: deferred).
- [ ] Tablet two-pane layout. The thread is width-capped at 720 instead.
- [ ] Hands-free voice lock (slide up while recording).

## BLOCKED
- [!] **iOS on-device testing.** Needs a Mac with Xcode, which the owner doesn't have. Android is the primary target (ADR-013).

## KNOWN RISKS ON FIRST COMPILE
These are the places most likely to need a one-line fix:
- **`local_auth` 2.x `AuthenticationOptions`**: pinned `^2.3.0`; version 3.x changed the API.
- **`record` 5.x**: `onAmplitudeChanged` and `cancel()`.
- **`cryptography`**: confirm `SecretBoxAuthenticationError` is exported. Its throw site was checked, but its definition wasn't found.
- **`share_plus` 10**: `Share.shareXFiles` is deprecated in 11.
- **Theme types**: Flutter-version differences such as `DialogThemeData` (needs Flutter 3.27 or newer).
- **Android NDK version warnings** from plugins. The README has the fix.

## TECHNICAL DEBT
**Medium**
- Last-write-wins is per entity, not per field. This only matters once multi-device sync exists.
- DB queries run synchronously on the UI isolate. Fine at personal scale; move to an isolate if libraries grow very large.
- Bridge is plain HTTP on the LAN. This is disclosed in-app and in the README.
- Encryption uses native AES (via `cryptography_flutter`), but Argon2 is pure Dart, so the first key derivation takes about 1–3 s.

**Low**
- The Bridge page uses simple hand-drawn SVG icons rather than Phosphor's.
- Search results open the item's actions and a "Show in box" button; there is no scroll-to-item.
- The box-lid micro-interaction from the design guide appears only in the empty state, the paywall and the success view.

## TEMPORARY / PLACEHOLDERS
- **TEMP:** `kSourceUrl` in `settings_screen.dart` points to `github.com/johngospel003/tibb`. Set it to the real repo.
- **TEMP:** the Terms and Privacy URLs in `paywall_sheet.dart` point to `tibb.app/...`. Point them at real pages; GitHub Pages is fine.
- **MOCK:** `tool/bridge_mock/` is a development-only mock of the phone server. It is never shipped.

## IMPORTANT DECISIONS
See `docs/DECISION_LOG.md`:
- ADR-001–013, including raw SQLite (no codegen), the custom paywall, tar exports, the WhatsApp creation gate, and Android-first.
- The owner's logo replaces the design guide's icon concept.

## PROJECT HEALTH (directional)
| Area | Score | Notes |
|---|---|---|
| Architecture | 80 | Single write path, change log, streaming media |
| Design consistency | 75 | Tokens everywhere; not yet seen on a device |
| UX completeness | 75 | Loading, empty, error and success states exist for main flows |
| Testing | 25 | Tests written, none run; Bridge page verified via mock |
| Production ready | 30 | Uncompiled; placeholder URLs; no store listing |
