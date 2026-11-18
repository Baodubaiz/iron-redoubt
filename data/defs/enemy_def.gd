class_name EnemyDef
extends Resource
## Static definition of an enemy type, including optional ability parameters.

enum Category { BASIC, DEFENSIVE, SPECIAL, BOSS }
enum Shape { CIRCLE, ARROW, HEAVY_CIRCLE, DOT, BRACKET_SQUARE, PENTAGON, CHEVRON, DASHED_TRIANGLE, CROSS, HEXAGON }

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.BASIC
@export var max_hp: float = 52.5
@export var speed: float = 73.5 ## px/s along the route
@export var armor: float = 0.0
## Per-damage-type armor override (key = DamageTypeDef.id, e.g. "poison", "explosive"; value =
## flat armor against that type). Unset types fall back to `armor` above, except Poison/True
## (Enemy.effective_armor_for), which default to 0 unless listed here explicitly. For "diversity",
## not every enemy needs one -- most should have none at all.
@export var armor_by_type: Dictionary = {}
## Per-damage-type PERCENT resistance (key = DamageTypeDef.id; value 0..1 = fraction cut, e.g. 0.3
## = -30%). Different from armor_by_type on purpose (2026-11-16, user: "giáp giảm dame ... giáp
## giảm ví dụ 100 dame mà 45 giáp thì còn 55 ... còn giảm sát thương là theo %"): armor subtracts a
## FLAT amount (countered by a tower's armor_pen), this takes a PERCENT cut of the hit instead
## (countered by a tower's own %-damage bonuses -- Beacon's Amplifier, a tag_mult bonus, etc. --
## which multiply the hit up before this cuts its slice, so a bigger raw hit still loses more
## absolute damage to the enemy than a smaller one would against the same %). The two stack
## independently and can both apply to the same hit.
@export var resist_pct: Dictionary = {}
@export var bounty: int = 1
@export var base_damage: int = 1 ## Base HP lost when it escapes
@export var flying: bool = false
@export var stealth: bool = false
@export var radius: float = 10.0
@export var color: Color = Color.WHITE
@export var shape: Shape = Shape.CIRCLE
## Free-form tags for data rules (towers' tag_mult, effects); built-ins: flying, boss, stealth, shielded, armored.
@export var tags: Array[StringName] = []
## How much harder this enemy is than its raw HP / armour / speed say (flying, stealth, healing, skills...).
## Used only by DifficultyModel to rate waves; 1.0 = plain.
@export var threat_mult: float = 1.0

@export_group("Shield")
@export var shield: float = 0.0
@export var shield_regen_delay: float = 3.0
@export var shield_regen_rate: float = 40.0

@export_group("Healer")
@export var heal_amount: float = 0.0
@export var heal_radius: float = 120.0
@export var heal_interval: float = 2.5
@export var heal_max_targets: int = 5
@export var heal_boss_fraction: float = 0.01 ## bosses are healed this fraction of max HP instead

@export_group("Boss")
@export var is_boss: bool = false
## Boss skill set: monolith (summon / EMP / fracture), warden, carrier, chimera, colossus.
@export var boss_kit: StringName = &"monolith"
## Number of phases this boss has (thresholds 66% / 33% of HP).
@export var boss_phase_count: int = 3
## Kit-specific tuning (see EnemyAbilities). Keys are documented there.
@export var boss_params: Dictionary = {}
## Data-driven boss skills (BossSkillDef). Empty = legacy kit code (Monolith).
@export var boss_skills: Array[BossSkillDef] = []
## Always-on boss effects by phase, e.g. {"kind": "overload", "min_phase": 3, "mult": 1.35} or
## {"kind": "overdrive", "min_phase": 3, "radius": 180, "haste": 0.3, "regen": 0.0015}.
@export var boss_passives: Array[Dictionary] = []
## Raised 0.6->0.8 (2026-11-16): now the backstop for the diminishing-returns multi-source slow
## formula (Enemy.speed_multiplier), not a single-source cap, so it needs room for several towers'
## worth of combined slow (e.g. 50% + 10% + 10% = 70%) before it kicks in. Bosses still use 0.25.
@export var slow_cap: float = 0.8
@export var summon_enemy: EnemyDef
@export var summon_interval: float = 8.0
@export var summon_count: int = 4
@export var summon_telegraph: float = 1.5
@export var emp_interval: float = 12.0
@export var emp_radius: float = 170.0
@export var emp_duration: float = 3.0
@export var emp_telegraph: float = 2.0
@export var fracture_speed_bonus: float = 0.3
@export var shard_count: int = 3
@export var shard_hp: float = 400.0
@export var shard_armor: float = 2.0
@export var shard_speed: float = 60.0
@export var shard_base_damage: int = 3
