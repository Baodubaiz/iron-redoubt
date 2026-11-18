class_name MatchModifiers
extends RefCounted
## Everything outside LevelDef that changes a match: research effects, unlock state and
## challenge restrictions. Built by ProgressionService; tests construct it directly.

var unlocks: UpgradeRules.Unlocks = UpgradeRules.Unlocks.everything()
## Tower ids the player owns (meta unlocks). Empty = no restriction (dev / tests).
var owned_towers: Array[StringName] = []
var banned_towers: Array[StringName] = []
var start_currency_bonus: int = 0
var currency_multiplier: float = 1.0
var base_hp_bonus: int = 0
var base_hp_cap: int = -1 ## challenge restriction: start with at most this Base HP
var early_bonus_multiplier: float = 1.0
var no_selling: bool = false
var challenge_id: StringName = &""
var challenge_period: String = ""


func allows_tower(def: TowerDef) -> bool:
	if banned_towers.has(def.id):
		return false
	return owned_towers.is_empty() or owned_towers.has(def.id)


func start_currency(level: LevelDef) -> int:
	var seed_money := level.economy.seed_money(level.starting_currency) if (level != null and level.economy != null) else int(round(level.starting_currency * 1.10))
	return int(round((seed_money + start_currency_bonus) * currency_multiplier))


func start_hp(level: LevelDef) -> int:
	var hp := level.base_hp + base_hp_bonus
	return mini(hp, base_hp_cap) if base_hp_cap > 0 else hp
