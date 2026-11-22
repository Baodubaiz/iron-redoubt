extends Node
## Autoload "Audio": pooled SFX playback with a limiter, and state-driven music (calm / action / boss).
## Assets: CC0 packs built by tools/audio_import.py (see audio/LICENSES.md), 2026-11-22.
##
## Music (2026-11-22, user: "fix every audio problem"): calm in menus and between waves, action during a wave,
## boss during a boss wave. calm and action are two versions of the same track (same length and tempo), so a
## switch between them starts the new one at the old one's position and crossfades: it sounds like the band
## picking up, not a new song. Only one track decodes at a time except during the 1.5 s crossfade.

const SFX_DIR := "res://audio/sfx/"
const MUSIC := {
	&"calm": "res://audio/music/calm.ogg",
	&"action": "res://audio/music/action.ogg",
	&"boss": "res://audio/music/boss.ogg",
}
const MUSIC_DB := -7.0
const FADE := 1.5
const SILENT_DB := -60.0
const POOL := 12
## Per-sound base volume (dB). Sources are peak-normalized to -1 dBFS; frequent sounds sit lower.
const GAIN := {
	&"shot_pulse": -15.0, &"shot_lance": -12.0, &"shot_nova": -12.0, &"shot_trap": -13.0, &"shot_venom": -13.0,
	&"shot_spotter": -15.0, &"shot_sniper": -10.0, &"shot_storm": -12.0, &"shot_coil": -13.0, &"impact": -16.0,
	&"enemy_death": -14.0, &"explosion": -9.0, &"shield_hit": -16.0, &"emp": -8.0,
	&"build": -6.0, &"sell": -7.0, &"upgrade": -6.0, &"evolve": -4.0, &"ui_click": -9.0, &"ui_error": -8.0,
	&"wave_start": -6.0, &"wave_clear": -6.0, &"boss": -3.0, &"boss_phase": -4.0, &"victory": -3.0, &"defeat": -3.0,
}

var limiter := SfxLimiter.new()
var music_state: StringName = &""
var _streams: Dictionary = {}
var _lengths: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: Dictionary = {} ## state -> AudioStreamPlayer
var _fades: Dictionary = {} ## state -> Tween
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.ensure_bus("Music")
	Settings.ensure_bus("SFX")
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	var dir := DirAccess.open(SFX_DIR)
	if dir != null:
		for f in dir.get_files():
			var base := f.trim_suffix(".import").trim_suffix(".remap")
			var id := StringName(base.get_basename())
			if (base.ends_with(".ogg") or base.ends_with(".wav")) and not _streams.has(id):
				var s: AudioStream = load(SFX_DIR + base)
				if s != null:
					_streams[id] = s
					_lengths[id] = int(s.get_length() * 1000.0)
	for state: StringName in MUSIC:
		var mp := AudioStreamPlayer.new()
		mp.bus = &"Music"
		mp.volume_db = SILENT_DB
		add_child(mp)
		var s := load(MUSIC[state]) as AudioStream
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		mp.stream = s
		_music[state] = mp
	Settings.apply()
	play_music()


func play(id: StringName, pitch_variation: float = 0.04) -> void:
	if not Settings.data.sfx_on or not _streams.has(id):
		return
	if not limiter.try_start(id, Time.get_ticks_msec(), int(_lengths.get(id, 100))):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.volume_db = float(GAIN.get(id, 0.0))
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()


## Menus call this (calm); matches switch with set_music().
func play_music() -> void:
	set_music(&"calm")


func set_music(state: StringName) -> void:
	if state == music_state or not _music.has(state):
		return
	var old: AudioStreamPlayer = _music.get(music_state)
	var new: AudioStreamPlayer = _music[state]
	var from := 0.0
	# calm <-> action are the same track: pick up where the other left off
	if old != null and old.playing and state != &"boss" and music_state != &"boss":
		from = fmod(old.get_playback_position(), maxf(new.stream.get_length(), 0.01))
	music_state = state
	if new.stream == null:
		return
	if not new.playing:
		new.play(from)
	_fade(state, new, MUSIC_DB, false)
	if old != null:
		_fade(StringName(_key_of(old)), old, SILENT_DB, true)


func _fade(state: StringName, p: AudioStreamPlayer, to_db: float, stop_after: bool) -> void:
	if _fades.has(state) and (_fades[state] as Tween).is_valid():
		(_fades[state] as Tween).kill()
	if not is_inside_tree():
		p.volume_db = to_db
		if stop_after:
			p.stop()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, FADE)
	if stop_after:
		tw.tween_callback(func() -> void:
			if _music.get(music_state) != p:
				p.stop())
	_fades[state] = tw


func _key_of(p: AudioStreamPlayer) -> String:
	for k in _music:
		if _music[k] == p:
			return String(k)
	return ""
