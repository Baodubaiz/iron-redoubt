class_name EffectDef
extends Resource
## A status effect built from generic components, applied to an enemy or a tower.
## New effects are pure data: combine the component keys below (no code change).
##
## Enemy components (all optional):
##   speed_mult       float  multiplies movement speed (0.7 = 30% slow); stacks multiply
##   damage_taken     float  multiplies damage the enemy takes (1.2 = +20%)
##   armor_add        float  added to armor (negative = shred)
##   dot_dps          float  damage per second, type `dot_type` (kinetic/explosive/energy/true)
##   regen_frac       float  heals this fraction of max HP per second
##   heal_mult        float  multiplies healing received (0.5 = half)
##   untargetable     bool   towers cannot pick it (splash still hits)
##   immune           bool   takes no damage at all
##   resist_type      String damage type resisted; resist_amount (0.9 = 90%)
##   stop             bool   cannot move (bosses ignore)
## Tower components:
##   fire_rate_mult   float  attack recharge speed multiplier
##   range_mult       float  attack range multiplier
##   damage_mult      float  damage multiplier
##   disabled         bool   cannot attack

enum Target { ENEMY, TOWER }
enum Stacking { REFRESH, KEEP_STRONGEST, STACK }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var target: Target = Target.ENEMY
@export var icon: String = "bolt" ## UI icon name (assets/ui/icons)
@export var color: Color = Color.WHITE
@export var duration: float = 3.0
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 1
@export var components: Dictionary = {}
@export var affects_bosses: bool = true
## Built-in statuses (slow, burn, freeze...) are listed here for UI / Codex; their rules live in code.
@export var builtin: bool = false


static var _cache: Dictionary = {}


## Loads data/effects/<id>.tres (cached). Null if it does not exist.
static func by_id(id: String) -> EffectDef:
	if _cache.has(id):
		return _cache[id]
	var path := "res://data/effects/%s.tres" % id
	var e: EffectDef = load(path) if ResourceLoader.exists(path) else null
	_cache[id] = e
	return e


func c(key: String, default: Variant = 0.0) -> Variant:
	return components.get(key, default)
