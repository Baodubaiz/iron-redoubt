class_name ShapeArt
extends RefCounted
## Minimalist geometric drawing for towers/enemies. Presentation only — no game rules here.
## Shapes (not colour alone) distinguish types.


static func draw_tower(ci: CanvasItem, def: TowerDef, aim: float, selected: bool, size_mult: float = 1.0) -> void:
	var r := def.footprint_radius
	var body := r * size_mult
	var fill := Color(def.color, 0.18)
	var line := def.color
	ci.draw_circle(Vector2.ZERO, r, Color(0.05, 0.07, 0.1, 0.9))
	match def.shape:
		TowerDef.Shape.TRIANGLE:
			var pts := _ngon(3, body * 0.78, aim)
			ci.draw_colored_polygon(pts, fill)
			_outline(ci, pts, line, 2.5)
		TowerDef.Shape.SQUARE:
			var pts := _ngon(4, body * 0.82, PI * 0.25)
			ci.draw_colored_polygon(pts, fill)
			_outline(ci, pts, line, 2.5)
			ci.draw_line(Vector2.ZERO, Vector2.from_angle(aim) * body * 0.7, line, 4.0)
		TowerDef.Shape.DIAMOND:
			var pts := _ngon(4, body * 0.88, aim)
			ci.draw_colored_polygon(pts, fill)
			_outline(ci, pts, line, 2.5)
		TowerDef.Shape.CIRCLE:
			ci.draw_circle(Vector2.ZERO, body * 0.5, fill)
			ci.draw_arc(Vector2.ZERO, body * 0.5, 0, TAU, 32, line, 2.5)
			ci.draw_arc(Vector2.ZERO, body * 0.78, 0, TAU, 32, Color(line, 0.6), 1.5)
	ci.draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1, 1, 1, 0.9) if selected else Color(line, 0.35), 2.0 if selected else 1.0)


static func draw_enemy(ci: CanvasItem, def: EnemyDef, flash: bool) -> void:
	var r := def.radius
	var col := Color.WHITE if flash else def.color
	var fill := Color(col, 0.35)
	match def.shape:
		EnemyDef.Shape.CIRCLE:
			ci.draw_circle(Vector2.ZERO, r, fill)
			ci.draw_arc(Vector2.ZERO, r, 0, TAU, 20, col, 2.0)
		EnemyDef.Shape.ARROW:
			var pts := PackedVector2Array([Vector2(r, 0), Vector2(-r, -r * 0.7), Vector2(-r * 0.4, 0), Vector2(-r, r * 0.7)])
			ci.draw_colored_polygon(pts, fill)
			_outline(ci, pts, col, 2.0)
		EnemyDef.Shape.HEAVY_CIRCLE:
			ci.draw_circle(Vector2.ZERO, r, fill)
			ci.draw_arc(Vector2.ZERO, r, 0, TAU, 28, col, 4.0)
			ci.draw_arc(Vector2.ZERO, r * 0.5, 0, TAU, 20, col, 2.0)
		EnemyDef.Shape.DOT:
			ci.draw_circle(Vector2.ZERO, r, col)
		EnemyDef.Shape.BRACKET_SQUARE:
			var pts := _ngon(4, r * 1.2, PI * 0.25)
			ci.draw_colored_polygon(pts, fill)
			_outline(ci, pts, col, 2.0)
			var k := r * 0.85
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var c := Vector2(sx * k, sy * k)
					ci.draw_line(c, c - Vector2(sx * k * 0.6, 0), col, 3.0)
					ci.draw_line(c, c - Vector2(0, sy * k * 0.6), col, 3.0)
		EnemyDef.Shape.PENTAGON:
			var pts := _ngon(5, r, -PI * 0.5)
			ci.draw_colored_polygon(pts, fill)
			_outline(ci, pts, col, 2.0)
		EnemyDef.Shape.CHEVRON:
			# flying: drop shadow offset + chevron
			var sh := PackedVector2Array([Vector2(r, 6), Vector2(-r, -r * 0.8 + 6), Vector2(-r * 0.3, 6), Vector2(-r, r * 0.8 + 6)])
			ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
			var pts := PackedVector2Array([Vector2(r, 0), Vector2(-r, -r * 0.8), Vector2(-r * 0.3, 0), Vector2(-r, r * 0.8)])
			ci.draw_colored_polygon(pts, fill)
			_outline(ci, pts, col, 2.0)
		EnemyDef.Shape.DASHED_TRIANGLE:
			var pts := _ngon(3, r, 0.0)
			ci.draw_colored_polygon(pts, Color(col, 0.2))
			for i in range(3):
				var a := pts[i]
				var b := pts[(i + 1) % 3]
				ci.draw_line(a, a.lerp(b, 0.4), col, 2.0)
				ci.draw_line(a.lerp(b, 0.6), b, col, 2.0)
		EnemyDef.Shape.CROSS:
			ci.draw_circle(Vector2.ZERO, r, fill)
			ci.draw_arc(Vector2.ZERO, r, 0, TAU, 20, col, 2.0)
			ci.draw_line(Vector2(-r * 0.6, 0), Vector2(r * 0.6, 0), col, 3.0)
			ci.draw_line(Vector2(0, -r * 0.6), Vector2(0, r * 0.6), col, 3.0)
		EnemyDef.Shape.HEXAGON:
			var pts := _ngon(6, r, 0.0)
			ci.draw_colored_polygon(pts, fill)
			_outline(ci, pts, col, 3.0)
			if r > 20.0:
				_outline(ci, _ngon(6, r * 0.55, PI / 6.0), col, 2.0)
		_:
			ci.draw_circle(Vector2.ZERO, r, fill)
			ci.draw_arc(Vector2.ZERO, r, 0, TAU, 20, col, 2.0)


static func _ngon(n: int, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		pts.append(Vector2.from_angle(rot + TAU * i / n) * r)
	return pts


static func _outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, w, true)
