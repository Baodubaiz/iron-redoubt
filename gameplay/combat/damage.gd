class_name Damage
extends RefCounted
## Damage types and the defence formula. Per-type numbers come from data/damage/catalog.tres
## (DamageTypeDef, index = Type value); a new type is a new catalog entry used by its index.
## POISON and PLASMA inserted before TRUE (2026-11-16, user: wants real elemental diversity --
## "vật lý, độc, điện, plasma..." -- each with its OWN mechanic, not just a numeric reskin of one
## formula): appending rather than reordering keeps every existing tower's serialized
## KINETIC(0)/EXPLOSIVE(1)/ENERGY(2) value stable; nothing used TRUE's old int directly (only
## EnemyDef-driven lookups by id), so only that kept shifting, harmlessly.
## Each type's distinct mechanic:
##   Kinetic   - the baseline: plain armor subtraction, no twist.
##   Explosive - innate shrapnel pierce (DamageTypeDef.flat_pierce) on top of the tower's own pen.
##   Energy    - x2 vs shields (burns through energy barriers fast, but still absorbed by them).
##   Poison    - ignores armor by default (DoT), but a specific enemy can resist it via
##               EnemyDef.armor_by_type (e.g. machines).
##   Plasma    - skips shields entirely (DamageTypeDef.ignores_shield) instead of just multiplying
##               into them -- it never interacts with a shield bar at all, for better or worse.
##   True      - always ignores armor, unconditionally; the one type nothing resists.

enum Type { KINETIC, EXPLOSIVE, ENERGY, POISON, PLASMA, TRUE }

## Minimum fraction of a hit that always gets through armor (default when a type has no entry).
const MIN_THROUGH := 0.25

static var _loaded := false
static var _defs: Array[DamageTypeDef] = []


static func defs() -> Array[DamageTypeDef]:
	if not _loaded:
		_loaded = true
		if ResourceLoader.exists(DamageCatalog.PATH):
			var c: DamageCatalog = load(DamageCatalog.PATH)
			_defs = c.types
	return _defs


static func type_def(type: int) -> DamageTypeDef:
	var d := defs()
	return d[type] if type >= 0 and type < d.size() else null


## Type index from an id ("kinetic", "true"...); -1 if unknown.
static func type_from_id(id: String) -> int:
	var d := defs()
	for i in range(d.size()):
		if String(d[i].id) == id:
			return i
	return -1


static func shield_mult(type: int) -> float:
	var d := type_def(type)
	return d.vs_shield if d != null else (2.0 if type == Type.ENERGY else 1.0)


## True while this type never touches a shield bar at all (Plasma): the controller must skip
## Enemy.absorb_with_shield() entirely for it, not just change the multiplier going in.
static func ignores_shield(type: int) -> bool:
	var d := type_def(type)
	return d != null and d.ignores_shield


## dealt = max(dmg - max(armor - pen, 0), dmg * min_through). `armor` is already the DEFENDER's
## armor FOR THIS SPECIFIC TYPE (Enemy.effective_armor_for) -- a type whose catalog entry defaults
## to ignoring armor (Poison, True) only does so because that lookup defaults to 0 armor for it,
## not because resolve() special-cases the type; an enemy with a per-type override still defends
## normally against it. So this formula alone is now type-agnostic by design. `flat_pierce` is the
## type's OWN innate pierce (Explosive's shrapnel), added on top of the tower's own armor_pen.
static func resolve(amount: float, type: int, armor_pen: float, armor: float) -> float:
	if amount <= 0.0:
		return 0.0
	var d := type_def(type)
	var pen := armor_pen + (d.flat_pierce if d != null else 0.0)
	var effective_armor := maxf(armor - pen, 0.0)
	return maxf(amount - effective_armor, amount * (d.min_through if d != null else MIN_THROUGH))


## Splits `amount` between two types by `mix` (0 = all primary, 1 = all secondary) and resolves
## each half against the defender's own per-type armor, via `armor_for`. Used by towers that deal
## a blended/hybrid hit (e.g. part Explosive, part Energy) instead of a single pure type.
static func resolve_mixed(amount: float, type: int, secondary_type: int, mix: float, armor_pen: float,
		armor_for: Callable) -> float:
	if secondary_type < 0 or mix <= 0.0:
		return resolve(amount, type, armor_pen, armor_for.call(type))
	if mix >= 1.0:
		return resolve(amount, secondary_type, armor_pen, armor_for.call(secondary_type))
	var primary_part := resolve(amount * (1.0 - mix), type, armor_pen, armor_for.call(type))
	var secondary_part := resolve(amount * mix, secondary_type, armor_pen, armor_for.call(secondary_type))
	return primary_part + secondary_part
