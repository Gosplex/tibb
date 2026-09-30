# Tibb — Design System & Product Design Specification

**Version 1.0 · Hackathon build (Shipaton 2026, Next Gen Award)**
**Source of truth for product scope:** *Tibb — Hackathon Brief (H2)*. This document defines how Tibb looks, moves, sounds and behaves. The brief defines *what* Tibb does.

**Platforms covered**
- **Tibb Mobile** — Flutter, Android and iOS.
- **Tibb Bridge page** — plain HTML/CSS/JS served from the phone to a desktop browser.
- **Landing site** — static HTML.

> **Labels used in this document**
> **ASSUMPTION** — a decision made where the brief is silent. It is safe to change, but change it everywhere.
> **RULE** — non-negotiable. Screens that break a rule fail design QA.

---

## 01 — Product Design Direction

### 1.1 What Tibb Really Is (design interpretation)

Tibb is a **private pocket**: the place you drop things so your head doesn't have to hold them. People arrive mid-task, often slightly stressed ("where did I put that code?"), and they need to leave within seconds. Most sessions last under ten seconds. A few sessions, like import, export or Bridge at a desk, are longer and more deliberate.

That produces two design modes that must feel like one product.

| Mode | When | Design priority |
|---|---|---|
| **Drop mode** | Capture from share sheet, composer, clipboard | Speed, zero decisions, instant confirmation |
| **Desk mode** | Search, triage, Bridge, import/export | Clarity, calm, confidence, control |

### 1.2 Emotional Journey

| Before | During | After |
|---|---|---|
| Low-level anxiety: *"I know I saved that somewhere."* Distrust of big chat platforms. | Relief. One tap, and it's tucked away. | Ownership. *"This is mine, it's all here, and nobody else can see it."* |

**Emotional goal:** Tibb should feel like a **well-made wooden box with a good lid**: warm to the touch, quiet, solid, and obviously yours. It is not a vault (cold, intimidating) and not a chat app (social, noisy).

### 1.3 Product Personality

| Trait | What it means | How it becomes design |
|---|---|---|
| **Private** | Yours alone, never observed | No avatars, presence dots or "online" language. Locked content is visually *absent*, not blurred. Copy says "on this phone," never "in the cloud." |
| **Quiet** | Doesn't demand attention | Warm paper neutrals and low-saturation surfaces, with one confident accent (saffron). No badges pushed outward. Notifications only for real events. |
| **Warm** | Human and friendly, not clinical | Warm-tinted neutrals (paper, not grey). Rounded geometry. A serif display face for emotional moments. Conversational microcopy. |
| **Quick** | Out of your way in seconds | The composer is always reachable. Optimistic UI everywhere. Motion under 250 ms for all capture paths. No spinners in capture flows. |
| **Honest** | Says exactly what's true | Plain-language limits ("Keep Tibb open on iPhone"). Prices named on buttons. Close buttons always visible. |
| **Crafted** | Small things done well | The "lid" micro-interaction, precise alignment, tabular numbers, and a monospaced type for addresses and codes. |

### 1.4 Design Philosophy — "Paper, Ink, Saffron"

- **Paper** is the ground: warm off-white backgrounds that feel personal, like a notebook rather than a dashboard.
- **Ink** is the content: near-black, slightly violet text with strong contrast.
- **Saffron** is the single signal color: *your* action, *your* things, the moment something is tucked away. It is warm, optimistic, and **unclaimed in this category**. WhatsApp owns green, Telegram and iMessage own blue, and Signal owns blue. Saffron also resonates culturally with Tibb's home market.

**Visual keywords:** warm paper · ink · saffron light · tucked · quiet confidence · handmade precision · nothing watching.

### 1.5 UX Principles (the rules for judging every future screen)

1. **Saving never waits.** Capture is a local write. No spinner, network or confirmation dialog ever stands between the user and "saved."
2. **No filing decisions at capture time.** The default box is always acceptable. Choosing a box is optional, never required.
3. **Retrieval beats organization.** Search is one tap from everywhere. Organization features (boxes, triage) must never slow capture.
4. **Absence, not obstruction, for private things.** Locked content isn't blurred or teased. It simply isn't there until unlocked.
5. **Say where things are.** Every item tells you where it came from (this phone / a named PC). Every privacy claim is literal and verifiable.
6. **Honest limits, stated once, at the right moment.** Disclose platform constraints where they matter, in plain words, without drama.
7. **Every state has a way forward.** No dead ends. Empty, error and locked states always offer the next action.
8. **Pay for power, never for your own data.** Paywalls gate new capabilities, never access to existing content. Export is always one tap away.
9. **Events, not nagging.** The app speaks only when something actually happened.

---

## 02 — Brand & Visual Identity

### 2.1 Brand Character

Tibb is the friend who keeps your spare key: dependable, discreet, and good-humored without being jokey.

### 2.2 The Brand Mark — "The Box with a Lid" (ASSUMPTION)

- A rounded square (squircle) box in ink, with a lid drawn as a separate, slightly lifted bar. A small saffron square sits inside, peeking out as "your thing."
- **App icon:** saffron background (#F5B324), ink box with lid, and a paper-colored item peeking out. It is bold at 29 px and distinctive in a grid of blue and green apps.
- The lid is also the core **micro-interaction**. When something is saved, the lid glyph in the header closes over it (see 10.4).

**Wordmark:** "tibb" in lowercase Figtree 800, with letter-spacing −2%. Lowercase feels personal and unpretentious.

### 2.3 Color Philosophy

- **One accent, used with discipline.** Saffron marks *your* actions and *your* items. It is never decoration.
- **Warm neutrals do 90% of the work.** Hierarchy comes from tone and type, not from many colors.
- **Semantic colors are reserved.** Plum means *private/locked*. Signal teal means *connected to your computer*. Neither is used for anything else.
- **Box accents** (8 swatches) let people recognize their boxes at a glance. They appear only as small tiles, dots and thin rules, never as large fills.

### 2.4 Shape Language

- **Soft rectangles with one tucked corner.** Message bubbles have 20 px radius on three corners and a tight 6 px "tucked" corner at the bottom on the origin side. This is Tibb's signature silhouette: things look like they have been *tucked in*.
- Containers use generous radii (14–20 px). Pills are used only for buttons, chips and tags.
- Never mix sharp (0 px) corners with the rounded system (RULE).

### 2.5 Illustration Language

- **Spot illustrations only**, used in empty states, onboarding, the paywall and the privacy explainer.
- **Style:** simple objects (boxes, lids, a laptop, a phone, a key, a paper slip) drawn with a 2 px ink stroke, rounded caps and joins, flat saffron and paper fills, and one box-accent color at most. There are no people, faces or hands. That fits "nothing watching" and avoids implying observers.
- **Size:** 160 × 120 pt on mobile, 240 × 180 px on desktop.
- **Dark theme:** strokes become #F2EEE8, saffron fills become #F2B33D, and paper fills become surface.2.
- **Format:** SVG, rendered with `flutter_svg`, and inlined in the Bridge page.

**Mascot: none (DECIDED).** A character would undermine the "private, nobody's here but you" feeling. The box-with-lid mark carries the personality instead.

### 2.6 Iconography

- **Family:** **Phosphor Icons** (MIT). Use *Regular* weight for default and inactive states and *Fill* weight for active and selected states. Rounded terminals match Tibb's geometry. The same SVGs are inlined on the Bridge page, so web and mobile icons are identical.
- **Flutter package:** `phosphor_flutter`.
- **Sizes:** see token `icon.size.*` (16 / 20 / 24 / 32 / 48).
- **Optical alignment:** icons sit on a 24 px grid. For play and arrow icons, nudge +1 px toward the direction of travel.
- **Key icon vocabulary (RULE: one meaning per icon)**

| Meaning | Icon |
|---|---|
| Box | `Package` |
| Locked box | `LockSimple` |
| Bridge / open on computer | `Laptop` |
| Clipboard | `ClipboardText` |
| Search | `MagnifyingGlass` |
| Archive | `Tray` → `TrayArrowDown` for the action |
| Unreviewed | small saffron dot (not an icon) |
| Pin | `PushPin` |
| Note | `NotePencil` |
| Voice | `Microphone` |
| Attach | `Paperclip` |
| Export | `Export` |
| Import | `DownloadSimple` |
| From computer (origin label) | `Desktop` |
| Pro | `Sparkle` (only on upgrade surfaces) |

### 2.7 Imagery

Tibb shows **only the user's own content**. There is no stock photography anywhere in the product.
- User images in bubbles keep their natural aspect ratio, capped at 4:5 portrait / 16:9 landscape, and are cropped with `BoxFit.cover` inside those caps.
- Thumbnails are square (1:1) in grids and search results.

---

## 03 — Color System

### 3.1 Core Palettes (raw values)

**Ink & Paper neutrals (warm, slightly violet-tinted)**

| Token | HEX | RGB | Use |
|---|---|---|---|
| `ink.950` | #121116 | 18, 17, 22 | Dark background |
| `ink.900` | #1C1A22 | 28, 26, 34 | Light text primary, dark text on saffron |
| `ink.850` | #1B1A20 | 27, 26, 32 | Dark surface |
| `ink.800` | #24222B | 36, 34, 43 | Dark surface.2 |
| `ink.750` | #2D2B35 | 45, 43, 53 | Dark surface.3 |
| `ink.700` | #34313D | 52, 49, 61 | Dark border |
| `ink.600` | #5E5866 | 94, 88, 102 | Light text secondary |
| `ink.550` | #6A6474 | 106, 100, 116 | Dark border strong |
| `ink.500` | #6F6876 | 111, 104, 118 | Light text tertiary |
| `ink.450` | #8B8392 | 139, 131, 146 | Light border strong (inputs) |
| `ink.400` | #8E8797 | 142, 135, 151 | Dark text tertiary |
| `ink.300` | #B7B0BE | 183, 176, 190 | Light disabled text |
| `ink.200` | #B8B1C0 | 184, 177, 192 | Dark text secondary |
| `paper.300` | #CFC7B9 | 207, 199, 185 | Light border emphasis (non-input) |
| `paper.200` | #E3DDD2 | 227, 221, 210 | Light border |
| `paper.150` | #EFEBE3 | 239, 235, 227 | Light sunken surface |
| `paper.100` | #F7F4EE | 247, 244, 238 | Light background |
| `paper.50` | #FFFFFF | 255, 255, 255 | Light surface |
| `paper.dark` | #F2EEE8 | 242, 238, 232 | Dark text primary |

**Saffron — the brand accent**

| Token | HEX | HSL |
|---|---|---|
| `saffron.50` | #FFF8E6 | 43°, 100%, 95% |
| `saffron.100` | #FCE9B8 | 43°, 91%, 85% |
| `saffron.200` | #FAD98A | 42°, 91%, 76% |
| `saffron.300` | #F7C552 | 42°, 91%, 65% |
| **`saffron.400`** | **#F5B324** | **41°, 91%, 55%** ← brand |
| `saffron.450` | #F2B33D | 39°, 88%, 59% ← dark-theme brand |
| `saffron.500` | #E09A0B | 40°, 91%, 46% |
| `saffron.600` | #B87A06 | 39°, 94%, 37% |
| `saffron.700` | #8A5A06 | 38°, 92%, 28% ← saffron *text* on light |
| `saffron.800` | #5E3D08 | 37°, 84%, 20% |
| `saffron.900` | #3A2F1A | 39°, 38%, 16% ← dark self-bubble |

**Semantic hues**

| Role | Light (text/icon) | Light tint bg | Dark (text/icon) | Dark tint bg |
|---|---|---|---|---|
| **Plum — private/locked** | #5B3FD1 | #EFEAFF | #A796FF | #2A2342 |
| **Signal — connected to PC** | #0A7366 (text) / #0B7D6E (icon) | #E3F6F2 | #3CC7B3 | #11302C |
| **Success** | #1D7F47 | #E4F4EA | #5BD08E | #12301F |
| **Warning** | #9A5B00 | #FFF1D9 | #F5B85A | #3A2A10 |
| **Error** | #C0352D | #FCE9E7 | #FF7A70 | #3D1A18 |
| **Info** | #2A62C9 | #E6EEFC | #7FAAFF | #18233D |

**Box accent swatches** (tiles, dots, thin rules only)

| Name | Light | Dark |
|---|---|---|
| Saffron (default) | #F5B324 | #F2B33D |
| Coral | #E8664F | #F08A76 |
| Rose | #D9477E | #EE7AA3 |
| Plum | #7B5CE6 | #A796FF |
| Ocean | #2F7DD6 | #7FB2F5 |
| Teal | #13A08C | #3CC7B3 |
| Leaf | #4E9A3A | #86C96F |
| Slate | #6E7580 | #A4ABB6 |

**RULE:** a box accent never carries meaning on its own. Box identity is always emoji + name + color.

### 3.2 Opacity Scale

| Token | Value | Use |
|---|---|---|
| `opacity.disabled` | 0.38 | Disabled controls (applied to content, not container) |
| `opacity.hover` | 0.06 | Hover overlay (web) |
| `opacity.pressed` | 0.10 | Pressed overlay |
| `opacity.focusTint` | 0.12 | Selected-row tint |
| `opacity.scrim.light` | 0.32 | Behind sheets, light theme (ink.900) |
| `opacity.scrim.dark` | 0.56 | Behind sheets, dark theme (#000000) |
| `opacity.dragOverlay` | 0.92 | Bridge drop overlay (paper.100 / ink.950) |

### 3.3 Verified Contrast (WCAG 2.2)

| Pair | Ratio | Passes |
|---|---|---|
| text.primary on background (light) | 15.7 : 1 | AAA |
| text.secondary on background (light) | 6.2 : 1 | AA |
| text.tertiary on background (light) | 4.9 : 1 | AA |
| text.tertiary on surface.sunken (light) | 4.5 : 1 | AA |
| text.secondary on bubble.self (light) | 5.7 : 1 | AA |
| ink.900 on saffron.400 (primary button) | 9.3 : 1 | AAA |
| saffron.700 on background (light, saffron text) | 5.4 : 1 | AA |
| border.input on background (light) | 3.3 : 1 | Non-text 3:1 ✓ |
| text.primary on background (dark) | 16.3 : 1 | AAA |
| text.tertiary on surface (dark) | 5.0 : 1 | AA |
| text on bubble.self (dark) | 11.2 : 1 | AAA |
| ink.950 on saffron.450 (dark primary button) | 10.1 : 1 | AAA |
| border.input on background (dark) | 3.3 : 1 | Non-text 3:1 ✓ |
| All semantic text colors on their background, both themes | ≥ 4.5 : 1 | AA |

**RULE:** saffron.400 is **never** used as text or as a thin line on light backgrounds (only 1.7 : 1). Use `saffron.700` for saffron-colored text on light, and saffron.400 only as a *fill* with ink text on top.

---

## 04 — Light Theme (semantic tokens)

| Token | Value | Notes |
|---|---|---|
| `color.background.primary` | #F7F4EE | App background (paper) |
| `color.background.thread` | #F7F4EE | Thread background |
| `color.surface.default` | #FFFFFF | Cards, sheets, other-device bubbles |
| `color.surface.sunken` | #EFEBE3 | Composer field, search field, code blocks |
| `color.surface.raised` | #FFFFFF + `elevation.low` | Menus, banners |
| `color.surface.inverse` | #1C1A22 | Toasts/snackbars |
| `color.text.primary` | #1C1A22 | |
| `color.text.secondary` | #5E5866 | Supporting text, previews |
| `color.text.tertiary` | #6F6876 | Timestamps, device labels, helper text |
| `color.text.disabled` | #B7B0BE | |
| `color.text.onAccent` | #1C1A22 | Text on saffron |
| `color.text.onInverse` | #F2EEE8 | Text on toasts |
| `color.text.link` | #1C1A22 + underline | Links rely on underline, not color |
| `color.text.accent` | #8A5A06 | Saffron-family text (e.g. "Launch price") |
| `color.border.subtle` | #E3DDD2 | Dividers, bubble outlines |
| `color.border.default` | #CFC7B9 | Cards needing definition |
| `color.border.input` | #8B8392 | Text inputs, checkboxes (≥ 3:1) |
| `color.border.focus` | #1C1A22 | 2 px focus ring |
| `color.border.selected` | #F5B324 | Selected plan card, selected box (2 px fill-color border) |
| `color.action.primary` | #F5B324 | Primary button fill |
| `color.action.primary.pressed` | #E09A0B | |
| `color.action.primary.hover` | #F7C552 | Web |
| `color.action.secondary` | #1C1A22 | Secondary (ink) button fill |
| `color.action.secondary.pressed` | #34313D | |
| `color.action.tertiary` | transparent + border.default | Outline button |
| `color.action.destructive` | #C0352D | |
| `color.bubble.self` | #FCE9B8 | Items from this phone |
| `color.bubble.self.text` | #1C1A22 | |
| `color.bubble.self.meta` | #6E6452 | Timestamp inside self bubble (4.9 : 1) |
| `color.bubble.other` | #FFFFFF | Items from a computer |
| `color.bubble.other.border` | #E3DDD2 | |
| `color.bubble.clipboard` | #FFFFFF + 2 px dashed border.default | Clipboard card |
| `color.unreviewed.dot` | #F5B324 with 1 px #8A5A06 ring | Ring keeps it visible to colorblind users |
| `color.private.fg` / `.bg` | #5B3FD1 / #EFEAFF | Locked states |
| `color.connected.fg` / `.bg` | #0A7366 / #E3F6F2 | Bridge states |
| `color.success.fg` / `.bg` | #1D7F47 / #E4F4EA | |
| `color.warning.fg` / `.bg` | #9A5B00 / #FFF1D9 | |
| `color.error.fg` / `.bg` | #C0352D / #FCE9E7 | |
| `color.info.fg` / `.bg` | #2A62C9 / #E6EEFC | |
| `color.overlay.scrim` | rgba(28, 26, 34, 0.32) | |
| `color.overlay.pressed` | rgba(28, 26, 34, 0.10) | |
| `color.overlay.hover` | rgba(28, 26, 34, 0.06) | |
| `color.skeleton.base` / `.highlight` | #EFEBE3 / #F7F4EE | |

---

## 05 — Dark Theme (semantic tokens)

**Design intent: "Ink at night."** The dark theme is not an inversion. It is the same box, seen by lamplight.
- The background is a **warm violet-black** (#121116), not pure black. This reduces halation around text and stays in family with light ink.
- **Elevation is tonal.** Surfaces get lighter as they rise (850 → 800 → 750). Shadows are nearly invisible in the dark, so they are not relied on.
- **Saffron is slightly desaturated and shifted** (#F2B33D) to reduce glare on large fills while keeping identity.
- **The self bubble changes character.** A pale saffron bubble would glare at night, so it becomes a **deep amber-brown** (#3A2F1A) with warm cream text. It still reads as "saffron family" without shouting.
- **Semantic colors are lifted and softened** (lighter, less saturated) so they read on dark without vibrating.

| Token | Value | Behavior vs light |
|---|---|---|
| `color.background.primary` | #121116 | Warm near-black |
| `color.background.thread` | #121116 | |
| `color.surface.default` | #1B1A20 | Lighter than background (tonal elevation) |
| `color.surface.sunken` | #24222B | In dark, "sunken" inputs are *lighter* than background, which is still distinguishable |
| `color.surface.raised` | #24222B | Menus, banners |
| `color.surface.overlay` | #2D2B35 | Sheets and dialogs (highest) |
| `color.surface.inverse` | #F2EEE8 | Toasts invert |
| `color.text.primary` | #F2EEE8 | Warm off-white, never #FFFFFF |
| `color.text.secondary` | #B8B1C0 | |
| `color.text.tertiary` | #8E8797 | |
| `color.text.disabled` | #5A5563 | |
| `color.text.onAccent` | #121116 | |
| `color.text.onInverse` | #1C1A22 | |
| `color.text.accent` | #F2B33D | Saffron text is fine on dark (10 : 1) |
| `color.border.subtle` | #2D2B35 | |
| `color.border.default` | #34313D | |
| `color.border.input` | #6A6474 | ≥ 3 : 1 |
| `color.border.focus` | #F2B33D | Focus ring turns saffron in dark (ink would vanish) |
| `color.border.selected` | #F2B33D | |
| `color.action.primary` | #F2B33D | Slightly desaturated |
| `color.action.primary.pressed` | #D99A24 | |
| `color.action.primary.hover` | #F5C35E | |
| `color.action.secondary` | #F2EEE8 | Secondary button inverts to paper, with ink text |
| `color.action.secondary.pressed` | #D9D4CC | |
| `color.action.destructive` | #FF7A70 | Text/icon. Destructive fills use #C0352D with white text. |
| `color.bubble.self` | #3A2F1A | Deep amber |
| `color.bubble.self.text` | #F7ECD6 | |
| `color.bubble.self.meta` | #C9B68E | |
| `color.bubble.other` | #1B1A20 | |
| `color.bubble.other.border` | #34313D | |
| `color.unreviewed.dot` | #F2B33D | No ring needed; contrast is high |
| `color.private.fg` / `.bg` | #A796FF / #2A2342 | |
| `color.connected.fg` / `.bg` | #3CC7B3 / #11302C | |
| `color.success.fg` / `.bg` | #5BD08E / #12301F | |
| `color.warning.fg` / `.bg` | #F5B85A / #3A2A10 | |
| `color.error.fg` / `.bg` | #FF7A70 / #3D1A18 | |
| `color.info.fg` / `.bg` | #7FAAFF / #18233D | |
| `color.overlay.scrim` | rgba(0, 0, 0, 0.56) | Stronger, because dark UIs need more separation |
| `color.overlay.pressed` | rgba(242, 238, 232, 0.10) | Light overlay on dark |
| `color.overlay.hover` | rgba(242, 238, 232, 0.06) | |
| `color.skeleton.base` / `.highlight` | #1B1A20 / #24222B | |

**Theme selection:** follows the system by default. Settings offers *System / Light / Dark*.

---

## 06 — Typography System

### 6.1 Families

| Role | Family | Why |
|---|---|---|
| **UI (everything)** | **Figtree** (variable, 300–900, OFL) | Friendly geometric sans with open apertures. Warm without being cute, very legible at 12–13 px for timestamps, with good Latin plus Indian-English punctuation coverage. Distinct from the category's default system fonts. |
| **Display (emotional moments only)** | **Fraunces** (variable, "soft" axis, OFL), 600, SOFT 100, opsz auto | A warm, slightly quirky serif. It gives onboarding, empty states, the paywall and the landing site a handmade, personal voice, like a label on your own box. |
| **Mono (addresses, codes, sizes)** | **JetBrains Mono** (OFL) | Unambiguous characters (0/O, 1/l) are critical when typing `192.168.1.42:8080` and pairing codes. It also gives a crafted technical accent. |

**Fallbacks**
- UI: `Figtree, -apple-system, "Segoe UI", Roboto, system-ui, sans-serif`
- Display: `Fraunces, Georgia, "Times New Roman", serif`
- Mono: `"JetBrains Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace`

**RULE (privacy):** fonts are **bundled** as assets in the app (and served from the phone for the Bridge page). They are **never** fetched at runtime; do not use the `google_fonts` package's network loading. Tibb must not contact third-party servers.

**RULE:** Fraunces is used **only** for `display.*` and `headline.hero` styles, on at most one element per screen, and never for UI controls, bubbles or data.

### 6.2 Mobile Type Scale

All sizes are in logical pixels (dp/pt). Line height is given in absolute px. Letter spacing is given in em.

| Token | Family | Weight | Size | Line | Tracking | Use |
|---|---|---|---|---|---|---|
| `display.lg` | Fraunces | 600 | 40 | 44 | −0.02 | Onboarding hero, purchase success |
| `display.md` | Fraunces | 600 | 32 | 38 | −0.015 | Paywall "Unlock Tibb." |
| `headline.hero` | Fraunces | 600 | 26 | 32 | −0.01 | Empty-state headlines |
| `title.lg` (H1) | Figtree | 750 | 24 | 30 | −0.01 | Screen titles (Settings, Search results header) |
| `title.md` (H2) | Figtree | 700 | 20 | 26 | −0.005 | Box name in header, sheet titles |
| `title.sm` (H3) | Figtree | 650 | 17 | 22 | 0 | Section headers, card titles |
| `title.xs` (H4) | Figtree | 650 | 15 | 20 | 0 | List-row titles |
| `overline` (H5) | Figtree | 700 | 12 | 16 | +0.06, UPPERCASE | Section labels in Settings. Sparingly. |
| `body.lg` | Figtree | 450 | 17 | 24 | 0 | **Bubble text**, onboarding body |
| `body.md` | Figtree | 450 | 15 | 21 | 0 | Default body, list secondary text |
| `body.sm` | Figtree | 450 | 13 | 18 | +0.005 | Supporting text, legal lines |
| `caption` | Figtree | 550 | 12 | 16 | +0.01 | Timestamps, device labels, file meta |
| `label.lg` | Figtree | 650 | 15 | 20 | 0 | Chips, segmented control |
| `label.md` | Figtree | 650 | 13 | 16 | +0.01 | Tags ("From PC", "Launch price") |
| `button.lg` | Figtree | 700 | 17 | 22 | 0 | Primary/secondary large buttons |
| `button.md` | Figtree | 650 | 15 | 20 | 0 | Medium buttons, text buttons |
| `input` | Figtree | 450 | 17 | 24 | 0 | Text fields, composer (17 prevents iOS auto-zoom on web) |
| `helper` | Figtree | 450 | 13 | 18 | 0 | Helper text |
| `error` | Figtree | 550 | 13 | 18 | 0 | Error text (always paired with an icon) |
| `mono.xl` | JetBrains Mono | 600 | 30 | 36 | 0 | **Bridge address** on phone |
| `mono.lg` | JetBrains Mono | 600 | 34 | 40 | +0.2 | **Pairing code** digits |
| `mono.md` | JetBrains Mono | 500 | 15 | 20 | 0 | Recovery hints, inline code |
| `mono.sm` | JetBrains Mono | 500 | 12 | 16 | 0 | File sizes, counts in meta |
| `number.price` | Figtree | 800 | 28 | 32 | −0.01, tabular | Paywall price |
| `number.stat` | Figtree | 750 | 22 | 28 | tabular | "1,284 items imported" |
| `promo` | Figtree | 750 | 13 | 16 | +0.02 | "LAUNCH PRICE" tag. Sentence case in app ("Launch price"); caps allowed only on the landing site. |

- **Numbers:** always use tabular figures (`FontFeature.tabularFigures()`) for timestamps, sizes, counts and prices, so they don't jitter as they update.
- **Line length:** bubble text maxes out at the bubble's max width (78% of the thread, about 36–42 characters on phones). Long-form text such as the privacy explainer is capped at 34 em.
- **Dynamic Type / font scale:** support up to 200%. Above 130%, timestamps move from inline to their own line below the bubble text, and headers truncate the box name with an ellipsis before the icons wrap.

### 6.3 Tablet (≥ 600 dp)

Same scale, with these changes: `display.lg` becomes 48/52, `display.md` becomes 36/42, and the thread column caps at 720 dp, centered.

### 6.4 Desktop — Bridge Page & Landing Site (px)

| Token | Size / Line | Notes |
|---|---|---|
| `display.lg` | 56 / 60 | Landing hero only (Fraunces) |
| `display.md` | 36 / 42 | Pairing screen headline (Fraunces) |
| `title.lg` | 22 / 28 | Box name header |
| `title.md` | 17 / 24 | Rail section titles |
| `body.lg` | 15 / 22 | Bubble text. Desktop reading distance allows smaller text. |
| `body.md` | 14 / 20 | |
| `caption` | 12 / 16 | |
| `mono.lg` | 32 / 40 | Pairing input digits |
| `input` | 15 / 22 | |

Desktop body text maxes out at 68 characters per line (thread column 760 px).

---

## 07 — Spacing & Layout System

### 7.1 Spacing Scale (base unit: 4)

A 4-point base gives the fine control a dense chat thread needs (2/4 px nudges inside bubbles). Major rhythm steps are 8/16/24.

| Token | Value | Typical use |
|---|---|---|
| `space.0` | 0 | |
| `space.050` | 2 | Hairline nudges (icon optical alignment, timestamp baseline) |
| `space.100` | 4 | Inside chips; icon-to-caption |
| `space.150` | 6 | Between stacked bubbles from the same origin within 2 minutes |
| `space.200` | 8 | Icon-to-label; between chips; list-row internal gap |
| `space.300` | 12 | Bubble horizontal padding; gap between bubble groups |
| `space.400` | 16 | **Screen padding (mobile)**; card padding; sheet section gap |
| `space.500` | 20 | Sheet horizontal padding; paywall card padding |
| `space.600` | 24 | Section spacing; dialog padding |
| `space.800` | 32 | Between major sections; empty-state stack |
| `space.1000` | 40 | Onboarding vertical rhythm |
| `space.1200` | 48 | Empty-state top offset; desktop section gap |
| `space.1600` | 64 | Landing site sections; desktop hero |

**RULE:** no values outside this scale. If something needs 10 px, it's either 8 or 12.

### 7.2 Applied Spacing

| Context | Spec |
|---|---|
| Screen padding | 16 horizontal (mobile < 400 dp). 20 at ≥ 400 dp. 24 on tablet. |
| Thread | 12 between groups; 6 inside a group (same origin, < 2 min apart); 16 above and below day separators |
| Bubble padding | 12 horizontal, 9 top, 8 bottom (optically balanced for the timestamp row). **Exception:** 9 comes from 8 + the 1 px border. |
| Media bubble | 4 px inner padding around images, so the tucked corner still shows |
| Card padding | 16 (mobile), 20 (desktop) |
| Button padding | Large: 24 horizontal. Medium: 20. Small: 14. |
| Form fields | 16 between fields; 6 label-to-field; 6 field-to-helper |
| List rows | 16 horizontal, 12 vertical; 56 min height (single line), 72 (two lines) |
| Settings groups | 24 between groups; 8 overline-to-group |
| Sheets | 20 horizontal; 12 grabber-to-title; 24 title-to-content; 20 bottom (+ safe area) |
| Dialogs | 24 all sides; 12 title-to-body; 24 body-to-actions |
| Empty states | 48 top offset; illustration → 24 → headline → 8 → body → 24 → primary action → 12 → secondary |

### 7.3 Layout & Grid

**Mobile (phones, < 600 dp)**
- Single column, 4-column conceptual grid, 16 gutter, 16 (or 20) margins.
- **Thread:** self bubbles align right, with max width 78% of content width. Other-device bubbles align left with the same max width. Media bubbles max out at 72%.
- **Composer:** pinned to the bottom, always above the keyboard, with safe-area inset included. Height is 56 min and grows to 5 lines of text (about 144), then scrolls internally.
- **Safe areas:** respect the status bar, notch/Dynamic Island and home indicator. Android is **edge-to-edge**: the thread scrolls under a translucent status bar, and the composer sits above the gesture bar with an 8 dp extra gap.
- **Keyboard:** the thread stays anchored to the newest item as the keyboard opens. Sheets with inputs rise with the keyboard, and their primary action stays visible.

**Tablet (600–1023 dp):** thread column max 720, centered. The box switcher becomes a persistent **left rail at 280 dp** when width ≥ 840 dp.

**Bridge page (desktop browser)**

| Breakpoint | Layout |
|---|---|
| ≥ 1280 px | Rail 280, thread 760 max (centered in remaining space), optional detail pane 360 when an item is opened |
| 1024–1279 | Rail 260, thread fluid (max 760), detail opens as an overlay panel |
| 720–1023 | Rail collapses to a 72 px icon rail (box emoji tiles), thread fluid |
| < 720 | Single column: box switcher becomes a dropdown in the header, detail becomes full-screen |

The page never scrolls horizontally (RULE).

**Landing site:** 12-column grid, max content 1120, 24 gutters, 24 margins (mobile 20). Sections are separated by 64 (desktop) or 48 (mobile).

**Vertical rhythm:** baseline 4. All text line heights are multiples of 2 and component heights multiples of 4.

---

## 08 — Shape System

### 8.1 Corner Radius Tokens

| Token | Value | Where |
|---|---|---|
| `radius.xs` | 6 | **Tucked bubble corner**, tags, small thumbnails in search |
| `radius.sm` | 10 | Inputs, composer field, segmented control segments, toasts |
| `radius.md` | 14 | Box tiles (squircle icon), list-card groups, image thumbnails, menus |
| `radius.lg` | 20 | **Bubbles** (three corners), cards, plan cards, banners |
| `radius.xl` | 28 | Bottom sheets (top corners), dialogs, paywall container |
| `radius.full` | 999 | Buttons, chips, pills, toggles, avatars of boxes in compact rail |

**Bubble geometry (RULE)**
- Self (right): TL 20, TR 20, BR **6**, BL 20.
- Other device (left): TL 20, TR 20, BR 20, BL **6**.
- In a group of consecutive bubbles, only the *last* bubble has the tucked corner. The rest are fully rounded (20), which visually "stacks" them.

**Box tile:** 40 × 40, `radius.md`, box accent at 16% opacity as background (dark: 24%), with the emoji centered at 22 pt.

### 8.2 Borders

| Token | Width | Color | Use |
|---|---|---|---|
| `border.hairline` | 1 | border.subtle | Other-device bubbles, dividers, cards on sunken bg |
| `border.default` | 1 | border.default | Outline buttons, cards needing definition |
| `border.input` | 1 | border.input | Inputs, checkboxes, radio (unselected) |
| `border.focus` | 2 + 2 offset | border.focus | Every focusable element (keyboard / switch access) |
| `border.selected` | 2 | border.selected | Selected plan, selected box in switcher |
| `border.error` | 2 | error.fg | Invalid input |
| `border.dashed` | 2, dash 6/4 | border.default | Clipboard card, Bridge drop zone |
| `border.disabled` | 1 | border.subtle | Disabled inputs |

**When to use borders (RULE):**
- Use borders for things that sit **on the same plane** but need edges (inputs, other-device bubbles, cards on paper).
- **Do not** border elevated things (sheets, menus); their tone and shadow define them.
- Self bubbles have **no border**. Their fill is the edge.

### 8.3 Elevation

Tibb uses **tonal elevation first and shadows sparingly**. Shadows are warm (ink-tinted), never pure black.

| Token | Light shadow | Dark treatment | Use |
|---|---|---|---|
| `elevation.none` | none | surface.default | Thread, bubbles, lists |
| `elevation.subtle` | 0 1 2 0 rgba(28,26,34,0.06) | none (use border.subtle) | Cards on paper, composer bar top edge |
| `elevation.low` | 0 2 8 −2 rgba(28,26,34,0.10) | surface.raised | Banners, pinned clipboard card, floating date pill |
| `elevation.medium` | 0 8 24 −6 rgba(28,26,34,0.14) | surface.raised + 1 px border.default | Menus, popovers, Bridge detail panel |
| `elevation.high` | 0 16 40 −8 rgba(28,26,34,0.18) | surface.overlay | Bottom sheets, dialogs |
| `elevation.modal` | 0 24 64 −12 rgba(28,26,34,0.24) | surface.overlay + scrim 0.56 | Paywall, full-screen sheets over thread |

Format: x y blur spread color.

---

## 09 — Component System

### 9.1 Buttons

**Shared anatomy:** `radius.full`, label `button.*`, 20 dp icon with 8 dp gap, and minimum hit area 48 × 48 (RULE). Visual height may be smaller only if the hit area is padded out.

| Variant | Height (lg / md / sm) | Fill | Text / icon | Border |
|---|---|---|---|---|
| **Primary** | 56 / 48 / 36 | action.primary (saffron) | text.onAccent (ink) | none |
| **Secondary** | 56 / 48 / 36 | action.secondary (ink; dark: paper) | light: #F2EEE8, dark: #1C1A22 | none |
| **Tertiary (outline)** | 48 / 40 / 32 | transparent | text.primary | border.default 1 px |
| **Ghost** | 48 / 40 / 32 | transparent | text.primary | none |
| **Text button** | 40 / 36 | transparent | text.primary, underlined on web hover | none |
| **Destructive** | 48 / 40 | error.fg fill (dark: #C0352D) | #FFFFFF | none |
| **Icon button** | 48 × 48 (icon 24) | transparent | text.primary | none |
| **Icon button (filled)** | 44 × 44 | surface.sunken | text.primary | none |
| **Send button** (composer) | 40 × 40 circle | action.primary | ink arrow icon `ArrowUp` (Bold weight) | none |

- **Minimum widths:** lg 160, md 120, sm 72. Full-width in sheets and dialogs on phones.
- **Hierarchy (RULE):** at most one Primary per screen or sheet. Secondary is for strong alternatives (e.g. "Export everything" on the Tibb Pro screen). Tertiary and ghost are for everything else.

**States**

| State | Treatment |
|---|---|
| Hover (web) | overlay.hover on top of the fill; primary shifts to action.primary.hover |
| Pressed | Scale to **0.97** over `motion.fast` + action.*.pressed fill; haptic `selectionClick` for primary actions only |
| Focused | 2 px focus ring, 2 px offset, `radius.full` |
| Disabled | Content opacity 0.38, fill becomes surface.sunken, no shadow, no hover. Always explain *why* nearby if it isn't obvious. |
| Loading | Label fades out (120 ms), a 20 dp spinner (2 px stroke, text color) fades in, and the width is locked so there's no layout jump. Controls are non-interactive. |
| Success (purchase, export) | Spinner morphs into a check `Check` icon (bold) over 240 ms, holds 600 ms, then the next state takes over |

### 9.2 Inputs

**Text field (standard)**
- Height 52; `radius.sm`; fill surface.default (light) / surface.sunken (dark); border.input 1 px.
- Label sits **above** the field (`label.md`, text.secondary) with a 6 dp gap. Floating labels are not used, because they hurt scanability and translate poorly.
- Padding: 14 horizontal. Leading icon 20 with a 10 dp gap (**exception:** 10 = 8 + 2 optical).
- Helper text below in `helper`, text.tertiary.
- States:
  - **Focused:** border becomes 2 px border.focus (ink; dark: saffron) with no glow.
  - **Error:** 2 px error border, error text below with a `WarningCircle` 16 icon. The message is human (see 17.6).
  - **Disabled:** fill surface.sunken, text.disabled, border.disabled.
  - **Read-only:** no border, fill surface.sunken, and a copy icon button on the right.
  - **Success:** only where it's meaningful (e.g. "Passwords match"): a `CheckCircle` in success.fg plus helper text.
  - **Loading:** only for async validation, which Tibb has almost none of. Use an inline 16 spinner at the trailing edge.

**Search field:** height 44, `radius.full`, fill surface.sunken, leading `MagnifyingGlass` 20, and a trailing clear `XCircle` shown when there is text. Placeholder: "Search everything". Autofocus when the search screen opens.

**Password field** (encrypted export): a standard field plus a trailing eye toggle (`Eye` / `EyeSlash`, 48 hit area). Strength is shown as a 4-segment bar (3 px tall, `radius.full`) below the field in text.tertiary → warning → success, with a label ("Weak / Okay / Strong"). Colors are never the only signal. "Confirm password" appears after the first field is non-empty.

**Multiline (note editor, composer):** grows from 1 to 5 lines, then scrolls. The composer field uses fill surface.sunken, `radius.lg` (20) to echo bubbles, and no border.

**Composer (special component)**
- Layout: `[+ attach 44]` `[field]` `[mic 44 ↔ send 40]`. The mic becomes the send button as soon as there's text, via a 150 ms cross-fade + scale.
- Hold the mic to record (see 9.10). Tap the mic for a hint toast: "Hold to record."
- Paste into the field: if the clipboard holds an image or a file, the composer shows a preview chip above the field with an ✕ button.

**Selection controls**

| Control | Spec |
|---|---|
| Checkbox | 22 × 22 box, `radius.xs`, border.input; checked: saffron fill + ink check (bold); 48 hit area |
| Radio | 22 circle; selected: 2 px saffron ring (dark saffron) + 10 dp ink dot (dark: saffron dot) |
| Toggle | 52 × 32 track, `radius.full`; off: surface.sunken track + border.input, 24 thumb paper; on: saffron track + ink-coloured check glyph inside the thumb, so on/off doesn't rely on color alone. Haptic `selectionClick`. |
| Segmented control | 40 height, container surface.sunken `radius.sm`, selected segment surface.default + elevation.subtle; label `label.lg`; slide indicator over 240 ms |
| Slider | Not used in V1 |
| Dropdown / Select | Bridge page only (box switcher < 720 px): a native `<select>` styled as a text field with a `CaretDown` |
| Date | Not used in V1 |
| Number | Not used in V1. The pairing code uses the OTP input (9.9). |

### 9.3 Bubbles (Thread Items)

**Common anatomy:** content, then a meta row (`caption`: time · origin label if other · state icons: pin 12, note 12). Meta sits bottom-right inside the bubble. Above 130% font scale it moves outside, below the bubble.

| Type | Spec |
|---|---|
| **Text** | `body.lg`. Links are auto-detected, underlined, and tappable (long-press → Copy link / Open / Share). Up to 12 lines, then fades out with "Show more." |
| **Link-only** | A card inside the bubble: `Link` icon 20 + domain (`label.md`, text.secondary) + full URL (`body.md`, 2 lines). No remote preview fetch (privacy). Tap opens it in the external browser. |
| **Image** | 4 px padding, image `radius.lg − 4` = 16 on outer corners and 4 on the tucked corner. Max 72% width, aspect capped. Tap opens the viewer. |
| **Video** | Like image, plus a center play glyph on a 48 circle (ink at 64%) and the duration in the bottom-left (`mono.sm` on ink 64% pill). |
| **Voice** | Play button 36 circle (self: ink fill / other: surface.sunken) + waveform (24 bars, 3 px wide, 2 px gap, `radius.full`; played portion text.primary, unplayed text.tertiary at 50%) + duration `mono.sm`. Tap the waveform to scrub. Speed chip (1× / 1.5× / 2×). |
| **File / PDF** | 44 file tile (`radius.md`, box-accent tint, file-type icon: `FilePdf`, `FileZip`, `File`) + filename (`title.xs`, middle-ellipsis to keep the extension) + size and type (`mono.sm`). Tap opens with the system viewer. |
| **Clipboard card** | Pinned at the top of the thread, full content width, `border.dashed`, `ClipboardText` icon + "Clipboard from Chrome on Windows" (`caption`) + content (`mono.md` if it looks like a code or URL, else `body.lg`) + primary small button **Copy**. Expiry note: "Clears in 23 h". |
| **Imported (WhatsApp)** | Same as its base type, with a meta tag `WhatsApp · 12 Mar 2023` (`caption`, text.tertiary). |
| **Locked-box item (search results only, after unlock)** | Leading 12 `LockSimple` in private.fg. |

**Origin labeling (RULE)**
- **Self** (this phone) bubbles are right-aligned in bubble.self, with no device label.
- **Other** bubbles (from a computer via Bridge, or from another phone via import) are left-aligned in bubble.other + hairline, with a device label *above* the first bubble of a group: `Desktop` icon 14 + "Chrome on Windows" (`caption`, text.tertiary).

**Unreviewed marker:** a 8 dp saffron dot left of self bubbles (right of other bubbles), vertically centered on the first line. A full-width divider "New since you last looked" (`caption`, text.accent, with hairline rules either side) marks the first unreviewed item on open.

**Day separator:** centered pill, `caption`, surface.sunken, `radius.full`, 6 × 12 padding: "Today", "Yesterday", "Mon 14 Sep", "14 Sep 2025". While scrolling, a floating copy pins to the top with elevation.low.

### 9.4 Cards

Cards are used only where grouping or interaction needs it: settings groups, plan cards, Bridge status, import summaries. **Threads never use cards.**

| Card | Spec |
|---|---|
| **Standard** | surface.default, `radius.lg`, border.hairline (light) / none (dark, tonal), padding 16 |
| **Interactive** | Standard + pressed overlay + chevron `CaretRight` 16 if it navigates |
| **Info / status** | Semantic bg tint (e.g. connected.bg), 20 icon in semantic fg, title `title.xs`, body `body.sm`, optional text button. Used for the Bridge status and honest-limit notes. |
| **Plan card** (paywall) | See 9.13 |
| **Statistic** | `number.stat` + `caption` label. Used on import/export completion. |
| **Settings group** | A list inside one card, rows separated by hairline dividers inset 16 from the leading edge |

### 9.5 Navigation

**Architecture (mobile):** **no bottom tab bar.** Tibb is one surface, the thread, and bottom tabs would push the composer up and imply "sections" Tibb doesn't have.

**Top app bar (thread)**
- Height 56 + status bar, background background.thread, hairline bottom border **only once content scrolls under it**.
- Left: **box switcher button**: box tile (28) + box name (`title.md`) + `CaretDown` 16. Tap opens the Box Switcher sheet.
- Right: `MagnifyingGlass` (Search), `Laptop` (Bridge: shows a 6 dp connected.fg ring on the icon when a session is active), `DotsThreeVertical` (Android) / `DotsThree` (iOS) overflow → Archive, Box settings, Settings.

**Back navigation:** platform native. iOS uses edge swipe and a `CaretLeft` + previous title. Android uses the system back gesture and `ArrowLeft`.

**Sheets over pushes.** Box switcher, attach, item actions, share-in, Bridge and the paywall are **sheets**, which keep the thread in context. Settings, Search, Archive, Import/Export and the Privacy explainer are **pushed screens**.

**Tablet ≥ 840 dp:** a persistent box rail on the left (280). The switcher button becomes static text.

**Bridge page:** a left rail listing boxes (emoji tile 32 + name + unreviewed count), with Search at the top of the rail and a Clipboard entry pinned at the top of the rail.

### 9.6 Lists & Rows

| Row | Spec |
|---|---|
| Box row | Tile 40 + name `title.xs` + last-item preview `body.sm` text.secondary (1 line) + trailing unreviewed count (`label.md` in a 20 high pill, surface.sunken). Locked: preview replaced by "Locked", with a lock icon in private.fg. |
| Settings row | Leading icon 24 (text.secondary) + title `body.md` + optional value `body.md` text.tertiary + trailing chevron or toggle. 56 min height. |
| Search result | Thumbnail/icon 40 (`radius.md`) + matched text with the **match highlighted** (saffron.100 bg, dark: saffron.900; text.primary; weight 650) + box name and date `caption`. |

**Swipe actions (thread items)**
- **Swipe left** reveals Archive (`TrayArrowDown`, surface.sunken → fills saffron past the 40% threshold, with haptic `lightImpact` at the threshold). Releasing past the threshold archives it.
- **Swipe right** reveals Pin.
- Every swipe action is also available from the long-press menu (RULE: gestures are never the only path).

### 9.7 Feedback Components

| Component | Spec |
|---|---|
| **Toast / snackbar** | surface.inverse, text.onInverse `body.md`, `radius.sm`, 48 min height, 16 from the bottom (above the composer). Optional action (`button.md`, saffron.450 text). Auto-dismiss 4 s (8 s if it has an action). **Undo** for archive, delete and move. |
| **Banner** (persistent) | Full width under the app bar, `radius.lg` inset 12, semantic tint, icon + text + action. Used for "PC connected — tap to stop," the storage warning, and the soft Pro prompt (shown once). |
| **Badge / count** | `label.md`, surface.sunken pill, text.secondary. **Never red, never pushed to the app icon** (RULE: events, not nagging). |
| **Tag** | 22 height, `radius.xs`, `label.md`; semantic tint bg + fg. E.g. "Launch price" (saffron.100 / saffron.700), "Pro" (saffron.100), "Locked" (private.bg / fg). |

### 9.8 Modals, Sheets & Overlays

| Type | Spec |
|---|---|
| **Bottom sheet** | Top radius 28, surface.overlay (light: surface.default), grabber 36 × 4 `radius.full` text.tertiary at 40%, 12 from the top. Snap points: content height (max 90%). Dismiss by drag-down, scrim tap or back. Entrance 300 ms emphasized-decelerate; exit 200 ms accelerate. |
| **Full-screen sheet** | For the paywall and import preview. iOS: large sheet (the card stack shows). Android: full screen with a top-left `X`. **Close is always visible** (RULE). |
| **Dialog** | Width min(360, 100% − 48), `radius.xl`, padding 24, `title.md` + `body.md`. Actions stacked full-width on phones (Primary/Destructive on top, Cancel ghost below). Scrim at theme opacity. Entrance: fade + scale 0.96→1 over 200 ms. |
| **Confirmation (destructive)** | Dialog with a destructive primary. The title names the object ("Delete 'Receipts'?"), and the body states the consequence and the undo path. |
| **Context menu** (long-press) | Mobile: a bottom sheet of actions (more reliable than floating menus with large text). Desktop Bridge: a floating menu, 240 wide, `radius.md`, elevation.medium, 40 row height. |
| **Tooltip** | Web only. Ink 90% bg, `caption`, `radius.xs`, shown after 500 ms hover. Icon-only buttons have tooltips on web and `semanticLabel`s on mobile. |
| **Popover** | Bridge page: the device menu ("Rename this computer"). |

### 9.9 Bridge-Specific Components

**Address display (phone)**
- The address is shown in `mono.xl` in one line, auto-shrinking to 22 minimum. The port is in text.secondary so the IP reads first.
- Below it sits the **pairing code** as 6 digits in `mono.lg`, grouped 3 + 3 with an 8 dp gap, each digit on a surface.sunken tile 44 × 56 `radius.sm`.
- A **Copy address** tertiary button. A countdown ring (24, 2 px stroke, connected.fg) shows the code's remaining lifetime, with text "New code in 4:12" (`caption`, tabular).

**OTP input (Bridge page)**
- 6 boxes, 52 × 64, `radius.sm`, border.input, `mono.lg`. Auto-advance, paste fills all six, and backspace moves back.
- Wrong code: the boxes shake (see motion), turn to error border, and show text "That code didn't match. Check your phone for the current one."

**Connection status card:** info card in connected.bg: `Laptop` + "Chrome on Windows is connected" + "Stop" (tertiary small).

**Drop zone (Bridge page):** dragging files over the window shows a full-window overlay (background at 0.92) with a centered dashed 2 px box, `radius.xl`, 320 × 200 min, `DownloadSimple` 48 + "Drop to save on your phone" (`title.md`) + box name. It highlights with saffron border and a 1.02 scale when hovering the drop target.

**Transfer row:** filename + linear progress (4 high, `radius.full`, saffron on surface.sunken) + `mono.sm` "12.4 / 48.0 MB" + cancel `X`.

### 9.10 Voice Recorder

- **Press and hold the mic:** after 150 ms the composer expands into the recorder bar. It shows a red-free recording indicator (a pulsing saffron dot 10, pulse 1 s), a live waveform, and the timer `mono.md`.
- **Slide left to cancel** (a trash icon appears, fills at threshold, haptic). **Slide up to lock** hands-free recording (a lock icon appears).
- Release to save, with haptic `lightImpact` and the lid animation.
- If live transcription (stretch) is on, the transcript streams in `body.sm` text.secondary above the bar.

### 9.11 Progress & Loading

| Component | Use |
|---|---|
| **Skeleton** | Thread first paint only if the DB takes > 150 ms (rare): 3–5 bubble-shaped skeletons alternating sides. Shimmer 1.2 s linear, off under reduced motion. |
| **Linear determinate** | Export, import, uploads/downloads: 6 high, `radius.full`, saffron fill, with a percentage in `mono.sm` + item count |
| **Spinner** | Only inside buttons, and for waits under 2 s with unknown length (paywall offerings). 20 or 24 px, 2 px stroke, 800 ms rotation. |
| **Optimistic UI** | Every capture, archive, pin, move and edit is applied instantly (RULE) |
| **Image loading** | Images are local, so decode happens with a 120 ms fade-in from surface.sunken, holding the aspect-ratio box to avoid layout shift. Bridge page: `loading="lazy"` + fade-in. |

### 9.12 Lock Gate

This is shown in place of a locked box's thread. It sits centered on the thread background: a 64 `LockSimple` in private.fg on a 96 private.bg circle, then "Receipts is locked" (`title.md`), then "Only you can open it." (`body.md`, text.secondary), then a primary button **"Unlock"** that triggers biometrics automatically on arrival.
- **Failure:** "That didn't work. Try again or use your passcode."
- **No device lock set:** info card explaining that locking needs a screen lock, with a "Open settings" button.

### 9.13 Paywall Components (from scratch)

**Plan card (radio card)**
- Full width, `radius.lg`, padding 20, surface.default. Unselected: border.default 1 px. Selected: border.selected 2 px + saffron.50 bg (dark: saffron.900). Radio at the leading edge.
- **Lifetime card:**
  - Title "Lifetime" (`title.sm`) + tag "Launch price" (`promo`).
  - Price `number.price`, e.g. "$14.99", from `storeProduct.priceString`.
  - Subtext "Pay once. Yours for good." (`body.sm`).
- **Yearly card:**
  - Title "Yearly" + price `title.sm` "$9.99 / year".
  - Subtext "Renews every year. Cancel anytime." (`body.sm`).
- Selecting a card uses a 200 ms border/bg cross-fade + radio dot scale-in, with haptic `selectionClick`.

**Value row:** 24 icon in text.primary on a 36 saffron.100 circle (dark: saffron.900), label `body.md`. Six rows maximum, 12 apart.

**Legal row:** `body.sm`, text.tertiary, centered: "Terms · Privacy · Restore purchases". The three are separate 48 dp tap targets.

---

## 10 — Motion System

### 10.1 Motion Personality

**"Settle, don't bounce."** Things move like objects placed gently into a box. They are quick to start, soft to land, with a hint of physical weight and never springy or cartoonish. Motion always explains **cause → effect**: where something came from and where it went.

### 10.2 Tokens

| Token | Duration | Use |
|---|---|---|
| `motion.instant` | 90 ms | Pressed states, color swaps, toggles |
| `motion.fast` | 150 ms | Button scale, icon swaps (mic ↔ send), fades |
| `motion.normal` | 240 ms | Item insertion, segmented control, card selection |
| `motion.slow` | 360 ms | Sheets, screen transitions, lock/unlock |
| `motion.emphasis` | 520 ms | Signature moments: purchase success, first-save lid, Bridge pairing success |

| Easing | Curve | Use |
|---|---|---|
| `ease.standard` | cubic-bezier(0.2, 0, 0, 1) | Most transitions |
| `ease.decelerate` | cubic-bezier(0, 0, 0, 1) | Entrances |
| `ease.accelerate` | cubic-bezier(0.3, 0, 1, 1) | Exits |
| `ease.emphasized` | cubic-bezier(0.2, 0, 0, 1) over `motion.slow`, with a decelerate tail | Sheets |
| `spring.settle` | mass 1, stiffness 420, damping 34 (≈ 5% overshoot) | Item landing, lid close |

### 10.3 Transitions

| Moment | Motion |
|---|---|
| Push screen | iOS: native slide. Android: shared-axis X (fade + 24 dp slide), `motion.slow`. |
| Bottom sheet in / out | Slide up from the bottom with the scrim fading to theme opacity, 300 ms `ease.emphasized` / 200 ms `ease.accelerate` |
| Dialog | Fade + scale 0.96 → 1, 200 ms decelerate; exit fade 150 ms |
| Paywall | Rises as a large sheet (360 ms). The hero illustration fades in 120 ms later. The contextual headline appears last, making it the focal point. |
| Box switch | Thread cross-fades (150 ms) and the header box name slides vertically by 8 dp. This communicates "same place, different box." |
| Search open | The search field expands from the header icon position (shared element, 240 ms), and results fade in as you type |

### 10.4 Signature Micro-Motions

1. **The Land (item saved).** A new self bubble enters from the composer: translateY 16 → 0, scale 0.96 → 1, opacity 0 → 1, using `spring.settle`. The thread scrolls to it in parallel. Haptic: `lightImpact`.
2. **The Lid.** On the *first* save of a session, and on every share-in confirmation, the header's box tile shows the lid glyph closing (rotate −18° → 0°, translateY −3 → 0, 240 ms spring). It says "tucked away" without words. It is not repeated on every save, to avoid fatigue.
3. **Arrival from the PC.** A bubble from Bridge enters from the **left**: translateX −24 → 0 + fade over 240 ms. Its device label gets a 1.2 s saffron underline sweep, so the user sees it arrived rather than just appeared.
4. **Pairing success.** Phone: the address card flips its top area into a connected.bg status card (360 ms) with a check morph, and haptic `mediumImpact`. Bridge page: the OTP boxes collapse into a single check that then expands into the library (520 ms).
5. **Unlock.** The lock icon's shackle lifts (translateY −4 over 150 ms), the gate fades, and the thread fades up (240 ms).
6. **Purchase success.** The primary button morphs into a check (240 ms). Then the sheet content cross-fades to a success view: "You're in." (`display.md`) with a saffron sparkle burst of 6 small squares (not confetti) drifting outward 24 dp and fading, over 520 ms. Haptic: `mediumImpact`, then `lightImpact` 80 ms later.
7. **Wrong pairing code.** OTP boxes shake horizontally ±6 dp for 3 cycles over 300 ms, and the error border fades in.
8. **Archive swipe.** The item collapses in height (240 ms) while the rest reflow. The undo toast rises.

### 10.5 Reduced Motion (RULE)

When `MediaQuery.disableAnimations` (mobile) or `prefers-reduced-motion: reduce` (web) is set:
- All translate, scale and spring motions become **opacity cross-fades of 120 ms**.
- Shimmer stops; skeletons are static.
- The shake is replaced by an error border + icon.
- The sparkle burst and the lid glyph are shown as static end states.
- Nothing essential is ever conveyed *only* by motion.

---

## 11 — Interaction System

### 11.1 Gestures (mobile)

| Gesture | Target | Result | Non-gesture alternative |
|---|---|---|---|
| Tap | Bubble | Media: open viewer. Text: nothing, so text stays selectable via long-press. | — |
| Long-press | Bubble | Item actions sheet + haptic `selectionClick` | — |
| Swipe left | Bubble | Archive | Actions sheet → Archive |
| Swipe right | Bubble | Pin / unpin | Actions sheet → Pin |
| Pull down | Thread top | Load older items (no refresh concept, since data is local) | Auto-load on scroll |
| Hold | Mic | Record voice | — (voice needs a hold; tapping shows the hint) |
| Drag down | Sheet | Dismiss | Close button / scrim tap |
| Edge swipe | Screen (iOS) | Back | Back button |

### 11.2 Haptics

| Moment | Haptic |
|---|---|
| Item saved | `lightImpact` |
| Swipe threshold crossed | `lightImpact` |
| Selection (toggle, plan card, segmented) | `selectionClick` |
| Lock / unlock success | `mediumImpact` |
| Pairing success, purchase success | `mediumImpact` (+ `lightImpact` 80 ms later for purchase) |
| Error (wrong biometric, failed export) | `heavyImpact` once, **only** for blocking errors |

Haptics respect the system setting. Tibb never uses haptics for passive events such as Bridge arrivals, which use notifications instead.

### 11.3 Desktop Interaction (Bridge page)

- **Paste anywhere** (Ctrl/Cmd + V) creates an item from text, an image or files. A toast confirms "Saved to your phone."
- **Drag files** anywhere to show the drop overlay.
- **Shortcuts:**
  - `/` focuses search;
  - `Esc` closes the viewer, menu or overlay;
  - `↑ / ↓` move between boxes in the rail when it is focused;
  - `Ctrl/Cmd + Enter` sends from the composer (Enter adds a new line);
  - `C` on a focused clipboard card copies it.
- **Hover:** bubbles reveal a small action cluster (Copy · Download · More) at their outer edge. Everything is also reachable by keyboard focus.
- **Cursor:** pointer on interactive elements, text cursor in bubbles (text is selectable), and `copy` cursor during drag-over.

### 11.4 Voice & Microcopy

**Tone:** plain, warm, brief, and a little dry-witted. Speak like a trustworthy friend, not a bank and not a mascot.

| Rule | Example ✅ | Avoid ❌ |
|---|---|---|
| Sentence case everywhere | "Open on computer" | "Open On Computer" |
| Say *where* things are | "Saved on this phone." | "Saved successfully!" |
| Verbs on buttons, name the result | "Export everything" · "Get Tibb Pro — $14.99" | "Continue" · "OK" (except dialogs) |
| No blame | "That code didn't match." | "You entered an invalid code." |
| No exclamation overload | at most one per flow, for real celebrations | "Done!!" |
| Honest limits in one sentence | "On iPhone, keep Tibb open while your computer is connected." | multi-paragraph warnings |
| Never imply watching | "Only you can open it." | "We keep it safe for you." |
| Numbers exact | "1,284 items" | "lots of items" |

**Terminology (RULE, use consistently):**
- **Box** (not folder, chat or channel)
- **Save** (not send or post)
- **Item** (not message or note)
- **Archive** (not done or clear)
- **Locked box**
- **Open on computer** (the action) and **Bridge** (the feature)
- **Pro**
- **This phone** / **your computer**

**Core copy library**

| Context | Copy |
|---|---|
| First-save privacy moment | "Saved on this phone. Nothing left it." |
| Empty thread | Headline: "Your box is ready." Body: "Save anything here — or share into Tibb from any app." |
| Share-in confirmation | "Tucked into Personal." |
| Locked gate | "Receipts is locked. Only you can open it." |
| Bridge start | "Open this on your computer" / "Type this address into any browser on the same Wi-Fi." |
| Bridge honest note | "This stays on your Wi-Fi and never touches the internet. Use it on networks you trust." |
| Bridge connected | "Chrome on Windows is connected" |
| Arrival notification | "Saved from Chrome on Windows" |
| Clipboard received | "Clipboard from your PC — tap to copy" |
| Export done | "Everything's in one file. Keep it somewhere safe." |
| Encrypted export warning | "If you forget this password, nobody can open the file — not even us." |
| Soft Pro banner (once) | "Enjoying Tibb? Pro adds photos, files and your computer." · [See Pro] [Not now] |
| Storage full | "Your phone is out of space. Free some up, then try again — nothing was lost." |
| Paywall subhead | "One payment. No account. Your stuff stays yours." |

---

## 12 — Accessibility

| Area | Requirement (RULE unless noted) |
|---|---|
| Contrast | All text ≥ 4.5 : 1, large text (≥ 24 px, or 19 px bold) ≥ 3 : 1, non-text UI ≥ 3 : 1. Verified pairs are in 3.3. |
| Color independence | Saffron dot + ring for unreviewed; the lock icon (not color) for locked; the toggle shows a check glyph; the password meter has a text label; errors always have an icon + text; links are underlined. |
| Color blindness | Semantic pairs differ in lightness, not only hue. Box identity is emoji + name, never color alone. |
| Touch targets | ≥ 48 × 48 dp everywhere, including legal links on the paywall and the eye toggle. 8 dp minimum spacing between adjacent targets. |
| Text scaling | Supports 200% (iOS Dynamic Type, Android font scale). Layouts reflow: meta moves under bubbles, button labels wrap to 2 lines before truncating, and sheet content scrolls. Tested at 85%, 100%, 130% and 200%. |
| Screen readers | Every bubble reads as a single semantic unit: "*From Chrome on Windows, 3:42 PM. PDF, invoice.pdf, 1.2 megabytes. Unreviewed. Pinned.*" Custom actions (TalkBack/VoiceOver actions rotor): Archive, Pin, Move, Copy, Delete. Icon buttons have labels ("Open on computer", "Search"). Decorative illustrations are excluded from semantics. |
| Live regions | Bridge arrivals and upload completion are announced politely ("Saved from Chrome on Windows"). The pairing-code countdown is **not** announced every second; it is announced at 1 minute left. |
| Focus | Visible 2 px focus ring (ink / saffron in dark) on all interactive elements, logical order, and the first field auto-focused in sheets with inputs. The Bridge page is fully keyboard-operable, with focus trapped in modals and returned on close. |
| Motion | Honors reduced motion (10.5). No auto-playing video. Waveforms don't animate when not playing. |
| Biometrics | Always offers the device passcode fallback. The gate never relies on timing. |
| Voice memos | A transcript, when available, serves as the text alternative. Without one, the item reads "Voice memo, 0:42." |
| Language | The Bridge page and landing site set `lang="en"`. Microcopy stays at about a grade-7 reading level. |

---

## 13 — UX Architecture

### 13.1 Information Architecture

```
Thread (home, current box)
├── Box Switcher (sheet) → Manage boxes → Create / Edit box (sheet)
├── Composer → Attach (sheet) · Voice recorder
├── Item → Viewer · Actions (sheet) → Note editor · Move to box (sheet)
├── Search (screen)
├── Bridge (sheet) → Connected state · Troubleshooting
├── Archive (screen, per box)
└── Settings (screen)
    ├── Tibb Pro (screen) → Paywall (sheet)
    ├── Appearance
    ├── Clipboard (expiry)
    ├── Export everything · Import (flows)
    ├── Import from WhatsApp (flow)
    ├── How Tibb keeps your stuff yours (privacy explainer)
    └── About · Licenses · Terms · Privacy
Paywall (sheet) ← triggered from: Bridge · 2nd box · media · lock · WhatsApp media · soft banner
Share-in (system share sheet → Tibb share sheet)
```

### 13.2 Key User Journeys

**J1 — First save (activation)**
- **Entry:** first launch.
- **Steps:** launch → the Personal box is open with one seeded item → the user types → send → The Land + The Lid → the privacy moment toast "Saved on this phone. Nothing left it." → an empty-state hint card: "Next time, share into Tibb from any app" with a mini demo animation.
- **Friction removed:** no signup, no permissions, no tour.
- **Failure:** storage full → inline error on the composer, and the text is kept.

**J2 — Share-in from another app**
- **Entry:** system share → Tibb.
- **Steps:** the Tibb share sheet (half height) shows a preview of the content + box chip ("Personal ▾") + primary **Save** → tap → "Tucked into Personal." with the lid → it auto-closes after 900 ms and returns the user to the source app.
- **Decision point:** changing the box is optional (tap the chip → box list).
- **Media on free tier:** the sheet shows the Pro reason inline ("Photos are part of Pro") with [See Pro] and [Save link instead] where applicable, and never loses the share.
- **Failure:** unsupported type → saved as a file. Oversized → a message with the size and available space.

**J3 — Retrieval (the real activation)**
- **Entry:** search icon, or pull-down on the thread.
- **Steps:** search → type → live results grouped by box, with matches highlighted → tap → the thread opens at that item with a 1.2 s saffron.100 highlight pulse.
- **Empty result:** "Nothing matches '…'. Try fewer words," plus a suggestion to check archived items if they are hidden.

**J4 — Bridge first time (includes the paywall)**
- **Entry:** `Laptop` icon.
- **Free user:** paywall with context "Open Tibb on your computer" → purchase → success → continues **directly** into Bridge, with no re-tap (RULE: finish the job the user started).
- **Pro user:** the Bridge sheet opens. First time only: a primer about local network + notifications ("Tibb needs to find your computer on Wi-Fi") → the system prompts → address + code → the user types it on the PC → pairs → phone: connected card + banner. PC: library.
- **Failure:** nothing connects in 60 s → a "Not connecting?" link appears → Troubleshooting (same Wi-Fi? try hotspot, disable VPN, campus Wi-Fi may block this).

**J5 — Clipboard to phone**
- **Entry:** PC, while Bridge is connected.
- **Steps:** copy an OTP → Ctrl/Cmd+V on the Bridge page → toast "Saved to your phone" → the phone shows a notification "Clipboard from your PC — tap to copy" → tap → Tibb opens with the clipboard card pinned → **Copy** → "Copied."

**J6 — Lock a box**
- **Entry:** Box settings → "Lock this box" toggle.
- **Steps:** (Pro gate) → biometric confirm → locked; the tile gets a lock → leaving the box re-locks it.
- **Decision point:** a note explains "Locked boxes stay hidden from search and from your computer."

**J7 — WhatsApp import**
- **Entry:** Settings, the onboarding link, or sharing a WhatsApp export zip.
- **Steps:** an instructions screen (3 illustrated steps for WhatsApp) → the user shares the export → the preview screen shows the detected date format ("We read dates as **day/month**. Look right?") with 3 sample messages → confirm → progress → done: `number.stat` "1,284 items" + "They're archived so your box stays tidy," with [Open WhatsApp import] and [Unarchive all].
- **Failure:** the parse fails → "This doesn't look like a WhatsApp export. Export the chat again with 'Include media' and share the .zip."

**J8 — Export everything**
- **Entry:** Settings. It is available in every payment state.
- **Steps:** "Protect with a password?" toggle (on by default) → password + confirm with the warning → progress → system save dialog → "Everything's in one file."
- **Failure:** out of space → the size needed is shown and nothing is partially written.

**J9 — Restore purchase**
- **Entry:** Settings → Tibb Pro → Restore, or the paywall's legal row.
- **Steps:** spinner in the button → "Pro restored" (success toast + the screen updates live) or "No purchases found for this account" with a help line about checking the store account.

### 13.3 Onboarding

- **Steps: zero screens before the product.** The thread *is* the onboarding.
- A seeded item (a self bubble, deletable): *"This is your box. Anything you save lands here — on this phone only. Try typing something below."*
- Progressive disclosure, one hint at a time, each shown once:
  1. After the first save: the privacy moment toast.
  2. After the second save: the share-in hint card ("Share into Tibb from any app"), with a 3-frame looping mini animation.
  3. After the fifth save: search is revealed with a gentle pulse on the search icon (1 cycle).
- **Restoring users:** if a `.tibb` file arrives via share or "Open with," the first screen offers **Restore** before showing an empty state.
- **Permissions:** notifications and local network are requested only at Bridge start. Microphone is requested at the first voice hold. Photos use the system picker (no library permission needed on modern OSes).

### 13.4 Retention (ethical)

The retention model is archive value plus habit, never pressure. Tibb uses:
- **Retrieval delight:** the highlight pulse when search lands on an old item.
- **Triage clarity:** "New since you last looked" gives a sense of completion without guilt.
- **Occasional milestones in Settings:** "1,000 things tucked away." These are passive, never notified.

**Not used (RULE):** streaks, badges on the app icon, absence notifications, or "you haven't saved…" messages.

### 13.5 Notification UX

| Level | Examples | Treatment |
|---|---|---|
| Informational (default channel) | Saved from PC, import finished | Standard. Grouped per session ("3 items saved from Chrome on Windows"). |
| Actionable | Clipboard received | Tap copies via Tibb (opens app → Copy is one tap) |
| Ongoing (Android) | Bridge running | Low-importance persistent notification with a "Stop" action |

- **Tone:** past tense, factual, device-named.
- **Frequency:** Bridge arrivals are batched within 10 s windows.
- **Android channels:** "From your computer," "Bridge status," "Imports."

---

## 14 — Screen-by-Screen Specification

Unless stated otherwise, all screens use: background.primary, 16/20 screen padding, top app bar 56, Phosphor icons, and toast feedback.

### S1 — Launch
- **Purpose:** open fast.
- **Layout:** the native splash is a saffron bg with an ink box mark (Android 12+ SplashScreen API; iOS launch storyboard).
- **Behavior:** it hands off directly to the thread without a custom animated splash. Speed *is* the brand.

### S2 — Thread (home)
- **Goal:** capture and glance.
- **Primary action:** the composer. **Secondary:** search, Bridge, box switch.
- **Hierarchy:** newest items → composer → header.
- **Layout:** header, then a banner slot (Bridge connected / soft prompt), then the pinned clipboard card slot, then the thread (reverse-chronological scroll anchored to the bottom), then the composer.
- **States:**
  - **Empty:** illustration (an open box with a paper slip, 160 × 120) + "Your box is ready." + body + ghost button "How to share into Tibb."
  - **Loading:** skeletons only if > 150 ms.
  - **Error:** DB failure (very rare) → full-state message "Tibb couldn't open your library" + "Try again" + "Export what's there" (safety valve).
  - **Success:** The Land.
- **Accessibility:** new items are announced; the composer has the label "Write something to save."

### S3 — Attach sheet
Grid of 4 tiles (80 × 88, `radius.md`, surface.sunken, icon 28 + `label.md`): **Photos & videos · Files · Camera · Clipboard**. Pro-gated tiles show a small `Sparkle` tag, and tapping one opens the paywall with context. Below it, a "Recent" row of the last 8 photos from the system picker (Android photo picker).

### S4 — Item viewer
- **Image/video:** full-screen black (both themes, since media needs neutral surroundings), pinch-zoom, swipe down to dismiss (the image shrinks back to its bubble via a shared element).
- **Top bar** (auto-hides): `X`, origin + time, `Export` (share out).
- **Bottom bar:** Note · Move · Pin · Archive · Delete.
- **PDF/file:** opens with the system viewer; there is no in-app viewer in V1.

### S5 — Item actions sheet
- **Header:** a mini preview of the item (1 line + type icon).
- **Rows (48 each):** Copy · Share · Add note · Move to box · Pin · Archive · Edit (text only) · **Delete** (error.fg, last, separated by a divider). The delete confirmation is an undo toast, not a dialog; a dialog is used only for bulk delete.

### S6 — Note editor (sheet)
The title shows "Why did you save this?" as the placeholder, over a multiline field with the keyboard up. **Save** (primary) / **Cancel** (ghost). Notes appear under the bubble in `body.sm` text.secondary with a `NotePencil` 12 icon.

### S7 — Box switcher (sheet)
- The list of boxes (box rows), with the current box selected (saffron.50 bg, `Check`).
- Locked boxes show the lock icon and no preview.
- Footer: "+ New box" (a Pro gate if 1 box already exists) and "Manage boxes."

### S8 — Create / edit box (sheet)
- Emoji picker (a curated grid of 48 + "More" to the system emoji keyboard), name field (label "Name", placeholder "e.g. Receipts"), and the color row (8 swatches 36 circles, selected = 2 px ring + check).
- "Lock this box" toggle (Pro).
- Primary **Create box** / **Save**.
- In edit mode, "Delete box" is a destructive text button at the bottom, with a confirmation dialog: "Delete 'Receipts' and its 42 items? You can't undo this. Export first if you want a copy." with a secondary "Export first" action.

### S9 — Manage boxes (screen)
Reorderable list (drag handle `DotsSixVertical`, haptic on pick-up), with a swipe to edit. The empty state isn't possible, because one box always exists.

### S10 — Locked box gate
Component 9.12. Biometrics auto-trigger on arrival **unless** the user arrived via back navigation (avoids re-prompt loops).

### S11 — Search (screen)
- The field autofocuses. Filter chips below: All · Text · Links · Media · Files · Voice (horizontal scroll, `label.lg`).
- Results grouped by box with `title.sm` headers.
- Before typing: "Recent searches" (local only, clearable) + "Try: a word, a website, a file name."
- **No results:** state described in J3.
- Locked results are hidden unless the box is unlocked in this session. Footer note when hidden: "Locked boxes aren't searched."

### S12 — Archive (screen)
- The same bubble list, read-only styling (bubbles at full opacity; header "Archived in Personal"), with a swipe to unarchive. Bulk "Archive older than…" is available from the overflow on the main thread.
- **Empty:** "Nothing archived. Swipe an item left to tidy it away."

### S13 — Share-in sheet (Android share target / iOS extension)
- Half-height sheet over the source app: preview (thumbnail / first 3 lines / filename + count if multiple), box chip, **Save** primary.
- **Success:** the lid + "Tucked into Personal." then auto-dismiss at 900 ms.
- If the target box is locked, "Locked boxes can't receive shares yet — saving to Personal."

### S14 — Bridge sheet (phone)
- **Pre-start (first time):** illustration (a phone and laptop on the same Wi-Fi arc) + "Open this on your computer" + a 3-line explanation + the honest note (info card) + primary **Start**.
- **Waiting:**
  - address display, pairing code, countdown;
  - **Copy address**;
  - a "Keep Tibb open" note (iOS only);
  - a "Not connecting?" link after 60 s;
  - a "Show locked boxes on computer" toggle, default off, which triggers biometrics.
- **Connected:** connected status card, session info (connected since, items sent/received in `mono.sm`), and a **Stop** secondary button.
- **Stopped:** the sheet closes and a toast says "Your computer is disconnected."

### S15 — Bridge troubleshooting (screen)
A checklist with icons: same Wi-Fi · try your phone's hotspot · turn off VPN · public/campus Wi-Fi may block this · type the address exactly (a copy button). Tone: calm, with no blame.

### S16 — Paywall (full-height sheet, custom-built)
**Layout, top to bottom:**
1. `X` close, top-left and always visible.
2. Context illustration (per reason), 160 high.
3. **"Unlock Tibb."** in `display.md` Fraunces.
4. Contextual line in `title.sm` (e.g. "Open Tibb on your computer").
5. Subhead "One payment. No account. Your stuff stays yours." in `body.md`, text.secondary.
6. Six value rows.
7. Plan cards (Lifetime pre-selected).
8. Primary lg button **"Get Tibb Pro — $14.99"**. The price is from the selected package, and the label updates when the plan changes.
9. When Yearly is selected, a line appears in `body.sm`: "$9.99 billed yearly. Renews automatically until you cancel in your store settings."
10. Legal row.

**Contextual lines by trigger**

| Trigger | Contextual line |
|---|---|
| Bridge | "Open Tibb on your computer" |
| Second box | "Keep work and life apart" |
| Media | "Save photos, videos, voice and files" |
| Lock | "Lock the boxes that are just for you" |
| WhatsApp media | "Open your imported photos and files" |
| Soft prompt | "Everything Tibb can do" |

**Value rows:** Unlimited boxes · Photos, videos, voice and files · Open Tibb on your computer · Clipboard between phone and PC · Locked private boxes · Pay once, no subscription needed.

**States**
- **Loading:** plan-card skeletons; the button is disabled with the label "Loading prices…".
- **Load failed:** the cards are replaced by an info card, "Couldn't load prices. Check your connection." + **Try again**. The paywall is the one place Tibb needs the network, and it says so honestly.
- **Purchasing:** the button is loading and all controls are disabled.
- **Cancelled:** returns silently to the idle state.
- **Error:** an error card above the button, "The purchase didn't go through. You haven't been charged." + retry.
- **Success:** S17.

**RULES:** no countdowns, no pre-checked upsells, and dismissing is always one tap.

### S17 — Purchase success
- The sheet content becomes: sparkle burst, then **"You're in."** (`display.md`), then "Tibb Pro is yours — for good." (lifetime) or "Tibb Pro is active. Renews [date]." (yearly), then a primary button that continues the original intent ("Open on computer," "Create your box," …).
- It auto-continues after 2.5 s if untouched, and the continue happens immediately under reduced motion.

### S18 — Settings (screen)
Groups, each with an `overline` label:
- **TIBB PRO:** status row → S19.
- **YOUR STUFF:** Export everything · Import · Import from WhatsApp.
- **PRIVACY:** How Tibb keeps your stuff yours · Clipboard expiry (24 h ▾).
- **APPEARANCE:** Theme (System/Light/Dark segmented) · Hide unreviewed counts toggle.
- **ABOUT:** Version · Open-source licenses · Terms · Privacy policy · GitHub.

### S19 — Tibb Pro (screen)
- **Status card.** Free: "You're on Tibb Free" + [See Pro]. Lifetime: "Lifetime — yours for good" with a sparkle. Yearly: "Yearly — renews 28 Sep 2027."
- Rows: Restore purchases · Manage subscription (yearly only; opens `managementURL`).
- A "Why one payment?" explainer card: "Tibb has no servers to pay for — your stuff lives on your phone — so there's nothing to charge you monthly for."
- A reassurance line: "Export is free forever, whatever happens to your plan."

### S20 — Export flow
1. **Options sheet:** "Protect with a password" toggle (on) + an estimated size (`mono.sm`).
2. **Password** step (component 9.2) + warning (info card, warning tint).
3. **Progress:** full-screen calm state with an illustration (the box closing), a linear progress bar, and "Packing 1,284 items…". The user can leave; Android shows a notification.
4. **Save:** system save / share.
5. **Done:** stat + "Keep it somewhere safe."
- **Cancel** is available throughout; cancelling deletes the partial file.

### S21 — Import flow
- Pick a file → if encrypted, a password field → validate → preview card: "1,284 items · 3 boxes · 412 MB · exported 12 Sep 2026" → **Import** → progress → done ("Merged — duplicates were skipped").
- **Wrong password:** "That password didn't open this file."
- **Corrupt file:** "This file is incomplete, so nothing was imported. Try exporting again." (RULE: never partial.)

### S22 — WhatsApp import (flow)
The steps are as in J7. The instructions screen uses 3 numbered illustrated cards with neutral ink-and-saffron drawings of generic chat UI (no WhatsApp logo or trademark). The date-format confirmation uses a segmented control (Day/Month · Month/Day) with live-updating samples.

### S23 — Privacy explainer (screen)
- Hero illustration (a box with a key) + "How Tibb keeps your stuff yours" (`headline.hero`), followed by 5 short sections with icons:
  1. Saved on this phone.
  2. No account, no Tibb servers.
  3. Your computer connects over your Wi-Fi.
  4. Payments go through RevenueCat and your app store — they see purchases, never your stuff.
  5. Export everything, anytime, free.
- **Honest limits:** Bridge is local and unencrypted HTTP, and on iPhone Tibb must stay open.
- Max line length 34 em.

### S24 — Permission primers (inline cards, not screens)
One sentence of why + a primary "Allow" + a ghost "Not now". If denied, the next time the card shows "Turn on in Settings" with a deep link. Primers exist for: local network (iOS), notifications, and microphone.

### B1 — Bridge page: pairing
- Centered card (max 440) on the page background: the Tibb mark, **"Open your box"** (`display.md` Fraunces), "Enter the 6-digit code shown on your phone," the OTP input, and a line of `body.sm`: "This page is coming straight from your phone over Wi-Fi."
- Wrong code: shake + error. Expired: "That code expired. Your phone is showing a new one."

### B2 — Bridge page: library
- **Rail:** Clipboard entry + Search + boxes list + the device footer ("This computer: Chrome on Windows · Rename").
- **Thread:** same bubbles (desktop sizes), with a composer at the bottom (multiline, attach, send; the drop zone is anywhere).
- **Header:** box name + unreviewed count + "Connected to Pixel 8" (connected.fg dot **with text**, not a bare dot).
- **Detail pane:** image/video viewer and file download.
- **States:**
  - **Empty box:** "Nothing here yet. Drop a file or paste something."
  - **Loading:** skeleton bubbles.
  - **Disconnected:** a full overlay "Phone disconnected — make sure Tibb is open on your phone" + **Reconnect** (retries; if the session has expired, returns to B1).

### B3 — Bridge page: drop overlay & transfers
The drop overlay is component 9.9. A transfer tray docks bottom-right (360 wide, elevation.medium) and lists uploads with progress. It collapses to "3 saved to your phone ✓" and hides after 4 s.

### L1 — Landing site
- **Hero:** "Message yourself. Keep it yourself." (`display.lg` Fraunces) + subhead + a looping muted screen recording of Bridge (MP4, poster frame, `radius.xl`) + buttons [Watch the demo] [View on GitHub].
- **Three promises** (icon cards): No account · No cloud · Export forever.
- **"How it works"** as a 3-step horizontal band (stacked on mobile).
- The privacy statement, then a footer.
- Light and dark via `prefers-color-scheme`. No trackers, no embeds, no web fonts from third parties (self-hosted woff2).

---

## 15 — Edge Cases & States

| Situation | Design response |
|---|---|
| **First use** | Seeded item + progressive hints (13.3) |
| **Returning user** | Opens to the last-used box at the newest item. "New since you last looked" divider if there are unreviewed items. |
| **Offline** | Irrelevant for capture, which is fully local. Only the paywall needs the network, and it has its own state (S16). Bridge needs Wi-Fi, not internet, and says so. |
| **Permissions denied** | Feature-specific inline card with a "Turn on in Settings" deep link. The feature degrades; the app never blocks. |
| **Storage full** | Composer error + persistent banner. The draft text is kept and nothing is lost. |
| **Huge file shared** | Shows the size and required space before copying. Progress is shown for anything > 20 MB. |
| **Pro lapsed / refunded** | Existing Pro content remains viewable and exportable. Creating new Pro content shows the paywall. A one-time banner says: "Your Pro plan ended. Everything you saved is still here." |
| **Destructive actions** | Single items: an undo toast (8 s). Boxes and bulk: a dialog naming the count + an "Export first" option. Never a double-confirmation maze. |
| **Clipboard expiry** | The card shows its time left. On expiry it fades out and nothing is announced. |
| **Bridge: phone locks or app backgrounded on iOS** | PC: the disconnected overlay. Phone: the session resumes on return if it's under 30 min. |
| **Bridge: a second PC tries to pair** | The code is invalid while a session is active. The PC shows "Tibb is already connected to another computer." |
| **Bridge: wrong network** | Troubleshooting (S15) is reached from the "Not connecting?" link |
| **Very long text item** | Collapsed at 12 lines with "Show more" |
| **RTL / non-Latin text in items** | Bubbles respect the text direction of their content (`Directionality` per bubble). Layout mirroring for full RTL locales comes later. |
| **Many boxes (50+)** | The switcher sheet gets a search field at the top when there are more than 12 boxes |
| **Font scale 200%** | Meta moves below bubbles; the header shows the box tile + a truncated name; the paywall plan cards stack price under the title |
| **Biometric lockout** | Passcode fallback, with the message: "Too many tries. Use your phone's passcode." |

---

## 16 — Design Tokens (consolidated)

```json
{
  "color": {
    "light": {
      "background": { "primary": "#F7F4EE", "thread": "#F7F4EE" },
      "surface": { "default": "#FFFFFF", "sunken": "#EFEBE3", "raised": "#FFFFFF", "overlay": "#FFFFFF", "inverse": "#1C1A22" },
      "text": { "primary": "#1C1A22", "secondary": "#5E5866", "tertiary": "#6F6876", "disabled": "#B7B0BE",
                "onAccent": "#1C1A22", "onInverse": "#F2EEE8", "accent": "#8A5A06" },
      "border": { "subtle": "#E3DDD2", "default": "#CFC7B9", "input": "#8B8392", "focus": "#1C1A22", "selected": "#F5B324" },
      "action": { "primary": "#F5B324", "primaryPressed": "#E09A0B", "primaryHover": "#F7C552",
                  "secondary": "#1C1A22", "secondaryPressed": "#34313D", "destructive": "#C0352D" },
      "bubble": { "self": "#FCE9B8", "selfText": "#1C1A22", "selfMeta": "#6E6452", "other": "#FFFFFF", "otherBorder": "#E3DDD2" },
      "private": { "fg": "#5B3FD1", "bg": "#EFEAFF" },
      "connected": { "fg": "#0A7366", "bg": "#E3F6F2" },
      "success": { "fg": "#1D7F47", "bg": "#E4F4EA" },
      "warning": { "fg": "#9A5B00", "bg": "#FFF1D9" },
      "error": { "fg": "#C0352D", "bg": "#FCE9E7" },
      "info": { "fg": "#2A62C9", "bg": "#E6EEFC" },
      "overlay": { "scrim": "rgba(28,26,34,0.32)", "pressed": "rgba(28,26,34,0.10)", "hover": "rgba(28,26,34,0.06)" },
      "skeleton": { "base": "#EFEBE3", "highlight": "#F7F4EE" }
    },
    "dark": {
      "background": { "primary": "#121116", "thread": "#121116" },
      "surface": { "default": "#1B1A20", "sunken": "#24222B", "raised": "#24222B", "overlay": "#2D2B35", "inverse": "#F2EEE8" },
      "text": { "primary": "#F2EEE8", "secondary": "#B8B1C0", "tertiary": "#8E8797", "disabled": "#5A5563",
                "onAccent": "#121116", "onInverse": "#1C1A22", "accent": "#F2B33D" },
      "border": { "subtle": "#2D2B35", "default": "#34313D", "input": "#6A6474", "focus": "#F2B33D", "selected": "#F2B33D" },
      "action": { "primary": "#F2B33D", "primaryPressed": "#D99A24", "primaryHover": "#F5C35E",
                  "secondary": "#F2EEE8", "secondaryPressed": "#D9D4CC", "destructive": "#FF7A70" },
      "bubble": { "self": "#3A2F1A", "selfText": "#F7ECD6", "selfMeta": "#C9B68E", "other": "#1B1A20", "otherBorder": "#34313D" },
      "private": { "fg": "#A796FF", "bg": "#2A2342" },
      "connected": { "fg": "#3CC7B3", "bg": "#11302C" },
      "success": { "fg": "#5BD08E", "bg": "#12301F" },
      "warning": { "fg": "#F5B85A", "bg": "#3A2A10" },
      "error": { "fg": "#FF7A70", "bg": "#3D1A18" },
      "info": { "fg": "#7FAAFF", "bg": "#18233D" },
      "overlay": { "scrim": "rgba(0,0,0,0.56)", "pressed": "rgba(242,238,232,0.10)", "hover": "rgba(242,238,232,0.06)" },
      "skeleton": { "base": "#1B1A20", "highlight": "#24222B" }
    },
    "boxAccent": {
      "saffron": ["#F5B324", "#F2B33D"], "coral": ["#E8664F", "#F08A76"], "rose": ["#D9477E", "#EE7AA3"],
      "plum": ["#7B5CE6", "#A796FF"], "ocean": ["#2F7DD6", "#7FB2F5"], "teal": ["#13A08C", "#3CC7B3"],
      "leaf": ["#4E9A3A", "#86C96F"], "slate": ["#6E7580", "#A4ABB6"]
    }
  },
  "font": {
    "family": { "ui": "Figtree", "display": "Fraunces", "mono": "JetBrains Mono" },
    "style": {
      "display.lg": [40, 44, 600, -0.02], "display.md": [32, 38, 600, -0.015], "headline.hero": [26, 32, 600, -0.01],
      "title.lg": [24, 30, 750, -0.01], "title.md": [20, 26, 700, -0.005], "title.sm": [17, 22, 650, 0], "title.xs": [15, 20, 650, 0],
      "overline": [12, 16, 700, 0.06], "body.lg": [17, 24, 450, 0], "body.md": [15, 21, 450, 0], "body.sm": [13, 18, 450, 0.005],
      "caption": [12, 16, 550, 0.01], "label.lg": [15, 20, 650, 0], "label.md": [13, 16, 650, 0.01],
      "button.lg": [17, 22, 700, 0], "button.md": [15, 20, 650, 0], "input": [17, 24, 450, 0],
      "mono.xl": [30, 36, 600, 0], "mono.lg": [34, 40, 600, 0.2], "mono.md": [15, 20, 500, 0], "mono.sm": [12, 16, 500, 0],
      "number.price": [28, 32, 800, -0.01], "number.stat": [22, 28, 750, 0]
    },
    "_format": "[size, lineHeight, weight, letterSpacingEm]"
  },
  "space": { "0": 0, "050": 2, "100": 4, "150": 6, "200": 8, "300": 12, "400": 16, "500": 20, "600": 24, "800": 32, "1000": 40, "1200": 48, "1600": 64 },
  "radius": { "xs": 6, "sm": 10, "md": 14, "lg": 20, "xl": 28, "full": 999 },
  "border": { "hairline": 1, "default": 1, "input": 1, "focus": 2, "focusOffset": 2, "selected": 2, "error": 2, "dashed": [2, 6, 4] },
  "elevation": {
    "subtle": "0 1 2 0 rgba(28,26,34,0.06)", "low": "0 2 8 -2 rgba(28,26,34,0.10)", "medium": "0 8 24 -6 rgba(28,26,34,0.14)",
    "high": "0 16 40 -8 rgba(28,26,34,0.18)", "modal": "0 24 64 -12 rgba(28,26,34,0.24)"
  },
  "icon": { "size": { "xs": 12, "sm": 16, "md": 20, "lg": 24, "xl": 32, "xxl": 48 }, "family": "Phosphor", "weights": ["regular", "fill", "bold"] },
  "motion": {
    "duration": { "instant": 90, "fast": 150, "normal": 240, "slow": 360, "emphasis": 520 },
    "easing": { "standard": [0.2, 0, 0, 1], "decelerate": [0, 0, 0, 1], "accelerate": [0.3, 0, 1, 1] },
    "spring": { "settle": { "mass": 1, "stiffness": 420, "damping": 34 } },
    "reduced": { "duration": 120, "type": "crossfade" }
  },
  "opacity": { "disabled": 0.38, "hover": 0.06, "pressed": 0.10, "focusTint": 0.12, "dragOverlay": 0.92 },
  "breakpoint": { "compact": 0, "medium": 600, "expanded": 840, "desktop": 1024, "wide": 1280, "bridgeSingleColumn": 720 },
  "component": {
    "touchTarget": 48, "appBar": 56, "composerMin": 56, "sendButton": 40,
    "button": { "lg": 56, "md": 48, "sm": 36 }, "input": 52, "search": 44, "listRow": { "single": 56, "double": 72 },
    "bubble": { "maxWidthPct": 0.78, "mediaMaxWidthPct": 0.72, "padH": 12, "padTop": 9, "padBottom": 8 },
    "boxTile": 40, "otpBox": [52, 64], "pairDigit": [44, 56], "sheetGrabber": [36, 4], "dialogMaxWidth": 360,
    "rail": { "wide": 280, "desktop": 260, "compact": 72 }, "threadMaxWidth": { "tablet": 720, "desktop": 760 }
  }
}
```

---

## 17 — Developer Handoff Notes

### 17.1 Flutter

- **Theme architecture.**
  - Build one `ThemeData` per brightness from the tokens, using Material 3 (`useMaterial3: true`) as the base for behaviors.
  - Map the core roles to `ColorScheme`: `primary` = action.primary, `onPrimary` = text.onAccent, `surface` = surface.default, `onSurface` = text.primary, `error` = error.fg.
  - Put everything Tibb-specific (bubbles, private, connected, box accents, spacing, radius, motion) in **`ThemeExtension`s**: `TibbColors`, `TibbSpacing`, `TibbRadius`, `TibbMotion`, `TibbType`.
  - Widgets read `Theme.of(context).extension<TibbColors>()!` and **never hardcode hex values** (RULE).
- **Fonts.** Bundle Figtree, Fraunces and JetBrains Mono (variable TTFs) under `assets/fonts/` and declare them in `pubspec.yaml`. No network fonts. Use `FontVariation('wght', 450)` for non-standard weights (450, 550, 650, 750), and `FontFeature.tabularFigures()` for numeric styles.
- **Components to build first, as reusable widgets:**
  - `TibbButton` (variant, size, loading, success);
  - `Bubble` (type, origin, grouped, tucked);
  - `Composer`;
  - `TibbSheet` (a wrapper with grabber, padding and safe area);
  - `TibbToast`;
  - `PlanCard`;
  - `BoxTile`;
  - `EmptyState`;
  - `InfoCard`;
  - `LockGate`;
  - `PairingCode`.
  - Every screen composes these; one-off styling is not allowed.
- **Bubble shape.** Use a `ShapeBorder` with per-corner radii (`BorderRadius.only`). Grouping is computed in the list builder (same origin and < 2 min gap), and it drives which corner tucks.
- **Motion.**
  - Wrap durations and curves in `TibbMotion`.
  - Check `MediaQuery.of(context).disableAnimations` in one helper (`motion.resolve(context, normal)`) that returns 120 ms fades when reduced.
  - Use `SpringSimulation` with the settle spring for The Land, and `AnimatedList` / `SliverAnimatedList` for insertions.
- **Haptics.** Go through a single `TibbHaptics` service so they can be globally disabled and tested.
- **Platform adaptation.**
  - Use `Theme.of(context).platform` for back-icon choice, the overflow icon, and sheet presentation (iOS large sheet feel via `showModalBottomSheet` with `useSafeArea` and top radius).
  - Enable edge-to-edge on Android (`SystemUiMode.edgeToEdge`) with transparent bars.
- **Accessibility.**
  - `Semantics` wrappers on bubbles with `customSemanticsActions` for Archive, Pin, Move, Copy and Delete.
  - `ExcludeSemantics` on decorative illustrations.
  - Test with TalkBack, VoiceOver and a 2.0 text scale.
- **Paywall.** The UI binds to a `PaywallController` with the states `loading / ready / failed / purchasing / success / error`. It is fed by `Purchases.getOfferings()`, and the button label is derived from `selectedPackage.storeProduct.priceString`.

### 17.2 Bridge Page (HTML/CSS/JS)

- **Tokens.** Tokens become **CSS custom properties** on `:root`, overridden in `@media (prefers-color-scheme: dark)`. Generate them from the JSON in §16 so mobile and web never drift.
- **Fonts.** Serve the fonts as woff2 from the phone (`/fonts/…`) with `font-display: swap` and the system fallbacks listed in 6.1.
- **Icons.** Inline the Phosphor SVG sprite (the subset used, about 30 icons).
- **Semantics.**
  - Use native semantic elements (`<button>`, `<nav>`, `<main>`, `<dialog>`).
  - Use `aria-live="polite"` for arrivals and transfer completion.
  - Label the OTP input as a group with `autocomplete="one-time-code"` on the first box.
- **No external requests of any kind** (RULE). There are no CDNs and no analytics.

### 17.3 Landing Site

It uses the same CSS variables file. It must remain static: no frameworks are required, and there are no trackers.

### 17.4 Design File (Figma)

- Variables mirror §16, with two modes (Light/Dark).
- Components mirror 17.1 names 1:1.
- Auto-layout gaps use only the spacing tokens.

---

## 18 — Design QA Checklist

**Identity**
- [ ] Only one saffron primary action on the screen; saffron is never used as text or a thin line on light backgrounds
- [ ] Fraunces appears at most once on the screen, only in a display/hero role
- [ ] Icons are all Phosphor, in the right weights (Regular inactive, Fill active)
- [ ] Bubble corners follow the tucked-corner rule; no sharp corners anywhere

**System integrity**
- [ ] Every color comes from a semantic token; no raw hex in widgets
- [ ] Every spacing value is on the scale; every radius is a token
- [ ] Borders only on same-plane elements; shadows only on floating ones
- [ ] Works in both themes. Dark was checked on a real device at low brightness.

**Usability**
- [ ] The primary action is obvious within 1 second
- [ ] Capture paths show no spinner and never wait on the network
- [ ] Every gesture has a visible alternative
- [ ] Empty, loading, error, success and offline states are designed
- [ ] Destructive actions have undo or a clear confirmation naming the object

**Trust & honesty**
- [ ] No copy implies servers, cloud, observers or presence
- [ ] Platform or privacy limits are stated in one plain sentence where relevant
- [ ] Paywall: the price is on the button, close is visible, Restore is present, and there is no fake urgency
- [ ] Export is reachable regardless of payment state

**Accessibility**
- [ ] Contrast meets §3.3; nothing relies on color alone
- [ ] Touch targets are ≥ 48 dp
- [ ] Layout holds at 200% text scale
- [ ] Screen-reader labels and custom actions are present; focus order is logical
- [ ] Reduced motion replaces movement with cross-fades

**Motion**
- [ ] Every animation explains cause and effect; none exists only to decorate
- [ ] Durations come from tokens; capture feedback is ≤ 240 ms

**Voice**
- [ ] Sentence case; the terminology table is respected (box, item, save, archive)
- [ ] Errors are blameless and actionable; success says *where* the thing went

---

*Tibb design principle to remember: **it should feel like closing the lid on something you care about — quick, quiet, and yours.***