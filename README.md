# MuSaiCa

**Mu**(sical) + **Sa**(il) + (Or)**ca**

A single desktop app for the [Snapmaker U1](https://snapmaker.com/snapmaker-u1) that slices, monitors, and sings — replacing the usual stack of three separate tools with one window.

[![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Status: pre-hardware](https://img.shields.io/badge/Status-pre--hardware-orange)](#milestones)

### Built on

[![Snapmaker](https://img.shields.io/badge/Snapmaker-U1-FF6900?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTEyIDJMMiAxMmgzdjEwaDR2LTZoNnY2aDR2LTEwaDN6Ii8+PC9zdmc+&logoColor=white)](https://snapmaker.com/snapmaker-u1)
[![OrcaSlicer](https://img.shields.io/badge/Forked%20from-OrcaSlicer-3DBAE6)](https://github.com/SoftFever/OrcaSlicer)
[![Klipper](https://img.shields.io/badge/Klipper-firmware-D1233A?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTEyIDJDNi40OCAyIDIgNi40OCAyIDEyczQuNDggMTAgMTAgMTAgMTAtNC40OCAxMC0xMFMxNy41MiAyIDEyIDJ6Ii8+PC9zdmc+)](https://www.klipper3d.org/)
[![Moonraker](https://img.shields.io/badge/Moonraker-API-191970)](https://moonraker.readthedocs.io/)
[![Mainsail](https://img.shields.io/badge/Mainsail-bundled-12AAE0?logo=vuedotjs&logoColor=white)](https://docs.mainsail.xyz/)
[![Spoolman](https://img.shields.io/badge/Spoolman-filament%20inventory-009688)](https://github.com/Donkie/Spoolman)

### Tech stack

[![C++](https://img.shields.io/badge/C%2B%2B-17-00599C?logo=cplusplus&logoColor=white)](https://isocpp.org/)
[![wxWidgets](https://img.shields.io/badge/wxWidgets-GUI-444D56)](https://www.wxwidgets.org/)
[![CMake](https://img.shields.io/badge/Build-CMake-064F8C?logo=cmake&logoColor=white)](https://cmake.org/)
[![Vue.js](https://img.shields.io/badge/Vue.js-Mainsail%20UI-4FC08D?logo=vuedotjs&logoColor=white)](https://vuejs.org/)
[![Python](https://img.shields.io/badge/Python-Klipper%20macros-3776AB?logo=python&logoColor=white)](https://www.python.org/)

---

## What it does

| Feature | How |
|---|---|
| **Slice** | Forked from [OrcaSlicer-FullSpectrum](https://github.com/ratdoux/OrcaSlicer-FullSpectrum), itself a Snapmaker Orca fork of OrcaSlicer. |
| **Monitor** | [Mainsail](https://github.com/mainsail-crew/mainsail) bundled inside the app, loaded in a webview tab. Talks to the U1's Moonraker over LAN — no second app to launch. |
| **Sing** | End-of-print stepper-music jingles (Mario 1-Up by default; configurable per-printer). Motors *are* the speaker — no extra hardware. |
| **Track filament** | [Spoolman](https://github.com/Donkie/Spoolman); the bundled Mainsail tab speaks it natively. Setup in [docs/SPOOLMAN.md](docs/SPOOLMAN.md). |

## Why it exists

Snapmaker ships **Snapmaker Orca** (slicer) + **Fluidd/Mainsail** (browser monitor) + the **Snapmaker mobile app**. Three things to keep open. Bambu Studio collapses slicing and monitoring into one window; the Snapmaker side doesn't have an equivalent. MuSaiCa is that equivalent.

The U1 has no built-in speaker, and the Snapmaker app doesn't reliably push when a print pauses for user input. Stepper-music jingles solve the workshop-audible-alert problem with zero extra hardware — step frequency *is* an audible frequency.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  MuSaiCa.app  (single install, single launch)               │
│                                                             │
│  ┌──────────┬──────────┬──────────┬────────────┐            │
│  │ Prepare  │ Preview  │ Device   │ Mainsail   │            │
│  │ (native) │ (native) │ (native) │ (webview)  │            │
│  └──────────┴──────────┴──────────┴─────┬──────┘            │
│                                         │ loads http://     │
│                                         ▼                   │
│            in-process HTTP server -> resources/web/         │
│                                       mainsail/dist/        │
└────────────────────────────┬────────────────────────────────┘
                             │ WebSocket + HTTP
                             │ over LAN
                             ▼
                ┌──────────────────────────┐
                │  Snapmaker U1            │
                │  ├─ Moonraker (Python)   │
                │  └─ Klipper (firmware)   │
                └──────────────────────────┘
```

**Key idea:** Mainsail is just static HTML/JS/CSS. Bundling its production `dist/` inside the slicer's resources and serving it over `http://localhost` lets the embedded webview load it as if it were any other Mainsail instance. The printer only needs Moonraker (which it ships with).

---

## Repo layout

```
MuSaiCa/                    outer repo (this repo)
├── mainsail/               submodule -> bundled Mainsail dist
├── slicer/                 submodule -> trippster56/OrcaSlicer-FullSpectrum
├── tunes/                  Klipper macros (uploaded to U1 once)
│   ├── tunes.cfg
│   └── CALIBRATION.md
├── scripts/
│   └── bundle-mainsail.sh
└── docs/
```

**Two repos, one project.** The slicer fork is large (~500k LOC) so it lives as a git submodule. A typical change touching slicer code is two commits — one inside `slicer/` on the `musaica` branch, one in the outer repo bumping the submodule SHA. Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/trippster56/MuSaiCa.git
```

---

## Build

Requires Xcode CLT, CMake, Ninja, Python 3, Node 18+.

```bash
# one-time: build deps
cd slicer && ./build_release_macos.sh -d

# slicer build
cd slicer && ./build_release_macos.sh -sx

# bundle Mainsail (when its dist changes)
./scripts/bundle-mainsail.sh
```

Output: `slicer/build/arm64/src/Release/Snapmaker_Orca.app`.

---

## Jingles

Stepper motors produce audible tones because step frequency *is* a frequency. With `S` steps/mm, a note at `f` Hz needs feedrate `(f × 60) / S` mm/min. Alternating direction each note keeps net displacement ≈ 0.

`PLAY_NOTE`, `PLAY_1UP`, `PLAY_ZELDA_CHEST`, `PLAY_SAD_TROMBONE`, and the `END_PRINT TUNE=…` dispatcher all live in [`tunes/tunes.cfg`](tunes/tunes.cfg). Upload once via Mainsail's config editor, add `[include tunes.cfg]` to `printer.cfg`, restart Klipper. Calibration procedure: [`tunes/CALIBRATION.md`](tunes/CALIBRATION.md).

The slicer dropdown (**Printer Settings → Machine G-code → Print completion tune**) injects the choice into machine end-G-code; the printer plays it after the print finishes.

---

## Milestones

| # | Milestone | Status |
|---|---|---|
| M0 | Validate jingle on U1 hardware | blocked on hardware |
| M1 | Calibrate `STEPS_PER_MM` | blocked on hardware |
| M2 | Fork OrcaSlicer-FullSpectrum → MuSaiCa | done |
| M3 | Bundle Mainsail dist into slicer resources | done |
| M4 | Mainsail webview tab loads bundled assets | done |
| M5 | Printer-host config + auto-connect | done |
| M6 | `print_completion_tune` dropdown + end-G-code hookup | done (preview button TBD) |
| M7 | v1 release | open |

---

## What MuSaiCa is *not*

- Not a Moonraker replacement. The U1's onboard Moonraker stays.
- Not a Klipper replacement. The U1's onboard Klipper stays.
- Not a separate web app. Single desktop binary.
- Not a Mainsail competitor — it *is* Mainsail, with the project's branding baked in.

---

## License

- This repo: **AGPLv3** (inherited from OrcaSlicer).
- Bundled Mainsail: **GPLv3**.
- `tunes/tunes.cfg` macros: **MIT** (negligible original work).

Distributing MuSaiCa requires making source available for both AGPL and GPL components.

---

## References

- OrcaSlicer-FullSpectrum: https://github.com/ratdoux/OrcaSlicer-FullSpectrum
- Upstream OrcaSlicer: https://github.com/SoftFever/OrcaSlicer
- Snapmaker Orca: https://github.com/Snapmaker/SnapmakerOrca
- Mainsail: https://github.com/mainsail-crew/mainsail
- Moonraker docs: https://moonraker.readthedocs.io/
- Klipper docs: https://www.klipper3d.org/
- Snapmaker U1 firmware on GitHub: https://blog.snapmaker.com/blog/snapmaker-u1-firmware-now-on-github/

The longer-term/stretch scope (LLC dashboard tab, Printables Discover tab, custom Moonraker UI) is preserved in [`README_GRAND_VISION.md`](README_GRAND_VISION.md).
