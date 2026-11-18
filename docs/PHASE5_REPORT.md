# Phase 5 Report — Mobile UI, Art & Audio

Status: **Implemented and tested on desktop at 4 aspect ratios. Not yet verified on a physical phone. Awaiting approval before Phase 6.**
Date: 2026-11-11 · Godot 4.7.2

## How to run / verify

- **Play:** run the project. Use **Settings** in the main menu or in the pause menu.
- **Tests:**

  ```bash
  godot --headless --path . -s res://tests/run_tests.gd
  ```

- **Layout captures at any aspect ratio** (`--fake-safe-area` is optional and simulates a notch):

  ```bash
  godot --path . --resolution 1600x720 -s res://tools/capture_layouts.gd -- --out=<dir> --tag=20x9 --profile=<dir>/p.json --fake-safe-area=60,0,30,0
  ```

- **Regenerate audio:**

  ```bash
  godot --headless --path . -s res://tools/audio_gen/gen_audio.gd
  ```

## Implemented

### Landscape and aspect ratios

- The 1280×720 world is **centred inside the safe area** for any aspect ratio (16:9, 19.5:9, 20:9 and 4:3 verified).
- The HUD and menus are inset by the **safe-area insets** (`DisplayServer.get_display_safe_area()` on mobile). They are recomputed on resize/rotation.
- Background fills any extra space.

### Touch

- Drag & tap placement from Phase 2, now in safe-area/offset-correct coordinates.
- The Build/Cancel box is clamped to the safe area.
- All touch targets are ≥ 48 px. Palette buttons are 96×88; panel buttons are 160×48 or larger.

### Tower panel

- Docks top or bottom so it doesn't cover the selected tower.
- The role line now shows the committed branch's description (this fixes the misleading Beacon text).
- Sell is disabled for no-selling challenges.

### Settings

- Music and SFX each have an on/off toggle and an independent volume slider. They are saved to `user://settings.cfg`.
- Settings open from the main menu and in-match from the pause menu.
- Values are applied through `Music` / `SFX` audio buses.

### Audio

- **15 original synthesized SFX:** build, upgrade, evolve, sell, 3 tower shots, impact, enemy death, wave start, boss, EMP, victory, defeat, UI click.
- **Music:** a 32 s seamless ambient loop.
- **`SfxLimiter`:** 40 ms per-sound cooldown, max 2 voices per sound, max 12 global voices, with quieter gains for frequent sounds. This avoids audio overload when many towers fire.
- **Licenses:** `audio/LICENSES.md`.

### Visuals (minimal VFX)

- Enemy death: shrink ring plus 6 fading shards.
- Towers grow slightly per tier and on evolution, in addition to tier pips and the evolution ring.
- Night: stronger blue tint, and Beacons draw a soft light circle at night.
- New geometric app icon.
- No particles, no shaders, no screen shake.

### Architecture

- `ScreenLayout` holds the layout math (pure, tested).
- `GameSettings` + `Settings` autoload.
- `Audio` autoload + `MatchAudio` presenter, connected to presentation-only controller signals. Gameplay never depends on audio.

## Tests executed (real output)

`107 passed, 0 failed (88.1 s)`. There were 0 `SCRIPT ERROR` lines in the run log. The game launches with no errors.

At runtime, all 15 SFX streams load, the music plays, the `Music` and `SFX` buses are created, and the limiter tracks voices.

New in Phase 5 (6 tests):
- settings roundtrip, out-of-range values clamped, defaults when the file is missing, mute = −80 dB;
- limiter cooldown, per-sound cap, voice release and global cap;
- safe-area conversion from screen pixels to canvas units;
- world centring for 16:9, 20:9 and 4:3, inside a notch safe area, and never under the notch;
- every audio asset loads, and the music is longer than 30 s;
- every attacking tower has a shot sound.

**Visual verification** (`docs/phase5_screens/`, rendered on the desktop GPU): 5 states × 4 aspect ratios.

| Aspect ratio | Window | Notes |
|---|---|---|
| 16:9 | 1280×720 | |
| 19.5:9 | 1560×720 | |
| 20:9 | 1600×720 | simulated notch L60 / R30 |
| 4:3 | 1280×960 | |

The 5 states are: main menu, campaign, match with tower panel, tap-to-place ghost, and pause + settings.

## Known issues / limitations

1. **Not run on a real Android/iOS device.** These are untested there:
   - real touch feel;
   - real safe areas;
   - performance;
   - audio latency.
   An Android export needs the Android SDK + export templates (Phase 6/7 prerequisites). iOS needs a Mac.
2. **Audio quality is functional, not produced.** The synthesized sounds are simple. A sound designer pass would improve feel, and the pipeline makes replacing the files easy.
3. **No volume preview tone while dragging the slider.** The volume applies when you release the slider.
4. **On a 16:9 device with a notch** there is no spare width, so the world shifts right by the inset and can sit slightly under the palette edge (~40 px). Notched phones are almost always ≥ 19.5:9, where this doesn't happen.
5. **UI language is English only.** Localization was not requested yet (open question from Phase 1).
6. **Default font:** the menus use Godot's default font. A custom geometric font could be added (OFL) if you want a stronger identity.
