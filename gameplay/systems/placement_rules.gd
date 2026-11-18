class_name PlacementRules
extends RefCounted
## Pure placement validation against map geometry and existing tower footprints.

enum Result { OK, OUT_OF_BOUNDS, ON_PATH, BLOCKED, OVERLAP_TOWER }

const RESULT_TEXT := {
	Result.OK: "",
	Result.OUT_OF_BOUNDS: "Outside the build area",
	Result.ON_PATH: "Too close to the path",
	Result.BLOCKED: "Blocked terrain",
	Result.OVERLAP_TOWER: "Overlaps another tower",
}

var map: MapDef


func _init(map_def: MapDef) -> void:
	map = map_def


func validate(pos: Vector2, footprint: float, towers: Array[Tower]) -> Result:
	var area := map.build_area
	if pos.x - footprint < area.position.x or pos.y - footprint < area.position.y \
			or pos.x + footprint > area.end.x or pos.y + footprint > area.end.y:
		return Result.OUT_OF_BOUNDS
	var min_path := map.path_half_width + footprint
	for route in map.routes:
		if GeoUtil.dist_point_polyline(pos, route) < min_path:
			return Result.ON_PATH
	for rect in map.blocked_rects:
		if GeoUtil.circle_intersects_rect(pos, footprint, rect):
			return Result.BLOCKED
	for t in towers:
		var min_d := footprint + t.def.footprint_radius
		if t.position.distance_squared_to(pos) < min_d * min_d - 0.001:
			return Result.OVERLAP_TOWER
	return Result.OK
