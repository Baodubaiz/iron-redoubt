class_name MenuBackdrop
extends Control
## Animated sci-fi backdrop for menu screens. Presentation only (no MatchController, no game data).
##   AMBIENT: metal floor, hex pattern, glowing circuit traces, drifting motes.
##   FULL:    + an illuminated track with drones walking it and a Pulse turret shooting them (main menu).
## Static layers are drawn once per resize; only a light dynamic layer redraws every frame.

enum Mode { AMBIENT, FULL }

const P = preload("res://ui/style/visual_palette.gd")
const PATH_N := [Vector2(1.04, 0.20), Vector2(0.80, 0.20), Vector2(0.80, 0.50), Vector2(0.95, 0.50),
	Vector2(0.95, 0.80), Vector2(0.66, 0.80), Vector2(0.66, 1.08)]
const TURRET_N := Vector2(0.875, 0.35)
const PYLONS_N := [Vector2(0.72, 0.36), Vector2(0.86, 0.65), Vector2(1.0, 0.95)]
const DRONE_SPEED := 62.0
const TURRET_RANGE := 250.0

var mode: int = Mode.AMBIENT
## Dims the left side so menu text stays readable (main menu).
var left_shade: bool = false

var _dyn: Control
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _traces: Array[PackedVector2Array] = []
var _motes: Array[Dictionary] = []
var _path := PackedVector2Array()
var _cum := PackedFloat32Array()
var _len := 0.0
var _drones: Array[Dictionary] = []
var _bolts: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _turret := Vector2.ZERO
var _aim := PI
var _cool := 0.5
var _recoil := 0.0
var _flash := 0.0
var _barrel := 1.0
var _tex_base: Texture2D
var _tex_turret: Texture2D
var _tex_drone: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	_dyn = Control.new()
	_dyn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dyn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dyn.draw.connect(_draw_dynamic)
	add_child(_dyn)
	if mode == Mode.FULL:
		_tex_base = load("res://assets/art/towers/base_hex.svg")
		_tex_turret = load("res://assets/art/towers/pulse_turret.svg")
		_tex_drone = load("res://assets/art/enemies/drone.svg")
	resized.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var s := size
	if s.x < 2.0 or s.y < 2.0:
		return
	_rng.seed = 7
	_traces.clear()
	for i in range(16):
		var p := Vector2(snappedf(_rng.randf() * s.x, 40.0), snappedf(_rng.randf() * s.y, 40.0))
		var line := PackedVector2Array([p])
		var horiz := _rng.randf() < 0.5
		for k in range(_rng.randi_range(2, 4)):
			var d := snappedf(_rng.randf_range(80.0, 240.0), 40.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
			p += Vector2(d, 0.0) if horiz else Vector2(0.0, d)
			line.append(p)
			horiz = not horiz
		_traces.append(line)
	_motes.clear()
	for i in range(42):
		_motes.append({"p": Vector2(_rng.randf() * s.x, _rng.randf() * s.y),
			"v": Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-18.0, -6.0)),
			"ph": _rng.randf() * TAU, "r": _rng.randf_range(1.0, 2.4),
			"c": [P.CYAN, P.BLUE, P.VIOLET][_rng.randi() % 3]})
	if mode == Mode.FULL:
		_path = PackedVector2Array()
		for n in PATH_N:
			_path.append(n * s)
		_cum = PackedFloat32Array([0.0])
		for i in range(1, _path.size()):
			_cum.append(_cum[i - 1] + _path[i - 1].distance_to(_path[i]))
		_len = _cum[_cum.size() - 1]
		_turret = TURRET_N * s
		if _drones.is_empty():
			for i in range(5):
				_drones.append({"d": -i * 150.0 + 520.0, "hp": 6, "flash": 0.0})
	queue_redraw()


func _pos_at(d: float) -> Array:
	d = clampf(d, 0.0, _len)
	for i in range(1, _cum.size()):
		if d <= _cum[i]:
			var a := _path[i - 1]
			var b := _path[i]
			var k := (d - _cum[i - 1]) / maxf(_cum[i] - _cum[i - 1], 0.001)
			return [a.lerp(b, k), (b - a).angle()]
	return [_path[_path.size() - 1], PI * 0.5]


# ---------------------------------------------------------------- static layer

func _draw() -> void:
	var s := size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color("111A36"), Color("0D1430"), P.BG_DEEP, P.BG]))
	# hex floor pattern
	var r := 34.0
	var hw := r * sqrt(3.0)
	var row := 0
	var y := -r
	while y < s.y + r:
		var x := -hw + (hw * 0.5 if row % 2 == 1 else 0.0)
		while x < s.x + hw:
			var pts := PackedVector2Array()
			for k in range(7):
				pts.append(Vector2(x, y) + Vector2.from_angle(PI / 6.0 + TAU * k / 6.0) * (r - 2.0))
			draw_polyline(pts, Color(P.BLUE, 0.045), 1.0)
			x += hw
		y += r * 1.5
		row += 1
	# circuit traces
	for t in _traces:
		draw_polyline(t, Color(P.CYAN, 0.07), 5.0)
		draw_polyline(t, Color(P.CYAN, 0.16), 1.5)
		draw_circle(t[0], 4.0, Color(P.CYAN, 0.25))
		draw_arc(t[t.size() - 1], 6.0, 0, TAU, 12, Color(P.CYAN, 0.3), 1.5)
	if mode == Mode.FULL and _path.size() > 1:
		for pn in PYLONS_N:
			_pylon(pn * s, 40.0)
		draw_polyline(_path, Color(P.CYAN, 0.10), 84.0)
		draw_polyline(_path, Color(P.CYAN, 0.55), 64.0)
		draw_polyline(_path, Color("121B33"), 60.0)
		draw_polyline(_path, Color("17233F"), 44.0)
		draw_polyline(_path, Color(P.CYAN, 0.12), 2.0)
		# chevrons
		for d in range(60, int(_len), 90):
			var pa: Array = _pos_at(float(d))
			var c: Vector2 = pa[0]
			var dir := Vector2.from_angle(pa[1])
			var n := Vector2(-dir.y, dir.x)
			draw_polyline(PackedVector2Array([c - dir * 6 + n * 9, c + dir * 4, c - dir * 6 - n * 9]), Color(P.CYAN, 0.22), 3.0)
	if left_shade:
		var w := s.x * 0.66
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, s.y), Vector2(0, s.y)]),
			PackedColorArray([Color(P.BG_DEEP, 0.85), Color(P.BG_DEEP, 0.0), Color(P.BG_DEEP, 0.0), Color(P.BG_DEEP, 0.85)]))
	# vignette
	draw_rect(Rect2(0, 0, s.x, 40), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(0, s.y - 40, s.x, 40), Color(0, 0, 0, 0.18))


func _pylon(c: Vector2, r: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in range(6):
		outer.append(c + Vector2.from_angle(TAU * k / 6.0) * r)
		inner.append(c + Vector2.from_angle(TAU * k / 6.0) * r * 0.62)
	var shadow := PackedVector2Array()
	for p in outer:
		shadow.append(p + Vector2(5, 9))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(outer, Color("1C2A47"))
	outer.append(outer[0])
	draw_polyline(outer, Color("3A4E73"), 3.0)
	draw_colored_polygon(inner, Color("111A30"))
	inner.append(inner[0])
	draw_polyline(inner, Color(P.VIOLET, 0.45), 2.0)


# ---------------------------------------------------------------- dynamic layer

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_t += delta
	var s := size
	for m in _motes:
		m["p"] += m["v"] * delta
		if m["p"].y < -10.0:
			m["p"] = Vector2(_rng.randf() * s.x, s.y + 10.0)
	if mode == Mode.FULL and _len > 0.0:
		_step_battle(delta)
	_dyn.queue_redraw()


func _step_battle(delta: float) -> void:
	for dr in _drones:
		dr["d"] += DRONE_SPEED * delta
		dr["flash"] = maxf(0.0, dr["flash"] - delta)
		if dr["d"] > _len + 40.0:
			_respawn(dr)
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	_flash = maxf(0.0, _flash - delta)
	_cool -= delta
	var target := -1
	var best := -1e9
	for i in range(_drones.size()):
		var dr: Dictionary = _drones[i]
		if dr["d"] < 0.0 or dr["d"] > _len:
			continue
		var p: Vector2 = _pos_at(dr["d"])[0]
		if p.distance_to(_turret) <= TURRET_RANGE and dr["d"] > best:
			best = dr["d"]
			target = i
	if target >= 0:
		var tp: Vector2 = _pos_at(_drones[target]["d"])[0]
		var want := (tp - _turret).angle()
		_aim = lerp_angle(_aim, want, minf(1.0, delta * 9.0))
		if _cool <= 0.0 and absf(angle_difference(_aim, want)) < 0.2:
			_cool = 0.32
			_barrel = -_barrel
			_recoil = 1.0
			_flash = 0.06
			var tip := _turret + Vector2(46.0, 9.6 * _barrel).rotated(_aim)
			_bolts.append({"p": tip, "t": target})
	else:
		_aim += delta * 0.4 * sin(_t * 0.7)
	var keep: Array[Dictionary] = []
	for b in _bolts:
		var dr: Dictionary = _drones[b["t"]]
		var tp: Vector2 = _pos_at(dr["d"])[0]
		var to := tp - (b["p"] as Vector2)
		var step := 950.0 * delta
		if to.length() <= step + 10.0 or dr["d"] < 0.0:
			if dr["d"] >= 0.0:
				_hit(dr, tp, to.normalized())
		else:
			b["p"] += to.normalized() * step
			b["dir"] = to.normalized()
			keep.append(b)
	_bolts = keep
	var ks: Array[Dictionary] = []
	for sp in _sparks:
		sp["life"] -= delta
		sp["p"] += sp["v"] * delta
		sp["v"] *= 0.9
		if sp["life"] > 0.0:
			ks.append(sp)
	_sparks = ks


func _hit(dr: Dictionary, at: Vector2, dir: Vector2) -> void:
	dr["hp"] -= 1
	dr["flash"] = 0.08
	for k in range(4):
		_sparks.append({"p": at, "v": (-dir).rotated(_rng.randf_range(-0.9, 0.9)) * _rng.randf_range(80, 200),
			"life": 0.25, "c": P.CYAN})
	if dr["hp"] <= 0:
		for k in range(14):
			_sparks.append({"p": at, "v": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60, 260),
				"life": _rng.randf_range(0.3, 0.6), "c": [P.ORANGE, P.RED, Color("C8CEDC")][k % 3]})
		_respawn(dr)


func _respawn(dr: Dictionary) -> void:
	var lowest := 0.0
	for o in _drones:
		lowest = minf(lowest, o["d"])
	dr["d"] = minf(-40.0, lowest - _rng.randf_range(110.0, 200.0))
	dr["hp"] = 6
	dr["flash"] = 0.0


func _draw_dynamic() -> void:
	var c := _dyn
	for m in _motes:
		var a := 0.25 + 0.25 * sin(_t * 2.0 + m["ph"])
		c.draw_circle(m["p"], m["r"] * 2.5, Color(m["c"], a * 0.25))
		c.draw_circle(m["p"], m["r"], Color(m["c"], a + 0.2))
	# energy running along circuit traces
	for i in range(_traces.size()):
		var t := _traces[i]
		var k := fmod(_t * 0.25 + i * 0.37, 1.0)
		var seg := int(k * (t.size() - 1))
		var f := k * (t.size() - 1) - seg
		var p := t[seg].lerp(t[mini(seg + 1, t.size() - 1)], f)
		c.draw_circle(p, 6.0, Color(P.CYAN, 0.12))
		c.draw_circle(p, 2.2, Color(P.CYAN, 0.7))
	if mode != Mode.FULL or _len <= 0.0:
		return
	# pulses running along the track edges
	for i in range(4):
		var d := fmod(_t * 160.0 + i * _len / 4.0, _len)
		var pa: Array = _pos_at(d)
		var dir := Vector2.from_angle(pa[1])
		var n := Vector2(-dir.y, dir.x) * 31.0
		for side in [-1.0, 1.0]:
			var p: Vector2 = pa[0] + n * side
			c.draw_line(p - dir * 26.0, p, Color(P.CYAN, 0.35), 3.0)
			c.draw_circle(p, 2.5, Color("C9F7FF"))
	# drones
	for dr in _drones:
		if dr["d"] < -30.0:
			continue
		var pa: Array = _pos_at(dr["d"])
		var bob := sin(_t * 14.0 + dr["d"] * 0.05) * 1.5
		c.draw_set_transform(pa[0], pa[1] + bob * 0.03, Vector2(0.9, 0.9))
		c.draw_texture(_tex_drone, Vector2(-32, -32), Color(4, 4, 4) if dr["flash"] > 0.0 else Color.WHITE)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# turret
	c.draw_circle(_turret, 70.0, Color(P.CYAN, 0.05))
	c.draw_set_transform(_turret, 0.0, Vector2(0.78, 0.78))
	c.draw_texture(_tex_base, Vector2(-64, -64))
	var back := Vector2(-5.0 * _recoil, 0.0).rotated(_aim)
	c.draw_set_transform(_turret + back, _aim, Vector2(0.78, 0.78))
	c.draw_texture(_tex_turret, Vector2(-64, -64))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _flash > 0.0:
		var tip := _turret + Vector2(50.0, 9.6 * _barrel).rotated(_aim)
		c.draw_circle(tip, 11.0, Color(P.CYAN, 0.35))
		c.draw_circle(tip, 5.0, Color(1, 1, 1, 0.9))
	for b in _bolts:
		var dir: Vector2 = b.get("dir", Vector2.from_angle(_aim))
		var p: Vector2 = b["p"]
		c.draw_line(p - dir * 22.0, p, Color(P.CYAN, 0.3), 7.0)
		c.draw_line(p - dir * 16.0, p, Color("E9FCFF"), 3.0)
	for sp in _sparks:
		var v: Vector2 = sp["v"]
		c.draw_line(sp["p"], sp["p"] - v * 0.03, Color(sp["c"], clampf(sp["life"] * 3.0, 0.0, 1.0)), 2.0)
