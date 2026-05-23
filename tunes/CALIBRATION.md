# U1 jingle calibration (M0 + M1)

Five-minute procedure for when the printer arrives. Validates the Mario 1-Up
plays end-of-print (M0) and tunes the notes to a chromatic tuner (M1).

## One-time setup

1. In MuSaiCa, open the **Mainsail** tab. Mainsail should auto-connect to the
   U1's Moonraker using the per-printer `print_host` you set in the printer
   profile (default Moonraker port is 7125).
2. Mainsail → **Machine** tab → **Config files** → upload
   `tunes/tunes.cfg` to the printer's `~/printer_data/config/` folder.
3. Edit `printer.cfg` from Mainsail's config editor, append on a new line:

   ```
   [include tunes.cfg]
   ```

4. Restart Klipper (Mainsail header → power → **FIRMWARE RESTART**).

## M0 — Does it play?

In Mainsail's console, run:

```
PLAY_1UP
```

X-axis should emit six recognizable beeps. If silent: the axis isn't moving —
check that the U1 is homed and not idle-disconnected (`SET_STEPPER_ENABLE
STEPPER=stepper_x ENABLE=1` first).

If you hear noise but it doesn't sound musical, you need M1.

## M1 — Calibrating `STEPS_PER_MM`

The default in `tunes/tunes.cfg` is **80.0 steps/mm**. The U1's actual value
comes from `printer.cfg`:

```
steps_per_mm = (motor_steps_per_rev × microsteps) / rotation_distance
```

(Snapmaker U1 will likely be in the 80–160 range for X. Check
`[stepper_x] rotation_distance` and `microsteps`.)

Procedure:

1. Open a tuner app (Insta-tuner, gStrings, etc.) on your phone, set to A4=440.
2. In Mainsail console, play a known reference note:

   ```
   PLAY_NOTE FREQ=440 MS=2000
   ```

3. Read the tuner's pitch. If it shows A4 dead-on (±10 cents), you're done.
4. If the tuner shows a flat A (say A3♯, ~415 Hz), your real steps/mm is
   *lower* than the value in tunes.cfg. Compute the ratio
   `STEPS_PER_MM_new = STEPS_PER_MM_old × measured_freq / 440` and update
   `variable_steps_per_mm` in `_MUSAICA_CFG` accordingly.
5. Re-run `PLAY_NOTE FREQ=440 MS=2000`. Within ±10 cents = done.

Spot-check higher notes (`PLAY_NOTE FREQ=1318 MS=1000` ≈ E6) to confirm the
tuning is linear, since some setups deviate at the extremes.

## After calibration

Set your slicer's machine end G-code so MuSaiCa's dropdown actually fires the
jingle. In the printer profile → **Machine G-code** → **Machine end G-code**,
add at the bottom:

```
END_PRINT TUNE=[print_completion_tune]
```

The `[print_completion_tune]` placeholder resolves to `none`, `1up`,
`zelda_chest`, or `sad_trombone` based on the dropdown selection. The
`END_PRINT` macro in tunes.cfg dispatches to the right `PLAY_*` body.

That's M6 lit up. Done.
