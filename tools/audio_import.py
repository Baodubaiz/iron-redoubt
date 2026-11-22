"""Builds the game's audio from CC0 source packs (2026-11-22, user: replace the synthesized beeps).

Sources (all CC0 / public domain, see audio/LICENSES.md), unpacked outside the repo in SRC:
  kenney/sci-fi-sounds, kenney/impact-sounds, kenney/interface-sounds, kenney/music-jingles  (kenney.nl)
  music/singularity_calm_0.mp3, music/singularity_action_0.mp3, music/brute_force_loop.mp3   (vitalezzz, opengameart.org)

Each sound: leading silence trimmed, capped to a max length with a short fade, peak-normalized to -1 dBFS,
mono 44.1 kHz Ogg Vorbis -> audio/sfx/<id>.ogg. Music: loudness-normalized mono Ogg -> audio/music/<id>.ogg.
To change a sound, edit SFX below and run:  python tools/audio_import.py   (then Godot --import)
"""
import os, re, subprocess, sys

SRC = os.environ.get("AUDIO_SRC", r"C:\code\audio_src")
FF = os.environ.get("FFMPEG_DIR", r"C:\code\ffmpeg\ffmpeg-9.1-essentials_build\bin")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCIFI = "kenney/sci-fi-sounds/Audio/"
IMPACT = "kenney/impact-sounds/Audio/"
UI = "kenney/interface-sounds/Audio/"
HIT = "kenney/music-jingles/Audio/Hit jingles/"

# id: (source, max seconds). Jingle picks by final-chord analysis (major = win/clear, minor = defeat/boss).
SFX = {
    # tower shots
    "shot_pulse": (SCIFI + "laserSmall_000.ogg", 0.35),
    "shot_lance": (SCIFI + "laserLarge_000.ogg", 0.6),
    "shot_sniper": (SCIFI + "laserLarge_002.ogg", 0.7),
    "shot_nova": (SCIFI + "thrusterFire_001.ogg", 0.45),
    "shot_trap": (IMPACT + "impactMetal_light_001.ogg", 0.4),
    "shot_venom": (SCIFI + "slime_000.ogg", 0.45),
    "shot_spotter": (SCIFI + "laserRetro_001.ogg", 0.35),
    "shot_storm": (SCIFI + "forceField_000.ogg", 0.6),
    "shot_coil": (SCIFI + "forceField_003.ogg", 0.6),
    # combat
    "impact": (IMPACT + "impactMetal_light_000.ogg", 0.3),
    "enemy_death": (SCIFI + "explosionCrunch_000.ogg", 0.5),
    "explosion": (SCIFI + "lowFrequency_explosion_000.ogg", 1.0),
    "shield_hit": (SCIFI + "forceField_002.ogg", 0.35),
    "emp": (SCIFI + "computerNoise_002.ogg", 0.7),
    # building
    "build": (IMPACT + "impactMetal_heavy_000.ogg", 0.6),
    "sell": (UI + "drop_003.ogg", 0.6),
    "upgrade": (UI + "confirmation_001.ogg", 0.9),
    "evolve": (HIT + "jingles_HIT03.ogg", 2.0),
    # UI
    "ui_click": (UI + "click_001.ogg", 0.15),
    "ui_error": (UI + "error_004.ogg", 0.5),
    # waves / match
    "wave_start": (HIT + "jingles_HIT07.ogg", 2.0),
    "wave_clear": (HIT + "jingles_HIT13.ogg", 2.0),
    "boss": (HIT + "jingles_HIT10.ogg", 2.0),
    "boss_phase": (HIT + "jingles_HIT05.ogg", 2.0),
    "victory": (HIT + "jingles_HIT11.ogg", 3.0),
    "defeat": (HIT + "jingles_HIT15.ogg", 3.0),
}

MUSIC = {
    "calm": "music/singularity_calm_0.mp3", # menus + between waves
    "action": "music/singularity_action_0.mp3", # during waves (same length/tempo as calm: crossfaded in sync)
    "boss": "music/brute_force_loop.mp3", # boss waves
}


def ff(*args):
    return subprocess.run([os.path.join(FF, "ffmpeg.exe" if os.name == "nt" else "ffmpeg"), "-hide_banner", *args],
                          capture_output=True, text=True)


def peak_db(path, filt):
    r = ff("-i", path, "-af", filt + ",volumedetect", "-f", "null", "-")
    m = re.search(r"max_volume: (-?[\d.]+) dB", r.stderr)
    return float(m.group(1)) if m else 0.0


def build_sfx(sid, src, max_s):
    path = os.path.join(SRC, src)
    if not os.path.exists(path):
        sys.exit("missing source: " + path)
    fade = min(0.05, max_s * 0.2)
    trim = "silenceremove=start_periods=1:start_threshold=-50dB,atrim=0:%g,afade=t=out:st=%g:d=%g" % (
        max_s, max_s - fade, fade)
    gain = -1.0 - peak_db(path, trim)
    out = os.path.join(ROOT, "audio", "sfx", sid + ".ogg")
    r = ff("-y", "-i", path, "-af", trim + ",volume=%gdB" % gain, "-ac", "1", "-ar", "44100",
           "-c:a", "libvorbis", "-q:a", "5", out)
    if r.returncode != 0:
        sys.exit(r.stderr[-800:])


def build_music(mid, src):
    out = os.path.join(ROOT, "audio", "music", mid + ".ogg")
    # mono (2026-11-22): web builds keep each track fully decoded in browser memory (float32 per channel), so
    # stereo 3-minute tracks cost ~70 MB each; mono halves that and the file size, game BGM sounds the same.
    r = ff("-y", "-i", os.path.join(SRC, src), "-af", "loudnorm=I=-16:TP=-1.5:LRA=11", "-ar", "44100", "-ac", "1",
           "-c:a", "libvorbis", "-q:a", "3", out)
    if r.returncode != 0:
        sys.exit(r.stderr[-800:])


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "audio", "sfx"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "audio", "music"), exist_ok=True)
    for sid, (src, max_s) in SFX.items():
        build_sfx(sid, src, max_s)
    for mid, src in MUSIC.items():
        build_music(mid, src)
    print("ok: %d sounds, %d music tracks" % (len(SFX), len(MUSIC)))
