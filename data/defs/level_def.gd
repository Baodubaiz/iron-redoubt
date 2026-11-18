class_name LevelDef
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var level_number: int = 1
@export var map: MapDef
@export var waves: Array[WaveDef] = []
@export var starting_currency: int = 350
@export var base_hp: int = 20
@export var available_towers: Array[TowerDef] = []
@export var economy: EconomyConfig
## Raised 20->30 (2026-11-15, user request alongside the tower-spam remake): more towers to place
## each round needs more time to place them in.
@export var prep_time: float = 30.0
@export_group("Campaign")
@export_multiline var objective: String = "Survive every wave."
@export var cores_first_clear: int = 10
@export var unlock_tower_on_clear: TowerDef ## meta unlock granted on first clear (null = none)
## Tower granted the first time this level is started: the counter to the special enemy it introduces.
@export var unlock_tower_on_start: TowerDef
## Difficulty = numbers, never stats: every regular enemy group count is multiplied by this when the match
## starts (bosses untouched), then busy waves are spread out to stay under the on-screen crowd cap.
## See DifficultyModel.effective_level(). Tuned by tools/sim/difficulty_tuner.gd.
@export var difficulty: float = 1.0
## Blueprint shard drop rolled on every win (boss levels); null = no shards.
@export var shard_drop: ShardDropDef
