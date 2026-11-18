extends Node
## Autoload "Audio": pooled SFX playback with a limiter, and the looping ambient music.
## All assets are original (see audio/LICENSES.md).

const SFX_DIR := "res://audio/sfx/"
const MUSIC := "res://audio/music/ambient_loop.wav"
const POOL := 12
## Per-sound base volume (dB) so frequent sounds stay subtle.
const GAIN := {
	&"shot_pulse": -11.0, &"shot_lance": -8.0, &"shot_nova": -8.0, &"shot_trap": -9.0, &"shot_venom": -10.0, &"shot_spotter": -11.0, &"shot_sniper": -6.0, &"shot_storm": -9.0, &"impact": -12.0,
	&"enemy_death": -9.0, &"ui_click": -6.0, &"ui_error": -6.0, &"explosion": -7.0, &"shield_hit": -13.0,
	&"wave_clear": -4.0, &"boss_phase": -3.0,
}

var limiter := SfxLimiter.new()
var _streams: Dictionary = {}
var _lengths: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
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
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	var dir := DirAccess.open(SFX_DIR)
	if dir != null:
		for f in dir.get_files():
			var base := f.trim_suffix(".import")
			if base.ends_with(".wav") and not _streams.has(StringName(base.get_basename())):
				var s: AudioStream = load(SFX_DIR + base)
				if s != null:
					_streams[StringName(base.get_basename())] = s
					_lengths[StringName(base.get_basename())] = int(s.get_length() * 1000.0)
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


func play_music() -> void:
	if _music.playing:
		return
	var s := load(MUSIC) as AudioStreamWAV
	if s == null:
		return
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2 # 16-bit mono frames
	_music.stream = s
	_music.volume_db = -4.0
	_music.play()
