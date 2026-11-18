class_name Targeting
extends RefCounted
## Automatic targeting rules, picked per tower-type by default but overridable per placed tower
## (Tower.targeting_override, set from the tower panel). Behaviour only, same for every tower role.
## Only targetable enemies are considered (unrevealed stealth enemies are skipped).

static var _buf: Array[Enemy] = []
static var _buf2: Array[Enemy] = []
static var _top: Array[Enemy] = []


static func pick(origin: Vector2, rule: int, attack_range: float, can_target_air: bool, splash: float,
		registry: EnemyRegistry) -> Enemy:
	registry.query_circle(origin, attack_range, can_target_air, _buf, true)
	if _buf.is_empty():
		return null
	match rule:
		TowerDef.TargetRule.FIRST:
			return first(_buf)
		TowerDef.TargetRule.DENSEST:
			return _densest(_buf, splash, registry)
		TowerDef.TargetRule.STRONGEST:
			return strongest(_buf)
		TowerDef.TargetRule.AIR_FIRST:
			return air_first(_buf)
	return null


## Furthest along its route.
static func first(cands: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	for e in cands:
		if best == null or e.progress > best.progress:
			best = e
	return best


## Flying enemies first (furthest along among them); if none are flying, same as `first`.
static func air_first(cands: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	var best_flying := false
	for e in cands:
		var flying := e.is_flying()
		if best == null or (flying and not best_flying) or (flying == best_flying and e.progress > best.progress):
			best = e
			best_flying = flying
	return best


## Highest current HP + shield; fliers win ties, then furthest along.
static func strongest(cands: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	var best_v := -1.0
	for e in cands:
		var v := e.hp + e.shield
		if best == null or v > best_v \
				or (v == best_v and e.is_flying() and not best.is_flying()) \
				or (v == best_v and e.is_flying() == best.is_flying() and e.progress > best.progress):
			best = e
			best_v = v
	return best


## Among the 3 furthest-along candidates, choose the one with the most ground enemies inside the splash.
static func _densest(cands: Array[Enemy], splash: float, registry: EnemyRegistry) -> Enemy:
	_top.clear()
	_top.append_array(cands)
	_top.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.progress > b.progress)
	var best: Enemy = null
	var best_count := -1
	for i in range(mini(3, _top.size())):
		var e := _top[i]
		registry.query_circle(e.position, maxf(splash, 1.0), e.is_flying(), _buf2)
		var c := _buf2.size()
		if c > best_count:
			best_count = c
			best = e
	return best
