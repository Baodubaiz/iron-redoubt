class_name ProjectileSystem
extends Node2D
## Pooled, node-less projectiles drawn by a single canvas item (cheap on mobile),
## plus lightweight FX (impact rings, chain/beam lines). Impacts are resolved by the controller.

class Shot:
	var active := false
	var pos := Vector2.ZERO
	var dest := Vector2.ZERO
	var target: Enemy = null
	var source: Tower = null
	var homing := true
	var speed := 600.0
	var damage := 0.0
	var damage_type := 0
	var armor_pen := 0.0
	var splash := 0.0
	var hits_air := true
	var color := Color.WHITE
	var crit := false ## Annihilator
	var quake := false ## Quake stun shell
	var echo := false ## Cascade: schedules a second detonation
	# presentation only (never read by rules)
	var origin := Vector2.ZERO
	var tower_id: StringName = &""
	var branch_id: StringName = &""

class Fx:
	var active := false
	var kind := 0 ## 0 ring, 1 line
	var pos := Vector2.ZERO
	var pos2 := Vector2.ZERO
	var radius := 0.0
	var t := 0.0
	var life := 0.18
	var color := Color.WHITE
	var seed := 0

const P = preload("res://ui/style/visual_palette.gd")
## Presentation cap: when exceeded, the oldest effect is recycled (never affects gameplay).
const MAX_FX := 220

## Called with (shot) when a projectile arrives.
var impact_callback: Callable
## Fire patches owned by MatchController (shared array; drawn here).
var zones: Array[Dictionary] = []

var _shots: Array[Shot] = []
var _fx: Array[Fx] = []


func active_count() -> int:
	var n := 0
	for s in _shots:
		if s.active:
			n += 1
	return n


func spawn(tower: Tower, target: Enemy) -> Shot:
	var s := _take_shot()
	var d := tower.def
	s.active = true
	s.pos = tower.position + Vector2.from_angle(tower.aim_angle) * (d.footprint_radius * 0.7)
	s.target = target
	s.source = tower
	s.dest = target.position
	s.homing = d.homing
	s.speed = d.projectile_speed
	s.damage = tower.eff_damage()
	s.damage_type = d.damage_type
	s.armor_pen = tower.armor_pen
	s.splash = tower.splash_radius
	s.hits_air = tower.can_target_air
	s.color = d.color
	s.crit = false
	s.quake = false
	s.echo = false
	s.origin = s.pos
	s.tower_id = d.id
	s.branch_id = tower.branch_def().id if tower.branch >= 0 else &""
	return s


func step(dt: float) -> void:
	for s in _shots:
		if not s.active:
			continue
		if s.homing:
			if s.target != null and is_instance_valid(s.target) and s.target.is_alive():
				s.dest = s.target.position
			else:
				s.active = false # target gone: homing shot fizzles
				s.source = null
				continue
		var to := s.dest - s.pos
		var step_len := s.speed * dt
		if to.length_squared() <= step_len * step_len:
			s.pos = s.dest
			s.active = false
			impact_callback.call(s)
			s.target = null
			s.source = null
		else:
			s.pos += to.normalized() * step_len
	for f in _fx:
		if f.active:
			f.t += dt
			if f.t >= f.life:
				f.active = false
	queue_redraw()


## Removes every in-flight projectile owned by a tower (used when a tower is sold).
func remove_from(tower: Tower) -> void:
	for s in _shots:
		if s.active and s.source == tower:
			s.active = false
			s.source = null
			s.target = null


func clear_all() -> void:
	for s in _shots:
		s.active = false
		s.target = null
		s.source = null
	for f in _fx:
		f.active = false
	queue_redraw()


func ring(pos: Vector2, radius: float, color: Color, life: float = 0.18) -> void:
	var f := _take_fx()
	f.kind = 0
	f.pos = pos
	f.radius = radius
	f.color = color
	f.life = life


## Minimal death effect: 6 short shards flying outward and fading.
func burst(pos: Vector2, color: Color, radius: float) -> void:
	var f := _take_fx()
	f.kind = 2
	f.pos = pos
	f.radius = radius
	f.color = color
	f.life = 0.55 if radius < 20.0 else 1.1 # visual duration only


func line(a: Vector2, b: Vector2, color: Color, life: float = 0.12) -> void:
	var f := _take_fx()
	f.kind = 1
	f.pos = a
	f.pos2 = b
	f.color = color
	f.life = life


func _take_shot() -> Shot:
	for s in _shots:
		if not s.active:
			return s
	var n := Shot.new()
	_shots.append(n)
	return n


var _fx_seed := 0


func _take_fx() -> Fx:
	_fx_seed += 1
	for x in _fx:
		if not x.active:
			x.active = true
			x.t = 0.0
			x.seed = _fx_seed
			return x
	if _fx.size() >= MAX_FX:
		var oldest := _fx[0]
		for x in _fx:
			if x.t / x.life > oldest.t / oldest.life:
				oldest = x
		oldest.t = 0.0
		oldest.seed = _fx_seed
		return oldest
	var f := Fx.new()
	f.active = true
	f.seed = _fx_seed
	_fx.append(f)
	return f


# ================================================================= presentation (Reforged Stage D)

var _t := 0.0
var _zone_layer: Node2D


func _ready() -> void:
	z_index = 4 # shots and impacts above enemy bodies (EnemyVisual uses z 1-3)
	_zone_layer = Node2D.new() # fire patches stay on the ground, under towers and enemies
	_zone_layer.z_as_relative = false
	_zone_layer.z_index = -5
	_zone_layer.draw.connect(_draw_zones)
	add_child(_zone_layer)


func _process(delta: float) -> void:
	_t += minf(delta, 0.1)
	if _zone_layer != null:
		_zone_layer.queue_redraw()


## Maps the legacy data colours handed to ring()/line() onto the Reforged palette.
static func _remap(c: Color) -> Color:
	var table := [[Color(0.3098, 0.8471, 1.0), P.CYAN], [Color(1.0, 0.6235, 0.2627), P.ORANGE],
		[Color(1.0, 0.4196, 0.8392), P.VIOLET], [Color(0.4196, 0.8784, 0.5412), P.GREEN],
		[Color("ff5c6c"), P.RED], [Color("ff9f43"), P.ORANGE], [Color("bfe9ff"), Color("8FD3FF")]]
	for row in table:
		var k: Color = row[0]
		if absf(k.r - c.r) + absf(k.g - c.g) + absf(k.b - c.b) < 0.06:
			return row[1]
	return c


static func _is(c: Color, ref: Color) -> bool:
	return absf(ref.r - c.r) + absf(ref.g - c.g) + absf(ref.b - c.b) < 0.06


func _draw_zones() -> void:
	var zl := _zone_layer
	for z in zones: # fire patches (Incendiary / Inferno) and shock traps
		var c: Vector2 = z["pos"]
		var r: float = z["radius"]
		if z.has("effect"): # Shock Trap: yellow grid plate with crackling arcs
			var y := Color("FFD84D")
			TowerArt.glow(zl, c, r * 1.05, Color(y, 0.16 + 0.05 * sin(_t * 11.0)))
			var hexa := PackedVector2Array()
			for k in range(7):
				hexa.append(c + Vector2.from_angle(TAU * k / 6.0) * r * 0.9)
			zl.draw_polyline(hexa, Color(y, 0.6), 2.0)
			for i in range(3):
				var a1 := _t * 6.0 + i * TAU / 3.0 + c.x * 0.01
				var p1 := c + Vector2.from_angle(a1) * r * 0.7
				var p2 := c + Vector2.from_angle(a1 + 1.4) * r * 0.7
				zl.draw_polyline(PackedVector2Array([p1, p1.lerp(p2, 0.5) + Vector2.from_angle(a1 * 3.0) * 6.0, p2]), Color(1, 0.95, 0.6, 0.85), 1.5)
			continue
		if z.get("venom", false): # Venom Spray: a toxic green cloud with slow-drifting bubbles
			var tox := Color("8be36a")
			TowerArt.glow(zl, c, r * 1.1, Color(tox, 0.20 + 0.05 * sin(_t * 5.0)))
			zl.draw_arc(c, r, 0, TAU, 32, Color(tox, 0.3), 1.5)
			for i in range(5):
				var a2 := i * TAU / 5.0 + _t * 0.6
				var drift := fmod(_t * 0.5 + i * 0.37, 1.0) # 0->1 repeating rise
				var p := c + Vector2.from_angle(a2) * r * 0.5 * (1.0 - drift * 0.3) - Vector2(0, drift * r * 0.5)
				zl.draw_circle(p, 3.0 + 2.0 * sin(_t * 3.0 + i), Color(tox, 0.5 * (1.0 - drift)))
			continue
		TowerArt.glow(zl, c, r * 1.1, Color(P.ORANGE, 0.22 + 0.05 * sin(_t * 9.0)))
		zl.draw_arc(c, r, 0, TAU, 32, Color(P.ORANGE, 0.35), 1.5)
		for i in range(6):
			var a := TAU * i / 6.0 + c.x * 0.01
			var base := c + Vector2.from_angle(a) * r * 0.55
			var h := 7.0 + 4.0 * sin(_t * 14.0 + i * 2.1)
			zl.draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(0, -h), base + Vector2(3, 0)]), Color("FF7A3D", 0.75))


func _draw() -> void:
	for s in _shots:
		if s.active:
			_draw_shot(s)
	for f in _fx:
		if f.active:
			_draw_fx(f)


func _draw_shot(s: Shot) -> void:
	var col := P.tower_color(s.tower_id) if s.tower_id != &"" else _remap(s.color)
	var dir := (s.dest - s.pos).normalized()
	if dir == Vector2.ZERO:
		dir = (s.pos - s.origin).normalized()
	if s.splash > 0.0: # plasma orb (Nova); lobbed shells arc visually (impact point/time unchanged)
		var p := s.pos
		if not s.homing:
			var total := maxf(s.origin.distance_to(s.dest), 1.0)
			var k := clampf(s.origin.distance_to(s.pos) / total, 0.0, 1.0)
			var lift := sin(PI * k) * minf(60.0, total * 0.3)
			draw_circle(s.pos, 4.0, Color(0, 0, 0, 0.3))
			p = s.pos - Vector2(0, lift)
		var big := 1.35 if s.quake else 1.0
		for i in range(3):
			draw_circle(p - dir * (6.0 + i * 6.0), (4.0 - i) * big, Color(col, 0.35 - i * 0.1))
		TowerArt.glow(self, p, 13.0 * big, Color(col, 0.75))
		draw_circle(p, 5.0 * big, col.lightened(0.35))
		draw_circle(p, 2.5 * big, Color.WHITE)
		if s.quake:
			draw_arc(p, 9.0, _t * 8.0, _t * 8.0 + 4.0, 10, Color.WHITE, 1.5)
		return
	var length := 30.0 if s.crit else (26.0 if s.branch_id == &"penetrator" else 19.0)
	var w := 4.5 if s.crit else 3.5
	draw_line(s.pos - dir * length, s.pos, Color(col, 0.28), w * 2.6)
	draw_line(s.pos - dir * length * 0.8, s.pos, col.lightened(0.45), w)
	draw_circle(s.pos, w * 0.7, Color.WHITE)


func _draw_fx(f: Fx) -> void:
	var k := f.t / f.life
	var inv := 1.0 - k
	var col := _remap(f.color)
	var rng := RandomNumberGenerator.new()
	rng.seed = f.seed
	match f.kind:
		0:
			if f.radius <= 8.0: # projectile impact: flash + sparks
				TowerArt.glow(self, f.pos, 12.0 * inv + 4.0, Color(col, 0.8 * inv))
				for i in range(4):
					var d := Vector2.from_angle(rng.randf() * TAU)
					var a := f.pos + d * (3.0 + 16.0 * k)
					draw_line(a, a + d * 5.0 * inv, Color(col.lightened(0.4), inv), 1.5)
			elif _is(f.color, Color("ff5c6c")) and f.life >= 0.35: # boss EMP shockwave
				var r := f.radius * (0.25 + 0.75 * sqrt(k))
				draw_circle(f.pos, r, Color(P.RED, 0.12 * inv))
				var pts := PackedVector2Array()
				for i in range(65):
					var a := TAU * i / 64.0
					pts.append(f.pos + Vector2.from_angle(a) * r * (1.0 + (0.03 if i % 2 == 0 else -0.03)))
				draw_polyline(pts, Color(P.RED, inv), 3.0)
				draw_arc(f.pos, r * 0.85, 0, TAU, 48, Color(1, 1, 1, 0.4 * inv), 1.5)
			elif _is(f.color, Color("bfe9ff")): # Cryo freeze pulse
				draw_arc(f.pos, f.radius * (0.4 + 0.6 * k), 0, TAU, 40, Color(col, 0.8 * inv), 3.0)
				for i in range(8):
					var d := Vector2.from_angle(TAU * i / 8.0)
					var c := f.pos + d * f.radius * (0.4 + 0.6 * k)
					draw_colored_polygon(PackedVector2Array([c + d * 5, c + d.orthogonal() * 2.5, c - d * 3, c - d.orthogonal() * 2.5]), Color(col, inv))
			else: # explosion with the real splash radius
				var r := f.radius
				TowerArt.glow(self, f.pos, r * (0.5 + 0.6 * k), Color(col, 0.55 * inv))
				draw_circle(f.pos, r * (0.25 + 0.3 * k), Color(1, 0.95, 0.8, 0.5 * maxf(0.0, 1.0 - k * 2.5)))
				draw_arc(f.pos, r * (0.3 + 0.7 * sqrt(k)), 0, TAU, 40, Color(col.lightened(0.3), 0.9 * inv), 3.0 * inv + 1.0)
				for i in range(6):
					var d := Vector2.from_angle(rng.randf() * TAU)
					var a := f.pos + d * r * (0.2 + 0.8 * k)
					draw_line(a, a + d * 7.0 * inv, Color("FFE07A", inv), 2.0)
		1:
			if _is(col, P.VIOLET): # Arc chain lightning
				var jit := RandomNumberGenerator.new()
				jit.seed = f.seed * 31 + int(f.t / 0.04)
				var pts := PackedVector2Array([f.pos])
				var n := 6
				var nrm := (f.pos2 - f.pos).orthogonal().normalized()
				for i in range(1, n):
					pts.append(f.pos.lerp(f.pos2, float(i) / n) + nrm * jit.randf_range(-7.0, 7.0))
				pts.append(f.pos2)
				draw_polyline(pts, Color(col, 0.35 * inv), 6.0)
				draw_polyline(pts, Color("EFE6FF", inv), 2.0)
				TowerArt.glow(self, f.pos2, 9.0, Color(col, 0.8 * inv))
			else: # piercing trail
				draw_line(f.pos, f.pos2, Color(col, 0.3 * inv), 7.0)
				draw_line(f.pos, f.pos2, Color(col.lightened(0.5), inv), 2.0)
		2: # destruction: metal fragments + embers + flash (bigger for large / boss units)
			var big := f.radius >= 20.0
			var n := (14 if big else 7) / (2 if P.reduce_effects else 1)
			var reach := (90.0 if big else 34.0) * (1.0 - pow(inv, 2.0))
			if k < 0.35:
				TowerArt.glow(self, f.pos, f.radius * (2.0 if big else 1.6) * (1.0 + k), Color(P.ORANGE, 0.9 * (1.0 - k / 0.35)))
				draw_circle(f.pos, f.radius * 0.6 * (1.0 - k / 0.35), Color(1, 1, 1, 0.8))
			for i in range(n):
				var d := Vector2.from_angle(rng.randf() * TAU)
				var dist := reach * rng.randf_range(0.5, 1.0)
				var c := f.pos + d * (f.radius * 0.4 + dist)
				var rot := rng.randf() * TAU + k * rng.randf_range(-8.0, 8.0)
				var sz := rng.randf_range(2.0, 4.5) * (1.6 if big else 1.0)
				var u := Vector2.from_angle(rot) * sz
				var v := u.orthogonal() * 0.6
				if i % 3 == 0:
					draw_circle(c, sz * 0.5, Color(P.ORANGE, inv))
				else:
					draw_colored_polygon(PackedVector2Array([c - u - v, c + u - v, c + u + v, c - u + v]), Color(0.55, 0.58, 0.66, inv))
			if big:
				draw_arc(f.pos, f.radius * (1.0 + 4.0 * k), 0, TAU, 48, Color(P.RED, 0.7 * inv), 4.0)
