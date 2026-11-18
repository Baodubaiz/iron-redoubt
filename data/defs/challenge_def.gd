class_name ChallengeDef
extends Resource
## Daily / weekly challenge: a level with restrictions and an objective (win).

enum Period { DAILY, WEEKLY }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var period: Period = Period.DAILY
@export var level: LevelDef
@export var banned_towers: Array[StringName] = []
@export var base_hp_cap: int = -1
@export var currency_multiplier: float = 1.0
@export var no_selling: bool = false
@export var max_seconds: float = -1.0 ## optional objective: win within this time
@export var cores: int = 10
