class_name CrazyGamesDataStore
extends ProgressionStore
## Player profile in the CrazyGames Data module (2026-11-19): the progress follows the CrazyGames account
## (synced across devices) for logged-in players and stays in the browser for guests. Same contract as
## LocalFileStore: JSON profile + optimistic revision check. Used only when the game runs on CrazyGames
## (see ProgressionService); everywhere else the on-device LocalFileStore stays.

const KEY := "iron_redoubt_profile"


func load_data() -> Dictionary:
	var r := CrazyGamesSdk.data_get(KEY)
	if not r.get("ok", false):
		return {"ok": false, "data": {}, "error": "data module: " + str(r.get("error", ""))}
	var text := str(r.get("value", ""))
	if text == "":
		return {"ok": true, "data": {}, "error": ""}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return {"ok": true, "data": parsed, "error": ""}
	return {"ok": false, "data": {}, "error": "profile unreadable"}


func save_data(data: Dictionary, base_revision: int) -> Dictionary:
	var current := load_data()
	if current["ok"] and not current["data"].is_empty():
		var stored_rev := int(current["data"].get("revision", 0))
		if stored_rev > base_revision:
			return {"ok": false, "conflict": true, "remote": current["data"], "error": "stale revision"}
	var w := CrazyGamesSdk.data_set(KEY, JSON.stringify(data))
	if not w.get("ok", false):
		return {"ok": false, "conflict": false, "remote": {}, "error": "data module: " + str(w.get("error", ""))}
	return {"ok": true, "conflict": false, "remote": {}, "error": ""}
