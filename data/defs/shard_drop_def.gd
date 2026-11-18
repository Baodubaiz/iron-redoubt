class_name ShardDropDef
extends Resource
## Blueprint shard drop of one level (boss levels): rolled once per win, random S/SS tower the player
## still needs (never chosen). Pity: after CampaignDef.shard_pity dry wins in a row the next win drops.

@export var chance: float = 0.3 ## normal drop chance per win
@export var min_shards: int = 1
@export var max_shards: int = 2
@export var jackpot_chance: float = 0.03 ## rolled first: a big drop
@export var jackpot_min: int = 5
@export var jackpot_max: int = 8
