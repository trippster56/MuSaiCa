# Filament inventory via Spoolman

MuSaiCa's "inventory" story is **Spoolman**, the Klipper-ecosystem standard
that the bundled Mainsail UI already talks to out of the box. Per-spool
weights, vendors, materials, costs, and per-print consumption all live on
the printer, and the **Mainsail** tab in MuSaiCa surfaces them automatically
once Moonraker can see a Spoolman instance.

## What you see when it's wired up

- A new **Spoolman** entry in Mainsail's left navigation.
- A **Filament selector** in the Status panel (pick the active spool for the
  current print).
- Per-spool detail pages: total/used/remaining weight, last-used timestamp,
  material/vendor/color, custom fields.
- After each print, Moonraker decrements the active spool's remaining weight
  by the slicer's reported filament usage.

No MuSaiCa-side configuration: Mainsail auto-detects Spoolman through
Moonraker's component registry the moment it's reachable.

## One-time setup on the U1

The exact commands depend on which firmware image the U1 ships with. The
shape will look like one of these.

### Option A — Spoolman on the U1 itself (Docker)

```bash
ssh u1@<u1-host>
mkdir -p ~/spoolman-data
docker run -d --restart=always \
    --name spoolman \
    -v ~/spoolman-data:/home/app/.local/share/spoolman \
    -p 7912:8000 \
    ghcr.io/donkie/spoolman:latest
```

Then add to `moonraker.conf` from Mainsail's config editor:

```ini
[spoolman]
server: http://localhost:7912
sync_rate: 5
```

Restart Moonraker (Mainsail header → power → SERVICES → moonraker → restart).
Reload the **Mainsail** tab in MuSaiCa.

### Option B — Spoolman on another machine

Same install steps but on a NAS / homelab box, then point `server:` at that
host's IP:port in `moonraker.conf`.

### Option C — No Docker available

```bash
pip install --user spoolman
python -m spoolman --host 0.0.0.0 --port 7912
```

Wrap in a systemd unit so it survives reboots; the Spoolman docs at
<https://github.com/Donkie/Spoolman#installation> have a sample.

## First-time use in MuSaiCa

1. Open MuSaiCa → **Mainsail** tab → **Spoolman** in the left nav.
2. **Vendors** → add the brands you use.
3. **Filaments** → add the materials (PLA, PETG, etc.) with density and
   default extrusion temps.
4. **Spools** → register each physical spool (1kg net, etc.). Stick a
   barcode or QR label on the spool — Mainsail's Spoolman panel can scan
   one via a USB scanner or phone-as-camera.
5. Before a print: pick the active spool in Mainsail's Status panel.
6. After the print: weight auto-decrements. Slicer's filament-usage
   estimate from the gcode header is the source of truth.

## Why Spoolman over a slicer-tracked ledger

- Lives on the printer, so multi-device usage (MuSaiCa on the Mac and the
  Snapmaker mobile app, or a phone-browser to Mainsail) stays consistent.
- Survives slicer reinstalls and profile resets.
- Standard schema → can integrate with bambu-style barcode/NFC tooling, or
  even with Home Assistant for "PLA low" alerts.
- Zero MuSaiCa code to maintain — pure ecosystem leverage.

## Limits worth knowing

- **No AMS-style 4-slot UI** because the U1 has no AMS hardware. Manual
  multi-material on the U1 (two-extruder loadouts) still needs you to
  pick the right spool per filament in the slicer.
- **Spoolman does not auto-detect the loaded spool.** It's the user's
  job to pick the active spool before the print; Spoolman just decrements
  whatever is selected. Some users wire QR/NFC readers to automate this.
- If you skip the Spoolman install, the Spoolman tab in Mainsail simply
  isn't shown — nothing else in MuSaiCa breaks.
