class_name HexLogo
extends Control
## Iron Redoubt emblem: hex shield, orange vanguard arrow, rotating dashed ring, breathing glow.

const P = preload("res://ui/style/visual_palette.gd")

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(96, 96)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var breathe := 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(c, r * 0.95, Color(P.CYAN, 0.06 + 0.05 * breathe))
	# rotating dashed ring
	var seg := 18
	for i in range(seg):
		if i % 3 == 2:
			continue
		var a0 := _t * 0.5 + TAU * i / seg
		draw_arc(c, r * 0.94, a0, a0 + TAU / seg * 0.7, 6, Color(P.CYAN, 0.55), 2.0, true)
	var hex := PackedVector2Array()
	for k in range(7):
		hex.append(c + Vector2.from_angle(-PI / 2.0 + TAU * k / 6.0) * r * 0.74)
	draw_colored_polygon(hex.slice(0, 6), Color(P.BG_DEEP, 0.9))
	draw_polyline(hex, Color(P.CYAN, 0.25), r * 0.2, true)
	draw_polyline(hex, P.CYAN, r * 0.1, true)
	# vanguard arrow
	var tri := PackedVector2Array([c + Vector2(0, -r * 0.36), c + Vector2(r * 0.33, r * 0.24), c + Vector2(0, r * 0.1),
		c + Vector2(-r * 0.33, r * 0.24)])
	draw_colored_polygon(tri, P.ORANGE)
	draw_circle(c + Vector2(0, -r * 0.02), r * 0.07, Color(1, 1, 1, 0.6 + 0.4 * breathe))
