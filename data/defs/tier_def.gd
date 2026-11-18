class_name TierDef
extends Resource
## One purchasable step (tier or evolution). `stats` overrides tower parameters; tiers are applied
## in order so later tiers overwrite earlier ones. Recognised keys are documented in
## docs/COMBAT_PARAMS.md and read by Tower.p().

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 100
@export var stats: Dictionary = {}
