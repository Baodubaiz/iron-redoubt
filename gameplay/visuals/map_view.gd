class_name MapView
extends Node2D
## Reforged battlefield renderer for a MapDef (presentation only; collision / placement rules
## still come from MapDef + PlacementRules). Same API as before: `map`, set_state(night, route).
##   static layer (this node, redrawn only on state changes): metal floor tiles, map-specific
##     floor detail, machinery on blocked terrain, illuminated tracks, overload pads, entrances,
##     night overlay
##   dynamic layer (child): moving direction chevrons, overload rings, air-lane arrows, animated
##     gates (Prism), spawn portals, the Iron Redoubt core (colour follows base HP, flashes on hit)
## It also attaches a TowerVisual to every tower the controller builds.

const P = preload("res://ui/style/visual_palette.gd")
const WORLD := Rect2(0, 0, 1280, 720)

var map: MapDef
var night: bool = false
var active_route: int = 0

var _fx: Node2D
var _ctrl: MatchController
var _t := 0.0
var _gates: Array[Dictionary] = [] ## {pos, dir, route, open (0..1)}
var _entries: Array[Dictionary] = [] ## {pos, dir}
var _base_hit := 0.0
var _look: Dictionary
var _boss_ui: Node2D
var _boss: Enemy
var _boss_lag := 0.0
## Baked floor: covers the painted tile area (tiles -6..21 x -3..11 of 80 px).
const FLOOR_ORIGIN := Vector2(-480, -240)
const FLOOR_SIZE := Vector2i(2240, 1200)
var _floor_vp: SubViewport
var _enemy_under: Node2D
var _enemy_over: Node2D


class _FloorPainter extends Node2D:
	var m: MapDef
	var look: Dictionary

	func _draw() -> void:
		MapView.paint_floor(self, m, look)


func _bake_floor() -> void:
	_floor_vp = SubViewport.new()
	_floor_vp.name = "FloorBake"
	_floor_vp.size = FLOOR_SIZE
	_floor_vp.disable_3d = true
	_floor_vp.transparent_bg = true
	_floor_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := _FloorPainter.new()
	painter.m = map
	painter.look = _look
	painter.position = -FLOOR_ORIGIN
	_floor_vp.add_child(painter)
	add_child(_floor_vp)


func set_state(is_night: bool, route: int) -> void:
	if night != is_night or active_route != route:
		night = is_night
		active_route = route
		queue_redraw()


func _ready() -> void:
	z_index = -10
	_look = P.map_look(map.region_id() if map != null else &"circuit")
	if map != null and not DisplayServer.get_name() == "headless":
		_bake_floor()
	_fx = Node2D.new()
	_fx.name = "MapFx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	if map != null:
		_compute_entries()
		_compute_gates()
	_ctrl = get_parent() as MatchController
	if _ctrl != null:
		_ctrl.tower_built.connect(func(t: Tower) -> void: t.add_child(TowerVisual.new(t)))
		_ctrl.tower_upgraded.connect(func(t: Tower) -> void:
			var v := t.get_node_or_null("Visual") as TowerVisual
			if v != null:
				v.on_upgraded())
		_ctrl.enemy_escaped.connect(func(_e: Enemy) -> void: _base_hit = 1.0)
		_wire_enemies.call_deferred() # enemies_root is created after this node
		# Shared enemy layers (perf): every shadow in one node under the enemies, every HP bar / status
		# icon in one node above them.
		EnemyVisual.shared_layers = true
		_enemy_under = Node2D.new()
		_enemy_under.name = "EnemyShadows"
		_enemy_under.z_as_relative = false
		_enemy_under.z_index = 0
		_enemy_under.draw.connect(_draw_enemy_under)
		add_child(_enemy_under)
		_enemy_over = Node2D.new()
		_enemy_over.name = "EnemyBars"
		_enemy_over.z_as_relative = false
		_enemy_over.z_index = 4
		_enemy_over.draw.connect(_draw_enemy_over)
		add_child(_enemy_over)
		_boss_ui = Node2D.new()
		_boss_ui.name = "BossBar"
		_boss_ui.z_as_relative = false
		_boss_ui.z_index = 50
		_boss_ui.draw.connect(_draw_boss_bar)
		add_child(_boss_ui)


func _draw_enemy_under() -> void:
	for e in _ctrl.enemies:
		if e.is_alive():
			var v := e.get_node_or_null("Visual") as EnemyVisual
			if v != null:
				v.draw_shadow(_enemy_under, e.position, v.fade())


func _draw_enemy_over() -> void:
	for e in _ctrl.enemies:
		if e.is_alive():
			var v := e.get_node_or_null("Visual") as EnemyVisual
			if v != null:
				v.draw_overlay(_enemy_over, e.position)


func _exit_tree() -> void:
	EnemyVisual.shared_layers = false


func _wire_enemies() -> void:
	if _ctrl == null or _ctrl.enemies_root == null:
		return
	for n in _ctrl.enemies_root.get_children():
		_attach_enemy(n)
	_ctrl.enemies_root.child_entered_tree.connect(func(n: Node) -> void: _attach_enemy.call_deferred(n))


func _attach_enemy(n: Node) -> void:
	if n is Enemy and is_instance_valid(n) and not n.has_node("Visual"):
		n.add_child(EnemyVisual.new(n))


func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	_t += delta
	_base_hit = maxf(0.0, _base_hit - delta * 2.5)
	for g in _gates:
		var want := 1.0 if g["route"] == active_route else 0.0
		g["open"] = move_toward(g["open"], want, delta * 1.6)
	_fx.queue_redraw()
	if _ctrl != null:
		EnemyVisual.crowd = _ctrl.enemies.size()
	if _enemy_under != null:
		_enemy_under.queue_redraw()
		_enemy_over.queue_redraw()
	if _boss_ui != null:
		_track_boss(delta)


# ================================================================= geometry helpers

func _compute_entries() -> void:
	_entries.clear()
	for route in map.routes:
		if route.size() < 2:
			continue
		var p := route[0]
		var dir := (route[1] - route[0]).normalized()
		for i in range(route.size() - 1): # first point of the route inside the world
			var a := route[i]
			var b := route[i + 1]
			var found := false
			for k in range(21):
				var q := a.lerp(b, k / 20.0)
				if WORLD.grow(-4).has_point(q):
					p = q
					dir = (b - a).normalized()
					found = true
					break
			if found:
				break
		_entries.append({"pos": p, "dir": dir})


## One gate per ground route on dynamic-route maps, where that route leaves the others.
func _compute_gates() -> void:
	_gates.clear()
	if not map.dynamic_routes or map.routes.size() < 2:
		return
	for i in range(map.routes.size()):
		var route := map.routes[i]
		var placed := false
		for s in range(route.size() - 1):
			var a := route[s]
			var b := route[s + 1]
			var steps := int(a.distance_to(b) / 8.0) + 1
			for k in range(steps):
				var q := a.lerp(b, float(k) / steps)
				var far := true
				for j in range(map.routes.size()):
					if j != i and _dist_to_polyline(q, map.routes[j]) < map.path_half_width * 2.4:
						far = false
						break
				if far and WORLD.has_point(q):
					var d := (b - a).normalized()
					_gates.append({"pos": q + d * 18.0, "dir": d, "route": i, "open": 1.0 if i == active_route else 0.0})
					placed = true
					break
			if placed:
				break


static func _dist_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best


static func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h % 1000) / 1000.0


# ================================================================= static layer

func _draw() -> void:
	if map == null:
		return
	var accent: Color = _look["accent"]
	var accent2: Color = _look["accent2"]
	var floor_col: Color = _look["floor"]
	draw_rect(Rect2(-2000, -2000, 5280, 4720), floor_col.darkened(0.25))
	# Floor tiles + region detail are baked once into a texture (2026-11-19 perf: ~2000 draw commands per
	# frame before); only the gameplay-relevant shapes below are drawn live.
	if _floor_vp != null:
		draw_texture(_floor_vp.get_texture(), FLOOR_ORIGIN)
	else:
		paint_floor(self, map, _look)
	for z in map.range_bonus_zones:
		_overload_pad(Vector2(z.x, z.y), z.z)
	for ar in map.air_routes:
		_dashed(ar, Color(P.GREEN, 0.12), 2.0, 14.0, 26.0)
	for rect in map.blocked_rects:
		_machine(rect, accent, accent2)
	for i in range(map.routes.size()):
		_track(map.routes[i], map.dynamic_routes and i != active_route, accent)
	for e in _entries:
		_portal_pad(e["pos"], e["dir"])
	if night:
		draw_rect(Rect2(-2000, -2000, 5280, 4720), Color(0.0, 0.01, 0.08, 0.52))


## Metal floor tiles (past the 1280x720 world too, so wide / tall screens see floor) + region detail.
## Static: painted once into the baked floor texture.
static func paint_floor(ci: CanvasItem, m: MapDef, look: Dictionary) -> void:
	var accent: Color = look["accent"]
	var accent2: Color = look["accent2"]
	var floor_col: Color = look["floor"]
	for ty in range(-3, 12):
		for tx in range(-6, 22):
			var r := Rect2(tx * 80, ty * 80, 80, 80)
			var v := _hash(tx, ty)
			ci.draw_rect(r, floor_col.lightened(0.02 + v * 0.05))
			ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(1, 1, 1, 0.045), 1.0)
			ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(1, 1, 1, 0.03), 1.0)
			ci.draw_line(Vector2(r.position.x, r.end.y - 1), r.end - Vector2(0, 1), Color(0, 0, 0, 0.25), 1.5)
			if v > 0.72: # bolted service panel
				var inner := r.grow(-18)
				ci.draw_rect(inner, Color(0, 0, 0, 0.12))
				ci.draw_rect(inner, Color(accent, 0.06), false, 1.0)
				for k in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
					ci.draw_circle(k, 1.6, Color(1, 1, 1, 0.08))
	_floor_detail(ci, m, accent, accent2)


static func _floor_detail(ci: CanvasItem, map: MapDef, accent: Color, accent2: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(map.id))
	match map.region_id():
		&"delta": # energy canals
			for k in range(3):
				var y := 120.0 + k * 240.0 + rng.randf_range(-30, 30)
				var pts := PackedVector2Array()
				for x in range(-20, 1320, 40):
					pts.append(Vector2(x, y + sin(x * 0.012 + k) * 22.0))
				ci.draw_polyline(pts, Color(accent, 0.05), 30.0)
				ci.draw_polyline(pts, Color(accent2, 0.12), 2.0)
		&"prism": # crystalline facets
			for k in range(26):
				var c := Vector2(rng.randf() * 1280.0, rng.randf() * 720.0)
				var r := rng.randf_range(18.0, 46.0)
				var a := rng.randf() * TAU
				var tri := PackedVector2Array([c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a + 2.2) * r * 0.7,
					c + Vector2.from_angle(a + 4.1) * r * 0.8])
				ci.draw_colored_polygon(tri, Color(accent if k % 4 else accent2, 0.05))
				tri.append(tri[0])
				ci.draw_polyline(tri, Color(accent, 0.10), 1.0)
		&"rift": # glowing fissures in cracked plating
			for k in range(9):
				var p := Vector2(rng.randf() * 1280.0, rng.randf() * 720.0)
				var crack := PackedVector2Array([p])
				var ang := rng.randf() * TAU
				for s in range(rng.randi_range(4, 7)):
					ang += rng.randf_range(-0.7, 0.7)
					p += Vector2.from_angle(ang) * rng.randf_range(24.0, 60.0)
					crack.append(p)
				ci.draw_polyline(crack, Color(accent2, 0.06), 9.0)
				ci.draw_polyline(crack, Color(accent, 0.22), 1.5)
				ci.draw_circle(crack[crack.size() - 1], 2.5, Color(accent, 0.4))
		_: # circuit traces
			for k in range(20):
				var p := Vector2(snappedf(rng.randf() * 1280.0, 40.0), snappedf(rng.randf() * 720.0, 40.0))
				var line := PackedVector2Array([p])
				var horiz := rng.randf() < 0.5
				for s in range(rng.randi_range(2, 4)):
					var d := snappedf(rng.randf_range(80.0, 200.0), 40.0) * (1.0 if rng.randf() < 0.5 else -1.0)
					p += Vector2(d, 0.0) if horiz else Vector2(0.0, d)
					line.append(p)
					horiz = not horiz
				ci.draw_polyline(line, Color(accent, 0.05), 5.0)
				ci.draw_polyline(line, Color(accent, 0.13), 1.5)
				ci.draw_circle(line[0], 3.5, Color(accent, 0.25))


## Blocked terrain = raised machinery (clearly not buildable, distinct per map).
func _machine(r: Rect2, accent: Color, accent2: Color) -> void:
	var block: Color = _look["block"]
	draw_rect(Rect2(r.position + Vector2(8, 12), r.size), Color(0, 0, 0, 0.4))
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([block.lightened(0.18), block.lightened(0.12), block.darkened(0.25), block.darkened(0.2)]))
	draw_rect(r, Color(accent2, 0.4), false, 2.0)
	draw_line(r.position + Vector2(2, 2), Vector2(r.end.x - 2, r.position.y + 2), Color(1, 1, 1, 0.12), 2.0)
	var inner := r.grow(-minf(r.size.x, r.size.y) * 0.14)
	draw_rect(inner, block.darkened(0.35))
	var c := r.get_center()
	var m := minf(inner.size.x, inner.size.y)
	match map.region_id():
		&"delta": # cooling unit: vent slats + fan
			var y := inner.position.y + 6.0
			while y < inner.end.y - 6.0:
				draw_line(Vector2(inner.position.x + 6, y), Vector2(inner.end.x - 6, y), Color(0, 0, 0, 0.35), 3.0)
				y += 9.0
			draw_circle(c, m * 0.32, block.darkened(0.1))
			draw_arc(c, m * 0.32, 0, TAU, 28, Color(accent, 0.5), 2.0)
			for k in range(4):
				draw_line(c, c + Vector2.from_angle(PI * 0.5 * k + 0.4) * m * 0.28, Color(accent2, 0.5), 3.0)
		&"rift": # rift shard reactor: jagged red crystal in a clamp frame
			var h := m * 0.44
			var shard := PackedVector2Array([c + Vector2(-h * 0.15, -h), c + Vector2(h * 0.45, -h * 0.2),
				c + Vector2(h * 0.2, h), c + Vector2(-h * 0.5, h * 0.25)])
			draw_colored_polygon(shard, Color(accent2, 0.85))
			shard.append(shard[0])
			draw_polyline(shard, accent, 2.0)
			draw_line(c + Vector2(-h * 0.15, -h), c + Vector2(h * 0.2, h), Color(1, 0.9, 0.8, 0.5), 1.5)
			for sx: float in [-1.0, 1.0]:
				draw_rect(Rect2(c + Vector2(sx * h * 0.85 - 3, -h * 0.6), Vector2(6, h * 1.2)), block.lightened(0.2))
		&"prism": # energy crystal housing
			var h := m * 0.42
			var d := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.6, 0), c + Vector2(0, h), c + Vector2(-h * 0.6, 0)])
			draw_polygon(d, PackedColorArray([accent.lightened(0.3), accent, accent.darkened(0.4), accent]))
			draw_circle(c, h * 0.18, accent2)
		_: # transformer coils + hazard stripe
			var n := 2 if inner.size.x > inner.size.y * 1.4 or inner.size.y > inner.size.x * 1.4 else 1
			for k in range(n):
				var cc := c
				if n == 2:
					cc = c + (Vector2(inner.size.x * 0.22, 0) if inner.size.x > inner.size.y else Vector2(0, inner.size.y * 0.22)) * (1 if k else -1)
				var rr := m * (0.3 if n == 2 else 0.36)
				draw_circle(cc, rr, block.darkened(0.15))
				for ring in range(3):
					draw_arc(cc, rr * (1.0 - ring * 0.28), 0, TAU, 24, Color(accent, 0.35 - ring * 0.08), 2.0)
				draw_circle(cc, rr * 0.2, Color(accent, 0.7))
			var sx := r.position.x + 4.0
			while sx < r.end.x - 10.0:
				draw_line(Vector2(sx, r.end.y - 6), Vector2(sx + 7, r.end.y - 6), P.ORANGE if int(sx / 11.0) % 2 == 0 else Color(0, 0, 0, 0.5), 3.0)
				sx += 11.0


func _track(route: PackedVector2Array, closed: bool, accent: Color) -> void:
	if route.size() < 2:
		return
	var hw := map.path_half_width
	var a := 0.35 if closed else 1.0
	var track: Color = _look["path"]
	_band(route, Color(accent, 0.07 * a), hw * 2.0 + 26.0)
	_band(route, Color(accent, 0.55 * a), hw * 2.0 + 6.0)
	_band(route, Color("0A0F1E"), hw * 2.0)
	_band(route, track if not closed else track.darkened(0.3), hw * 2.0 - 8.0)
	# cross treads
	for i in range(route.size() - 1):
		var p0 := route[i]
		var p1 := route[i + 1]
		var length := p0.distance_to(p1)
		if length < 1.0:
			continue
		var dir := (p1 - p0) / length
		var n := Vector2(-dir.y, dir.x)
		var d := 12.0
		while d < length:
			var c := p0 + dir * d
			draw_line(c - n * (hw - 8.0), c + n * (hw - 8.0), Color(1, 1, 1, 0.025 * a), 2.0)
			d += 24.0
	draw_polyline(route, Color(accent, 0.12 * a), 2.0)
	if closed: # hazard marks on a closed lane
		for i in range(route.size() - 1):
			var c := route[i].lerp(route[i + 1], 0.5)
			draw_circle(c, 5.0, Color(P.RED, 0.35))


func _band(route: PackedVector2Array, col: Color, w: float) -> void:
	draw_polyline(route, col, w)
	for j in range(1, route.size() - 1):
		draw_circle(route[j], w * 0.5, col)


func _overload_pad(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color(P.ORANGE, 0.05))
	draw_arc(c, r, 0, TAU, 48, Color(P.ORANGE, 0.22), 1.5)
	var hexa := PackedVector2Array()
	for k in range(7):
		hexa.append(c + Vector2.from_angle(TAU * k / 6.0) * 20.0)
	draw_colored_polygon(hexa.slice(0, 6), Color("2A1D10"))
	draw_polyline(hexa, Color(P.ORANGE, 0.8), 2.5)


func _portal_pad(p: Vector2, dir: Vector2) -> void:
	var n := Vector2(-dir.y, dir.x)
	var hw := map.path_half_width + 6.0
	draw_line(p - n * hw, p + n * hw, Color(P.RED, 0.8), 4.0)
	draw_line(p - n * hw + dir * 6.0, p + n * hw + dir * 6.0, Color(P.RED, 0.3), 2.0)


func _dashed(route: PackedVector2Array, col: Color, w: float, dash: float, gap: float) -> void:
	for i in range(route.size() - 1):
		var a := route[i]
		var c := route[i + 1]
		var length := a.distance_to(c)
		var dir := (c - a) / maxf(length, 0.001)
		var d := 0.0
		while d < length:
			draw_line(a + dir * d, a + dir * minf(d + dash, length), col, w)
			d += dash + gap


# ================================================================= dynamic layer

func _draw_fx() -> void:
	if map == null:
		return
	var accent: Color = _look["accent"]
	var dimk := 0.6 if night else 1.0
	# direction chevrons flowing along open routes
	for i in range(map.routes.size()):
		if map.dynamic_routes and i != active_route:
			continue
		_flow(map.routes[i], 72.0, 38.0, Color(accent, 0.38 * dimk), 9.0)
	for ar in map.air_routes:
		_flow(ar, 120.0, 30.0, Color(P.GREEN, 0.22 * dimk), 5.0)
	# overload nodes
	for z in map.range_bonus_zones:
		var c := Vector2(z.x, z.y)
		for k in range(6):
			var a0 := _t * 0.8 + TAU * k / 6.0
			_fx.draw_arc(c, 28.0, a0, a0 + 0.6, 6, Color(P.ORANGE, 0.75), 3.0)
		TowerArt.glow(_fx, c, 16.0 + 3.0 * sin(_t * 3.0), Color(P.ORANGE, 0.55))
	# spawn portals
	for e in _entries:
		var p: Vector2 = e["pos"]
		var hexa := PackedVector2Array()
		for k in range(7):
			hexa.append(p + Vector2.from_angle(_t * 1.2 + TAU * k / 6.0) * 15.0)
		_fx.draw_polyline(hexa, Color(P.RED, 0.8 * dimk), 2.5)
		TowerArt.glow(_fx, p, 22.0 + 4.0 * sin(_t * 4.0), Color(P.RED, 0.35))
	# gates
	for g in _gates:
		_gate(g)
	_core()


func _flow(route: PackedVector2Array, spacing: float, speed: float, col: Color, size: float) -> void:
	var off := fmod(_t * speed, spacing)
	var carried := 0.0
	for i in range(route.size() - 1):
		var a := route[i]
		var b := route[i + 1]
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var dir := (b - a) / length
		var n := Vector2(-dir.y, dir.x)
		var d := fmod(spacing - fmod(carried, spacing) + off, spacing)
		while d < length:
			var c := a + dir * d
			_fx.draw_polyline(PackedVector2Array([c - dir * size * 0.7 + n * size, c + dir * size * 0.3, c - dir * size * 0.7 - n * size]), col, 3.0)
			d += spacing
		carried += length


## Prism gate: a gantry across the lane. Closed = barrier panels with hazard stripes and red
## lights; opening = panels slide into the posts (blinking), open = green lights.
func _gate(g: Dictionary) -> void:
	var c: Vector2 = g["pos"]
	var d: Vector2 = g["dir"]
	var n := Vector2(-d.y, d.x)
	var hw := map.path_half_width + 2.0
	var open: float = g["open"]
	var closed := 1.0 - open
	# barrier panels (each covers half the lane when closed)
	for side: float in [-1.0, 1.0]:
		var inner := c + n * side * (hw * open)
		var outer := c + n * side * hw
		if inner.distance_to(outer) > 1.0:
			var quad := PackedVector2Array([inner - d * 8.0, outer - d * 8.0, outer + d * 8.0, inner + d * 8.0])
			_fx.draw_polygon(quad, PackedColorArray([Color("3A4E73"), Color("22314F"), Color("22314F"), Color("3A4E73")]))
			var steps := int(inner.distance_to(outer) / 9.0)
			for k in range(steps):
				var a := outer.lerp(inner, (k + 0.5) / maxf(steps, 1))
				_fx.draw_line(a - d * 6.0 - n * side * 3.0, a + d * 6.0 + n * side * 3.0,
					P.ORANGE if k % 2 == 0 else Color(0, 0, 0, 0.6), 3.0)
			quad.append(quad[0])
			_fx.draw_polyline(quad, Color(TowerArt.RIM, 0.9), 1.5)
	# posts + overhead beam
	for side: float in [-1.0, 1.0]:
		var pc := c + n * side * (hw + 9.0)
		var post := PackedVector2Array([pc - d * 11 - n * 8, pc + d * 11 - n * 8, pc + d * 11 + n * 8, pc - d * 11 + n * 8])
		_fx.draw_polygon(post, PackedColorArray([Color("5A6F96"), Color("3A4E73"), Color("22314F"), Color("22314F")]))
		post.append(post[0])
		_fx.draw_polyline(post, TowerArt.RIM, 1.5)
	_fx.draw_line(c - n * (hw + 9.0) - d * 12.0, c + n * (hw + 9.0) - d * 12.0, Color("8FA6CF", 0.5), 2.0)
	var light := P.GREEN if open > 0.5 else P.RED
	var blink := 1.0 if open > 0.98 or open < 0.02 else (0.4 + 0.6 * absf(sin(_t * 9.0)))
	for side: float in [-1.0, 1.0]:
		var pc := c + n * side * (hw + 9.0)
		_fx.draw_circle(pc, 4.0, light)
		TowerArt.glow(_fx, pc, 14.0, Color(light, 0.8 * blink))
	if closed > 0.5: # X on the lane behind a closed gate
		var x := c + d * 30.0
		_fx.draw_line(x - Vector2(8, 8), x + Vector2(8, 8), Color(P.RED, 0.7 * closed), 3.0)
		_fx.draw_line(x - Vector2(8, -8), x + Vector2(8, -8), Color(P.RED, 0.7 * closed), 3.0)


## The Iron Redoubt core at the base: rotating rings, colour follows base HP, flashes on a leak.
func _core() -> void:
	var b := map.base_position()
	var ratio := 1.0
	if _ctrl != null and _ctrl.base != null and _ctrl.base.max_hp > 0:
		ratio = clampf(float(_ctrl.base.hp) / _ctrl.base.max_hp, 0.0, 1.0)
	var col := P.GREEN if ratio > 0.6 else (P.ORANGE if ratio > 0.3 else P.RED)
	var shake := Vector2(sin(_t * 60.0), cos(_t * 53.0)) * 3.0 * _base_hit
	var c := b + shake
	TowerArt.glow(_fx, c, 54.0 + 6.0 * sin(_t * 2.0), Color(col, 0.22 + 0.3 * _base_hit))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in range(7):
		outer.append(c + Vector2.from_angle(TAU * k / 6.0) * 30.0)
		inner.append(c + Vector2.from_angle(TAU * k / 6.0 + PI / 6.0) * 18.0)
	_fx.draw_colored_polygon(outer.slice(0, 6), Color("141D31"))
	_fx.draw_polyline(outer, Color(col, 0.9), 4.0)
	_fx.draw_colored_polygon(inner.slice(0, 6), Color(col, 0.35))
	_fx.draw_polyline(inner, col, 2.0)
	for k in range(3):
		var a0 := _t * (0.9 + k * 0.4) * (1 if k % 2 == 0 else -1) + k
		_fx.draw_arc(c, 38.0 + k * 5.0, a0, a0 + 1.4, 12, Color(col, 0.6 - k * 0.15), 2.0)
	TowerArt.glow(_fx, c, 12.0, Color(1, 1, 1, 0.8))
	if _base_hit > 0.0:
		_fx.draw_arc(c, 30.0 + 30.0 * (1.0 - _base_hit), 0, TAU, 32, Color(P.RED, _base_hit), 3.0)


# ================================================================= boss HP bar

func _track_boss(delta: float) -> void:
	if _boss != null and (not is_instance_valid(_boss) or not _boss.is_alive()):
		_boss = null
	if _boss == null and _ctrl.enemies_root != null:
		for n in _ctrl.enemies_root.get_children():
			if n is Enemy and (n as Enemy).is_boss() and (n as Enemy).is_alive():
				_boss = n
				_boss_lag = _boss.hp
				break
	if _boss != null:
		_boss_lag = move_toward(_boss_lag, _boss.hp, _boss.max_hp * delta * 0.25) if _boss_lag > _boss.hp else _boss.hp
	_boss_ui.queue_redraw()


func _draw_boss_bar() -> void:
	if _boss == null:
		return
	# bottom-centre of the world: the boss maps keep their lanes away from this strip
	var w := 400.0
	var x := 640.0 - w * 0.5
	var y := 700.0
	var bg := PackedVector2Array([Vector2(x - 16, y - 24), Vector2(x + w + 4, y - 24), Vector2(x + w + 16, y - 12),
		Vector2(x + w + 16, y + 20), Vector2(x - 4, y + 20), Vector2(x - 16, y + 8)])
	_boss_ui.draw_colored_polygon(bg, Color(P.BG_DEEP, 0.85))
	bg.append(bg[0])
	_boss_ui.draw_polyline(bg, Color(P.RED, 0.6), 1.5)
	var f := UiKit.font("head", 3)
	var title := I18n.t(_boss.def.display_name).to_upper()
	_boss_ui.draw_string(f, Vector2(x, y - 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, P.RED)
	for i in range(_boss.max_boss_phases):
		var on := i < _boss.boss_phase
		var c := Vector2(x + w - 40 + i * 16, y - 12)
		var d := PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)])
		if i < _boss.max_boss_phases:
			_boss_ui.draw_colored_polygon(d, P.RED if on else Color(P.RED, 0.2))
	var tk := _boss.telegraph_kind
	if tk != 0 and tk != EnemyAbilities.SUMMON_KIND and fmod(_t, 0.5) < 0.32:
		var lbl: String = _boss.current_skill.label if _boss.current_skill != null and _boss.current_skill.label != "" 			else EnemyAbilities.KIND_LABEL.get(tk, "EMP incoming!")
		var warn := I18n.t(lbl)
		# right-aligned, ending before the phase pips, so it never runs into the boss name on the left
		_boss_ui.draw_string(f, Vector2(x + w - 262, y - 6), warn, HORIZONTAL_ALIGNMENT_RIGHT, 200, 13, Color.WHITE)
	var ratio := _boss.hp / maxf(_boss.max_hp, 1.0)
	_boss_ui.draw_rect(Rect2(x, y, w, 10), Color(0, 0, 0, 0.8))
	_boss_ui.draw_rect(Rect2(x, y, w * (_boss_lag / maxf(_boss.max_hp, 1.0)), 10), Color(1, 1, 1, 0.65))
	_boss_ui.draw_rect(Rect2(x, y, w * ratio, 10), P.RED)
	# phase thresholds
	for k: float in ([0.66, 0.33] if _boss.max_boss_phases >= 3 else [0.66]):
		_boss_ui.draw_line(Vector2(x + w * k, y - 2), Vector2(x + w * k, y + 12), Color(1, 1, 1, 0.5), 1.0)
