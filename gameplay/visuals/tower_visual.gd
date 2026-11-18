class_name TowerVisual
extends Node2D
## Presentation of one Tower (child node). Reads the tower's state, never writes it.
## Idle: breathing cores, gentle scan sweep when there is no target. Attack: recoil + muzzle flash
## on the tower's `fired` signal, continuous Lance beam (thickness follows beam_ramp()).
## Also: build drop-in, upgrade pop, evolution burst, selection ring + range, night light,
## EMP-disrupted look, synergy buff badges, tier pips.

const P = preload("res://ui/style/visual_palette.gd")

var tower: Tower
var look := TowerArt.Look.new()
var _t := 0.0
var _vis_aim := -PI * 0.5
var _spawn := 0.0 ## 1 -> 0 drop-in
var _pop := 0.0 ## upgrade pop 1 -> 0
var _evo_fx := 0.0 ## evolution burst 1 -> 0
var _last_fire_t := -10.0
var _was_evolved := false
var _light: Node2D


func _init(t: Tower) -> void:
	tower = t
	name = "Visual"


func _ready() -> void:
	look.def = tower.def
	_vis_aim = tower.aim_angle
	_spawn = 1.0
	_was_evolved = tower.evolved
	tower.fired.connect(_on_fired)
	# night light pool / selection range: drawn below every tower and enemy
	_light = Node2D.new()
	_light.z_index = -1
	_light.draw.connect(_draw_under)
	add_child(_light)


func on_upgraded() -> void:
	if tower.evolved and not _was_evolved:
		_evo_fx = 1.0
		_was_evolved = true
	else:
		_pop = 1.0


func _on_fired(_t2: Tower, _target: Enemy) -> void:
	look.recoil = 1.0
	look.flash = 0.07
	look.barrel = -look.barrel
	_last_fire_t = _t


func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	_t += delta
	_spawn = maxf(0.0, _spawn - delta / 0.35)
	_pop = maxf(0.0, _pop - delta / 0.3)
	_evo_fx = maxf(0.0, _evo_fx - delta / 0.7)
	look.t = _t
	look.recoil = maxf(0.0, look.recoil - delta * 7.0)
	look.flash = maxf(0.0, look.flash - delta)
	var sec := tower.secondary_branch()
	look.main_id = tower.branch_def().id if tower.branch >= 0 else &""
	look.main_tier = tower.tier
	look.sec_id = tower.def.branches[sec].id if sec >= 0 else &""
	look.sec_tier = tower.tiers[sec] if sec >= 0 else 0
	look.evolved = tower.evolved
	var rate := maxf(tower.eff_rate(), 0.05)
	look.charge = clampf((_t - _last_fire_t) * rate, 0.0, 1.0)
	if tower.beam_target() != null:
		look.charge = clampf(tower.beam_ramp() - 1.0, 0.0, 1.0) if tower.pf("ramp_max") > 1.0 else 1.0
	if look.main_id == &"rapid" and look.evolved:
		look.spin += delta * (14.0 if _t - _last_fire_t < 0.4 else 1.5)
	# aim: follow the gameplay aim; idle towers sweep slightly (visual only)
	var want := tower.aim_angle
	if tower.target == null and tower.beam_target() == null:
		want += sin(_t * 0.8 + tower.uid) * 0.35
	_vis_aim = lerp_angle(_vis_aim, want, minf(1.0, delta * 14.0))
	look.aim = _vis_aim
	var dim := tower.night_dimmed or tower.is_disrupted()
	look.tint = Color(0.62, 0.62, 0.7) if dim else Color.WHITE
	queue_redraw()
	_light.queue_redraw()


func _draw_under() -> void:
	var col := P.tower_color(tower.def.id)
	if tower.night_glow:
		var r := tower.attack_range
		TowerArt.glow(_light, Vector2.ZERO, r * 1.05, Color(1.0, 0.95, 0.75, 0.16))
		_light.draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(P.GREEN, 0.25), 1.5)
	if tower.selected:
		var rng := tower.eff_range()
		_light.draw_circle(Vector2.ZERO, rng, Color(col, 0.07))
		_light.draw_arc(Vector2.ZERO, rng, 0, TAU, 96, Color(col, 0.55), 2.0)
		for i in range(24): # rotating tick marks
			var a := TAU * i / 24.0 + _t * 0.15
			_light.draw_line(Vector2.from_angle(a) * (rng - 7.0), Vector2.from_angle(a) * rng, Color(col, 0.6), 2.0)


func _draw() -> void:
	var col := P.tower_color(tower.def.id)
	var r := tower.def.footprint_radius
	# beam (Lance) — under the turret so it leaves the muzzle
	var bt := tower.beam_target()
	if bt != null and is_instance_valid(bt) and bt.is_alive():
		_draw_beam(bt, col)
	# drop-in / pop scale
	var sc := 1.0 + 0.35 * _spawn * _spawn + 0.12 * sin(_pop * PI)
	if sc != 1.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	if _spawn > 0.0:
		modulate.a = 1.0 - _spawn * _spawn
	else:
		modulate.a = 1.0
	TowerArt.draw(self, Vector2.ZERO, look)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _spawn > 0.0 and _spawn < 0.6: # landing dust ring
		var k := 1.0 - _spawn / 0.6
		draw_arc(Vector2.ZERO, r + 22.0 * k, 0, TAU, 32, Color(col, 0.6 * (1.0 - k)), 2.0)
	if _pop > 0.0:
		draw_arc(Vector2.ZERO, r + 4.0 + 18.0 * (1.0 - _pop), 0, TAU, 32, Color(col, _pop), 3.0)
	if _evo_fx > 0.0:
		var k := 1.0 - _evo_fx
		TowerArt.glow(self, Vector2.ZERO, r * (1.5 + 2.5 * k), Color(col, 0.6 * _evo_fx))
		if not P.reduce_effects: # light column
			draw_rect(Rect2(-6.0 * _evo_fx, -260.0 * _evo_fx - 10.0, 12.0 * _evo_fx, 260.0 * _evo_fx), Color(1, 1, 1, 0.5 * _evo_fx))
		TowerArt._hex_ring(self, Vector2.ZERO, r + 50.0 * k, k * 2.0, Color(col, _evo_fx), 3.0)
	if tower.selected:
		TowerArt._hex_ring(self, Vector2.ZERO, r + 8.0, _t * 0.6, Color(1, 1, 1, 0.9), 2.0)
	if tower.is_disrupted(): # EMP: crackling red arcs
		for i in range(3):
			var a := _t * 11.0 + i * TAU / 3.0
			var p1 := Vector2.from_angle(a) * (r + 2.0)
			var p2 := Vector2.from_angle(a + 0.7) * (r + 2.0)
			draw_polyline(PackedVector2Array([p1, p1.lerp(p2, 0.5) + Vector2.from_angle(a * 3.0) * 6.0, p2]), P.RED, 2.0)
	elif tower.is_static(): # Dynamo static field: cyan sparks, range shrunk
		for i in range(3):
			var a := _t * 7.0 + i * TAU / 3.0
			draw_line(Vector2.from_angle(a) * (r + 1.0), Vector2.from_angle(a + 0.4) * (r + 7.0), P.CYAN, 2.0)
	elif tower.is_jammed(): # Chimera jam: orange static ring, slow blink
		var k := 0.5 + 0.5 * sin(_t * 9.0)
		draw_arc(Vector2.ZERO, r + 4.0, 0, TAU, 24, Color(P.ORANGE, 0.35 + 0.4 * k), 2.0)
		for i in range(4):
			var a := TAU * i / 4.0 + _t * 2.0
			draw_line(Vector2.from_angle(a) * (r + 1.0), Vector2.from_angle(a) * (r + 8.0), Color(P.ORANGE, 0.8), 2.0)
	_draw_badges(r, col)


func _draw_beam(bt: Enemy, col: Color) -> void:
	var from := TowerArt.muzzle(look, 0.0)
	var to := bt.position - tower.position
	var ramp := 0.0
	if tower.pf("ramp_max") > 1.0:
		ramp = (tower.beam_ramp() - 1.0) / maxf(tower.pf("ramp_max") - 1.0, 0.01)
	var w := 2.0 + 4.0 * ramp
	var flick := 0.85 + 0.15 * sin(_t * 40.0)
	if bool(tower.p("beam_pierce", false)):
		draw_line(from, to.normalized() * tower.eff_range(), Color(col, 0.25), w + 2.0)
	draw_line(from, to, Color(col, 0.28 * flick), w * 3.2)
	draw_line(from, to, Color(col.lightened(0.4), 0.9), w * 1.4)
	draw_line(from, to, Color(1, 1, 1, 0.95), maxf(1.0, w * 0.45))
	TowerArt.glow(self, to, 10.0 + 6.0 * ramp, Color(col, 0.85))
	TowerArt.glow(self, from, 8.0 + 4.0 * ramp, Color(1, 1, 1, 0.8))


## Tier pips (main = diamonds, secondary = squares, evolved = star) and synergy buff badges.
func _draw_badges(r: float, col: Color) -> void:
	var y := r + 7.0
	var n := look.main_tier
	for i in range(3):
		var c := Vector2(-9 + i * 9, y)
		var pts := PackedVector2Array([c + Vector2(0, -3.5), c + Vector2(3.5, 0), c + Vector2(0, 3.5), c + Vector2(-3.5, 0)])
		draw_colored_polygon(pts, col if i < n else Color(0, 0, 0, 0.45))
	if look.sec_tier > 0:
		for i in range(look.sec_tier):
			draw_rect(Rect2(-6 + i * 8, y + 5, 4, 4), Color(TowerArt._branch_color(tower.def.id, look.sec_id), 0.9))
	if tower.evolved:
		var c := Vector2(0, -r - 10)
		var pts := PackedVector2Array()
		for i in range(10):
			pts.append(c + Vector2.from_angle(-PI / 2 + TAU * i / 10.0) * (5.0 if i % 2 == 0 else 2.2))
		draw_colored_polygon(pts, P.ORANGE)
	# synergy buffs, shape-coded like before: damage = triangle, rate = open arc, range = ring
	var bx := -r + 3.0
	var by := -r - 6.0
	if tower.amp_damage > 0.0:
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 3, by + 3), Vector2(bx + 3, by + 3), Vector2(bx, by - 3)]), P.GREEN)
		bx += 9.0
	if tower.amp_rate > 0.0:
		draw_arc(Vector2(bx, by), 3.2, 0.5, TAU - 0.5, 8, P.GREEN, 1.8)
		bx += 9.0
	if tower.amp_range > 0.0:
		draw_arc(Vector2(bx, by), 3.2, 0, TAU, 10, P.GREEN, 1.2)
		draw_circle(Vector2(bx, by), 1.2, P.GREEN)
