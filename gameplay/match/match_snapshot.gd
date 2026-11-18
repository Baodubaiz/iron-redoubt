class_name MatchSnapshot
extends RefCounted
## Mid-match save (2026-11-18): a checkpoint taken every time a wave is cleared (start of the prep phase),
## when no enemy, shot or ground effect is alive, so the match can be rebuilt exactly. Campaign only.
## Resuming starts the prep phase of the next wave. One file; deleted when the match ends or is abandoned.
## Restarting a wave by quitting the app mid-wave is allowed on purpose (offline game, player-friendly).

const PATH := "user://match_resume.json"
const VERSION := 1


# ---------------------------------------------------------------- capture / restore

static func capture(c: MatchController, match_id: String, loadout: Array) -> Dictionary:
	var towers: Array = []
	for t in c.towers:
		towers.append({
			"id": String(t.def.id), "uid": t.uid, "x": t.position.x, "y": t.position.y,
			"order": t.branch_order.duplicate(), "tiers": t.tiers.duplicate(), "evolved": t.evolved,
			"waves_t3": t.waves_since_t3, "target": t.targeting_override, "invested": t.total_invested,
			"mint": t.mint_count,
		})
	var ids: Array = []
	for id in loadout:
		ids.append(String(id))
	return {
		"version": VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"level_id": String(c.level.id),
		"fingerprint": fingerprint(c.level),
		"match_id": match_id,
		"loadout": ids,
		"seed": c.seed_used,
		"wave_index": c.waves.index,
		"early_starts": c.waves.early_starts,
		"currency": c.economy.currency,
		"paid": c.economy._paid_keys.keys(),
		"passive_count": c.economy._passive_count,
		"base_hp": c.base.hp,
		"damage_taken": c.base.damage_taken,
		"is_night": c.is_night,
		"active_route": c.active_route,
		"match_time": c.match_time,
		"kills": c._kills,
		"next_uid": c._next_uid,
		"stats": _to_json(c.stats),
		"interactions": c.interaction_counts.duplicate(),
		"towers": towers,
	}


## Rebuilds a freshly set-up controller (same level, modifiers) at the checkpoint. False = not usable.
static func apply(c: MatchController, d: Dictionary) -> bool:
	if not is_compatible(d, c.level):
		return false
	var e := c.economy
	e.currency = int(d["currency"])
	e._paid_keys.clear()
	for k in d["paid"]:
		e._paid_keys[String(k)] = true
	e._passive_count = int(d.get("passive_count", 0))
	c.base.hp = int(d["base_hp"])
	c.base.damage_taken = int(d["damage_taken"])
	c.match_time = float(d["match_time"])
	c._kills = int(d["kills"])
	c.stats = _from_json(d["stats"])
	c.interaction_counts = (d["interactions"] as Dictionary).duplicate()
	c.is_night = bool(d["is_night"])
	c.active_route = int(d["active_route"])
	c.map_view.set_state(c.is_night, c.active_route)
	for td in d["towers"]:
		var def := _tower_def(c, String(td["id"]))
		if def == null:
			continue
		var t := Tower.new()
		t.setup(def, int(td["uid"]), def.cost)
		t.position = Vector2(float(td["x"]), float(td["y"]))
		t.map_range_bonus = c.range_bonus_at(t.position)
		var tiers: Array = td["tiers"]
		for b in td["order"]:
			for k in range(int(tiers[int(b)])):
				t.add_tier(int(b))
		t.evolved = bool(td["evolved"])
		t.waves_since_t3 = int(td["waves_t3"])
		t.targeting_override = int(td["target"])
		t.total_invested = int(td["invested"])
		t.mint_count = int(td.get("mint", 0))
		t.recompute()
		c.towers.append(t)
		c.towers_root.add_child(t)
		c.tower_built.emit(t) # MapView attaches the TowerVisual on this signal (otherwise invisible)
	c._next_uid = int(d["next_uid"])
	var w := c.waves
	w.index = int(d["wave_index"])
	w.early_starts = int(d["early_starts"])
	w.phase = WaveManager.Phase.PREP
	var next_def := c.level.waves[w.index + 1]
	w.prep_remaining = next_def.prep_time_override if next_def.prep_time_override >= 0.0 else c.level.prep_time
	c._set_state(MatchController.State.PREP)
	return true


static func _tower_def(c: MatchController, id: String) -> TowerDef:
	for d in c.level.available_towers:
		if String(d.id) == id:
			return d
	return null


## Changes whenever the level's waves change (regenerated data), so an old checkpoint is never applied
## to different waves.
static func fingerprint(l: LevelDef) -> String:
	var parts := PackedStringArray([String(l.id), str(l.waves.size())])
	for w in l.waves:
		var n := 0
		for g in w.groups:
			n += g.count
		parts.append(str(n))
	return ",".join(parts)


static func is_compatible(d: Dictionary, l: LevelDef) -> bool:
	if d.is_empty() or int(d.get("version", 0)) != VERSION or l == null:
		return false
	if String(d.get("game_version", "")) != str(ProjectSettings.get_setting("application/config/version", "")):
		return false
	if String(d.get("level_id", "")) != String(l.id) or String(d.get("fingerprint", "")) != fingerprint(l):
		return false
	var i := int(d.get("wave_index", -1))
	return i >= 0 and i < l.waves.size() - 1


# ---------------------------------------------------------------- file

static func save(d: Dictionary, path: String = PATH) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


static func load_saved(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


static func clear(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The saved campaign match if it still matches its level, else {} (and the stale file is removed).
static func pending(campaign: CampaignDef, path: String = PATH) -> Dictionary:
	var d := load_saved(path)
	if d.is_empty():
		return {}
	for l in campaign.levels:
		if String(l.id) == String(d.get("level_id", "")):
			if is_compatible(d, l):
				return d
			break
	clear(path)
	return {}


static func level_of(campaign: CampaignDef, d: Dictionary) -> LevelDef:
	for l in campaign.levels:
		if String(l.id) == String(d.get("level_id", "")):
			return l
	return null


# ---------------------------------------------------------------- stats <-> JSON (StringName keys)

static func _to_json(stats: Dictionary) -> Dictionary:
	var out := {}
	for k in stats:
		var v: Variant = stats[k]
		if v is Dictionary:
			var m := {}
			for kk in v:
				m[str(kk)] = v[kk]
			out[str(k)] = m
		elif v is Array:
			out[str(k)] = (v as Array).duplicate()
		else:
			out[str(k)] = v
	return out


static func _from_json(d: Dictionary) -> Dictionary:
	var out := {
		"tower_types": {}, "kills_by_enemy": {}, "evolved_types": {}, "sells": 0, "seen_enemies": {},
		"boss_spawn_time": {}, "boss_kill_seconds": [],
	}
	for k in d:
		var v: Variant = d[k]
		if v is Dictionary:
			var m := {}
			for kk in v:
				var val: Variant = v[kk]
				if k == "boss_spawn_time":
					m[int(kk)] = val
				else:
					m[StringName(kk)] = int(val) if (val is float and k == "kills_by_enemy") else val
			out[k] = m
		elif k == "sells":
			out[k] = int(v)
		else:
			out[k] = v
	return out
