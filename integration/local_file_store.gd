class_name LocalFileStore
extends ProgressionStore
## On-device JSON profile (user://). Atomic writes (temp file + rename) with a backup copy.
## This is a local cache only — it does NOT synchronise with a GameHub account (Phase 6).

var path: String


func _init(file_path: String = "user://profile.json") -> void:
	path = file_path


func load_data() -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var text := FileAccess.get_file_as_string(candidate)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			return {"ok": true, "data": parsed, "error": "" if candidate == path else "recovered from backup"}
	if FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "error": "profile unreadable"}
	return {"ok": true, "data": {}, "error": ""}


func save_data(data: Dictionary, base_revision: int) -> Dictionary:
	var current := load_data()
	if current["ok"] and not current["data"].is_empty():
		var stored_rev := int(current["data"].get("revision", 0))
		if stored_rev > base_revision:
			return {"ok": false, "conflict": true, "remote": current["data"], "error": "stale revision"}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "conflict": false, "remote": {}, "error": error_string(FileAccess.get_open_error())}
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return {"ok": false, "conflict": false, "remote": {}, "error": "cannot open directory"}
	if FileAccess.file_exists(path):
		dir.copy(path, path + ".bak")
	var err := dir.rename(tmp, path)
	if err != OK:
		return {"ok": false, "conflict": false, "remote": {}, "error": error_string(err)}
	return {"ok": true, "conflict": false, "remote": {}, "error": ""}
