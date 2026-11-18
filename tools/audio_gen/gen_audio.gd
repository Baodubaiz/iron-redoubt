extends SceneTree
## Synthesizes all ORIGINAL game audio (SFX + ambient music loop) as 16-bit mono WAV files.
## No third-party samples are used; see audio/LICENSES.md.
##   godot --headless --path . -s res://tools/audio_gen/gen_audio.gd
## Then re-import: godot --headless --path . --import

const RATE := 22050

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 7
	DirAccess.make_dir_recursive_absolute("res://audio/sfx")
	DirAccess.make_dir_recursive_absolute("res://audio/music")
	# Reforged (Stage E): sci-fi set. FM "metal", filtered noise "mechanics", glides for energy weapons.
	_sfx("ui_click", _mix(_tone(1650, 0.028, 0.32, "sine", 1500, 70.0), _noise(0.012, 0.12, 200.0, 0.2)))
	_sfx("ui_error", _concat([_tone(240, 0.07, 0.3, "square_soft", 200, 20.0), _tone(190, 0.1, 0.3, "square_soft", 160, 18.0)]))
	_sfx("build", _mix(_mix(_noise(0.09, 0.45, 32.0, 0.75), _tone(120, 0.12, 0.45, "sine", 70, 22.0)),
		_tone(420, 0.16, 0.22, "tri", 940, 14.0, 0.02)))
	_sfx("upgrade", _mix(_concat([_tone(660, 0.05, 0.3, "tri"), _tone(880, 0.05, 0.3, "tri"), _tone(1320, 0.16, 0.3, "tri", 1320, 14.0)]),
		_fm(2640, 0.26, 0.06, 1.5, 2.0, 10.0)))
	_sfx("evolve", _mix(_mix(_tone(260, 0.55, 0.22, "saw_soft", 1500, 3.0, 0.03), _fm(1046, 0.7, 0.18, 2.0, 3.0, 4.0)),
		_concat([_silence(0.3), _tone(2093, 0.4, 0.07, "sine", 2093, 6.0)])))
	_sfx("sell", _mix(_tone(900, 0.16, 0.28, "tri", 380, 12.0), _concat([_silence(0.05), _fm(2200, 0.18, 0.12, 1.41, 2.5, 22.0)])))
	_sfx("shot_pulse", _mix(_tone(2300, 0.065, 0.2, "square_soft", 850, 45.0), _tone(1150, 0.05, 0.12, "sine", 520, 50.0)))
	_sfx("shot_nova", _mix(_mix(_tone(150, 0.26, 0.55, "sine", 48, 12.0), _noise(0.14, 0.3, 22.0, 0.6)),
		_tone(600, 0.06, 0.1, "saw_soft", 200, 40.0)))
	_sfx("shot_lance", _mix(_tone(2500, 0.14, 0.18, "saw_soft", 1500, 16.0), _fm(1200, 0.14, 0.12, 3.01, 4.0, 18.0)))
	_sfx("shot_trap", _mix(_tone(260, 0.12, 0.35, "square_soft", 120, 18.0), _noise(0.08, 0.2, 30.0, 0.4)))
	_sfx("shot_spotter", _tone(1250, 0.07, 0.14, "sine", 1700, 30.0))
	_sfx("shot_venom", _mix(_noise(0.12, 0.28, 18.0, 0.75), _tone(520, 0.1, 0.12, "sine", 300, 22.0)))
	_sfx("shot_sniper", _mix(_tone(1800, 0.09, 0.3, "saw_soft", 300, 28.0), _noise(0.12, 0.3, 26.0, 0.2)))
	_sfx("shot_storm", _mix(_fm(900, 0.18, 0.2, 2.7, 6.0, 14.0), _noise(0.16, 0.22, 16.0, 0.1)))
	_sfx("impact", _mix(_fm(1250, 0.07, 0.22, 1.41, 3.0, 55.0), _noise(0.04, 0.18, 80.0, 0.3)))
	_sfx("explosion", _mix(_tone(95, 0.45, 0.6, "sine", 38, 8.0), _noise(0.4, 0.42, 9.0, 0.86)))
	_sfx("shield_hit", _fm(1850, 0.12, 0.2, 2.71, 2.5, 26.0))
	_sfx("enemy_death", _mix(_mix(_noise(0.16, 0.35, 22.0, 0.5), _tone(320, 0.16, 0.25, "square_soft", 75, 16.0)),
		_fm(700, 0.1, 0.1, 1.41, 4.0, 30.0)))
	_sfx("wave_start", _tremolo(_mix(_tone(220, 0.6, 0.28, "saw_soft", 225, 3.0, 0.05), _tone(330, 0.6, 0.2, "saw_soft", 336, 3.0, 0.05)), 7.0))
	_sfx("wave_clear", _mix(_concat([_tone(880, 0.09, 0.28, "tri"), _tone(1320, 0.3, 0.28, "tri", 1320, 8.0)]), _fm(2640, 0.4, 0.05, 2.0, 1.5, 7.0)))
	_sfx("boss", _tremolo(_mix(_mix(_tone(70, 1.5, 0.45, "tri", 64, 1.4, 0.2), _tone(140, 1.5, 0.22, "saw_soft", 132, 1.6, 0.2)),
		_fm(420, 1.2, 0.08, 1.5, 2.0, 2.0)), 5.0))
	_sfx("boss_phase", _mix(_tone(80, 0.8, 0.4, "saw_soft", 170, 3.0, 0.08), _noise(0.7, 0.2, 4.0, 0.8)))
	_sfx("emp", _mix(_tone(1300, 0.55, 0.24, "saw_soft", 90, 4.5), _noise(0.55, 0.2, 5.0, 0.1)))
	_sfx("victory", _mix(_concat([_tone(523, 0.12, 0.32, "tri"), _tone(659, 0.12, 0.32, "tri"), _tone(784, 0.12, 0.32, "tri"),
		_tone(1046, 0.6, 0.32, "tri", 1046, 3.5)]), _concat([_silence(0.36), _fm(2093, 0.6, 0.08, 2.0, 2.0, 4.0)])))
	_sfx("defeat", _concat([_tone(392, 0.22, 0.32, "saw_soft", 380, 6.0), _tone(311, 0.22, 0.32, "saw_soft", 300, 6.0),
		_tone(262, 0.7, 0.32, "saw_soft", 200, 2.5)]))
	_music()
	print("gen_audio: done")
	quit(0)


# ---------------------------------------------------------------- primitives (float buffers)

func _osc(kind: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match kind:
		"sine":
			return sin(TAU * p)
		"tri":
			return 4.0 * absf(p - 0.5) - 1.0
		"square_soft":
			return clampf(sin(TAU * p) * 3.0, -1.0, 1.0) * 0.7
		"saw_soft":
			return (2.0 * p - 1.0) * 0.6 + sin(TAU * p) * 0.3
	return sin(TAU * p)


## Tone with exponential decay `decay` (1/s), linear pitch glide f0->f1, optional attack.
func _tone(f0: float, dur: float, amp: float, kind: String = "sine", f1: float = -1.0, decay: float = 10.0,
		attack: float = 0.005) -> PackedFloat32Array:
	if f1 < 0.0:
		f1 = f0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		phase += f / RATE
		var env := exp(-decay * t) * minf(1.0, t / attack) * minf(1.0, (dur - t) / 0.01)
		out[i] = _osc(kind, phase) * amp * env
	return out


func _noise(dur: float, amp: float, decay: float, smooth: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in range(n):
		var t := float(i) / RATE
		prev = lerpf(_rng.randf_range(-1.0, 1.0), prev, smooth) # one-pole low-pass
		out[i] = prev * amp * exp(-decay * t) * minf(1.0, (dur - t) / 0.01)
	return out


## FM tone (metallic / bell timbres): carrier glides f0 -> f1, modulator index decays.
func _fm(f0: float, dur: float, amp: float, ratio: float, index: float, decay: float, f1: float = -1.0) -> PackedFloat32Array:
	if f1 < 0.0:
		f1 = f0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var pc := 0.0
	var pm := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		pc += f / RATE
		pm += f * ratio / RATE
		var env := exp(-decay * t) * minf(1.0, t / 0.003) * minf(1.0, (dur - t) / 0.01)
		out[i] = sin(TAU * pc + index * exp(-decay * 0.5 * t) * sin(TAU * pm)) * amp * env
	return out


func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return out


func _tremolo(a: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	for i in range(a.size()):
		a[i] *= 0.75 + 0.25 * sin(TAU * hz * i / RATE)
	return a


func _sfx(name: String, buf: PackedFloat32Array) -> void:
	_write(buf, "res://audio/sfx/%s.wav" % name)


func _write(buf: PackedFloat32Array, path: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in range(buf.size()):
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	var err := w.save_to_wav(path)
	if err != OK:
		push_error("save failed %s" % path)


# ---------------------------------------------------------------- ambient music (32 s seamless loop)

func _music() -> void:
	var bpm := 60.0
	var beat := 60.0 / bpm
	var bars := 8 # 4 beats each -> 32 s
	var n := int(bars * 4 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# A minor - F - C - G (two bars each), soft pads + sparse pluck arpeggio
	var chords := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [130.81, 196.0, 261.63], [196.0, 246.94, 293.66]]
	for bar in range(bars):
		var chord: Array = chords[(bar / 2) % 4]
		var start := int(bar * 4 * beat * RATE)
		var length := int(4 * beat * RATE)
		for f in chord:
			for i in range(length):
				var t := float(i) / RATE
				var env := minf(1.0, t / 1.2) * minf(1.0, (4 * beat - t) / 1.2)
				var v := (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t + 0.4)) * 0.045 * env
				out[(start + i) % n] += v
		# pluck arpeggio on beats 1..4 (offbeat 8ths every other bar for variation)
		for k in range(4):
			var note: float = chord[k % 3] * 2.0
			var s0 := start + int(k * beat * RATE) + (int(0.5 * beat * RATE) if bar % 2 == 1 else 0)
			var pl := _tone(note, 0.9, 0.05, "tri", note, 5.0, 0.004)
			for i in range(pl.size()):
				out[(s0 + i) % n] += pl[i]
	# gentle low drone for cohesion
	for i in range(n):
		out[i] += sin(TAU * 55.0 * i / RATE) * 0.02
	_write(out, "res://audio/music/ambient_loop.wav")
