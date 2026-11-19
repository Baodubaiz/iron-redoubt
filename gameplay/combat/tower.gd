class_name Tower
extends Node2D
## Tower runtime: effective parameters (base + branch tiers + evolution), synergy buffs,
## target acquisition (every RETARGET_INTERVAL), cooldown and firing.
## Hit effects are resolved by MatchController so every rule lives in one place.

const RETARGET_INTERVAL := 0.1

signal fired(tower: Tower, target: Enemy)

var uid: int = 0
var def: TowerDef
var total_invested: int = 0
## Purchased tier per branch. Rules (UpgradeRules): at most 2 branches, only one above tier 2.
var tiers: Array[int] = [0, 0, 0]
## Branches in the order they were first bought (tie-break for the main branch).
var branch_order: Array[int] = []
## Main branch: the one at tier 3, else the highest tier (first bought wins ties); -1 = none.
var branch: int:
	get:
		var best := -1
		for b in branch_order:
			if best == -1 or tiers[b] > tiers[best]:
				best = b
		return best
## Tier of the main branch.
var tier: int:
	get:
		var b := branch
		return tiers[b] if b >= 0 else 0
var evolved: bool = false
var waves_since_t3: int = 0
var sold: bool = false
## Player-chosen targeting priority for this one placed tower; -1 = use def.targeting (default).
## Behaviour only, never power: free to change mid-match, any number of times, no balance impact.
var targeting_override: int = -1

## Effective parameters after upgrades (see docs/COMBAT_PARAMS.md).
var params: Dictionary = {}
# hot-path copies of params
var damage: float = 0.0
var fire_rate: float = 1.0
var attack_range: float = 150.0
var armor_pen: float = 0.0
var splash_radius: float = 0.0
var can_target_air: bool = true

# Synergy (recomputed by MatchController each step; Beacons never receive these)
var amp_damage: float = 0.0
var amp_rate: float = 0.0
var amp_range: float = 0.0
var buff_sources: Array[Tower] = []

var map_range_bonus: float = 0.0 ## Overload node bonus (fixed at build time)
var night_dimmed: bool = false ## night without Beacon light: reduced range
var night_penalty: float = 0.0
var night_glow: bool = false: ## Beacons light the night (visual)
	set(v):
		if night_glow != v:
			night_glow = v
			queue_redraw()
var disrupted_timer: float = 0.0
var jam_timer: float = 0.0 ## Chimera jam: attacks recharge slower
var jam_factor: float = 1.0
var static_timer: float = 0.0 ## Dynamo static field: reduced range
var static_factor: float = 1.0
## Generic data effects on this tower (EffectDef, target TOWER): id -> {"def", "time"}
var effects: Dictionary = {}
## Inside a field generator: immune to disruption (EMP), jamming, static and tower debuff effects.
var protected: bool = false
var target: Enemy = null
var aim_angle: float = -PI * 0.5
var shots_fired: int = 0
var beam_time: float = 0.0
var beam_from_main := false ## Focus is the main branch: the tower fires a continuous beam
var ramp_time_on_target := 0.0 ## normal shots: seconds spent on the current target (secondary Focus ramp)
var _ramp_target: Enemy = null
var aura_timer: float = 0.0 ## Cryo freeze pulse
var mint_timer: float = 0.0
var mint_count: int = 0
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()

var _cooldown: float = 0.0
var _retarget: float = 0.0
var _build_pulse: float = 0.35
var _beam_target: Enemy = null


func setup(tower_def: TowerDef, tower_uid: int, invested: int) -> void:
	def = tower_def
	uid = tower_uid
	total_invested = invested
	recompute()


## Any non-attacking aura tower (Beacon, field generators).
func is_aura() -> bool:
	return def.attack_mode == TowerDef.AttackMode.AURA


## Beacon-type aura (reveal / slow / buffs / economy). Field generators ("field" param) are auras but not Beacons.
func is_beacon() -> bool:
	return def.attack_mode == TowerDef.AttackMode.AURA and not bool(params.get("field", false))


func is_disrupted() -> bool:
	return disrupted_timer > 0.0


func is_jammed() -> bool:
	return jam_timer > 0.0


func is_static() -> bool:
	return static_timer > 0.0


func apply_effect(e: EffectDef, duration: float = -1.0) -> void:
	if e == null:
		return
	var dur := e.duration if duration < 0.0 else duration
	if effects.has(e.id):
		effects[e.id]["time"] = maxf(float(effects[e.id]["time"]), dur)
	else:
		effects[e.id] = {"def": e, "time": dur}
	queue_redraw()


func effect_product(key: String) -> float:
	var m := 1.0
	for k in effects:
		var d: EffectDef = effects[k]["def"]
		if d.components.has(key):
			m *= float(d.components[key])
	return m


func effect_flag(key: String) -> bool:
	for k in effects:
		if bool((effects[k]["def"] as EffectDef).components.get(key, false)):
			return true
	return false


func _tick_effects(dt: float) -> void:
	var done: Array = []
	for k in effects:
		effects[k]["time"] = float(effects[k]["time"]) - dt
		if float(effects[k]["time"]) <= 0.0:
			done.append(k)
	for k in done:
		effects.erase(k)


func p(key: String, default: Variant = 0.0) -> Variant:
	return params.get(key, default)


func pf(key: String) -> float:
	return float(params.get(key, 0.0))


## Rebuilds `params` from the definition, the committed branch tiers and the evolution.
func recompute() -> void:
	params = {
		"damage": def.damage, "fire_rate": def.fire_rate, "attack_range": def.attack_range,
		"armor_pen": def.armor_pen, "splash_radius": def.splash_radius, "can_target_air": def.can_target_air,
	}
	params.merge(def.base_params, true)
	# Branches ADD UP (2026-11-19, user): each branch's tiers (and the main branch's evolution) give that
	# branch's value of a stat; the change it makes is (branch value - base value), and every branch's change
	# is added to the base -- a "+" adds, a "-" subtracts, no max / no %. Flags: or. Lists: union.
	# Dictionaries (tag_mult): per-key max. Numbers never go below 0 when nothing involved was negative.
	var main_b := branch
	var base := params.duplicate(true)
	var deltas := {}
	var others := {}
	var touched_neg := {}
	beam_from_main = false
	for b in range(mini(def.branches.size(), tiers.size())):
		if tiers[b] <= 0:
			continue
		var bp := {}
		for i in range(mini(tiers[b], def.branches[b].tiers.size())):
			bp.merge(def.branches[b].tiers[i].stats, true)
		if b == main_b and evolved and def.branches[b].evolution != null:
			bp.merge(def.branches[b].evolution.stats, true)
		if b == main_b and bp.has("beam_dps"):
			beam_from_main = true
		for k in bp:
			var v: Variant = bp[k]
			var bv: Variant = base.get(k)
			if (v is float or v is int) and not (bv is bool) and (bv == null or bv is float or bv is int):
				var b0 := float(bv) if bv != null else 0.0
				deltas[k] = float(deltas.get(k, 0.0)) + float(v) - b0
				if float(v) < 0.0 or b0 < 0.0:
					touched_neg[k] = true
			else:
				others[k] = v if not others.has(k) else _stronger(others[k], v)
	for k in others:
		params[k] = others[k] if not base.has(k) else _stronger(base[k], others[k])
	for k in deltas:
		var bv: Variant = base.get(k)
		var total := (float(bv) if bv != null else 0.0) + float(deltas[k])
		if not touched_neg.has(k):
			total = maxf(total, 0.0)
		params[k] = int(round(total)) if (bv is int or (bv == null and _all_int(k, main_b))) else total
	# Focus (beam) is a firing mode: only the MAIN branch can switch the tower to a beam. As a secondary
	# branch it lends its ramp to normal shots on the same target instead (see shot_ramp()).
	if not beam_from_main:
		params.erase("beam_dps")
	damage = float(params["damage"])
	fire_rate = maxf(float(params["fire_rate"]), 0.01)
	attack_range = float(params["attack_range"])
	armor_pen = float(params["armor_pen"])
	splash_radius = float(params["splash_radius"])
	can_target_air = bool(params["can_target_air"])
	queue_redraw()


## True when every branch tier that sets `k` uses a whole number (counts like chain / pierce / crit_every).
func _all_int(k: String, _main: int) -> bool:
	for b in range(mini(def.branches.size(), tiers.size())):
		var br := def.branches[b]
		for tr in br.tiers + ([br.evolution] if br.evolution != null else []):
			if tr != null and tr.stats.has(k) and not (tr.stats[k] is int):
				return false
	return true


static func _stronger(a: Variant, b: Variant) -> Variant:
	if a is bool or b is bool:
		return bool(a) or bool(b)
	if a is Array or b is Array: # e.g. on_hit_effects: union
		var out: Array = (a as Array).duplicate() if a is Array else []
		for x in (b if b is Array else []):
			if not out.has(x):
				out.append(x)
		return out
	if a is Dictionary or b is Dictionary: # e.g. tag_mult: per-key max
		var d: Dictionary = (a as Dictionary).duplicate() if a is Dictionary else {}
		for k in (b if b is Dictionary else {}):
			d[k] = maxf(float(d.get(k, 0.0)), float(b[k]))
		return d
	if a is String or a is StringName or b is String or b is StringName:
		return b
	return maxf(float(a), float(b))


## Records one purchased tier on branch `b` (validation lives in UpgradeRules / controller).
func add_tier(b: int) -> void:
	if not branch_order.has(b):
		branch_order.append(b)
	tiers[b] += 1


func secondary_branch() -> int:
	var main := branch
	for b in branch_order:
		if b != main:
			return b
	return -1


func eff_damage() -> float:
	return damage * (1.0 + amp_damage) # data effect damage_mult is applied per hit (MatchController._hit_mult)


func eff_rate() -> float:
	return fire_rate * (1.0 + amp_rate)


func eff_range() -> float:
	var r := attack_range * (1.0 + amp_range) * (1.0 + map_range_bonus)
	if night_dimmed:
		r *= 1.0 - night_penalty
	if static_timer > 0.0:
		r *= static_factor
	if not effects.is_empty():
		r *= effect_product("range_mult")
	return r


func branch_def() -> BranchDef:
	return def.branches[branch] if branch >= 0 and branch < def.branches.size() else null


func _has_valid_target(rng: float) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_targetable():
		return false
	if target.is_flying() and not can_target_air:
		return false
	return target.position.distance_squared_to(position) <= rng * rng


func step(dt: float, ctrl: MatchController) -> void:
	if static_timer > 0.0:
		static_timer = maxf(static_timer - dt, 0.0)
	var cdt := dt
	if not effects.is_empty():
		_tick_effects(dt)
		cdt = dt * effect_product("fire_rate_mult")
		if effect_flag("disabled"):
			disrupted_timer = maxf(disrupted_timer, dt)
	if jam_timer > 0.0:
		jam_timer = maxf(jam_timer - dt, 0.0)
		cdt = dt * jam_factor
	_cooldown = maxf(_cooldown - cdt, -cdt) # small negative carry keeps the fire rate exact across frames
	_retarget -= dt
	if _build_pulse > 0.0:
		_build_pulse = maxf(_build_pulse - dt, 0.0)
		queue_redraw()
	if disrupted_timer > 0.0:
		disrupted_timer = maxf(disrupted_timer - dt, 0.0)
		target = null
		_beam_target = null
		beam_time = 0.0
		_cooldown = maxf(_cooldown, 0.0)
		queue_redraw()
		return
	if is_aura():
		return # auras are applied by MatchController
	var rng := eff_range()
	if not _has_valid_target(rng):
		target = null
		if _retarget <= 0.0:
			_retarget = RETARGET_INTERVAL
			target = Targeting.pick(position, targeting_override if targeting_override >= 0 else def.targeting,
				rng, can_target_air, splash_radius, ctrl.registry)
	if target == null:
		_cooldown = maxf(_cooldown, 0.0)
		if _beam_target != null:
			_beam_target = null
			beam_time = 0.0
			queue_redraw()
		return
	var new_angle := (target.position - position).angle()
	if absf(angle_difference(aim_angle, new_angle)) > 0.01:
		aim_angle = new_angle
		queue_redraw()
	if pf("beam_dps") > 0.0:
		if _beam_target != target:
			_beam_target = target
			beam_time = 0.0
		beam_time += cdt
		ctrl.beam_tick(self, target, cdt)
		queue_redraw()
		return
	if _ramp_target != target:
		_ramp_target = target
		ramp_time_on_target = 0.0
	ramp_time_on_target += cdt
	if _cooldown <= 0.0:
		_cooldown += 1.0 / eff_rate()
		shots_fired += 1
		ctrl.fire(self, target)
		fired.emit(self, target)


func beam_ramp() -> float:
	var ramp_max := maxf(pf("ramp_max"), 1.0)
	var ramp_time := maxf(pf("ramp_time"), 0.01)
	return 1.0 + (ramp_max - 1.0) * minf(beam_time / ramp_time, 1.0)


## Beam damage per second before ramp: Focus beam scaled by any damage gain (secondary Overcharge) and buffs.
func beam_dps() -> float:
	var dmg_scale := damage / def.damage if def.damage > 0.0 else 1.0
	return pf("beam_dps") * dmg_scale * (1.0 + amp_damage)


## Secondary Focus on a shooting tower: shots ramp up on the same target, like the beam does.
func shot_ramp() -> float:
	if pf("ramp_max") <= 1.0 or pf("beam_dps") > 0.0:
		return 1.0
	var ramp_max := pf("ramp_max")
	var ramp_t := maxf(pf("ramp_time"), 0.01)
	return 1.0 + (ramp_max - 1.0) * minf(ramp_time_on_target / ramp_t, 1.0)


## Presentation hook (read-only): the enemy the continuous beam is on, or null.
func beam_target() -> Enemy:
	return _beam_target


## Drawing lives in TowerVisual (gameplay/visuals) since Reforged Stage C.
func pulse_feedback() -> void:
	_build_pulse = 0.35
	queue_redraw()
