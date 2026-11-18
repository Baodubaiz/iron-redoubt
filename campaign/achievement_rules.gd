class_name AchievementRules
extends RefCounted
## Evaluates AchievementDefs against a match result plus the (already updated) profile.


static func is_met(def: AchievementDef, result: Dictionary, profile: Profile, campaign: CampaignDef) -> bool:
	var p := def.params
	var won := bool(result.get("won", false))
	var level_id := String(result.get("level_id", ""))
	match def.kind:
		AchievementDef.Kind.FLAWLESS_LEVELS:
			for id in p.get("levels", []):
				if not bool(profile.level_record(StringName(id))["flawless"]):
					return false
			return true
		AchievementDef.Kind.FLAWLESS_ON_MAP:
			for l in campaign.levels:
				if (String(l.map.id) == String(p.get("map", "")) or String(l.map.region_id()) == String(p.get("map", ""))) \
						and bool(profile.level_record(l.id)["flawless"]):
					return true
			return false
		AchievementDef.Kind.BOSS_FAST:
			for s in result.get("boss_kill_seconds", []):
				if float(s) <= float(p.get("seconds", 0)):
					return true
			return false
		AchievementDef.Kind.WIN_MAX_TOWER_TYPES:
			var types: Array = result.get("tower_types", [])
			return won and not types.is_empty() and types.size() <= int(p.get("count", 0))
		AchievementDef.Kind.WIN_WITHOUT_TOWER:
			var idx := campaign.level_index(StringName(level_id))
			return won and idx + 1 >= int(p.get("min_level", 1)) \
				and not (result.get("tower_types", []) as Array).has(String(p.get("tower", "")))
		AchievementDef.Kind.LIFETIME_SET:
			var have := profile.lifetime_set(String(p.get("counter", "")))
			for v in p.get("values", []):
				if not have.has(String(v)):
					return false
			return true
		AchievementDef.Kind.LIFETIME_COUNT:
			return profile.counter(String(p.get("counter", ""))) >= int(p.get("target", 1))
		AchievementDef.Kind.WIN_AT_MOST_HP:
			return won and int(result.get("base_hp", 0)) <= int(p.get("hp", 1))
		AchievementDef.Kind.MATCH_COUNT:
			return int(result.get(String(p.get("stat", "")), 0)) >= int(p.get("target", 1))
		AchievementDef.Kind.CLEAR_LEVEL:
			return won and level_id == String(p.get("level", ""))
		AchievementDef.Kind.CLEAR_LEVEL_WITHOUT_RESEARCH:
			return won and level_id == String(p.get("level", "")) \
				and not profile.has_research(StringName(String(p.get("research", ""))))
	return false
