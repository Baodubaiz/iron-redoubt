class_name RarityDef
extends Resource
## One tower rank (C, B, A, S, SS) — data/stats/rarity.tres. Purely a classification: it drives
## colours / badges and tells the player how rare a tower is. Level-unlocked ranks (C/B/A) have
## shard_cost 0; shop ranks (S, SS) are bought in the Armory with blueprint shards + Cores.

@export var id: StringName ## "C", "B", "A", "S", "SS"
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var accent: Color = Color.WHITE ## border / glow (SS uses a second colour)
@export var order: int = 0 ## 0 = most common
@export var shard_cost: int = 0 ## blueprint shards needed before the tower can be bought (0 = not in the shop)
@export var core_price: int = 0 ## Cores paid in the shop once the shards are complete
