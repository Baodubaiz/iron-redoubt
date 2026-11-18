class_name RoutePath
extends RefCounted
## Runtime polyline route with cumulative lengths. Enemies store a scalar `progress` along it.

var points: PackedVector2Array
var cumulative: PackedFloat32Array
var total_length: float = 0.0


func _init(pts: PackedVector2Array) -> void:
	points = pts
	cumulative = PackedFloat32Array()
	cumulative.resize(pts.size())
	var acc := 0.0
	for i in range(pts.size()):
		if i > 0:
			acc += pts[i - 1].distance_to(pts[i])
		cumulative[i] = acc
	total_length = acc


## Returns the segment index containing `progress`, scanning forward from `hint` (progress is monotonic).
func segment_for(progress: float, hint: int) -> int:
	var i := clampi(hint, 0, maxi(points.size() - 2, 0))
	while i < points.size() - 2 and cumulative[i + 1] < progress:
		i += 1
	return i


func position_at(progress: float, seg: int) -> Vector2:
	if points.size() < 2:
		return points[0] if points.size() == 1 else Vector2.ZERO
	var a := points[seg]
	var b := points[seg + 1]
	var seg_len := cumulative[seg + 1] - cumulative[seg]
	if seg_len <= 0.0:
		return b
	var t := clampf((progress - cumulative[seg]) / seg_len, 0.0, 1.0)
	return a.lerp(b, t)


func direction_at(seg: int) -> Vector2:
	if points.size() < 2:
		return Vector2.RIGHT
	return (points[seg + 1] - points[seg]).normalized()
