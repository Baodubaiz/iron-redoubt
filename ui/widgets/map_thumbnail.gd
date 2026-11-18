class_name MapThumbnail
extends Control
## Miniature of a real MapDef (routes, blocked terrain, overload nodes, air lanes, entrances, base)
## in the map's region colours, plus level badges derived from the level data (boss, night, air,
## gates). Redrawn only on resize. Presentation only.

const P = preload("res://ui/style/visual_palette.gd")
const WORLD := Vector2(1280, 720)

var map: MapDef
var level: LevelDef
var dim: bool = false
var show_badges: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)


func badges() -> Array[Array]:
	var out: Array[Array] = []
	if level == null:
		return out
	var boss := false
	var night := false
	var air := false
	for w in level.waves:
		boss = boss or w.is_boss
		night = night or w.night
		for g in w.groups:
			if g.enemy != null and g.enemy.flying:
				air = true
	if boss: out.append(["boss", P.RED])
	if night: out.append(["night", P.BLUE])
	if air: out.append(["air", P.GREEN])
	if map != null and map.dynamic_routes: out.append(["gate", P.VIOLET])
	return out


func _draw() -> void:
	if map == null:
		return
	var look := P.map_look(map.region_id())
	var accent: Color = look["accent"]
	var accent2: Color = look["accent2"]
	var k := minf(size.x / WORLD.x, size.y / WORLD.y) # contain (whole map visible)
	var off := (size - WORLD * k) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), look["floor"])
	draw_set_transform(off, 0.0, Vector2(k, k))
	var lw := 1.0 / k # one screen pixel in world units
	for x in range(0, 1281, 80):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(accent, 0.05), lw)
	for y in range(0, 721, 80):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(accent, 0.05), lw)
	for r in map.blocked_rects:
		draw_rect(Rect2(r.position + Vector2(10, 16), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, look["block"])
		draw_rect(r, Color(accent2, 0.45), false, 2.0 * lw)
		draw_rect(r.grow(-r.size.x * 0.22), Color(accent2, 0.12))
	for z in map.range_bonus_zones:
		draw_circle(Vector2(z.x, z.y), z.z, Color(P.ORANGE, 0.08))
		draw_circle(Vector2(z.x, z.y), 14.0, P.ORANGE)
	for ar in map.air_routes:
		_dashed(ar, Color(P.GREEN, 0.45), 3.0 * lw)
	var hw := map.path_half_width
	for i in range(map.routes.size()):
		var route := map.routes[i]
		var closed := map.dynamic_routes and i != 0
		var a := 0.35 if closed else 1.0
		_band(route, Color(accent, 0.16 * a), hw * 2.0 + 30.0)
		_band(route, Color(accent, 0.75 * a), hw * 2.0 + 8.0)
		_band(route, look["path"], hw * 2.0)
		draw_polyline(route, Color(accent, 0.22 * a), 4.0)
		if route.size() >= 2:
			var dir := (route[1] - route[0]).normalized()
			var n := Vector2(-dir.y, dir.x)
			var s := route[0] + dir * 46.0
			draw_colored_polygon(PackedVector2Array([s + dir * 30.0, s - dir * 14.0 + n * 26.0, s - dir * 14.0 - n * 26.0]),
				Color(P.RED, 0.9 * a))
	var b := map.base_position()
	var hexa := PackedVector2Array()
	for j in range(7):
		hexa.append(b + Vector2.from_angle(TAU * j / 6.0) * 40.0)
	draw_circle(b, 70.0, Color(P.GREEN, 0.15))
	draw_colored_polygon(hexa.slice(0, 6), Color(P.GREEN, 0.35))
	draw_polyline(hexa, P.GREEN, 8.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dim:
		draw_rect(Rect2(Vector2.ZERO, size), Color(P.BG_DEEP, 0.72))
	elif show_badges:
		var x := size.x - 6.0
		for bd in badges():
			x -= 28.0
			draw_rect(Rect2(x, 6, 24, 24), Color(P.BG_DEEP, 0.8))
			draw_rect(Rect2(x, 6, 24, 24), Color(bd[1], 0.6), false, 1.0)
			draw_texture_rect(UiKit.icon(bd[0]), Rect2(x + 3, 9, 18, 18), false, bd[1])
			x -= 4.0


func _band(route: PackedVector2Array, col: Color, w: float) -> void:
	draw_polyline(route, col, w)
	for j in range(1, route.size() - 1):
		draw_circle(route[j], w * 0.5, col)


func _dashed(route: PackedVector2Array, col: Color, w: float) -> void:
	for i in range(route.size() - 1):
		var a := route[i]
		var c := route[i + 1]
		var length := a.distance_to(c)
		var dir := (c - a) / maxf(length, 0.001)
		var d := 0.0
		while d < length:
			draw_line(a + dir * d, a + dir * minf(d + 24.0, length), col, w * 2.0)
			d += 48.0
