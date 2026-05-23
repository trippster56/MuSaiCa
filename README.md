# MuSaiCa

**Mu**(sical) + **Sa**(il) + (Or)**ca** — the jingles, the monitor UI, and the slicer in one name.

A single desktop app for the **Snapmaker U1** that combines:

- **Slicer** — forked from [OrcaSlicer-FullSpectrum](https://github.com/ratdoux/OrcaSlicer-FullSpectrum) (itself a Snapmaker Orca fork of OrcaSlicer).
- **Printer monitor** — Mainsail bundled inside the slicer binary, loaded in a webview tab. Talks to the U1's Moonraker over the network. No second app to launch.
- **End-of-print stepper-music jingles** — Mario 1-Up by default, configurable via a dropdown in printer settings.
- **Filament inventory** — handled by [Spoolman](https://github.com/Donkie/Spoolman), which the bundled Mainsail tab speaks natively. Setup in [docs/SPOOLMAN.md](docs/SPOOLMAN.md). Zero MuSaiCa-side code; pure ecosystem leverage.

> The previous, broader scope (LLC dashboard tab, Printables Discover tab, custom-built Moonraker UI) is preserved in `README_GRAND_VISION.md` as a stretch. This README is the realistic v1 plan.

---

## Why this shape

Snapmaker ships Snapmaker Orca (slicer only) + Fluidd/Mainsail (browser-based monitor) + the Snapmaker mobile app. That's three things to keep open. Bambu Studio collapses slicing + monitoring into one app, and the Snapmaker side doesn't have an equivalent.

MuSaiCa is that equivalent — one window, slice and monitor, plus a fun audible alert nobody else has.

The U1 has no built-in speaker, and the Snapmaker app doesn't reliably push when a print pauses for user input. Stepper-music jingles solve the workshop-audible-alert problem with zero extra hardware: the motors play tones because step frequency *is* an audible frequency.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  MuSaiCa.app  (single install, single launch)           │
│                                                             │
│  ┌──────────┬──────────┬──────────────────────┐             │
│  │ Prepare  │ Preview  │ Device (webview)     │             │
│  │ (native) │ (native) │   │                  │             │
│  └──────────┴──────────┴───┼──────────────────┘             │
│                            │ loads file://                  │
│                            ▼                                │
│            resources/webviews/mainsail/index.html           │
│            (Mainsail dist, bundled inside the .app)         │
└────────────────────────────┬────────────────────────────────┘
                             │ WebSocket + HTTP
                             │ to U1's Moonraker over LAN
                             ▼
                ┌──────────────────────────┐
                │  Snapmaker U1            │
                │  ├─ Moonraker (Python)   │  ← already runs on the U1
                │  └─ Klipper (firmware)   │     out of the box
                └──────────────────────────┘
```

Key idea: **Mainsail is just static HTML/JS/CSS**. It's a Vue.js app that talks to Moonraker's API over the network. Bundling Mainsail's production `dist/` folder inside the slicer's resources lets the webview load it via `file://` — no Mainsail process on the printer needed, no second app on your Mac. The printer only needs Moonraker, which it has by default.

If you fork Mainsail to customize the visuals, you rebuild your fork, copy the new `dist/` into the slicer's resources, and ship it as part of the next slicer release. Total UI ownership.

---

## What MuSaiCa is *not*

- Not a Moonraker replacement. The U1's onboard Moonraker stays.
- Not a Klipper replacement. The U1's onboard Klipper stays.
- Not a separate web app. Single desktop binary.
- Not a Mainsail competitor — it *is* Mainsail, with your branding/theme baked in.

---

## Repo layout (planned)

```
musaica/
├── slicer/                   # forked OrcaSlicer-FullSpectrum (C++)
│   └── (small diff: webview tab host, tune dropdown, resource path)
├── mainsail/                 # git submodule → your Mainsail fork
│   └── (Vue source; customized branding/theme)
├── tunes/
│   └── tunes.cfg             # Klipper macros uploaded to U1 once via Fluidd/Mainsail
├── scripts/
│   └── bundle-mainsail.sh    # npm run build in mainsail/, copy dist/ into slicer resources
└── docs/
```

### Build flow

1. `cd mainsail && npm install && npm run build` → produces `mainsail/dist/`.
2. `scripts/bundle-mainsail.sh` copies `dist/` into `slicer/resources/webviews/mainsail/`.
3. Normal OrcaSlicer build (`cmake -B build && cmake --build build`).
4. Output: a single `MuSaiCa.app` containing the slicer + bundled Mainsail.

CI can chain these into one workflow.

---

## Slicer-side changes (the small C++ diff)

Goal: keep the fork tiny so rebasing against ratdoux/upstream is cheap.

1. **Add a webview tab.** `wxWebView` is already a dependency in OrcaSlicer. Register one new tab; point it at `file:///.../resources/webviews/mainsail/index.html`. Done.
2. **Printer URL config field.** Per-printer setting: Mainsail's bundled JS needs to know where the U1's Moonraker lives. Add a "Printer host" input in the printer profile (e.g., `192.168.1.42` or `u1.local`). At webview-load time, inject this into Mainsail's `config.json` so it auto-connects.
3. **`print_completion_tune` config field + dropdown.** Enum: `none | 1up | zelda_chest | sad_trombone`. Templated machine end-G-code emits the corresponding `PLAY_*` macro call.

Estimated C++ diff: a few hundred lines across maybe 5–6 files.

---

## Mainsail-side changes (optional, your own pace)

Tier 1 — no fork:
- Drop a `custom.css` + theme files into the bundled Mainsail's expected theme directory. Override colors, logos, panel layout via CSS. Covers most of what you'll want visually.

Tier 2 — fork:
- Fork [mainsail-crew/mainsail](https://github.com/mainsail-crew/mainsail) into your GitHub.
- Add as a submodule under `mainsail/` in this repo.
- Modify Vue components for layout / panel changes that CSS can't handle.
- Rebuild → ships in the next MuSaiCa release.

Tier 2 is independent of the slicer work. Ship v1 with stock Mainsail; iterate on the theme later.

---

## Jingles — quick reference

Stepper motors produce audible tones because step frequency *is* a frequency. With steps-per-mm `S`, a note at `f` Hz needs feedrate `(f / S) × 60` mm/min. Alternating direction each note keeps net displacement ≈ 0.

The full `PLAY_NOTE` / `PLAY_1UP` / `END_PRINT` Klipper macros live in `tunes/tunes.cfg`. Upload once via Mainsail's config editor to the U1. The slicer's tune dropdown injects `PLAY_1UP` (or whichever is selected) into the machine end-G-code; the macro runs after the print finishes.

Validate the jingle on real hardware before touching any C++.

---

## Milestones

| # | Milestone | DoD |
|---|---|---|
| M0 | Validate jingle on U1 hardware | `PLAY_1UP` plays a recognizable 1-Up at the end of a real test print |
| M1 | Calibrate `STEPS_PER_MM` | Notes match a tuner within ±10 cents |
| M2 | Fork OrcaSlicer-FullSpectrum → MuSaiCa | Builds clean on macOS from a checkout |
| M3 | Add Mainsail submodule + bundle script | `scripts/bundle-mainsail.sh` produces `dist/` and copies it into resources |
| M4 | Webview tab loads bundled Mainsail | New "Device" tab in the slicer renders Mainsail's UI from `file://` |
| M5 | Printer-host config + auto-connect | Mainsail in the webview connects to U1's Moonraker using the configured host |
| M6 | `print_completion_tune` dropdown | Selection persists per-printer; jingle plays after print ends |
| M7 | v1 release | Single `.app`, installable, used daily |

Estimated total: **2–3 focused weekends** of work after the U1 arrives.

---

## Pre-arrival prep (can start now)

- Clone `OrcaSlicer-FullSpectrum` and do a clean build on macOS. First build is ~20 min — don't discover toolchain issues on print day.
- Clone Mainsail, run `npm install && npm run build` once. Confirm `dist/` is produced and is a reasonable size (~3 MB).
- Set up the Docker sandbox at `~/Desktop/Projects/PrinterUI-Sandbox/` (already done). Use it to live-test Mainsail customizations before the U1 arrives.
- Bookmark Moonraker's docs: https://moonraker.readthedocs.io/
- Read the U1 `printer.cfg` once it ships, capture the actual `rotation_distance` / steps-per-mm for the jingle macro.

---

## Caveats

- **Mainsail is GPLv3, OrcaSlicer is AGPLv3.** Bundling Mainsail's `dist/` inside the slicer's `.app` is fine — both licenses are open, and ship Mainsail's license file alongside the bundle. If you ever distribute MuSaiCa, source for both must be available.
- **Rebase tax** against upstream OrcaSlicer. Mitigated by keeping the C++ diff small. Most upstream merges should be zero-conflict because all your custom UI lives in Mainsail (a separate submodule).
- **Mainsail config injection.** Mainsail expects a `config.json` at its web root. You inject the printer host at runtime — either by editing the file before webview load, or by intercepting the webview's request for `config.json` and serving a dynamically-generated one via wxWebView's URL scheme handlers.
- **WebView2 / WebKit quirks.** wxWebView uses WebKit on macOS and WebView2 on Windows. Some Mainsail features (notifications, clipboard) may behave differently across them. Test both before declaring v1 done if you ship to Windows.

---

## References

- OrcaSlicer-FullSpectrum: https://github.com/ratdoux/OrcaSlicer-FullSpectrum/releases
- Upstream OrcaSlicer: https://github.com/SoftFever/OrcaSlicer
- Snapmaker Orca: https://github.com/Snapmaker/SnapmakerOrca
- Mainsail: https://github.com/mainsail-crew/mainsail
- Moonraker docs: https://moonraker.readthedocs.io/
- Snapmaker U1 firmware on GitHub: https://blog.snapmaker.com/blog/snapmaker-u1-firmware-now-on-github/
- Klipper M300 / beeper discussion: https://github.com/KevinOConnor/klipper/issues/847
