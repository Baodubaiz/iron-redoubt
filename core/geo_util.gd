class_name GeoUtil
extends RefCounted
## Pure geometry helpers (no engine state) — unit-testable.


static func dist_sq_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.000001:
		return p.distance_squared_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_squared_to(a + ab * t)


static func dist_point_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	if pts.size() == 0:
		return INF
	if pts.size() == 1:
		return p.distance_to(pts[0])
	var best := INF
	for i in range(pts.size() - 1):
		best = minf(best, dist_sq_point_segment(p, pts[i], pts[i + 1]))
	return sqrt(best)


## True when a circle (center, radius) overlaps the rectangle.
static func circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var cx := clampf(center.x, rect.position.x, rect.end.x)
	var cy := clampf(center.y, rect.position.y, rect.end.y)
	return center.distance_squared_to(Vector2(cx, cy)) < radius * radius
