class_name MapDef
extends Resource
## Geometry of a map in world space (1280x720). Ground routes end at the base.
## Air routes are buildable (fliers pass over towers). If none is authored, fliers fly a
## straight line from the first ground route's start to the base.

@export var id: StringName
@export var display_name: String = ""
## Campaign region this map belongs to (circuit / delta / prism / rift). Empty = the map id.
@export var region: StringName = &""
@export var routes: Array[PackedVector2Array] = []
@export var air_routes: Array[PackedVector2Array] = []
@export var path_half_width: float = 26.0
@export var build_area: Rect2 = Rect2(0, 64, 1160, 656)
@export var blocked_rects: Array[Rect2] = []
@export_group("Mechanics")
## Overload nodes: towers whose centre lies inside get +range_bonus range. Each entry = (x, y, radius).
@export var range_bonus_zones: PackedVector3Array = PackedVector3Array()
@export var range_bonus: float = 0.15
## Day/Night: night waves reduce tower range unless the tower stands inside a Beacon aura.
@export var day_night: bool = false
@export var night_range_penalty: float = 0.20
## Dynamic gates: ground routes are alternatives; WaveDef.active_route switches which one is open.
@export var dynamic_routes: bool = false
@export_group("Look")
@export var background_color: Color = Color("0e1117")
@export var path_color: Color = Color("1f2633")


func base_position() -> Vector2:
	if routes.is_empty() or routes[0].is_empty():
		return Vector2.ZERO
	return routes[0][routes[0].size() - 1]


func air_route(i: int) -> PackedVector2Array:
	if not air_routes.is_empty():
		return air_routes[clampi(i, 0, air_routes.size() - 1)]
	if routes.is_empty() or routes[0].is_empty():
		return PackedVector2Array()
	return PackedVector2Array([routes[0][0], base_position()])


func region_id() -> StringName:
	return region if region != &"" else id
