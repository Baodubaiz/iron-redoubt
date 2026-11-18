class_name MemoryStore
extends ProgressionStore
## In-memory store for tests. Supports injected failures and simulated concurrent writers.

var stored: Dictionary = {}
var fail_next_saves: int = 0
var saves: int = 0


func load_data() -> Dictionary:
	return {"ok": true, "data": stored.duplicate(true), "error": ""}


func save_data(data: Dictionary, base_revision: int) -> Dictionary:
	if fail_next_saves > 0:
		fail_next_saves -= 1
		return {"ok": false, "conflict": false, "remote": {}, "error": "simulated network failure"}
	if not stored.is_empty() and int(stored.get("revision", 0)) > base_revision:
		return {"ok": false, "conflict": true, "remote": stored.duplicate(true), "error": "stale revision"}
	stored = data.duplicate(true)
	saves += 1
	return {"ok": true, "conflict": false, "remote": {}, "error": ""}
