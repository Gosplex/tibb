# Changelog

## 0.2.0 — 2026-09-28 (product polish pass)

Added
- **Share into Tibb (Android)** — real system share target for text, links, photos, videos, audio, PDFs and any file, single or multiple; "Open with Tibb" for `.zip`. Native Kotlin (`MainActivity.kt`), no new pub packages. Share-in sheet (design S13) with preview, optional box chip, Pro gating that never loses the share, locked-box redirect, progress for large files, the lid moment, and return to the source app.
- **Notifications (Android, native)** — channels "From your computer", "Bridge status", "Imports". Batched "Saved from Chrome on Windows", "Clipboard from your computer", "Imported N items from WhatsApp" (only when Tibb isn't on screen). Never about absence.
- **Bridge foreground service (Android)** — Bridge survives minimizing; persistent notification with Stop; Wi-Fi and wake locks while connected. iPhone keeps the screen-awake behavior.
- **WhatsApp import, rebuilt** — shared `WhatsAppImporter` used by the phone and the computer; parsing in a background isolate; date-order detection with user confirmation (Day/Month · Month/Day with live samples); duplicate skipping on re-import; batched writes with progress and Stop; clear errors; done view with counts, Open box and Unarchive all. WhatsApp exports shared to Tibb go straight into import.
- **WhatsApp import from the computer** — new Bridge endpoints (`/api/import/whatsapp`, `/order`, `/commit`, `/status`) and a dialog on the Bridge page.
- **Bridge API** — `POST /api/items/update` for archive/pin from the computer.
- Illustrations drawn in code (open box, phone + laptop, chat → box, locked box, closed box, tucked) and the lid micro-motion; `TibbSegmented` and `TibbProgress` components.
- iOS `Info.plist` permission strings (Face ID, microphone, photos, camera, local network).
- `tool/bridge_mock/e2e.py` Playwright walk-through; mock extended with the new endpoints.

Changed
- **Bridge web page redesigned end to end**: pairing with illustration and success morph; rail with connection pill, search, clipboard entry, boxes (locked shown as absent), WhatsApp import, device rename dialog; header with archive view; clipboard card; bubbles with link cards, media thumbnails, custom voice player, file tiles with middle-ellipsis; hover actions (copy, download, pin, archive with undo); full-screen media viewer; search grouped by box with highlighted matches and "Show in box"; skeletons; empty states; drop overlay; transfer tray with cancel; toasts; tooltips; keyboard shortcuts; reduced motion; icon rail at 720–1023 px and drawer + box dropdown under 720 px.
- **Bridge phone sheet redesigned**: first-run explainer with the honest HTTP note, address with the IP emphasized, pairing tiles, countdown ring, "Not connecting?" after 60 s, connected card with a settle-in check, Send clipboard, Stop.
- **Paywall** follows S16/S17: "Unlock Tibb.", trigger-specific headline and illustration, six value rows, yearly billing line, success sparkle burst, and a Continue button that finishes the original action (auto after 2.5 s).
- Thread empty state ("Your box is ready."), "Coming from WhatsApp?" link, one-time share hint, WhatsApp import in the ⋯ menu; no haptics on passive arrivals (design §11.2); theme picker uses the design-system segmented control; privacy screen illustration.

Not added (by design)
- No Phosphor package: icons stay on Material `IconData`; the Bridge page uses its own inline SVG sprite.
- No iOS Share Extension (needs Xcode; stretch goal).


## 0.1.0 — 2026-09-28 (hackathon build, unverified on device)

Added
- Thread with boxes, day separators, grouping, tucked-corner bubbles, unreviewed dots and "New since you last looked"
- Text, links, photos, videos, files, voice memos (hold to record, slide to cancel)
- Swipe to archive / pin, item actions (copy, share, note, move, edit, archive, delete with undo), archive screen, bulk "archive older than 30 days"
- Full-text search with filters and highlighted matches
- Boxes: create, edit (emoji, color), delete, locked boxes with Face ID
- Tibb Bridge: phone-hosted web page, pairing code, uploads/downloads, live updates, clipboard card, search
- Custom RevenueCat paywall (lifetime + yearly), restore, Pro status screen
- Export / import (optionally encrypted), WhatsApp import
- Light and dark themes, reduced-motion support
- `tool/setup.dart` (cross-platform), adaptive Android icon, Bridge mock server + Playwright walk-through, unit tests
- RevenueCat placements per paywall trigger and custom-paywall impression tracking
- Platform-aware wording (Android / iPhone)

Known
- Flutter code not yet compiled (see PROJECT_STATE.md)
