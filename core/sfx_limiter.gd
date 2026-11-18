class_name SfxLimiter
extends RefCounted
## Prevents audio overload when many towers fire at once: per-sound cooldown, per-sound voice
## cap and a global voice cap. Pure time-based logic (milliseconds) so it is unit-testable.

var cooldown_ms: int = 40
var per_sound_max: int = 2
var global_max: int = 12

var _last: Dictionary = {} ## id -> last start ms
var _active: Dictionary = {} ## id -> Array[int] end times (ms)


func _prune(now_ms: int) -> int:
	var total := 0
	for id in _active:
		var ends: Array = _active[id]
		var i := 0
		while i < ends.size():
			if int(ends[i]) <= now_ms:
				ends.remove_at(i)
			else:
				i += 1
		total += ends.size()
	return total


## Returns true and records the voice if the sound may start now.
func try_start(id: StringName, now_ms: int, length_ms: int) -> bool:
	var total := _prune(now_ms)
	if _last.has(id) and now_ms - int(_last[id]) < cooldown_ms:
		return false
	var ends: Array = _active.get(id, [])
	if ends.size() >= per_sound_max or total >= global_max:
		return false
	ends.append(now_ms + maxi(length_ms, 1))
	_active[id] = ends
	_last[id] = now_ms
	return true


func active_count(now_ms: int) -> int:
	return _prune(now_ms)
