class_name TowerArt
extends RefCounted
## Draws a Reforged tower (presentation only): hex base (SVG), rotating turret (SVG for Pulse /
## Nova / Lance, procedural for Beacon) and procedural branch parts that change the SILHOUETTE per
## branch and tier, plus a distinct evolved form. Used by TowerVisual (live towers) and the
## placement ghost. All coordinates below are "art units" (the 128 px SVG space, turret facing +x);
## draw() scales them to the tower footprint.

const P = preload("res://ui/style/visual_palette.gd")
const M_LIGHT := Color("5A6F96")
const M_MID := Color("2E4066")
const M_DARK := Color("141D31")
const RIM := Color("8FA6CF")
const ICE := Color("8FD3FF")
const ART_TO_FOOTPRINT := 1.0 / 42.0

static var _tex := {}
static var _glow_tex: Texture2D


## Visual state of one tower (filled by TowerVisual each frame, or once for a ghost).
class Look:
	var def: TowerDef
	var aim: float = -PI * 0.5
	var main_id: StringName = &""
	var main_tier: int = 0
	var sec_id: StringName = &""
	var sec_tier: int = 0
	var evolved: bool = false
	var t: float = 0.0 ## seconds, drives idle animation
	var recoil: float = 0.0 ## 0..1
	var flash: float = 0.0 ## >0 while the muzzle flash shows
	var barrel: float = 1.0 ## Pulse: which barrel fired last (+1 / -1)
	var charge: float = 0.0 ## 0..1 readiness of the next shot (Nova reactor / Lance rings)
	var spin: float = 0.0 ## Storm Array drum angle
	var tint: Color = Color.WHITE


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/art/towers/%s.svg" % name)
	return _tex[name]


static func glow_tex() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_glow_tex = gt
	return _glow_tex


static func glow(ci: CanvasItem, pos: Vector2, radius: float, col: Color) -> void:
	ci.draw_texture_rect(glow_tex(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


static func art_scale(k: Look) -> float:
	return k.def.footprint_radius * ART_TO_FOOTPRINT * (1.1 if k.evolved else 1.0)


## Muzzle position in art units (turret space), including barrel extensions from upgrades.
static func muzzle_local(k: Look) -> Vector2:
	match k.def.id:
		&"pulse":
			if k.evolved and k.main_id == &"rapid": return Vector2(74, 0)
			if k.evolved and k.main_id == &"penetrator": return Vector2(92, 0)
			var ext := 6.0 * k.main_tier if k.main_id == &"penetrator" else 0.0
			return Vector2(62 + ext, 12.0 * k.barrel)
		&"nova":
			var ext := 8.0 * k.main_tier if k.main_id == &"siege" else 0.0
			if k.evolved and k.main_id == &"siege": ext += 14.0
			if k.evolved and k.main_id == &"cluster": return Vector2(72, 0)
			return Vector2(58 + ext, 0)
		&"lance":
			if k.evolved and k.main_id == &"focus": return Vector2(98, 0)
			var ext := 6.0 * k.main_tier + 4.0 if k.main_id == &"focus" else 0.0
			if k.main_id == &"arc": ext = 6.0
			return Vector2(62 + ext, 0)
	return Vector2.ZERO


## Muzzle position in the tower's local space (what effects and beams start from).
static func muzzle(k: Look, recoil_px: float = 0.0) -> Vector2:
	var s := art_scale(k)
	return (muzzle_local(k) * s + Vector2(-recoil_px, 0)).rotated(k.aim)


static func draw(ci: CanvasItem, at: Vector2, k: Look) -> void:
	var s := art_scale(k)
	var col := P.tower_color(k.def.id)
	# ---- base (does not rotate)
	ci.draw_set_transform(at, 0.0, Vector2(s, s))
	if k.evolved:
		_hex_ring(ci, Vector2.ZERO, 58.0, k.t * 0.4, Color(col, 0.55), 3.0)
		glow(ci, Vector2.ZERO, 70.0, Color(col, 0.18))
	ci.draw_texture(tex("base_hex"), Vector2(-64, -64), k.tint)
	_armor(ci, k, col)
	_secondary_module(ci, k)
	# ---- turret
	if k.def.id == &"beacon":
		_beacon(ci, k, col)
	else:
		var back := Vector2(-6.0 * k.recoil, 0.0).rotated(k.aim)
		ci.draw_set_transform(at + back * s, k.aim, Vector2(s, s))
		_turret_under(ci, k, col)
		ci.draw_texture(tex("%s_turret" % k.def.id), Vector2(-64, -64), k.tint)
		_turret_over(ci, k, col)
		if k.flash > 0.0:
			var m := muzzle_local(k)
			glow(ci, m, 22.0, Color(col, 0.8))
			glow(ci, m, 9.0, Color(1, 1, 1, 0.95))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ base parts

## One armour clamp per main-branch tier on the hex corners (silhouette grows with tiers).
static func _armor(ci: CanvasItem, k: Look, col: Color) -> void:
	var corners := [PI, PI / 3.0, -PI / 3.0]
	for i in range(mini(k.main_tier, 3)):
		var d := Vector2.from_angle(corners[i])
		var tn := Vector2(-d.y, d.x)
		var c := d * 50.0
		var pts := PackedVector2Array([c + d * 6.0, c - d * 8.0 + tn * 13.0, c - d * 14.0, c - d * 8.0 - tn * 13.0])
		ci.draw_polygon(pts, PackedColorArray([M_LIGHT, M_LIGHT, M_DARK, M_DARK]))
		pts.append(pts[0])
		ci.draw_polyline(pts, RIM, 1.5)
		ci.draw_line(c - d * 4.0 + tn * 5.0, c - d * 4.0 - tn * 5.0, col, 2.5)


## Secondary branch: an auxiliary module bolted to the base, with one light per tier.
static func _secondary_module(ci: CanvasItem, k: Look) -> void:
	if k.sec_tier <= 0:
		return
	var c := Vector2.from_angle(PI * 0.75) * 36.0
	_metal_rect(ci, Rect2(c - Vector2(14, 9), Vector2(28, 18)))
	for i in range(k.sec_tier):
		ci.draw_circle(c + Vector2(-6 + i * 12, 0), 3.5, _branch_color(k.def.id, k.sec_id))


static func _branch_color(tower: StringName, branch: StringName) -> Color:
	match branch:
		&"cryo": return ICE
		&"incendiary": return Color("FF7A3D")
		&"arc": return Color("C9A6FF")
		&"relay": return P.ORANGE
	return P.tower_color(tower)


# ------------------------------------------------------------------ turret parts

static func _turret_under(ci: CanvasItem, k: Look, col: Color) -> void:
	match [k.def.id, k.main_id]:
		[&"nova", &"incendiary"]:
			var n := 3 if k.evolved else k.main_tier
			for i in range(n):
				for side: float in [-1.0, 1.0]:
					var r := Rect2(-34 + i * 15, side * 31 - 7, 12, 14)
					_metal_rect(ci, r)
					ci.draw_rect(Rect2(r.position.x + 2, r.position.y + 5, 8, 4), Color("FF7A3D"))
		[&"lance", &"overcharge"]:
			var n := 3 if k.evolved else k.main_tier
			var h := 9.0 if k.evolved else 7.0
			for i in range(n):
				for side: float in [-1.0, 1.0]:
					var r := Rect2(-30 + i * 15, side * (18 + h * 0.5) - h, 12, h * 2.0)
					_metal_rect(ci, r)
					ci.draw_rect(r.grow(-3), Color(col, 0.5 + 0.5 * k.charge))
		[&"pulse", &"sensor"]:
			var rx := 7.0 + 3.0 * k.main_tier + (8.0 if k.evolved else 0.0)
			_dish(ci, Vector2(-30, 0), rx, k.t * 2.2, col)


static func _turret_over(ci: CanvasItem, k: Look, col: Color) -> void:
	var tier := k.main_tier
	match k.def.id:
		&"pulse":
			match k.main_id:
				&"rapid":
					for i in range(tier):
						_metal_rect(ci, Rect2(20 + i * 11, -21, 5, 42))
						ci.draw_line(Vector2(22.5 + i * 11, -19), Vector2(22.5 + i * 11, 19), Color(col, 0.6), 1.5)
					if k.evolved: # Storm Array: rotating 4-barrel drum
						var order := []
						for j in range(4):
							var a := k.spin + j * PI * 0.5
							order.append([cos(a), sin(a) * 11.0])
						order.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
						for b in order:
							var shade: Color = M_DARK.lerp(M_LIGHT, 0.5 + 0.5 * b[0])
							ci.draw_rect(Rect2(32, b[1] - 3.5, 42, 7), shade)
							ci.draw_rect(Rect2(70, b[1] - 3, 5, 6), Color(col, 0.5 + 0.5 * b[0]))
						ci.draw_circle(Vector2(32, 0), 15.0, M_MID)
						ci.draw_arc(Vector2(32, 0), 15.0, 0, TAU, 20, RIM, 2.0)
						glow(ci, Vector2(32, 0), 12.0, Color(col, 0.7))
				&"penetrator":
					for y: float in [-12.0, 12.0]:
						if tier > 0:
							_metal_rect(ci, Rect2(58, y - 4, 6.0 * tier, 8))
					if tier > 0:
						var tip := 58.0 + 6.0 * tier
						for y: float in [-12.0, 12.0]:
							ci.draw_colored_polygon(PackedVector2Array([Vector2(tip - 8, y - 4), Vector2(tip, y - 9), Vector2(tip, y - 4)]), M_LIGHT)
							ci.draw_colored_polygon(PackedVector2Array([Vector2(tip - 8, y + 4), Vector2(tip, y + 9), Vector2(tip, y + 4)]), M_LIGHT)
					if k.evolved: # Railspike: twin long rails with an energy channel
						_metal_rect(ci, Rect2(8, -15, 84, 7))
						_metal_rect(ci, Rect2(8, 8, 84, 7))
						ci.draw_rect(Rect2(12, -3, 80, 6), Color(col, 0.35 + 0.35 * k.charge))
						ci.draw_line(Vector2(12, 0), Vector2(92, 0), Color(1, 1, 1, 0.7), 1.5)
				&"sensor":
					if k.evolved:
						glow(ci, Vector2(-30, 0), 22.0, Color(col, 0.5))
		&"nova":
			match k.main_id:
				&"siege":
					if tier > 0:
						var ext := 8.0 * tier + (14.0 if k.evolved else 0.0)
						_metal_rect(ci, Rect2(56, -10, ext, 20))
						ci.draw_arc(Vector2(56 + ext, 0), 10.0, -PI / 2, PI / 2, 8, RIM, 2.0)
						for side: float in [-1.0, 1.0]:
							ci.draw_line(Vector2(10, side * 15), Vector2(-4, side * 30), M_LIGHT, 4.0)
					if k.evolved: # Quake: hammer brake
						_metal_rect(ci, Rect2(52 + 8.0 * tier + 14.0, -17, 12, 34))
						ci.draw_rect(Rect2(55 + 8.0 * tier + 14.0, -12, 6, 24), Color(col, 0.7))
				&"incendiary":
					if k.evolved: # Inferno: flickering muzzle flame
						var m := Vector2(58, 0)
						var f := 0.7 + 0.3 * sin(k.t * 23.0)
						ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -7), m + Vector2(16 * f, 0), m + Vector2(0, 7)]), Color("FF7A3D", 0.85))
						glow(ci, m + Vector2(6, 0), 14.0, Color("FFD36B", 0.6))
				&"cluster":
					var holes := 2 * tier
					for i in range(holes):
						var p := Vector2(-14, 0) + Vector2.from_angle(TAU * i / maxf(holes, 1)) * 21.0
						ci.draw_circle(p, 3.2, Color("120B05"))
						ci.draw_arc(p, 3.2, 0, TAU, 8, Color(col, 0.6), 1.0)
					if k.evolved: # Cascade: triple launch tubes
						for y: float in [-15.0, 0.0, 15.0]:
							_metal_rect(ci, Rect2(40, y - 6, 32, 12))
							ci.draw_circle(Vector2(72, y), 4.0, Color("120B05"))
			# reactor charge glow
			glow(ci, Vector2(-14, 0), 16.0 + 10.0 * k.charge, Color(col, 0.25 + 0.5 * k.charge))
		&"lance":
			match k.main_id:
				&"focus":
					if tier > 0:
						_metal_rect(ci, Rect2(62, -4, 6.0 * tier + 4.0, 8))
						for i in range(tier):
							ci.draw_rect(Rect2(64 + i * 6, -8 + i, 3, 16 - 2 * i), Color(col, 0.55 + 0.45 * k.charge))
					if k.evolved: # Phase Beam: long emitter, glowing rings
						_metal_rect(ci, Rect2(60, -5, 38, 10))
						for i in range(4):
							ci.draw_rect(Rect2(66 + i * 8, -9, 3, 18), Color(col, 0.6 + 0.4 * k.charge))
						glow(ci, Vector2(98, 0), 10.0, Color(col, 0.8))
				&"arc":
					var coils: Array[Vector2] = [Vector2(66, 0)]
					if k.evolved:
						coils = [Vector2(60, -15), Vector2(72, 0), Vector2(60, 15)]
					for c in coils:
						var r := 5.0 + 2.0 * tier
						ci.draw_circle(c, r, M_MID)
						ci.draw_arc(c, r, 0, TAU, 14, RIM, 1.5)
						glow(ci, c, r + 6.0, Color(col, 0.55))
						var a := k.t * 9.0 + c.y
						var p1 := c + Vector2.from_angle(a) * (r + 6.0)
						ci.draw_polyline(PackedVector2Array([c, c.lerp(p1, 0.5) + Vector2(3, -3).rotated(a), p1]), Color("E6D9FF", 0.8), 1.2)
				&"overcharge":
					if k.evolved: # Annihilator: heavy barrel sleeve
						_metal_rect(ci, Rect2(4, -10, 64, 20))
						ci.draw_rect(Rect2(8, -3, 58, 6), Color(col, 0.5 + 0.5 * k.charge))
			glow(ci, Vector2(-12, 0), 12.0 + 6.0 * k.charge, Color(col, 0.3 + 0.4 * k.charge))
	# core breathing (all turret towers)
	var core := {&"pulse": Vector2(-4, 0), &"nova": Vector2(-14, 0), &"lance": Vector2(-12, 0)}.get(k.def.id, Vector2.ZERO) as Vector2
	glow(ci, core, 14.0, Color(col, 0.18 + 0.12 * sin(k.t * 2.4)))


static func _beacon(ci: CanvasItem, k: Look, col: Color) -> void:
	var tier := k.main_tier
	var overclock := k.evolved and k.main_id == &"amplifier"
	var rings := 2 + (tier if k.main_id == &"amplifier" else 0)
	var speed := 0.6 * (2.2 if overclock else 1.0)
	var ring_col := ICE if k.main_id == &"cryo" else col
	glow(ci, Vector2.ZERO, 34.0, Color(col, 0.22 + 0.1 * sin(k.t * 2.0)))
	for j in range(rings):
		_ellipse_line(ci, Vector2.ZERO, 34.0 + j * 2.0, 12.0, k.t * speed + j * PI / rings, Color(ring_col, 0.85 - 0.12 * j), 3.0)
	if k.main_id == &"cryo":
		var n := 8 if k.evolved else 2 * tier
		for i in range(n):
			var a := TAU * i / maxf(n, 1) + k.t * 0.3
			var c := Vector2.from_angle(a) * (40.0 if k.evolved else 26.0)
			var d := Vector2.from_angle(a)
			var tn := Vector2(-d.y, d.x)
			ci.draw_colored_polygon(PackedVector2Array([c + d * 9, c + tn * 4, c - d * 5, c - tn * 4]), Color(ICE, 0.9))
		if k.evolved:
			ci.draw_arc(Vector2.ZERO, 50.0, 0, TAU, 40, Color(ICE, 0.45), 2.0)
	var core_r := 11.0 + (4.0 if overclock else 0.0) + (1.0 * tier if k.main_id == &"amplifier" else 0.0)
	glow(ci, Vector2.ZERO, core_r + 12.0, Color(col, 0.7))
	ci.draw_circle(Vector2.ZERO, core_r, col.lightened(0.35))
	ci.draw_circle(Vector2.ZERO, core_r * 0.5, Color(1, 1, 1, 0.9))
	# antenna (+ relay dishes)
	ci.draw_line(Vector2(0, -12), Vector2(0, -50), Color("9FB8D8"), 3.5)
	ci.draw_line(Vector2(-10, -40), Vector2(10, -40), Color("9FB8D8"), 3.0)
	ci.draw_circle(Vector2(0, -52), 4.5, col if fmod(k.t, 1.2) < 0.9 else Color.WHITE)
	if k.main_id == &"relay":
		for i in range(tier):
			var side := -1.0 if i % 2 == 0 else 1.0
			_dish(ci, Vector2(side * 14, -28 + i * 6), 6.0, side * 0.6, P.ORANGE)
		if k.evolved: # Mint: orbiting credit chip
			var c := Vector2.from_angle(k.t * 1.4) * 44.0
			var hexp := PackedVector2Array()
			for j in range(6):
				hexp.append(c + Vector2.from_angle(TAU * j / 6.0) * 8.0)
			ci.draw_colored_polygon(hexp, P.ORANGE)
			glow(ci, c, 14.0, Color(P.ORANGE, 0.5))


# ------------------------------------------------------------------ helpers

static func _metal_rect(ci: CanvasItem, r: Rect2) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	ci.draw_polygon(pts, PackedColorArray([M_LIGHT, M_LIGHT, M_DARK, M_DARK]))
	pts.append(pts[0])
	ci.draw_polyline(pts, RIM, 1.2)


static func _hex_ring(ci: CanvasItem, c: Vector2, r: float, rot: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in range(7):
		pts.append(c + Vector2.from_angle(rot + TAU * i / 6.0) * r)
	ci.draw_polyline(pts, col, w)


static func _ellipse_line(ci: CanvasItem, c: Vector2, rx: float, ry: float, rot: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	ci.draw_polyline(pts, col, w)


## Radar / relay dish: an ellipse seen edge-on that turns.
static func _dish(ci: CanvasItem, c: Vector2, rx: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var squash := absf(cos(rot)) * 0.8 + 0.2
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx * squash, sin(a) * rx))
	ci.draw_polygon(pts, PackedColorArray([M_LIGHT]))
	pts.append(pts[0])
	ci.draw_polyline(pts, RIM, 1.5)
	ci.draw_circle(c, 2.5, col)
