class_name Enemy
extends Node2D
## Enemy runtime state, movement and status effects.
## Status policy: one instance per status; re-application refreshes duration and keeps the
## highest magnitude (no summing). Exception: Shred stacks up to its cap.
## Terminal transitions (death/escape) are enforced exactly once by MatchController via `state`.

enum State { ALIVE, DEAD, ESCAPED }

const REVEAL_LINGER := 1.5
const BOSS_STAGGER_SLOW := 0.15

var uid: int = 0
var def: EnemyDef
var route: RoutePath
var hp: float = 0.0
var max_hp: float = 0.0
var base_damage: int = 1
var progress: float = 0.0
var state: State = State.ALIVE
var summoned: bool = false ## spawned by an ability: grants no bounty

# Shield
var shield: float = 0.0
var shield_max: float = 0.0
var _shield_idle: float = 0.0

# Statuses
var aura_slow: float = 0.0 ## recomputed every step from Beacon auras (removed instantly if the Beacon goes)
var aura_reveal: bool = false
var reveal_timer: float = 0.0
var mark_value: float = 0.0
var mark_timer: float = 0.0
var burn_dps: float = 0.0
var burn_timer: float = 0.0
var burn_explode: float = 0.0 ## Inferno: explosion damage on death while burning
var shred: float = 0.0
var shred_timer: float = 0.0
var stun_timer: float = 0.0
var frozen_timer: float = 0.0
var shatter: float = 0.0
var stagger_timer: float = 0.0
var grounded_timer: float = 0.0

# Abilities (healer / boss)
var ability_timer: float = 0.0
var telegraph_timer: float = 0.0
var telegraph_kind: int = 0 ## 0 none, 1 summon, 2 emp
var boss_phase: int = 1
var max_boss_phases: int = 3
var heal_pulse_fx: float = 0.0
# Boss kits (EnemyAbilities): second skill timer, skill alternation, total telegraph length (visuals)
var ability_timer2: float = 0.0
var skill_toggle: bool = false
var telegraph_total: float = 0.0
var boss_speed_mult: float = 1.0 ## Warden sprint
var sprint_timer: float = 0.0
var cloak_timer: float = 0.0 ## Carrier cloak: untargetable unless revealed (splash still hits)
var overshield: float = 0.0 ## temporary absorb layer (Warden shell, Colossus bulwark); no regen
var overshield_timer: float = 0.0
var bonus_armor: float = 0.0 ## Chimera armour mode
var chimera_mode: int = 0 ## 0 armour, 1 shield
var haste: float = 0.0 ## Colossus overdrive aura
var haste_timer: float = 0.0
var hit_cap: float = 0.0 ## Dynamo capacitor: max damage per hit while active
var hit_cap_timer: float = 0.0
var submerge_timer: float = 0.0 ## Leviathan: untargetable and immune to all damage
var immune_type: int = -1 ## Refractor prismatic shield: damage type resisted 90%
var immune_timer: float = 0.0
var overload: bool = false ## Dynamo phase III: permanent speed boost
var skill_index: int = 0 ## data-driven boss skills: next skill in the rotation
var current_skill: BossSkillDef = null
var telegraph_params: Dictionary = {} ## params of the skill being telegraphed (visuals read radii here)
## Generic data effects (EffectDef): id -> {"def": EffectDef, "time": float, "stacks": int}
var effects: Dictionary = {}

var _seg: int = 0
var _flash: float = 0.0
var _redraw_accum: float = 0.0


func setup(enemy_def: EnemyDef, enemy_route: RoutePath, enemy_uid: int, hp_mult: float = 1.0,
		base_damage_override: int = -1, phase_limit: int = 3) -> void:
	def = enemy_def
	route = enemy_route
	uid = enemy_uid
	max_hp = def.max_hp * hp_mult
	hp = max_hp
	base_damage = base_damage_override if base_damage_override >= 0 else def.base_damage
	shield_max = def.shield
	shield = shield_max
	max_boss_phases = mini(phase_limit, def.boss_phase_count)
	progress = 0.0
	_seg = 0
	state = State.ALIVE
	ability_timer = def.heal_interval if def.heal_amount > 0.0 else 0.0
	if def.is_boss:
		if def.boss_kit == &"monolith":
			ability_timer = def.summon_interval
		else:
			EnemyAbilities.init_kit(self)
	elif not def.boss_skills.is_empty():
		EnemyAbilities.init_kit(self)
	position = route.position_at(0.0, 0)
	queue_redraw()


func place_at_progress(p: float) -> void:
	progress = clampf(p, 0.0, route.total_length)
	_seg = route.segment_for(progress, 0)
	position = route.position_at(progress, _seg)
	if is_inside_tree():
		reset_physics_interpolation() # teleport (Colossus blink): jump, do not slide


func is_alive() -> bool:
	return state == State.ALIVE


func is_boss() -> bool:
	return def.is_boss


func is_flying() -> bool:
	return def.flying and grounded_timer <= 0.0


func is_revealed() -> bool:
	return reveal_timer > 0.0 or aura_reveal


## Can a tower pick this enemy as a target? (Splash damage ignores this.)
func is_targetable() -> bool:
	if not effects.is_empty() and effect_flag("untargetable"):
		return false
	return state == State.ALIVE and submerge_timer <= 0.0 and (not is_stealthy() or is_revealed())


## Natural stealth (Phantom) or a boss cloak.
func is_stealthy() -> bool:
	return def.stealth or cloak_timer > 0.0


func is_chilled() -> bool:
	return aura_slow > 0.0 or frozen_timer > 0.0


func is_frozen() -> bool:
	return frozen_timer > 0.0


func is_burning() -> bool:
	return burn_timer > 0.0


## True while any Venom poison stack (direct hit or the Spray cloud) is active.
func is_poisoned() -> bool:
	for k in effects:
		if String(k).begins_with("venom"):
			return true
	return false


func effective_armor() -> float:
	if not effects.is_empty():
		return maxf(def.armor + bonus_armor - shred + effect_sum("armor_add"), 0.0)
	return maxf(def.armor + bonus_armor - shred, 0.0)


## Armor against one specific damage type: EnemyDef.armor_by_type override if this enemy has one
## for it, else the type's own default (0 for Poison/True, the generic `armor` stat otherwise).
## True always resolves to 0, even with an override -- true damage is meant to be unconditional.
func effective_armor_for(type: int) -> float:
	if type == Damage.Type.TRUE:
		return 0.0
	var d := Damage.type_def(type)
	var key := String(d.id) if d != null else ""
	if def.armor_by_type.has(key):
		var base: float = def.armor_by_type[key]
		if not effects.is_empty():
			return maxf(base + bonus_armor - shred + effect_sum("armor_add"), 0.0)
		return maxf(base + bonus_armor - shred, 0.0)
	if d != null and d.ignores_armor:
		return 0.0
	return effective_armor()


## This enemy's permanent PERCENT resistance to one damage type (EnemyDef.resist_pct), separate
## from (and stacks with) its flat armor. 0 if this enemy has none set for that type.
func resist_pct_for(type: int) -> float:
	var d := Damage.type_def(type)
	var key := String(d.id) if d != null else ""
	return clampf(float(def.resist_pct.get(key, 0.0)), 0.0, 1.0)


## Diminishing-returns cap for every slow source beyond the strongest one (user request, 2026-11-16:
## "cộng lên... max 50% mỗi 50% cộng thêm 10%"): the strongest active slow (Beacon aura, Shock Trap,
## Venom's Neurotoxin, boss stagger, ...) counts in full; each additional source adds at most this
## much on top, however strong it is on its own. Combining towers is always worth something, but
## never as much as the first one -- so one maxed tower can't reach the old single-source cap alone,
## while several still can't push the total anywhere near a full stop (def.slow_cap backstops that).
const EXTRA_SLOW_CAP := 0.10


func speed_multiplier() -> float:
	if not def.is_boss and (stun_timer > 0.0 or frozen_timer > 0.0):
		return 0.0
	if not effects.is_empty() and effect_flag("stop") and not def.is_boss:
		return 0.0
	var slows: Array[float] = []
	if aura_slow > 0.0:
		slows.append(aura_slow)
	if stagger_timer > 0.0:
		slows.append(BOSS_STAGGER_SLOW)
	for k in effects:
		var inst: Dictionary = effects[k]
		var d: EffectDef = inst["def"]
		if d.components.has("speed_mult"):
			var raw := 1.0 - float(d.components["speed_mult"])
			if raw > 0.0:
				slows.append(raw)
	var total_slow := 0.0
	if not slows.is_empty():
		slows.sort()
		slows.reverse()
		total_slow = slows[0]
		for i in range(1, slows.size()):
			total_slow += minf(slows[i], EXTRA_SLOW_CAP)
	total_slow = minf(total_slow, def.slow_cap)
	var mult := 1.0 - total_slow
	if def.is_boss and boss_phase >= 3 and def.boss_kit == &"monolith":
		mult *= 1.0 + def.fracture_speed_bonus
	if haste_timer > 0.0:
		mult *= 1.0 + haste
	if sprint_timer > 0.0:
		mult *= boss_speed_mult
	if overload:
		mult *= boss_speed_mult
	for k in effects:
		var inst: Dictionary = effects[k]
		var d: EffectDef = inst["def"]
		if d.components.has("speed_mult"):
			var sm := float(d.components["speed_mult"])
			if sm > 1.0:
				mult *= pow(sm, int(inst.get("stacks", 1)))
	return mult


var _hop_t := -1.0


## Hopper: dash (x cycle/on speed) then stand still; average speed unchanged. Advances the hop clock.
func hop_factor(dt: float) -> float:
	if def.hop_on <= 0.0:
		return 1.0
	var cycle := def.hop_on + def.hop_off
	if _hop_t < 0.0:
		_hop_t = fmod(float(uid) * 0.37, cycle) # not all in step
	_hop_t = fmod(_hop_t + dt, cycle)
	return cycle / def.hop_on if _hop_t < def.hop_on else 0.0


## 0..1 through the current dash, -1 while standing still (visuals).
func hop_phase() -> float:
	if def.hop_on <= 0.0 or _hop_t < 0.0:
		return -1.0
	return _hop_t / def.hop_on if _hop_t < def.hop_on else -1.0


func current_speed() -> float:
	return def.speed * speed_multiplier()


# ---------------------------------------------------------------- status application

func apply_mark(value: float, duration: float) -> void:
	mark_value = maxf(mark_value if mark_timer > 0.0 else 0.0, value)
	mark_timer = maxf(mark_timer, duration)


func apply_burn(dps: float, duration: float, explode: float = 0.0) -> void:
	if burn_timer <= 0.0:
		burn_dps = 0.0
		burn_explode = 0.0
	burn_dps = maxf(burn_dps, dps)
	burn_explode = maxf(burn_explode, explode)
	burn_timer = maxf(burn_timer, duration)


func apply_shred(amount: float, cap: float, duration: float = 4.0) -> void:
	shred = minf(shred + amount, cap)
	shred_timer = duration


## Bosses are immune to stun: they receive a short Stagger slow instead.
func apply_stun(duration: float) -> void:
	if def.is_boss:
		stagger_timer = maxf(stagger_timer, duration)
	else:
		stun_timer = maxf(stun_timer, duration)


func apply_freeze(duration: float, shatter_bonus: float) -> void:
	if def.is_boss:
		stagger_timer = maxf(stagger_timer, duration)
		return
	frozen_timer = maxf(frozen_timer, duration)
	shatter = maxf(shatter, shatter_bonus)


func apply_grounded(duration: float) -> void:
	if def.flying:
		grounded_timer = maxf(grounded_timer, duration)


func reveal() -> void:
	reveal_timer = REVEAL_LINGER


## Advances status timers. Returns burn damage for this step (applied by the controller).
func tick_statuses(dt: float) -> float:
	var burn := 0.0
	if burn_timer > 0.0:
		burn = burn_dps * minf(dt, burn_timer)
		burn_timer -= dt
		if burn_timer <= 0.0:
			burn_dps = 0.0
			burn_explode = 0.0
	if mark_timer > 0.0:
		mark_timer -= dt
		if mark_timer <= 0.0:
			mark_value = 0.0
	if shred_timer > 0.0:
		shred_timer -= dt
		if shred_timer <= 0.0:
			shred = 0.0
	stun_timer = maxf(stun_timer - dt, 0.0)
	stagger_timer = maxf(stagger_timer - dt, 0.0)
	grounded_timer = maxf(grounded_timer - dt, 0.0)
	if frozen_timer > 0.0:
		frozen_timer -= dt
		if frozen_timer <= 0.0:
			frozen_timer = 0.0
			shatter = 0.0
	if aura_reveal:
		reveal_timer = REVEAL_LINGER
	else:
		reveal_timer = maxf(reveal_timer - dt, 0.0)
	if shield_max > 0.0 and shield < shield_max:
		_shield_idle += dt
		if _shield_idle >= def.shield_regen_delay:
			shield = minf(shield_max, shield + def.shield_regen_rate * dt)
	heal_pulse_fx = maxf(heal_pulse_fx - dt, 0.0)
	if cloak_timer > 0.0:
		cloak_timer = maxf(cloak_timer - dt, 0.0)
	if sprint_timer > 0.0:
		sprint_timer = maxf(sprint_timer - dt, 0.0)
	if haste_timer > 0.0:
		haste_timer = maxf(haste_timer - dt, 0.0)
	if hit_cap_timer > 0.0:
		hit_cap_timer = maxf(hit_cap_timer - dt, 0.0)
	if submerge_timer > 0.0:
		submerge_timer = maxf(submerge_timer - dt, 0.0)
	if immune_timer > 0.0:
		immune_timer = maxf(immune_timer - dt, 0.0)
		if immune_timer <= 0.0:
			immune_type = -1
	if overshield_timer > 0.0:
		overshield_timer -= dt
		if overshield_timer <= 0.0:
			overshield_timer = 0.0
			overshield = 0.0
	return burn


# ---------------------------------------------------------------- movement & damage

## Moves along the route. Returns true when the end (base) is reached this step.
func advance(dt: float) -> bool:
	if state != State.ALIVE:
		return false
	progress += current_speed() * hop_factor(dt) * dt
	if progress >= route.total_length:
		progress = route.total_length
		position = route.points[route.points.size() - 1]
		return true
	_seg = route.segment_for(progress, _seg)
	position = route.position_at(progress, _seg)
	if _flash > 0.0:
		_flash = maxf(_flash - dt, 0.0)
	_redraw_accum += dt
	if _redraw_accum >= 0.1 or _flash > 0.0:
		_redraw_accum = 0.0
		queue_redraw()
	return false


## Shield absorbs first (scaled by shield_mult); the remainder is returned for HP damage.
func absorb_with_shield(amount: float, shield_mult: float) -> float:
	_shield_idle = 0.0
	if overshield > 0.0 and amount > 0.0:
		var vs_over := amount * shield_mult
		if vs_over <= overshield:
			overshield -= vs_over
			return 0.0
		amount = (vs_over - overshield) / shield_mult
		overshield = 0.0
	if shield <= 0.0 or amount <= 0.0:
		return amount
	var vs_shield := amount * shield_mult
	if vs_shield <= shield:
		shield -= vs_shield
		return 0.0
	var leftover := (vs_shield - shield) / shield_mult
	shield = 0.0
	return leftover


func take_damage(amount: float) -> float:
	if state != State.ALIVE or amount <= 0.0:
		return 0.0
	var removed := minf(amount, hp)
	hp -= removed
	_flash = 0.06
	queue_redraw()
	return removed


func heal(amount: float) -> float:
	if state != State.ALIVE or amount <= 0.0:
		return 0.0
	if not effects.is_empty():
		amount *= effect_product("heal_mult")
	var healed := minf(amount, max_hp - hp)
	hp += healed
	return healed


func remaining_distance() -> float:
	return route.total_length - progress


# ---------------------------------------------------------------- generic data effects (EffectDef)

## Applies a data effect. Stacking rules come from the EffectDef. Returns false if ignored.
func apply_effect(e: EffectDef, duration: float = -1.0) -> bool:
	if e == null or state != State.ALIVE or (def.is_boss and not e.affects_bosses):
		return false
	var dur := e.duration if duration < 0.0 else duration
	var cur: Variant = effects.get(e.id)
	if cur == null:
		effects[e.id] = {"def": e, "time": dur, "stacks": 1}
	else:
		match e.stacking:
			EffectDef.Stacking.STACK:
				cur["stacks"] = mini(int(cur["stacks"]) + 1, maxi(e.max_stacks, 1))
				cur["time"] = maxf(float(cur["time"]), dur)
			_:
				cur["time"] = maxf(float(cur["time"]), dur)
	return true


func has_effect(id: StringName) -> bool:
	return effects.has(id)


func remove_effect(id: StringName) -> void:
	effects.erase(id)


## Product of a multiplier component over all active effects (stacks multiply).
func effect_product(key: String) -> float:
	var m := 1.0
	for k in effects:
		var inst: Dictionary = effects[k]
		var d: EffectDef = inst["def"]
		if d.components.has(key):
			m *= pow(float(d.components[key]), int(inst["stacks"]))
	return m


## Sum of an additive component over all active effects (stacks add).
func effect_sum(key: String) -> float:
	var v := 0.0
	for k in effects:
		var inst: Dictionary = effects[k]
		var d: EffectDef = inst["def"]
		if d.components.has(key):
			v += float(d.components[key]) * int(inst["stacks"])
	return v


func effect_flag(key: String) -> bool:
	for k in effects:
		if bool((effects[k]["def"] as EffectDef).components.get(key, false)):
			return true
	return false


## Advances data effects. Returns [[amount, damage_type], ...] for damage-over-time this step
## (applied by the controller) and applies regeneration.
func tick_effects(dt: float) -> Array:
	var out: Array = []
	if effects.is_empty():
		return out
	var done: Array = []
	for k in effects:
		var inst: Dictionary = effects[k]
		var d: EffectDef = inst["def"]
		var stacks := int(inst["stacks"])
		var step_t := minf(dt, float(inst["time"]))
		var dps := float(d.components.get("dot_dps", 0.0))
		if dps > 0.0:
			var t := Damage.type_from_id(String(d.components.get("dot_type", "true")))
			out.append([dps * stacks * step_t, t if t >= 0 else Damage.Type.TRUE])
		var regen := float(d.components.get("regen_frac", 0.0))
		if regen > 0.0:
			heal(max_hp * regen * stacks * step_t)
		inst["time"] = float(inst["time"]) - dt
		if float(inst["time"]) <= 0.0:
			done.append(k)
	for k in done:
		effects.erase(k)
	return out


## Built-in + data tags: flying, boss, stealth, shielded, armored + EnemyDef.tags.
func has_tag(tag: StringName) -> bool:
	match tag:
		&"flying": return is_flying()
		&"boss": return def.is_boss
		&"stealth": return def.stealth
		&"shielded": return shield_max > 0.0
		&"armored": return def.armor >= 4.0
	return def.tags.has(tag)


# ---------------------------------------------------------------- presentation

## Presentation hook (read-only): remaining hit-flash time. Drawing lives in EnemyVisual
## (gameplay/visuals) since Reforged Stage D.
func hit_flash() -> float:
	return _flash
