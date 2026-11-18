class_name CampaignDef
extends Resource
## The whole V1 campaign: ordered levels (3 per map), meta catalogues and challenge pools.

@export var levels: Array[LevelDef] = []
@export var starting_towers: Array[StringName] = [&"pulse", &"nova"]
@export var replay_reward_fraction: float = 0.25
@export var flawless_bonus: int = 5
@export var research: Array[ResearchDef] = []
@export var achievements: Array[AchievementDef] = []
@export var daily_pool: Array[ChallengeDef] = []
@export var weekly_pool: Array[ChallengeDef] = []
@export_group("Armory")
## Towers bought in the shop (rank with shard_cost > 0). Adding an S / SS tower = list it here (author_data
## does it automatically from the rank); price and shards come from its RarityDef.
@export var shop_towers: Array[TowerDef] = []
@export var shard_pity: int = 8 ## dry boss wins in a row before a drop is guaranteed
@export var ad_daily_cap: int = 25 ## rewarded ads per day
@export var ad_shards: int = 1 ## shards per rewarded ad (for the tower the player picks)
@export_group("Items")
@export var consumables: Array[ConsumableDef] = [] ## one-shot items sold in the Armory


func level_index(id: StringName) -> int:
	for i in range(levels.size()):
		if levels[i].id == id:
			return i
	return -1


func shard_cost(t: TowerDef) -> int:
	var r := RarityCatalog.get_default().find(t.rarity)
	return r.shard_cost if r != null else 0


func core_price(t: TowerDef) -> int:
	var r := RarityCatalog.get_default().find(t.rarity)
	return r.core_price if r != null else 0


func find_consumable(id: StringName) -> ConsumableDef:
	for c in consumables:
		if c.id == id:
			return c
	return null


func find_shop_tower(id: StringName) -> TowerDef:
	for t in shop_towers:
		if t.id == id:
			return t
	return null


func find_research(id: StringName) -> ResearchDef:
	for r in research:
		if r.id == id:
			return r
	return null
