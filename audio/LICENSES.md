# Audio Asset Licenses

Every sound and music track in this folder comes from **CC0 (public domain)** sources: free for commercial
use, modification and redistribution, no attribution required (credited below anyway). Replaced the earlier
synthesized set on 2026-11-22.

| Files | Source | Author | License |
|---|---|---|---|
| `sfx/*.ogg` (tower shots, impacts, explosions, force field, EMP) | Sci-fi Sounds 1.0, https://kenney.nl/assets/sci-fi-sounds | Kenney | CC0 1.0 |
| `sfx/build.ogg`, `sfx/impact.ogg`, `sfx/shot_trap.ogg` | Impact Sounds, https://kenney.nl/assets/impact-sounds | Kenney | CC0 1.0 |
| `sfx/ui_*.ogg`, `sfx/sell.ogg`, `sfx/upgrade.ogg` | Interface Sounds, https://kenney.nl/assets/interface-sounds | Kenney | CC0 1.0 |
| `sfx/wave_*.ogg`, `sfx/boss*.ogg`, `sfx/victory.ogg`, `sfx/defeat.ogg`, `sfx/evolve.ogg` | Music Jingles ("Hit" set), https://kenney.nl/assets/music-jingles | Kenney | CC0 1.0 |
| `music/calm.ogg`, `music/action.ogg` | "Singularity" (calm + action versions), https://opengameart.org/content/singularity-0 | vitalezzz | CC0 |
| `music/boss.ogg` | "Brute Force" (loop version), https://opengameart.org/content/brute-force | vitalezzz | CC0 |

The exact source file for every sound id is listed in `tools/audio_import.py` (`SFX` / `MUSIC`). That script
trims, normalizes and converts the originals (kept outside the repo, in `C:\code\audio_src`) to Ogg Vorbis:

```bash
python tools/audio_import.py   # then: godot --headless --path . --import
```

Other assets (fonts, icons, sprites): see `docs/ASSET_SOURCES.md`.
