class_name TowerDef
extends Resource
## Static definition of a base tower type. Runtime state lives in Tower.

enum TargetRule { FIRST, DENSEST, STRONGEST, AIR_FIRST, NONE }
enum Shape { TRIANGLE, SQUARE, DIAMOND, CIRCLE }
enum AttackMode { PROJECTILE, AURA, PULSE } ## PULSE: periodic discharge hitting every enemy in range (Coil)

@export var id: StringName
@export var display_name: String = ""
## Rank / rarity: "C", "B", "A", "S" or "SS" (see data/stats/rarity.tres).
@export var rarity: StringName = &"C"
@export_multiline var role: String = ""
@export var cost: int = 100
@export var damage: float = 10.0
@export var damage_type: int = 0 ## Damage.Type
@export var armor_pen: float = 0.0
@export var fire_rate: float = 1.0 ## shots per second
@export var attack_range: float = 150.0
@export var splash_radius: float = 0.0 ## 0 = single target
@export var projectile_speed: float = 600.0
@export var homing: bool = true ## false = lobbed to the target's position at fire time
@export var can_target_air: bool = true
@export var targeting: TargetRule = TargetRule.FIRST
@export var attack_mode: AttackMode = AttackMode.PROJECTILE
@export var footprint_radius: float = 22.0
@export var color: Color = Color.CYAN
@export var shape: Shape = Shape.TRIANGLE
## Extra base parameters (e.g. Beacon slow / reveal). Same keys as TierDef.stats.
@export var base_params: Dictionary = {}
@export var branches: Array[BranchDef] = []
