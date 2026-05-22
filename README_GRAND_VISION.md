# MuSaiCa — Grand Vision (stretch scope)

**Mu**(sical) + **Sa**(il) + (Or)**ca**.

> This document is the broader, more ambitious version of the project. The realistic v1 plan lives in `README.md`. Treat this file as the long-term ceiling, not the immediate roadmap.

A unified desktop 3D printing app for the **Snapmaker U1**: slicer, printer monitor, business dashboard, and model discovery in one window. Built as a fork of [OrcaSlicer-FullSpectrum](https://github.com/ratdoux/OrcaSlicer-FullSpectrum) (itself a fork of Snapmaker Orca, itself a fork of OrcaSlicer).

---

## Vision

Bambu Studio is the obvious reference: a single desktop app where you slice, monitor, browse models, and run your printer. The Snapmaker side of the ecosystem has Snapmaker Orca (just a slicer) + Fluidd (in-browser monitor) + the Snapmaker mobile app + nothing for business ops. That's four tools, two of them ugly, none of them aware of each other.

MuSaiCa consolidates them:

| Concern | Today's tool | MuSaiCa tab |
|---|---|---|
| Slice files | Snapmaker Orca / Orca-FullSpectrum | **Prepare** + **Preview** (native, upstream) |
| Monitor printer | Fluidd (browser) | **Device** (embedded webview, custom React UI) |
| LLC business ops | LLCdashboard (browser) | **Dashboard** (embedded webview) |
| Find models | Printables / MakerWorld (browser) | **Discover** (embedded webview, Printables-first) |
| End-of-print alerts | nothing audible | Native stepper-music jingles |

---

## Target

- **Snapmaker U1** (primary, only printer in scope).
- Future Klipper/Moonraker-based printers reuse the Device tab unchanged.
- Bambu P1S is **out of scope** (being sold within ~2 months).

---

## Architecture

The C++ shell (forked OrcaSlicer-FullSpectrum) stays as close to upstream as possible. All custom UI lives in **embedded webviews** loading React apps you own. This keeps the rebase tax against ratdoux/upstream Orca low while letting most iteration happen in TypeScript/React where it's fast.

```
┌─────────────────────────────────────────────────────────────────┐
│  MuSaiCa (forked OrcaSlicer-FullSpectrum, C++ / wxWidgets)  │
│                                                                 │
│  ┌──────────┬──────────┬──────────┬───────────┬─────────────┐   │
│  │ Prepare  │ Preview  │  Device  │ Dashboard │  Discover   │   │
│  │ (native) │ (native) │(webview) │ (webview) │  (webview)  │   │
│  └──────────┴──────────┴────┬─────┴─────┬─────┴──────┬──────┘   │
│                             │           │            │          │
│       End-print jingle ─────┘           │            │          │
│       (PLAY_1UP injected into           │            │          │
│        machine end-gcode)               │            │          │
└─────────────────────────────────────────┼────────────┼──────────┘
                                          │            │
              ┌───────────────────────────┼────────────┼───────────────┐
              │                           │            │               │
              ▼                           ▼            ▼               ▼
       ┌─────────────┐         ┌──────────────┐  ┌───────────┐  ┌─────────────┐
       │  Snapmaker  │         │ MuSaiCa  │  │ LLC       │  │ Printables  │
       │  U1         │◄────────┤ Device app   │  │ Dashboard │  │ GraphQL API │
       │ (Moonraker  │ WS/HTTP │ (React/Vite) │  │ (Next.js) │  │             │
       │  + Klipper) │         └──────────────┘  └───────────┘  └─────────────┘
       └─────────────┘
```

### Webview hosting

- `wxWebView` (WebKit on macOS, WebView2 on Windows) — already used by upstream Orca for some panels.
- Each tab embeds a single URL. In dev, point at `http://localhost:5173` (Vite). In production, ship bundled HTML/JS as resources alongside the binary and load via `file://`.
- C++ ↔ JS bridge via `wxWebView::AddScriptMessageHandler` for: (a) sending a `.3mf` from Discover into Prepare, (b) reading the active printer profile, (c) emitting jingle settings.

### Tab responsibilities

**Prepare / Preview (native, mostly upstream)**
- Slicing UI, plate layout, support generation, multi-material setup.
- Minimum diff against ratdoux. Only changes: register webview tab hosts; add `print_completion_tune` config field and dropdown.

**Device (custom React app, replaces Fluidd)**
- Live state: temps, progress, ETA, current tool, position, fans.
- Job control: pause, resume, cancel.
- Macros and console.
- File management on the printer.
- Camera still + AI detection events.
- 24h temperature graph.
- Designed so visually it stops looking like a Klipper UI and starts looking like a product.

**Dashboard (LLC Next.js app via webview)**
- Renders the existing 3D Prints tab.
- Already tracks clients, orders, expenses; the printer-monitoring module from `LLCdashboard/PRD_3DPrinter_Monitoring.md` lights up the job-history side.
- Webview auth: cookie-based (already in production at `dashboard.tripplisenby.com`); MuSaiCa opens a login flow once and persists the session.

**Discover (custom React app, Printables-first)**
- Search Printables, filter by category / collection / license.
- Model detail page: previews, files, instructions.
- "Send to Prepare" — downloads `.3mf` and pushes into the native slicer tab via the JS↔C++ bridge.
- Local cache so re-browsing offline works.

**End-of-print jingles**
- Same as original MuSaiCa scope. Tune dropdown in the Machine tab → injects `PLAY_*` macro call into machine end-G-code at slice time.
- Macro library (`PLAY_1UP`, `PLAY_ZELDA_CHEST`, `PLAY_SAD_TROMBONE`, `PLAY_PAUSE_LOOP`) ships as a Klipper `tunes.cfg` include uploaded to the printer via Fluidd once.

---

## Component sketch — Device tab (React/Vite)

```
src/
├── main.tsx
├── App.tsx                       # tab router (live / jobs / macros / console / camera)
├── lib/
│   ├── moonraker.ts              # WS JSON-RPC client + auto-reconnect
│   ├── moonraker-hooks.ts        # useMoonrakerState, useTemps, useJobProgress
│   ├── bridge.ts                 # postMessage bridge to C++ shell
│   └── notify.ts                 # ntfy passthrough (shares config with Dashboard)
├── components/
│   ├── StatusHero.tsx            # big "Printing • 47% • 1h 12m left"
│   ├── TempGauges.tsx            # hotend / bed; live ring gauges
│   ├── TempChart.tsx             # 24h Recharts area chart
│   ├── JobControls.tsx           # pause/resume/cancel server actions
│   ├── ToolStack.tsx             # U1's 4 toolheads, active highlighted
│   ├── CameraStill.tsx           # last frame + AI-detection overlay
│   ├── MacroList.tsx             # PLAY_1UP, PARK, etc. one-tap buttons
│   ├── Console.tsx               # Moonraker /gcode/script terminal
│   └── FilesPanel.tsx            # upload / queue / delete .gcode
├── theme/
│   ├── tokens.css                # dark-first; match LLCdashboard prints theme
│   └── components.css
└── state/
    └── store.ts                  # Zustand: connection, last-error, job, temps
```

**Moonraker client (`lib/moonraker.ts`):**
- One WebSocket at `ws://<u1-ip>/websocket`.
- JSON-RPC 2.0; subscribe via `printer.objects.subscribe` to `toolhead`, `extruder`, `heater_bed`, `print_stats`, `display_status`, `virtual_sdcard`.
- Reconnect with exponential backoff (1s → 30s cap).
- Emits typed events; Zustand store consumes them.

**Theme:**
- Match LLC dashboard's `data-business="prints"` tokens so the visual language flows between Device and Dashboard tabs.
- Dark theme primary; light theme parity later.

---

## Printables API audit

There is **no official public API**. The web app talks to a GraphQL endpoint that's accessible but undocumented and unstable. Community projects exist and work; build against them at your own risk.

### Endpoint
```
POST https://api.printables.com/graphql/
Content-Type: application/json
```

### Authentication
- Public anonymous queries: search, browse, model details, file metadata — work without auth.
- Downloads of files: a session token from the website is required for some files. Anonymous downloads work for many models. (Confirm at build time.)
- No documented OAuth flow. Don't ship user login to Printables in v1; treat it as read-only anonymous browsing.

### Known queries (from community implementations)
- `SearchModels` — name, slug, ratingAvg, likesCount, downloadCount, datePublished, thumbnail.
- `Model(id:)` — files (`.3mf`, `.stl`, `.gcode`), images, instructions, license, user.
- `PrintFile` / `ModelFile` — download URL (signed/temporary).
- Categories, tags, collections.

### Risks
- **No SLA, no versioning.** Printables can change the schema or rate-limit at any time.
- **No documentation.** Schema introspection may or may not be enabled — check at build time.
- **TOS.** Printables' terms allow personal use; commercial redistribution of model files is restricted. The Discover tab should treat itself as a *browser*, not a *mirror* — link out, don't cache files long-term.
- **Rate limits.** Unknown; community implementations have been throttled. Cache search results aggressively; debounce typing.

### Reference implementations to crib from
- [100prznt/PrintablesGraphQL](https://github.com/100prznt/PrintablesGraphQL) — .NET client with working `SearchModels` query and field selections.
- [GhostTypes/printables-cli-api](https://github.com/GhostTypes/printables-cli-api) — Python CLI; useful as a query reference and shows how downloads work.

### MakerWorld
- No official API; no public GraphQL endpoint exposed. Community scrapers exist and break frequently.
- **Decision:** explicitly skip MakerWorld in v1. If Bambu opens an API later, add then.

### Thingiverse
- REST API exists but is dated. Quality of results is low compared to Printables.
- **Decision:** skip in v1.

**Net:** Discover tab targets Printables only via the undocumented GraphQL endpoint. Build defensively (typed wrappers, retry/backoff, fallback to "browse on web" link if the schema breaks).

---

## Phases & milestones

Total estimate: **6–10 weeks** of focused work for v1 (slicer + jingles + Device tab + Dashboard tab + minimal Discover).

### Phase 1 — MuSaiCa core (weeks 1–2)

| # | Milestone | Definition of Done |
|---|---|---|
| M0 | Validate jingle on U1 hardware | `PLAY_1UP` plays a recognizable 1-up at print end |
| M1 | Calibrate `STEPS_PER_MM` | Notes match a tuner within ±10 cents |
| M2 | Author tune library | 1-Up, Zelda Chest, Sad Trombone, Two-note Pause loop |
| M3 | Fork OrcaSlicer-FullSpectrum → MuSaiCa | Builds clean from ratdoux's main on macOS |
| M4 | `print_completion_tune` config field + dropdown | Tune selection persists in profile, emitted in end-G-code |

### Phase 2 — Shell + Dashboard tab (weeks 3–4)

| # | Milestone | Definition of Done |
|---|---|---|
| M5 | Webview tab host in C++ shell | New tab loads an arbitrary URL inside the Orca window |
| M6 | Dashboard tab live | LLC dashboard renders inside MuSaiCa, login persists |
| M7 | JS↔C++ bridge | Webview can request active printer profile / send slice intents |

### Phase 3 — Device tab (weeks 5–7)

| # | Milestone | Definition of Done |
|---|---|---|
| M8 | Moonraker client + Zustand state | Reconnect on drop, typed events, unit-tested |
| M9 | Status, temps, job controls | Glanceable status hero, pause/resume/cancel work |
| M10 | Macros, console, files panel | Parity with Fluidd's daily-use features |
| M11 | Camera + AI detection display | Last still + overlay on detection events |
| M12 | Visual polish | Looks like a product, not a Klipper UI |

### Phase 4 — Discover tab (weeks 8–10)

| # | Milestone | Definition of Done |
|---|---|---|
| M13 | Printables GraphQL client | Typed search + model detail queries with retry |
| M14 | Browse UI | Search, filters, model grid, detail page |
| M15 | "Send to Prepare" | Downloaded `.3mf` opens in the native slicer tab |
| M16 | Cache + offline browse | Recent search results cached locally |

### Phase 5 — Stretch

- Spoolman integration (filament inventory).
- Multi-printer support (when a second U1-or-Klipper printer joins the fleet).
- Native macOS notifications (in addition to ntfy on mobile).
- Auto-feedrate from `rotation_distance` for jingles (no per-printer constant).
- Open PR upstream to ratdoux for the jingle feature.

---

## Build & dev setup

**Prerequisites:**
- macOS 14+ (primary dev target). Linux/Windows possible later.
- CMake 3.25+, Ninja, a recent Clang.
- Node 20+ for the webview React apps.
- Bambu/Orca-style first build is ~20 min; incremental builds are fast.

**Layout (planned):**
```
musaica/
├── slicer/                   # forked OrcaSlicer-FullSpectrum (mostly upstream)
├── webviews/
│   ├── device/               # React/Vite Moonraker UI
│   ├── discover/             # React/Vite Printables browser
│   └── shared/               # shared theme tokens, bridge types
├── tunes/
│   └── tunes.cfg             # Klipper macros uploaded to printer
└── docs/
```

**Dev loop:**
- `pnpm --filter device dev` → Vite at `localhost:5173`.
- Build slicer in `Debug` config; webview points at the dev server.
- Production build bundles webviews into `slicer/resources/webviews/` and loads via `file://`.

---

## Caveats

- **Rebase tax against upstream.** Every Orca release brings C++ changes that may touch tab routing, profile schema, or build files. Keep the C++ diff small. Most upstream merges should be zero-conflict.
- **Printables API instability.** Build the Discover tab to fail gracefully (skeleton + retry + "open on web" link). Don't depend on it for critical workflows.
- **Webview perf.** `wxWebView` is fine for SPA-style apps but heavy DOM (10k-model grids) needs virtualization. Plan for `react-virtuoso` or similar.
- **Auth flow for Dashboard tab.** Better Auth's cookie scoping (`.tripplisenby.com`) works in webviews, but session refresh edge cases need testing — particularly when MuSaiCa runs offline.
- **AGPLv3 compliance.** OrcaSlicer is AGPLv3. The fork must remain open if you distribute it. Internal-only LLC use has fewer obligations, but if you ever ship it publicly, source must follow.

---

## References

- OrcaSlicer-FullSpectrum: https://github.com/ratdoux/OrcaSlicer-FullSpectrum/releases
- Upstream OrcaSlicer: https://github.com/SoftFever/OrcaSlicer
- Snapmaker Orca: https://github.com/Snapmaker/SnapmakerOrca
- Moonraker docs: https://moonraker.readthedocs.io/
- Klipper M300 / beeper discussion: https://github.com/KevinOConnor/klipper/issues/847
- Fluidd: https://github.com/fluidd-core/fluidd
- Mainsail (alternate Klipper UI for reference): https://github.com/mainsail-crew/mainsail
- Snapmaker U1 firmware on GitHub: https://blog.snapmaker.com/blog/snapmaker-u1-firmware-now-on-github/
- 100prznt/PrintablesGraphQL: https://github.com/100prznt/PrintablesGraphQL
- GhostTypes/printables-cli-api: https://github.com/GhostTypes/printables-cli-api
- BambuStudio pause-sound feature request (motivating prior art): https://github.com/bambulab/BambuStudio/issues/4142
