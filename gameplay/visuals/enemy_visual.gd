class_name EnemyVisual
extends Node2D
## Presentation of one Enemy (child node). Reads the enemy's state, never writes it.
## Mechanical bodies (SVG) facing the movement direction + procedural animation per type:
## walking legs (Drone, Swarmling), stomping feet (Brute), exhaust (Dart), hover + shadow (Glider),
## shield dome (Aegis), rotating cross + heal pulse (Mender), stealth shimmer (Phantom),
## per-boss presentation: Monolith (orbiting armour / antenna / exposed core), Warden (shell, sprint
## exhaust), Carrier (deck lights, cloak), Chimera (armour vs shield plating), Colossus (bulwark,
## rift blink, overdrive aura) + every telegraph drawn with its real radius / timing.
## Feedback: hit flash, armour sparks, shield ripples, HP bar with damage lag, status icons.

const P = preload("res://ui/style/visual_palette.gd")
const ICE := Color("8FD3FF")
const BODY := {
	&"drone": "drone_body", &"swarmling": "swarmling", &"dart": "dart", &"brute": "brute",
	&"plated": "plated", &"aegis": "aegis", &"glider": "glider", &"phantom": "phantom",
	&"mender": "mender", &"monolith": "monolith", &"monolith_shard": "shard",
	&"warden": "warden", &"carrier": "carrier", &"chimera": "chimera", &"colossus": "colossus",
	&"dynamo": "dynamo", &"leviathan": "leviathan", &"refractor": "refractor", &"refractor_decoy": "refractor",
	&"escort": "escort", &"sludge": "sludge", &"shade": "shade", &"sprinter": "sprinter", &"jammer": "jammer",
	&"prismling": "prismling", &"diver": "diver",
	&"disruptor": "disruptor", &"static_crawler": "static_crawler", &"wraith": "wraith",
	&"vanguard": "vanguard", &"rallier": "rallier", &"cloaker": "cloaker", &"mender_elite": "mender_elite",
	&"hopper": "hopper", &"foreman": "foreman",
}
const KIT_COLOR := {
	&"monolith": Color("FF5368"), &"warden": Color("FFB84D"), &"carrier": Color("7FA8FF"),
	&"chimera": Color("C77DFF"), &"colossus": Color("FF5368"), &"dynamo": Color("38D9F5"),
	&"leviathan": Color("4D8CFF"), &"refractor": Color("A66BFF"), &"foreman": Color("FFCC33"),
}
const PRISM_COLOR := {0: Color("E6EBF5"), 1: Color("FFAA45"), 2: Color("A66BFF")} ## kinetic / explosive / energy
const LEG := Color("5A5F6E")

static var _tex := {}
## 2026-11-19 perf: shadows (under) and HP bars + status icons (over) of ALL enemies are drawn by two shared
## layers (MapView), so they batch into a few draw calls instead of 2-3 per enemy. Off = each enemy draws its
## own (tests / tools without a MapView).
static var shared_layers := false
## Unit circle (16 points), scaled per ellipse instead of 16 sin/cos per shadow per frame.
## Alive enemies on the map (set by MapView each frame). In a big crowd (80+) the procedural animation (legs,
## facing, shimmer) is re-drawn at 30 Hz, staggered per enemy; movement stays smooth (the node itself moves every
## frame). Bosses, hits and telegraphs always redraw. 2026-11-19 perf: re-building ~180 enemy drawings every
## frame cost ~9 ms on desktop, the GPU part ~1 ms.
static var crowd := 0
static var WEB := OS.has_feature("web")
static var _unit16 := PackedVector2Array()
static var _unit12 := PackedVector2Array()

var e: Enemy
var _t := 0.0
var _face := 0.0
var _walk := 0.0
var _last_pos := Vector2.ZERO
var _hp_lag := 0.0
var _last_hp := 0.0
var _last_shield := 0.0
var _shield_hit := 0.0
var _shield_break := 0.0
var _reveal_fx := 0.0
var _was_revealed := false
var _phase := 1
var _phase_fx := 0.0
var _sparks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


static func body_tex(id: StringName) -> Texture2D:
	var name: String = BODY.get(id, "drone_body")
	if not _tex.has(name):
		_tex[name] = load("res://assets/art/enemies/%s.svg" % name)
	return _tex[name]


func _init(enemy: Enemy) -> void:
	e = enemy
	name = "Visual"


func _ready() -> void:
	_rng.seed = e.uid
	_last_pos = e.position
	_hp_lag = e.hp
	_last_hp = e.hp
	_last_shield = e.shield
	_phase = e.boss_phase
	_face = _initial_facing()
	_t = _rng.randf() * 10.0
	z_index = 3 if e.is_flying() else (2 if e.is_boss() else 1)


func _initial_facing() -> float:
	if e.route != null and e.route.points.size() >= 2:
		return (e.route.points[1] - e.route.points[0]).angle()
	return 0.0


func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	_t += delta
	var moved := e.position - _last_pos
	_last_pos = e.position
	if moved.length_squared() > 0.0004:
		_face = lerp_angle(_face, moved.angle(), minf(1.0, delta * 12.0))
	var spd := moved.length() / maxf(delta, 0.0001)
	_walk += delta * (3.0 + spd * 0.16)
	# damage feedback by polling (no gameplay hooks needed)
	if e.hp < _last_hp - 0.01:
		var armored := e.def.armor >= 4.0
		for i in range(2 if armored else 1):
			_spark(Vector2.from_angle(_rng.randf() * TAU) * e.def.radius * 0.8,
				Color("E6EBF5") if armored else P.ORANGE)
	_last_hp = e.hp
	if e.hp < _hp_lag:
		_hp_lag = move_toward(_hp_lag, e.hp, e.max_hp * delta * 0.9)
	else:
		_hp_lag = e.hp
	if e.shield < _last_shield - 0.01:
		if _shield_hit <= 0.0:
			_sfx(&"shield_hit")
		_shield_hit = 1.0
		if e.shield <= 0.0:
			_shield_break = 1.0
	_last_shield = e.shield
	_shield_hit = maxf(0.0, _shield_hit - delta * 4.0)
	_shield_break = maxf(0.0, _shield_break - delta * 2.5)
	var rev := e.is_revealed()
	if e.is_stealthy() and rev and not _was_revealed:
		_reveal_fx = 1.0
	_was_revealed = rev
	_reveal_fx = maxf(0.0, _reveal_fx - delta * 4.0)
	if e.boss_phase != _phase:
		_phase = e.boss_phase
		_phase_fx = 1.0
	_phase_fx = maxf(0.0, _phase_fx - delta * 1.5)
	if not _sparks.is_empty():
		for i in range(_sparks.size() - 1, -1, -1):
			var sp: Dictionary = _sparks[i]
			sp["life"] -= delta
			sp["p"] += sp["v"] * delta
			if sp["life"] <= 0.0:
				_sparks.remove_at(i)
	if _needs_redraw():
		queue_redraw()


func _needs_redraw() -> bool:
	# smoothness first: 60 Hz up to 80 enemies, then 30 Hz. Web (2026-11-22 perf, GDScript ~3x slower in the
	# browser): 30 Hz from 30 enemies, 20 Hz from 100. Movement itself stays per-frame either way.
	var every := 1 if crowd < 80 else 2
	if WEB:
		every = 1 if crowd < 30 else (2 if crowd < 100 else 3)
	# hit flashes / sparks last ~0.1-0.2 s: still visible at 20 Hz, so only bosses and skill telegraphs
	# (timing the player reads) always redraw
	if every == 1 or e.def.is_boss or e.telegraph_kind != 0 or _phase_fx > 0.0:
		return true
	return (Engine.get_process_frames() + e.uid) % every == 0


func _sfx(id: StringName) -> void:
	var tree := get_tree()
	if tree != null and tree.root.has_node("Audio"):
		tree.root.get_node("Audio").play(id)


func _spark(at: Vector2, col: Color) -> void:
	if _sparks.size() > (4 if P.reduce_effects else 10):
		return
	_sparks.append({"p": at, "v": at.normalized() * _rng.randf_range(60.0, 140.0), "life": 0.18, "c": col})


func _draw() -> void:
	var d := e.def
	var id := d.id
	var r := d.radius
	var boss := d.is_boss
	var s := r * (1.75 / 30.0 if boss else 1.3 / 20.0)
	var hidden := e.is_stealthy() and not e.is_revealed()
	modulate.a = 0.28 if hidden else (0.35 if e.submerge_timer > 0.0 else 1.0)
	var flying := e.is_flying()
	var bob := (-6.0 - 2.5 * sin(_t * 3.2)) if flying else 0.0
	if not shared_layers:
		draw_shadow(self, Vector2.ZERO, 1.0)
	if boss:
		_boss_under(r)
	elif e.telegraph_kind != 0: # regular enemies with data skills
		_kit_under(r, d.color)
	var tint := Color.WHITE
	if e.is_frozen():
		tint = Color(0.65, 0.88, 1.25)
	elif e.is_burning():
		tint = Color(1.15, 0.85 + 0.1 * sin(_t * 20.0), 0.7)
	elif e.is_chilled():
		tint = Color(0.82, 0.92, 1.12)
	elif e.is_poisoned(): # toxic green, matches Venom's own color, distinct from the generic hit flash
		tint = Color(0.72, 1.15 + 0.08 * sin(_t * 10.0), 0.72)
	if e.hit_flash() > 0.0:
		tint = Color(3.0, 3.0, 3.0)
	draw_set_transform(Vector2(0, bob), _face, Vector2(s, s))
	_parts_under(id)
	if hidden: # stealth shimmer: two offset ghost copies
		for k: float in [-1.0, 1.0]:
			draw_set_transform(Vector2(k * 2.0 * sin(_t * 9.0), bob), _face, Vector2(s, s))
			draw_texture_rect(body_tex(id), Rect2(-32, -32, 64, 64), false, Color(0.75, 0.6, 1.0, 0.5))
		draw_set_transform(Vector2(0, bob), _face, Vector2(s, s))
	draw_texture_rect(body_tex(id), Rect2(-32, -32, 64, 64), false, tint)
	_parts_over(id)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if boss:
		_boss_over(r)
	if id == &"aegis" or (boss and e.shield_max > 0.0):
		_shield_dome(r)
	if e.overshield > 0.0:
		_overshield(r)
	if not boss and e.immune_timer > 0.0 and e.immune_type >= 0: # Prismling: resisted type colour
		var pc: Color = PRISM_COLOR.get(e.immune_type, Color.WHITE)
		draw_arc(Vector2.ZERO, r * 1.4, 0, TAU, 6, Color(pc, 0.9), 2.0)
	if not boss and e.sprint_timer > 0.0: # Sprinter burst
		var back := Vector2.from_angle(_face + PI)
		draw_line(back * r, back * (r + 14.0), Color(P.ORANGE, 0.8), 3.0)
	if e.haste_timer > 0.0 and not boss: # Colossus overdrive: speed streaks
		var back := Vector2.from_angle(_face + PI)
		var side := back.orthogonal()
		for k: float in [-0.5, 0.0, 0.5]:
			var o := side * r * k + back * r
			draw_line(o, o + back * (10.0 + 6.0 * sin(_t * 20.0 + k * 4.0)), Color(P.RED, 0.7), 2.0)
	if (id == &"mender" or id == &"mender_elite") and e.heal_pulse_fx > 0.0:
		var k := 1.0 - e.heal_pulse_fx / 0.4
		draw_arc(Vector2.ZERO, d.heal_radius * k, 0, TAU, 40, Color(P.GREEN, 0.7 * (1.0 - k)), 3.0)
		for i in range(3):
			var p := Vector2(-12 + i * 12, -r - 8.0 - 18.0 * k)
			draw_line(p - Vector2(3, 0), p + Vector2(3, 0), Color(P.GREEN, 1.0 - k), 2.0)
			draw_line(p - Vector2(0, 3), p + Vector2(0, 3), Color(P.GREEN, 1.0 - k), 2.0)
	if _reveal_fx > 0.0: # "signal lock" glitch when a Phantom is revealed
		for i in range(3):
			var y := -r + _rng.randf() * r * 2.0
			draw_line(Vector2(-r * 1.4, y), Vector2(r * 1.4, y), Color(P.VIOLET, _reveal_fx * 0.8), 2.0)
		draw_arc(Vector2.ZERO, r * (1.3 + 0.6 * (1.0 - _reveal_fx)), 0, TAU, 24, Color(P.VIOLET, _reveal_fx), 2.0)
	if e.is_frozen():
		var hexa := PackedVector2Array()
		for k in range(7):
			hexa.append(Vector2.from_angle(TAU * k / 6.0 + 0.3) * r * 1.35)
		draw_colored_polygon(hexa.slice(0, 6), Color(ICE, 0.22))
		draw_polyline(hexa, Color(ICE, 0.8), 2.0)
	if e.stun_timer > 0.0 or e.stagger_timer > 0.0:
		for i in range(3):
			var a := _t * 6.0 + TAU * i / 3.0
			_star(Vector2(cos(a) * r * 0.9, -r - 6.0 + sin(a) * 3.0), 3.0, Color("FFE07A"))
	for sp in _sparks:
		var v: Vector2 = sp["v"]
		draw_line(sp["p"], sp["p"] - v * 0.05, Color(sp["c"], sp["life"] / 0.18), 2.0)
	if not shared_layers:
		draw_overlay(self, Vector2.ZERO)


# ------------------------------------------------------------------ per-type parts (body space)

func _parts_under(id: StringName) -> void:
	match id:
		&"drone":
			for i in range(4):
				var side := -1.0 if i < 2 else 1.0
				var fx := 8.0 if i % 2 == 0 else -8.0
				var ph := _walk * 2.0 + (0.0 if (i % 2 == 0) == (side < 0.0) else PI)
				var foot := Vector2(fx + sin(ph) * 5.0, side * 22.0)
				draw_line(Vector2(fx * 0.6, side * 8.0), foot, LEG, 4.0)
				draw_circle(foot, 2.5, Color("3A3F4E"))
		&"hopper": # spring legs: tucked while it stands, stretched mid-hop
			var hp := e.hop_phase()
			var reach := 14.0 if hp < 0.0 else 14.0 + 10.0 * sin(hp * PI)
			for i in range(4):
				var side := -1.0 if i < 2 else 1.0
				var fx := 9.0 if i % 2 == 0 else -9.0
				var knee := Vector2(fx * 0.6, side * 10.0)
				var foot := Vector2(fx + (4.0 if hp >= 0.0 else 0.0) * (-1.0 if fx > 0.0 else 1.0), side * (reach + 4.0))
				draw_line(Vector2(fx * 0.4, side * 6.0), knee, LEG, 3.5)
				draw_line(knee, foot, LEG, 3.0)
				draw_circle(foot, 2.2, Color("3A2E24"))
		&"swarmling":
			for i in range(6):
				var side := -1.0 if i < 3 else 1.0
				var fx := -7.0 + (i % 3) * 7.0
				var ph := _walk * 3.0 + i * 1.7
				draw_line(Vector2(fx, side * 6.0), Vector2(fx + sin(ph) * 5.0, side * 17.0), LEG, 3.0)
		&"brute":
			for side: float in [-1.0, 1.0]:
				var ph := _walk * 1.2 + (0.0 if side < 0.0 else PI)
				var foot := Vector2(sin(ph) * 9.0, side * 26.0)
				draw_rect(Rect2(foot - Vector2(9, 6), Vector2(18, 12)), Color("2A2E3A"))
				draw_rect(Rect2(foot - Vector2(9, 6), Vector2(18, 12)), Color("8A90A4"), false, 1.5)
		&"dart":
			var f := 0.7 + 0.3 * sin(_t * 30.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -6), Vector2(-10 - 22 * f, 0), Vector2(-10, 6)]), Color(P.ORANGE, 0.75))
			TowerArt.glow(self, Vector2(-14, 0), 12.0, Color(P.RED, 0.5))
		&"glider":
			TowerArt.glow(self, Vector2(-12, 0), 14.0 + 3.0 * sin(_t * 20.0), Color(P.GREEN, 0.55))
		&"plated":
			for side: float in [-1.0, 1.0]: # tracks
				draw_rect(Rect2(-24, side * 20.0 - 4.0, 48, 8), Color("1A1D26"))
				var off := fmod(_walk * 6.0, 8.0)
				var x := -24.0 + off
				while x < 24.0:
					draw_line(Vector2(x, side * 20.0 - 4.0), Vector2(x, side * 20.0 + 4.0), Color("4A4F5E"), 1.5)
					x += 8.0
		&"static_crawler":
			for i in range(6):
				var side := -1.0 if i < 3 else 1.0
				var fx := -12.0 + (i % 3) * 12.0
				var ph := _walk * 2.2 + i * 1.5
				var foot := Vector2(fx + sin(ph) * 6.0, side * 27.0)
				draw_line(Vector2(fx * 0.7, side * 14.0), foot, Color("344D5E"), 4.0)
				draw_circle(foot, 3.0, Color("14222E"))
		&"vanguard":
			for side: float in [-1.0, 1.0]:
				draw_rect(Rect2(-24, side * 21.0 - 4.0, 48, 8), Color("111D2A"))
				draw_rect(Rect2(-24, side * 21.0 - 4.0, 48, 8), Color("406790"), false, 1.5)
		&"rallier":
			var fl := 0.75 + 0.25 * sin(_t * 26.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-16, -10), Vector2(-16 - 14 * fl, -10), Vector2(-12, -6)]), Color(P.ORANGE, 0.8))
			draw_colored_polygon(PackedVector2Array([Vector2(-16, 10), Vector2(-16 - 14 * fl, 10), Vector2(-12, 6)]), Color(P.ORANGE, 0.8))
		&"wraith":
			var w_pulse := 0.6 + 0.4 * sin(_t * 18.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -3), Vector2(-14 - 18 * w_pulse, 0), Vector2(-14, 3)]), Color(P.VIOLET, 0.7))


func _parts_over(id: StringName) -> void:
	match id:
		&"mender":
			var a := _t * 1.6
			for k in range(2):
				var d := Vector2.from_angle(a + k * PI * 0.5)
				draw_line(-d * 10.0, d * 10.0, P.GREEN, 6.0)
			draw_circle(Vector2.ZERO, 3.5, Color("E8FFF4"))
		&"aegis":
			TowerArt.glow(self, Vector2(-6, 0), 10.0 + 2.0 * sin(_t * 4.0), Color(ICE, 0.6))
		&"monolith_shard":
			TowerArt.glow(self, Vector2.ZERO, 10.0, Color(P.RED, 0.6))
		&"disruptor":
			TowerArt.glow(self, Vector2(-2, 0), 11.0 + 3.0 * sin(_t * 8.0), Color(P.ORANGE, 0.65))
			if int(_t * 14.0) % 2 == 0:
				var rng_y := sin(_t * 31.0) * 8.0
				draw_polyline(PackedVector2Array([Vector2(24, -20), Vector2(20, rng_y), Vector2(24, 20)]), Color("FFF0D0"), 1.8)
		&"static_crawler":
			TowerArt.glow(self, Vector2.ZERO, 15.0 + 3.0 * sin(_t * 6.0), Color(Color("38D9F5"), 0.55))
			draw_arc(Vector2.ZERO, 16.0, _t * 5.0, _t * 5.0 + 3.5, 12, Color("E8FFFF"), 1.5)
		&"wraith":
			TowerArt.glow(self, Vector2(2, 0), 12.0 + 2.0 * sin(_t * 10.0), Color(P.VIOLET, 0.7))
		&"vanguard":
			TowerArt.glow(self, Vector2(8, 0), 14.0 + 2.0 * sin(_t * 4.0), Color(Color("8FD3FF"), 0.6))
		&"rallier":
			TowerArt.glow(self, Vector2(-2, 0), 9.0 + 3.0 * sin(_t * 12.0), Color(P.ORANGE, 0.65))
		&"cloaker":
			var a := _t * 2.5
			for k in range(3):
				var p := Vector2.from_angle(a + k * TAU / 3.0) * 18.0
				draw_circle(p, 2.5, Color(Color("DF9FFF"), 0.85))
				draw_line(Vector2.ZERO, p * 0.7, Color(Color("DF9FFF"), 0.3), 1.0)
		&"mender_elite":
			TowerArt.glow(self, Vector2.ZERO, 14.0 + 3.0 * sin(_t * 5.0), Color(P.GREEN, 0.65))
			var a := _t * 1.8
			for k in range(4):
				var d := Vector2.from_angle(a + k * PI * 0.5)
				draw_line(d * 6.0, d * 14.0, Color("7EFFBE"), 3.5)


func _shield_dome(r: float) -> void:
	var ratio := e.shield / maxf(e.shield_max, 1.0)
	var rad := r * 1.75
	if ratio > 0.0:
		var hexa := PackedVector2Array()
		for k in range(7):
			hexa.append(Vector2.from_angle(TAU * k / 6.0 + _t * 0.3) * rad)
		draw_colored_polygon(hexa.slice(0, 6), Color(P.BLUE, 0.06 + 0.10 * ratio + 0.2 * _shield_hit))
		draw_polyline(hexa, Color(ICE, 0.3 + 0.5 * ratio + 0.2 * _shield_hit), 1.5 + _shield_hit * 2.0)
		if _shield_hit > 0.0:
			draw_arc(Vector2.ZERO, rad * (0.6 + 0.4 * (1.0 - _shield_hit)), 0, TAU, 24, Color(1, 1, 1, _shield_hit * 0.8), 2.0)
	if _shield_break > 0.0: # shield shatters into hex fragments
		for k in range(6):
			var dir := Vector2.from_angle(TAU * k / 6.0)
			var p := dir * rad * (1.0 + (1.0 - _shield_break) * 0.8)
			draw_line(p, p + dir.orthogonal() * 7.0, Color(ICE, _shield_break), 2.0)


# ------------------------------------------------------------------ boss

func _boss_under(r: float) -> void:
	var kc: Color = KIT_COLOR.get(e.def.boss_kit, P.RED)
	var k := _phase_fx
	if k > 0.0:
		TowerArt.glow(self, Vector2.ZERO, r * (2.5 + 3.0 * (1.0 - k)), Color(kc, 0.5 * k))
	TowerArt.glow(self, Vector2.ZERO, r * 2.2, Color(kc, 0.18 + 0.08 * sin(_t * (6.0 if _phase >= 3 else 2.5))))
	if e.def.boss_kit != &"monolith":
		_kit_under(r, kc)
		return
	# telegraphs (real radii from the boss data)
	if e.telegraph_timer > 0.0:
		if e.telegraph_kind == 2:
			var prog := 1.0 - e.telegraph_timer / maxf(e.def.emp_telegraph, 0.01)
			var R := e.def.emp_radius
			draw_circle(Vector2.ZERO, R, Color(P.RED, 0.05 + 0.08 * prog))
			draw_arc(Vector2.ZERO, R, 0, TAU, 64, Color(P.RED, 0.45), 2.0)
			var pts := PackedVector2Array()
			for i in range(49):
				var a := TAU * i / 48.0
				pts.append(Vector2.from_angle(a) * R * prog * (1.0 + (0.04 if i % 2 == 0 else -0.04)))
			draw_polyline(pts, Color(P.RED, 0.9), 3.0)
		else: # summon: hatch opens, red beams
			var prog := 1.0 - e.telegraph_timer / maxf(e.def.summon_telegraph, 0.01)
			for i in range(4):
				var a := TAU * i / 4.0 + 0.4
				draw_line(Vector2.ZERO, Vector2.from_angle(a) * r * (1.4 + 1.2 * prog), Color(P.ORANGE, 0.6 * prog), 3.0)
			draw_arc(Vector2.ZERO, r * 1.6, 0, TAU * prog, 32, Color(P.ORANGE, 0.9), 3.0)


func _boss_over(r: float) -> void:
	if e.def.boss_kit != &"monolith":
		_kit_over(r)
		return
	var s := r * 1.75 / 30.0
	# orbiting armour blocks: attached in phase I-II, torn loose in phase III
	var detached := _phase >= 3
	var orbit := (40.0 if not detached else 52.0 + 3.0 * sin(_t * 7.0)) * s
	for i in range(3):
		var a := _t * (0.35 if not detached else 0.9) + TAU * i / 3.0
		var c := Vector2.from_angle(a) * orbit
		var tn := Vector2.from_angle(a + PI * 0.5)
		var dn := Vector2.from_angle(a)
		var quad := PackedVector2Array([c - tn * 13 * s - dn * 6 * s, c + tn * 13 * s - dn * 6 * s, c + tn * 10 * s + dn * 6 * s, c - tn * 10 * s + dn * 6 * s])
		draw_polygon(quad, PackedColorArray([Color("6A707F"), Color("6A707F"), Color("3A3F4E"), Color("3A3F4E")]))
		quad.append(quad[0])
		draw_polyline(quad, Color("B0B6C4"), 1.5)
		if detached and fmod(_t * 3.0 + i, 1.0) < 0.3:
			draw_line(c, c * 0.6, Color("FFE07A", 0.8), 1.5)
	if _phase == 2: # EMP antenna mast
		for k in range(3):
			var d := Vector2.from_angle(TAU * k / 3.0 + 0.5)
			draw_line(d * 10.0 * s, d * 34.0 * s, Color("AAB1C2"), 3.0)
			draw_circle(d * 34.0 * s, 3.0, P.RED if fmod(_t * 2.0, 1.0) < 0.5 else Color.WHITE)
	var core := (14.0 + (5.0 if detached else 0.0)) * s
	TowerArt.glow(self, Vector2.ZERO, core * 2.2, Color(P.RED, 0.8))
	draw_circle(Vector2.ZERO, core * 0.7, Color("FF9AA6"))
	draw_circle(Vector2.ZERO, core * 0.35, Color(1, 0.95, 0.95))


func _bp(key: String, default: float) -> float:
	if e.telegraph_params.has(key):
		return float(e.telegraph_params[key])
	return float(e.def.boss_params.get(key, default))


func _passive(kind: String) -> Dictionary:
	for pv in e.def.boss_passives:
		if String(pv.get("kind", "")) == kind:
			return pv
	return {}


## Telegraphs and auras of the newer boss kits (world space, real radii from the boss data).
func _kit_under(r: float, kc: Color) -> void:
	var kit := e.def.boss_kit
	if kit == &"colossus" and _phase >= 3: # overdrive aura
		var R := float(_passive("overdrive").get("radius", 180.0))
		draw_circle(Vector2.ZERO, R, Color(P.RED, 0.04 + 0.02 * sin(_t * 8.0)))
		for i in range(3):
			var rr := fmod(_t * 90.0 + i * R / 3.0, R)
			draw_arc(Vector2.ZERO, rr, 0, TAU, 48, Color(P.RED, 0.35 * (1.0 - rr / R)), 2.0)
	if e.telegraph_timer <= 0.0:
		return
	var prog := 1.0 - e.telegraph_timer / maxf(e.telegraph_total, 0.01)
	match e.telegraph_kind:
		EnemyAbilities.SHELL_KIND: # plates gather inward
			for i in range(6):
				var a := TAU * i / 6.0 + _t
				var d := r * (2.6 - 1.2 * prog)
				draw_line(Vector2.from_angle(a) * d, Vector2.from_angle(a) * (d - 10.0), Color(kc, 0.9), 4.0)
			draw_arc(Vector2.ZERO, r * 1.5, 0, TAU * prog, 32, kc, 3.0)
		EnemyAbilities.SPRINT_KIND: # charge-up chevrons ahead
			var fwd := Vector2.from_angle(_face)
			for i in range(3):
				var c := fwd * (r * 1.4 + i * 12.0)
				var n := fwd.orthogonal() * 8.0
				draw_polyline(PackedVector2Array([c - fwd * 6.0 + n, c, c - fwd * 6.0 - n]), Color(kc, prog), 3.0)
		EnemyAbilities.HANGAR_KIND: # deck lights + launch rails
			var fwd := Vector2.from_angle(_face)
			for side: float in [-1.0, 1.0]:
				var o := fwd.orthogonal() * side * r * 0.6
				draw_line(o - fwd * r, o + fwd * r * (0.8 + 1.4 * prog), Color(P.GREEN, 0.7 * prog), 3.0)
			draw_arc(Vector2.ZERO, r * 1.6, 0, TAU * prog, 32, P.GREEN, 3.0)
		EnemyAbilities.CLOAK_KIND: # cloak field radius closes in
			var R := _bp("radius", 120.0)
			draw_circle(Vector2.ZERO, R, Color(P.VIOLET, 0.06 + 0.06 * prog))
			draw_arc(Vector2.ZERO, R * (1.0 - 0.3 * prog), 0, TAU, 48, Color(P.VIOLET, 0.8), 2.0)
		EnemyAbilities.ADAPT_KIND: # plating flips: armour grey <-> shield blue
			var to_shield := e.chimera_mode == 0
			var col := ICE if to_shield else Color("C9CED8")
			draw_arc(Vector2.ZERO, r * 1.5, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, col, 4.0)
		EnemyAbilities.JAM_KIND: # jammer ring (towers inside recharge slower)
			var R := _bp("radius", 190.0)
			draw_circle(Vector2.ZERO, R, Color(P.ORANGE, 0.04 + 0.07 * prog))
			draw_arc(Vector2.ZERO, R, 0, TAU, 64, Color(P.ORANGE, 0.5), 2.0)
			var pts := PackedVector2Array()
			for i in range(49):
				pts.append(Vector2.from_angle(TAU * i / 48.0) * R * prog * (1.0 + (0.05 if i % 3 == 0 else 0.0)))
			draw_polyline(pts, Color(P.ORANGE, 0.9), 2.5)
		EnemyAbilities.BULWARK_KIND:
			var R := _bp("radius", 220.0)
			draw_circle(Vector2.ZERO, R, Color(ICE, 0.04 + 0.05 * prog))
			draw_arc(Vector2.ZERO, R * prog, 0, TAU, 64, Color(ICE, 0.8), 3.0)
		EnemyAbilities.STATIC_KIND: # static field radius (towers inside lose range)
			var R := _bp("radius", 200.0)
			draw_circle(Vector2.ZERO, R, Color(P.CYAN, 0.04 + 0.06 * prog))
			for i in range(8):
				var a := TAU * i / 8.0 + _t * 2.0
				var p1 := Vector2.from_angle(a) * R * prog
				draw_line(p1, p1 + Vector2.from_angle(a + 1.2) * 14.0, Color(P.CYAN, 0.9), 2.0)
			draw_arc(Vector2.ZERO, R, 0, TAU, 64, Color(P.CYAN, 0.5), 2.0)
		EnemyAbilities.CAPACITOR_KIND: # capacitor charge-up rings
			for k in range(3):
				draw_arc(Vector2.ZERO, r * (1.3 + 0.25 * k), 0, TAU * prog, 32, Color(P.CYAN, 0.8 - 0.2 * k), 3.0)
		EnemyAbilities.SUBMERGE_KIND: # water closing over it
			for k in range(3):
				draw_arc(Vector2.ZERO, r * (1.0 + prog * (0.6 + 0.4 * k)), 0, TAU, 32, Color(P.BLUE, 0.7 * (1.0 - 0.25 * k)), 2.0)
		EnemyAbilities.REVIVE_KIND: # revive radius + rising sparks
			var R := _bp("radius", 260.0)
			draw_arc(Vector2.ZERO, R, 0, TAU, 64, Color(P.GREEN, 0.25 + 0.4 * prog), 2.0)
			for i in range(6):
				var a := TAU * i / 6.0 + _t
				var p1 := Vector2.from_angle(a) * R * 0.6
				draw_line(p1, p1 - Vector2(0, 18.0 * prog), Color(P.GREEN, 0.8), 2.0)
		EnemyAbilities.DECOY_KIND: # light splits ahead of it
			var fwd := Vector2.from_angle(_face)
			for k: float in [-1.0, 1.0]:
				var tip := fwd * r * (1.5 + 1.5 * prog) + fwd.orthogonal() * k * r * prog
				draw_line(Vector2.ZERO, tip, Color(P.VIOLET, 0.8), 3.0)
				draw_circle(tip, 4.0, Color.WHITE)
		EnemyAbilities.PRISM_KIND:
			draw_arc(Vector2.ZERO, r * 1.6, 0, TAU * prog, 32, Color.WHITE, 3.0)
		EnemyAbilities.EFFECT_KIND, EnemyAbilities.SUMMON_DATA_KIND, EnemyAbilities.HEAL_KIND: # data skills
			var fx := EffectDef.by_id(String(e.telegraph_params.get("effect", "")))
			var col: Color = fx.color if fx != null else (P.GREEN if e.telegraph_kind == EnemyAbilities.HEAL_KIND else kc)
			var R := _bp("radius", r * 2.0)
			draw_circle(Vector2.ZERO, R, Color(col, 0.04 + 0.06 * prog))
			draw_arc(Vector2.ZERO, R * prog, 0, TAU, 48, Color(col, 0.9), 2.5)
		EnemyAbilities.BLINK_KIND: # rift tear: where it will land (real distance along the lane)
			var limit := e.route.total_length - _bp("keep", 260.0)
			var to := minf(e.progress + _bp("distance", 160.0), limit)
			if to > e.progress:
				var land := e.route.position_at(to, e.route.segment_for(to, 0)) - e.position
				draw_line(Vector2.ZERO, land, Color(P.RED, 0.25 + 0.5 * prog), 3.0)
				draw_arc(land, r * (1.6 - 0.6 * prog), 0, TAU, 32, Color(P.RED, 0.9), 3.0)
				for i in range(4):
					var a := TAU * i / 4.0 + _t * 3.0
					draw_line(land + Vector2.from_angle(a) * r * 0.4, land + Vector2.from_angle(a) * r * 1.2, Color(P.RED, prog), 2.0)


func _kit_over(r: float) -> void:
	var kit := e.def.boss_kit
	var kc: Color = KIT_COLOR.get(kit, P.RED)
	var s := r * 1.75 / 30.0
	match kit:
		&"warden":
			if e.sprint_timer > 0.0: # overclock exhaust
				var back := Vector2.from_angle(_face + PI)
				for k: float in [-0.4, 0.4]:
					var o := back * r * 0.9 + back.orthogonal() * r * k
					draw_line(o, o + back * (18.0 + 8.0 * sin(_t * 30.0)), Color(P.ORANGE, 0.85), 5.0)
			if _phase >= 2:
				TowerArt.glow(self, Vector2.ZERO, 10.0 * s, Color(kc, 0.7))
		&"carrier":
			for i in range(4): # deck lights
				var on := fmod(_t * 2.0 + i * 0.25, 1.0) < 0.5
				var p := Vector2(-14.0 + i * 8.0, 0).rotated(_face) * s
				draw_circle(p, 1.8 * s, P.GREEN if on else Color(P.GREEN, 0.25))
		&"chimera":
			var core := 7.0 * s
			var col := ICE if e.chimera_mode == 1 else Color("C9CED8")
			TowerArt.glow(self, Vector2.ZERO, core * 2.4, Color(kc, 0.7))
			draw_arc(Vector2.ZERO, r * 1.15, 0, TAU, 32, Color(col, 0.6), 2.0)
			if e.chimera_mode == 0: # armour plates bolted around
				for i in range(6):
					var a := TAU * i / 6.0 + _t * 0.4
					draw_line(Vector2.from_angle(a - 0.25) * r * 1.15, Vector2.from_angle(a + 0.25) * r * 1.15, Color("D6DAE3"), 4.0)
		&"dynamo":
			var core := 8.0 * s
			TowerArt.glow(self, Vector2.ZERO, core * (2.4 + (1.0 if e.overload else 0.0)), Color(kc, 0.8))
			if e.hit_cap_timer > 0.0: # capacitor plates
				for i in range(4):
					var a := TAU * i / 4.0 + _t * 3.0
					draw_arc(Vector2.ZERO, r * 1.25, a, a + 0.9, 8, Color(P.CYAN, 0.9), 4.0)
			if e.overload and fmod(_t * 6.0, 1.0) < 0.5:
				var a2 := _rng.randf() * TAU
				draw_line(Vector2.from_angle(a2) * r, Vector2.from_angle(a2 + 0.3) * r * 1.6, Color.WHITE, 2.0)
		&"leviathan":
			if e.submerge_timer > 0.0: # ripples while under water
				for k in range(3):
					var rr := r * (1.0 + fmod(_t * 0.8 + k * 0.33, 1.0) * 1.2)
					draw_arc(Vector2.ZERO, rr, 0, TAU, 32, Color(P.BLUE, 0.6 * (1.0 - (rr / r - 1.0) / 1.2)), 2.0)
		&"refractor":
			if e.immune_timer > 0.0 and e.immune_type >= 0: # prismatic shield in the resisted type's colour
				var pc: Color = PRISM_COLOR.get(e.immune_type, Color.WHITE)
				var hexa := PackedVector2Array()
				for k in range(7):
					hexa.append(Vector2.from_angle(TAU * k / 6.0 + _t) * r * 1.5)
				draw_colored_polygon(hexa.slice(0, 6), Color(pc, 0.15))
				draw_polyline(hexa, Color(pc, 0.9), 2.5)
		&"colossus":
			var core := (12.0 + (4.0 if _phase >= 3 else 0.0)) * s
			TowerArt.glow(self, Vector2.ZERO, core * 2.4, Color(P.RED, 0.85))
			draw_circle(Vector2.ZERO, core * 0.5, Color(1, 0.95, 0.95))
			for i in range(4): # leg pods stomp
				var a := PI * 0.25 + PI * 0.5 * i + _face
				var p := Vector2.from_angle(a) * r * 1.08
				var lift := maxf(0.0, sin(_walk * 1.5 + i * PI * 0.5)) * 4.0
				draw_circle(p, (5.0 + lift * 0.4) * s * 0.6, Color("3A3F4E"))


## Temporary overshield (Warden shell / Colossus bulwark): amber hex plates.
func _overshield(r: float) -> void:
	var rad := r * 1.55
	var hexa := PackedVector2Array()
	for k in range(7):
		hexa.append(Vector2.from_angle(TAU * k / 6.0 - _t * 0.5) * rad)
	draw_colored_polygon(hexa.slice(0, 6), Color(P.ORANGE, 0.10))
	draw_polyline(hexa, Color(P.ORANGE, 0.75), 2.0)


# ------------------------------------------------------------------ HUD-ish bits

func _hp_bar(ci: CanvasItem, o: Vector2, r: float) -> void:
	if e.hp >= e.max_hp and e.shield >= e.shield_max:
		return
	var w := maxf(r * 2.4, 20.0)
	var y := o.y - r - 10.0
	var ratio := e.hp / maxf(e.max_hp, 1.0)
	var col := P.GREEN if ratio > 0.6 else (P.ORANGE if ratio > 0.3 else P.RED)
	ci.draw_rect(Rect2(o.x - w * 0.5 - 1, y - 1, w + 2, 6), Color(0, 0, 0, 0.75))
	ci.draw_rect(Rect2(o.x - w * 0.5, y, w * (_hp_lag / maxf(e.max_hp, 1.0)), 4), Color(1, 1, 1, 0.7))
	ci.draw_rect(Rect2(o.x - w * 0.5, y, w * ratio, 4), col)
	if e.shield_max > 0.0 and e.shield > 0.0:
		ci.draw_rect(Rect2(o.x - w * 0.5, y - 3, w * (e.shield / e.shield_max), 2), ICE)


func _status_icons(ci: CanvasItem, o: Vector2, r: float, hidden: bool) -> void:
	var icons: Array = []
	if e.is_chilled() and not e.is_frozen(): icons.append("slow")
	if e.is_burning(): icons.append("burn")
	if e.mark_timer > 0.0: icons.append("mark")
	if e.shred > 0.0: icons.append("shred")
	if e.grounded_timer > 0.0: icons.append("grounded")
	if e.is_stealthy() and not hidden: icons.append("revealed")
	var x := -(icons.size() - 1) * 5.5
	var y := -r - 18.0 if e.hp < e.max_hp else -r - 10.0
	for ic in icons:
		var c := o + Vector2(x, y)
		match ic:
			"slow":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(3, 0), c + Vector2(0, 4), c + Vector2(-3, 0)]), ICE)
			"burn":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(3, 1), c + Vector2(0, 4), c + Vector2(-3, 1)]), P.ORANGE)
				ci.draw_circle(c + Vector2(0, 1.5), 1.5, Color("FFE07A"))
			"mark":
				ci.draw_arc(c, 3.5, 0, TAU, 10, P.RED, 1.5)
				ci.draw_line(c - Vector2(5, 0), c + Vector2(5, 0), P.RED, 1.0)
				ci.draw_line(c - Vector2(0, 5), c + Vector2(0, 5), P.RED, 1.0)
			"shred":
				ci.draw_polyline(PackedVector2Array([c + Vector2(-3, -4), c + Vector2(1, -1), c + Vector2(-1, 1), c + Vector2(3, 4)]), Color("FFE07A"), 1.5)
			"grounded":
				ci.draw_line(c + Vector2(0, -4), c + Vector2(0, 3), P.GREEN, 1.5)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-3, 0), c + Vector2(0, 4), c + Vector2(3, 0)]), P.GREEN, 1.5)
			"revealed":
				_ellipse_line_on(ci, c, 4.5, 2.5, Color.WHITE)
				ci.draw_circle(c, 1.3, Color.WHITE)
		x += 11.0


## Shadow under the enemy, at `o` (its position when drawn by the shared layer). `alpha` = stealth fade.
func draw_shadow(ci: CanvasItem, o: Vector2, alpha: float) -> void:
	var r := e.def.radius
	if e.is_flying():
		_ellipse_on(ci, o + Vector2(8, 10), r * 1.1, r * 0.55, Color(0, 0, 0, 0.32 * alpha))
	else:
		_ellipse_on(ci, o + Vector2(2, 4), r * 1.05, r * 0.8, Color(0, 0, 0, 0.28 * alpha))


## HP bar + status icons above the enemy, at `o`.
func draw_overlay(ci: CanvasItem, o: Vector2) -> void:
	var hidden := e.is_stealthy() and not e.is_revealed()
	if not hidden and not e.def.is_boss:
		_hp_bar(ci, o, e.def.radius)
	_status_icons(ci, o, e.def.radius, hidden)


## Same fade the enemy's own drawing uses (stealth / submerged), for the shared shadow layer.
func fade() -> float:
	if e.is_stealthy() and not e.is_revealed():
		return 0.28
	return 0.35 if e.submerge_timer > 0.0 else 1.0


static func _units() -> void:
	if _unit16.is_empty():
		for i in range(16):
			_unit16.append(Vector2.from_angle(TAU * i / 16.0))
		for i in range(13):
			_unit12.append(Vector2.from_angle(TAU * i / 12.0))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	_ellipse_on(self, c, rx, ry, col)


static func _ellipse_on(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	_units()
	var pts := PackedVector2Array()
	pts.resize(16)
	for i in range(16):
		pts[i] = c + _unit16[i] * Vector2(rx, ry)
	ci.draw_colored_polygon(pts, col)


func _ellipse_line(c: Vector2, rx: float, ry: float, col: Color) -> void:
	_ellipse_line_on(self, c, rx, ry, col)


static func _ellipse_line_on(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	_units()
	var pts := PackedVector2Array()
	pts.resize(13)
	for i in range(13):
		pts[i] = c + _unit12[i] * Vector2(rx, ry)
	ci.draw_polyline(pts, col, 1.2)


func _star(c: Vector2, rr: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		pts.append(c + Vector2.from_angle(-PI / 2 + TAU * i / 10.0) * (rr if i % 2 == 0 else rr * 0.45))
	draw_colored_polygon(pts, col)
