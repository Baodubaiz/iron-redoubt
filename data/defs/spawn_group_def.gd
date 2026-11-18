class_name SpawnGroupDef
extends Resource
## One group of identical enemies inside a wave. Variance is bounded and seeded.

@export var enemy: EnemyDef
@export var count: int = 5
@export_range(0.0, 0.15) var count_variance: float = 0.0 ## +/- fraction of count
@export var interval: float = 1.0 ## seconds between spawns
@export_range(0.0, 0.2) var interval_jitter: float = 0.0 ## +/- fraction of interval
@export var start_delay: float = 0.0 ## seconds after wave start
@export var route_index: int = 0 ## ground route (-1 = the currently open gate route), or air route for fliers
@export_group("Overrides")
@export var hp_multiplier: float = 1.0
@export var base_damage_override: int = -1
@export var max_boss_phases: int = 3 ## Monolith: 2 = phases I-II only (no fracture/split)
