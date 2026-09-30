# Decision log

### ADR-001 — Flutter, iOS first (2026-09-27) — *superseded by ADR-013*
**Decision:** Flutter; iOS is the primary, tested-on-device platform. Android is generated and configured by the setup script but secondary.
**Reason:** The developer's only test device is an iPhone; the hackathon requires a demo on a real device.
**Impact:** iOS-specific behavior (foreground-only Bridge, Local Network prompt, Face ID copy) is designed in, not patched later.

### ADR-002 — Custom paywall on RevenueCat offerings (2026-09-27)
**Decision:** Build the paywall from scratch on `getOfferings()` / `purchasePackage()`; no RevenueCat dashboard paywalls, no purchases_ui_flutter, no Customer Center.
**Reason:** Owner directive; also lets copy match the trigger and keeps the design system intact.
**Alternatives:** RevenueCat Paywalls (faster, less on-brand).

### ADR-003 — Raw SQL via `sqlite3` instead of drift (2026-09-28)
**Decision:** `sqlite3` + `sqlite3_flutter_libs`, hand-written SQL.
**Reason:** No build_runner step (fewer ways for a first build to fail), bundled SQLite guarantees FTS5 on iOS, schema is small.
**Alternatives:** drift (typed queries, codegen), sqflite (system SQLite, async).
**Impact:** Queries are synchronous on the UI isolate. Fine at personal-library scale; revisit with an isolate if libraries reach tens of thousands of items.

### ADR-004 — Dependency list (2026-09-28)
Each package maps to a brief requirement: sqlite3(+libs), path_provider, path, file_picker, image_picker, record, just_audio, video_player, local_auth, crypto, cryptography(+_flutter), archive (WhatsApp .zip only), share_plus, url_launcher, wakelock_plus, purchases_flutter, phosphor_flutter.
**Rejected:** shelf (dart:io is enough and streams better), a state-management package (five ChangeNotifiers), flutter_local_notifications (see ADR-007), uuid (10-line helper).

### ADR-005 — The owner's logo replaces the design guide's icon concept (2026-09-28)
**Decision:** The uploaded logo (orange 3D open box on cream, "Tibb" wordmark with saffron dot) is the brand mark and app icon. The design guide's lowercase-wordmark / flat-icon concept is superseded. Colors, type and components are unchanged — the logo's orange/saffron matches the palette.

### ADR-006 — dart:io HttpServer for Bridge (2026-09-28)
**Reason:** Zero dependencies; direct control of streaming bodies, Range responses and headers.

### ADR-007 — No local notifications on iOS (2026-09-28)
**Decision:** Arrivals from a computer show an in-app toast ("Saved from Chrome on Windows").
**Reason:** On iOS Bridge only works while Tibb is on screen, so a system notification would never be seen in a state where it adds value.

### ADR-008 — Plain tar for exports (2026-09-28)
**Decision:** Exports are POSIX tar (streamed, own ~150-line writer/reader) instead of zip.
**Reason:** Streams multi-GB libraries in constant memory, opens with standard tools on every OS, and removes a dependency on the `archive` package's changing async/sync API for our own format.

### ADR-009 — WhatsApp media is a creation gate (2026-09-28)
**Decision:** Free users import WhatsApp text; attachments are imported only with Pro. Free imports go into the existing box as archived (a second box needs Pro); Pro imports get a dedicated "WhatsApp import" box.
**Reason:** Keeps the brief's rule that no payment state ever locks content the user already has in Tibb.

### ADR-010 — Photos saved as JPEG on iOS (2026-09-28)
**Decision:** `image_picker` with `imageQuality: 92`, which makes iOS return JPEG instead of HEIC.
**Reason:** HEIC doesn't render in Chrome/Edge on Windows, which would break the Bridge demo. Small quality trade-off, documented.

### ADR-011 — Share Extension deferred (2026-09-28)
**Decision:** No iOS Share Extension in the hackathon build. Capture on iOS = composer, attach sheet (photos, camera, files, clipboard), Bridge, WhatsApp import.
**Reason:** A Share Extension is a separate Xcode target with an App Group and can't be generated reliably without a Mac to test on.

### ADR-012 — License: AGPL-3.0 (2026-09-28)
**Decision:** AGPL-3.0 (the brief's recommendation). Swapping to MIT is a one-file change if the owner prefers.

### ADR-013 — Android becomes the primary test target (2026-09-28)
**Decision:** The owner will demo on a borrowed Android phone; iOS stays supported in code but is no longer the tested path.
**Reason:** An iOS build needs a Mac with Xcode, which the owner doesn't have. Android builds from any OS.
**Changes:**
- `tool/setup.sh` (bash, Mac-only edits) is replaced by `tool/setup.dart`, which runs anywhere Flutter runs.
- Adaptive Android launcher icon generated from the logo.
- User-facing wording is platform-aware via `PlatformCopy` (fingerprint vs Face ID, Google Play vs App Store).
- Android hotspot interfaces are recognized by Bridge.
- The cleartext-traffic flag is *not* set: Tibb only receives HTTP (Bridge); its outbound traffic (RevenueCat) is HTTPS.
