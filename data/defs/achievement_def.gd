class_name AchievementDef
extends Resource
## Achievement evaluated from real match results / lifetime counters (see campaign/achievements.gd).

enum Kind {
	FLAWLESS_LEVELS, ## params.levels: all listed levels cleared without losing Base HP (any time)
	FLAWLESS_ON_MAP, ## params.map: any level of the map cleared flawlessly
	BOSS_FAST, ## params.seconds: a boss killed within N s of spawning
	WIN_MAX_TOWER_TYPES, ## params.count: win having built at most N tower types
	WIN_WITHOUT_TOWER, ## params.tower, params.min_level: win level >= min_level without building it
	LIFETIME_SET, ## params.counter, params.values: lifetime set contains all values
	LIFETIME_COUNT, ## params.counter, params.target: lifetime counter reaches target
	WIN_AT_MOST_HP, ## params.hp: win with Base HP <= hp
	MATCH_COUNT, ## params.stat, params.target: a single match stat reaches target
	CLEAR_LEVEL, ## params.level: clear the level
	CLEAR_LEVEL_WITHOUT_RESEARCH, ## params.level, params.research: clear while not owning the research
}

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.CLEAR_LEVEL
@export var params: Dictionary = {}
@export var cores: int = 5
