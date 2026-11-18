class_name EnemyRegistry
extends RefCounted
## Uniform spatial hash of alive enemies, rebuilt once per simulation step.
## Towers query circles instead of scanning every enemy.

const CELL := 64.0

var _cells: Dictionary = {} # Vector2i -> Array[Enemy]; arrays are reused to avoid per-frame allocation
var _used_keys: Array[Vector2i] = []


func rebuild(enemies: Array[Enemy]) -> void:
	for key in _used_keys:
		(_cells[key] as Array).clear()
	_used_keys.clear()
	for e in enemies:
		if not e.is_alive():
			continue
		var key := Vector2i(floori(e.position.x / CELL), floori(e.position.y / CELL))
		var bucket: Array = _cells.get(key, [])
		if bucket.is_empty():
			if not _cells.has(key):
				_cells[key] = bucket
			_used_keys.append(key)
		bucket.append(e)


## Appends alive enemies within `radius` of `center` into `out` (cleared first).
## targetable_only excludes unrevealed stealth enemies (tower targeting); splash passes false.
func query_circle(center: Vector2, radius: float, include_air: bool, out: Array[Enemy], targetable_only: bool = false) -> void:
	out.clear()
	var r_sq := radius * radius
	var min_c := Vector2i(floori((center.x - radius) / CELL), floori((center.y - radius) / CELL))
	var max_c := Vector2i(floori((center.x + radius) / CELL), floori((center.y + radius) / CELL))
	for cx in range(min_c.x, max_c.x + 1):
		for cy in range(min_c.y, max_c.y + 1):
			var bucket: Array = _cells.get(Vector2i(cx, cy), [])
			for e: Enemy in bucket:
				if not e.is_alive():
					continue
				if e.is_flying() and not include_air:
					continue
				if targetable_only and not e.is_targetable():
					continue
				if e.position.distance_squared_to(center) <= r_sq:
					out.append(e)
