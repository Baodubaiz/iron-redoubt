class_name EnemyAbilities
extends RefCounted
## Active enemy abilities: Mender healing and the boss kits. Every boss skill is telegraphed and
## runs on the match clock (pause-safe, deterministic).
##   monolith  (Prism, L9)    I summon Swarmlings | II EMP (towers stop) | III fracture + split
##   warden    (Circuit, L3)  I Carapace: self overshield | II + Overclock sprint
##   carrier   (Delta, L6)    I Hangar: launches Gliders | II + Cloak field (self + escorts)
##   chimera   (Rift, L14)    I Adaptive plating: armour <-> regenerating shield | II + Jammer
##                            (towers recharge slower) | III plating swaps twice as fast
##   colossus  (Rift, L19)    I Bulwark: overshields nearby allies | II + Rift blink forward |
##                            III Overdrive: allies around it run faster, it regenerates
##   dynamo    (Circuit, 10)  I Static field: towers nearby lose range | II + Capacitor: each hit capped |
##                            III Overload: permanently faster
##   leviathan (Delta, 10)    I Submerge: untargetable + immune | II + Revive: recent kills rise again |
##                            III submerges twice as often
##   refractor (Prism, 5)     I Mirror decoys: fragile copies run ahead | II + Prismatic shield: resists
##                            one damage type (cycles kinetic -> explosive -> energy)

const SUMMON_KIND := 1
const EMP_KIND := 2
const SHELL_KIND := 3
const SPRINT_KIND := 4
const HANGAR_KIND := 5
const CLOAK_KIND := 6
const ADAPT_KIND := 7
const JAM_KIND := 8
const BULWARK_KIND := 9
const BLINK_KIND := 10
const STATIC_KIND := 11
const CAPACITOR_KIND := 12
const SUBMERGE_KIND := 13
const REVIVE_KIND := 14
const DECOY_KIND := 15
const PRISM_KIND := 16
const EFFECT_KIND := 17 ## data action effect_area
const SUMMON_DATA_KIND := 18 ## data action summon
const HEAL_KIND := 19 ## data action heal_area

## Telegraph label per kind (HUD boss bar).
const KIND_LABEL := {
	EMP_KIND: "EMP incoming!", SUMMON_KIND: "Summoning!", SHELL_KIND: "Hardening shell!",
	SPRINT_KIND: "Overclocking!", HANGAR_KIND: "Launching fighters!", CLOAK_KIND: "Cloaking!",
	ADAPT_KIND: "Adapting plating!", JAM_KIND: "Jamming towers!", BULWARK_KIND: "Shielding escorts!",
	BLINK_KIND: "Rift jump!", STATIC_KIND: "Static field!", CAPACITOR_KIND: "Capacitor charging!",
	SUBMERGE_KIND: "Submerging!", REVIVE_KIND: "Raising the fallen!", DECOY_KIND: "Splitting light!",
	PRISM_KIND: "Prismatic shield!", EFFECT_KIND: "Charging!", SUMMON_DATA_KIND: "Summoning!", HEAL_KIND: "Healing!",
}
const PRISM_CYCLE := [Damage.Type.KINETIC, Damage.Type.EXPLOSIVE, Damage.Type.ENERGY]
static var _decoy_cache: Dictionary = {}

static var _buf: Array[Enemy] = []
static var _shard_cache: Dictionary = {}


static func step(e: Enemy, dt: float, ctrl: MatchController) -> void:
	if not e.is_alive():
		return
	if e.def.heal_amount > 0.0:
		_mender(e, dt, ctrl)
	if e.def.is_boss:
		_boss(e, dt, ctrl)
	elif not e.def.boss_skills.is_empty(): # regular enemies with data skills (single phase)
		_kit(e, dt, ctrl, 1)


# ---------------------------------------------------------------- Mender

static func _mender(e: Enemy, dt: float, ctrl: MatchController) -> void:
	e.ability_timer -= dt
	if e.ability_timer > 0.0:
		return
	e.ability_timer += e.def.heal_interval
	ctrl.registry.query_circle(e.position, e.def.heal_radius, true, _buf)
	var allies: Array[Enemy] = []
	for a in _buf:
		if a != e and a.hp < a.max_hp:
			allies.append(a)
	# most missing HP first, deterministic tie-break by uid
	allies.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		var ma := a.max_hp - a.hp
		var mb := b.max_hp - b.hp
		return ma > mb if ma != mb else a.uid < b.uid)
	var n := mini(e.def.heal_max_targets, allies.size())
	for i in range(n):
		var a := allies[i]
		var amount := a.max_hp * e.def.heal_boss_fraction if a.is_boss() else e.def.heal_amount
		if a.is_burning():
			amount *= 0.5 # Burn: -50% healing received
		ctrl.stats_healed += a.heal(amount)
	e.heal_pulse_fx = 0.4
	e.queue_redraw()


# ---------------------------------------------------------------- Monolith

static func phase_for(e: Enemy) -> int:
	var ratio := e.hp / e.max_hp
	var phase := 1
	if ratio <= 0.33:
		phase = 3
	elif ratio <= 0.66:
		phase = 2
	return mini(phase, e.max_boss_phases)


static func _boss(e: Enemy, dt: float, ctrl: MatchController) -> void:
	var phase := phase_for(e)
	var monolith := e.def.boss_kit == &"monolith"
	if phase != e.boss_phase:
		e.boss_phase = phase
		e.telegraph_timer = 0.0
		e.telegraph_kind = 0
		if monolith:
			e.ability_timer = e.def.emp_interval * 0.5 if phase == 2 else 0.0
		else:
			e.ability_timer = minf(e.ability_timer, 1.5)
			_open_phase(e, phase) # the new phase opens with its newest skill
		ctrl.boss_phase_changed.emit(e, phase)
		e.queue_redraw()
	if not monolith:
		_kit(e, dt, ctrl, phase)
		return
	if phase >= 3:
		return
	if e.telegraph_timer > 0.0:
		e.telegraph_timer -= dt
		e.queue_redraw()
		if e.telegraph_timer <= 0.0:
			e.telegraph_timer = 0.0
			var kind := e.telegraph_kind
			e.telegraph_kind = 0
			if kind == SUMMON_KIND:
				_summon(e, ctrl)
			elif kind == EMP_KIND:
				ctrl.disrupt_towers(e.position, e.def.emp_radius, e.def.emp_duration)
		return
	e.ability_timer -= dt
	if e.ability_timer <= 0.0:
		if phase == 1 and e.def.summon_enemy != null:
			e.telegraph_kind = SUMMON_KIND
			e.telegraph_timer = e.def.summon_telegraph
			e.ability_timer = e.def.summon_interval
		elif phase == 2:
			e.telegraph_kind = EMP_KIND
			e.telegraph_timer = e.def.emp_telegraph
			e.ability_timer = e.def.emp_interval


# ---------------------------------------------------------------- other boss kits

## Boss parameter: the current skill's params first, then EnemyDef.boss_params.
static func bp(e: Enemy, key: String, default: float) -> float:
	if e.telegraph_params.has(key):
		return float(e.telegraph_params[key])
	return float(e.def.boss_params.get(key, default))


## action id (BossSkillDef.action) -> telegraph kind (visuals / HUD labels)
const ACTION_KIND := {
	&"shell": SHELL_KIND, &"sprint": SPRINT_KIND, &"hangar": HANGAR_KIND, &"cloak": CLOAK_KIND,
	&"adapt": ADAPT_KIND, &"jam": JAM_KIND, &"bulwark": BULWARK_KIND, &"blink": BLINK_KIND,
	&"static": STATIC_KIND, &"capacitor": CAPACITOR_KIND, &"submerge": SUBMERGE_KIND, &"revive": REVIVE_KIND,
	&"decoy": DECOY_KIND, &"prism": PRISM_KIND, &"effect_area": EFFECT_KIND, &"summon": SUMMON_DATA_KIND,
	&"heal_area": HEAL_KIND,
}


## Called from Enemy.setup for data-driven bosses.
static func init_kit(e: Enemy) -> void:
	e.ability_timer = bp(e, "first_skill", 4.0)
	for sk in e.def.boss_skills:
		if sk.action == &"adapt": # Chimera starts in armour mode
			e.telegraph_params = sk.params
			_set_chimera_mode(e, 0)
			e.telegraph_params = {}


## Data-driven bosses: passives by phase, then the telegraphed skill rotation (BossSkillDef).
## In each phase the eligible skills take turns; a new phase opens with its newest skill.
static func _kit(e: Enemy, dt: float, ctrl: MatchController, phase: int) -> void:
	for pv in e.def.boss_passives:
		if phase < int(pv.get("min_phase", 1)):
			continue
		match String(pv.get("kind", "")):
			"overload": # permanent speed boost
				if not e.overload:
					e.overload = true
					e.boss_speed_mult = float(pv.get("mult", 1.35))
			"overdrive": # escorts around it run faster, it regenerates
				ctrl.registry.query_circle(e.position, float(pv.get("radius", 180.0)), true, _buf)
				for a in _buf:
					if a != e and a.is_alive():
						a.haste = float(pv.get("haste", 0.3))
						a.haste_timer = 0.25
				e.heal(e.max_hp * float(pv.get("regen", 0.003)) * dt)
			"aura_effect": # data: apply an EffectDef to allies around it every step
				var fx := EffectDef.by_id(String(pv.get("effect", "")))
				if fx != null:
					ctrl.registry.query_circle(e.position, float(pv.get("radius", 150.0)), true, _buf)
					for a in _buf:
						if a != e and a.is_alive():
							a.apply_effect(fx, 0.25)
	# telegraphed skills
	if e.telegraph_timer > 0.0:
		e.telegraph_timer -= dt
		e.queue_redraw()
		if e.telegraph_timer <= 0.0:
			e.telegraph_timer = 0.0
			var kind := e.telegraph_kind
			e.telegraph_kind = 0
			if e.current_skill != null:
				_fire(e, e.current_skill, ctrl)
			ctrl.boss_skill_used.emit(e, kind)
		return
	e.ability_timer -= dt
	if e.ability_timer > 0.0:
		return
	var eligible: Array[BossSkillDef] = []
	for sk in e.def.boss_skills:
		if phase >= sk.min_phase and phase <= sk.max_phase:
			eligible.append(sk)
	if eligible.is_empty():
		e.ability_timer = 1.0
		return
	var pick := eligible[e.skill_index % eligible.size()]
	e.skill_index += 1
	e.current_skill = pick
	e.telegraph_params = pick.params
	e.telegraph_kind = int(ACTION_KIND.get(pick.action, EFFECT_KIND))
	e.telegraph_timer = pick.telegraph
	e.telegraph_total = pick.telegraph
	e.ability_timer = pick.interval * float(pick.phase_interval_mult.get(phase, 1.0))


## Phase change for data-driven bosses: the rotation restarts on the newest skill of the phase.
static func _open_phase(e: Enemy, phase: int) -> void:
	var eligible: Array[BossSkillDef] = []
	for sk in e.def.boss_skills:
		if phase >= sk.min_phase and phase <= sk.max_phase:
			eligible.append(sk)
	var newest := 0
	for i in range(eligible.size()):
		if eligible[i].min_phase >= eligible[newest].min_phase:
			newest = i
	e.skill_index = newest


static func _fire(e: Enemy, sk: BossSkillDef, ctrl: MatchController) -> void:
	e.telegraph_params = sk.params
	match sk.action:
		&"shell": # Warden: armour shell absorbs damage for a while
			e.overshield = maxf(e.overshield, e.max_hp * bp(e, "fraction", 0.15))
			e.overshield_timer = bp(e, "duration", 5.0)
		&"sprint":
			e.boss_speed_mult = bp(e, "mult", 1.8)
			e.sprint_timer = bp(e, "duration", 2.5)
		&"hangar", &"summon": # fighters / minions from its position (no bounty)
			var path := String(sk.params.get("enemy", ""))
			var def: EnemyDef = load(path) if path != "" and ResourceLoader.exists(path) else e.def.summon_enemy
			if def != null:
				var spacing := bp(e, "spacing", -18.0)
				for i in range(int(bp(e, "count", 3.0))):
					var m := ctrl.spawn_enemy_on(def, e.route, e.progress + spacing * i)
					m.summoned = true
		&"cloak": # Carrier: cloaks itself and escorts nearby (Beacon / Sensor reveal them)
			var dur := bp(e, "duration", 4.0)
			e.cloak_timer = dur
			ctrl.registry.query_circle(e.position, bp(e, "radius", 120.0), true, _buf)
			for a in _buf:
				if a.is_alive() and not a.def.is_boss:
					a.cloak_timer = maxf(a.cloak_timer, dur)
		&"adapt":
			_set_chimera_mode(e, 1 - e.chimera_mode)
		&"jam":
			ctrl.jam_towers(e.position, bp(e, "radius", 190.0), bp(e, "duration", 4.0), bp(e, "factor", 0.5))
		&"bulwark": # Colossus: overshield on every ally around it
			ctrl.registry.query_circle(e.position, bp(e, "radius", 200.0), true, _buf)
			for a in _buf:
				if a != e and a.is_alive():
					a.overshield = maxf(a.overshield, bp(e, "amount", 120.0))
					a.overshield_timer = bp(e, "duration", 6.0)
			ctrl.projectiles.ring(e.position, bp(e, "radius", 200.0), Color("8fd3ff"), 0.4)
		&"static": # Dynamo: static field shortens tower range
			ctrl.static_towers(e.position, bp(e, "radius", 200.0), bp(e, "duration", 5.0), bp(e, "factor", 0.65))
		&"capacitor": # Dynamo: every hit is capped (big single shots are wasted)
			e.hit_cap = bp(e, "cap", 50.0)
			e.hit_cap_timer = bp(e, "duration", 4.0)
		&"submerge": # Leviathan: dives - untargetable and immune, keeps moving
			e.submerge_timer = bp(e, "duration", 2.5)
		&"revive": # Leviathan: the most recent kills near it rise again (no bounty)
			var n := int(bp(e, "count", 3.0))
			var r := bp(e, "radius", 260.0)
			var horizon := ctrl.match_time - bp(e, "window", 12.0)
			var i := ctrl.recent_deaths.size() - 1
			while i >= 0 and n > 0:
				var d: Dictionary = ctrl.recent_deaths[i]
				if float(d["t"]) >= horizon and (d["pos"] as Vector2).distance_to(e.position) <= r:
					var m := ctrl.spawn_enemy_on(d["def"], d["route"], float(d["progress"]))
					m.summoned = true
					ctrl.recent_deaths.remove_at(i)
					n -= 1
				i -= 1
		&"decoy": # Refractor: fragile mirror copies run just ahead of it
			var dd := decoy_def(e.def, e.max_hp * bp(e, "hp", 0.05))
			for k in range(int(bp(e, "count", 2.0))):
				var m := ctrl.spawn_enemy_on(dd, e.route, e.progress + 24.0 * (k + 1))
				m.summoned = true
		&"prism": # Refractor: resists one damage type, cycling
			var idx := PRISM_CYCLE.find(e.immune_type)
			e.immune_type = PRISM_CYCLE[(idx + 1) % PRISM_CYCLE.size()] if idx >= 0 else PRISM_CYCLE[e.uid % 3]
			e.immune_timer = bp(e, "duration", 4.0)
		&"blink": # Colossus: tears through the rift and reappears further down its lane
			var limit := e.route.total_length - bp(e, "keep", 260.0)
			var to := minf(e.progress + bp(e, "distance", 150.0), limit)
			if to > e.progress:
				ctrl.projectiles.ring(e.position, e.def.radius * 2.0, Color("ff5368"), 0.35)
				e.place_at_progress(to)
				ctrl.projectiles.ring(e.position, e.def.radius * 2.5, Color("ff5368"), 0.45)
		&"effect_area": # data: an EffectDef on allies / itself / towers around it
			var fx := EffectDef.by_id(String(sk.params.get("effect", "")))
			if fx != null:
				var radius := bp(e, "radius", 180.0)
				var dur := bp(e, "duration", -1.0)
				match String(sk.params.get("on", "allies")):
					"towers":
						ctrl.effect_towers(e.position, radius, fx, dur)
					"self":
						e.apply_effect(fx, dur)
					_:
						ctrl.registry.query_circle(e.position, radius, true, _buf)
						for a in _buf:
							if a.is_alive() and (a != e or bool(sk.params.get("self", false))):
								a.apply_effect(fx, dur)
						ctrl.projectiles.ring(e.position, radius, fx.color, 0.4)
		&"heal_area": # data: heal allies around it by a fraction of their max HP
			var radius := bp(e, "radius", 180.0)
			ctrl.registry.query_circle(e.position, radius, true, _buf)
			for a in _buf:
				if a.is_alive() and (a != e or bool(sk.params.get("self", false))):
					ctrl.stats_healed += a.heal(a.max_hp * bp(e, "frac", 0.1))
			ctrl.projectiles.ring(e.position, radius, Color("4de6a1"), 0.4)


## Chimera plating: 0 = armour (+armor_bonus), 1 = regenerating energy shield (x2 energy damage).
static func _set_chimera_mode(e: Enemy, mode: int) -> void:
	e.chimera_mode = mode
	if mode == 0:
		e.bonus_armor = bp(e, "armor_bonus", 10.0)
		e.shield = 0.0
		e.shield_max = 0.0
	else:
		e.bonus_armor = 0.0
		e.shield_max = e.max_hp * bp(e, "shield_fraction", 0.12)
		e.shield = e.shield_max


static func _summon(e: Enemy, ctrl: MatchController) -> void:
	for i in range(e.def.summon_count):
		var m := ctrl.spawn_enemy_on(e.def.summon_enemy, e.route, e.progress - 14.0 * (i + 1))
		m.summoned = true


## Called by the controller when a boss dies in its final phase.
static func fracture(e: Enemy, ctrl: MatchController) -> void:
	if e.def.boss_kit != &"monolith" or e.max_boss_phases < 3 or e.def.shard_count <= 0:
		return
	var shard := shard_def(e.def)
	for i in range(e.def.shard_count):
		ctrl.spawn_enemy_on(shard, e.route, e.progress - 20.0 * i)


## Refractor decoys: same look, fragile, harmless to the base budget (1 damage), no bounty.
static func decoy_def(boss: EnemyDef, hp: float) -> EnemyDef:
	var key := boss.get_instance_id()
	if _decoy_cache.has(key):
		return _decoy_cache[key]
	var s := EnemyDef.new()
	s.id = StringName(String(boss.id) + "_decoy")
	s.display_name = boss.display_name
	s.category = EnemyDef.Category.SPECIAL
	s.max_hp = hp
	s.speed = boss.speed * 1.1
	s.base_damage = 1
	s.bounty = 0
	s.radius = boss.radius * 0.8
	s.color = boss.color
	s.shape = EnemyDef.Shape.HEXAGON
	_decoy_cache[key] = s
	return s


## Shards are a product of the boss's split mechanic, derived from its definition.
static func shard_def(boss: EnemyDef) -> EnemyDef:
	var key := boss.get_instance_id()
	if _shard_cache.has(key):
		return _shard_cache[key]
	var s := EnemyDef.new()
	s.id = StringName(String(boss.id) + "_shard")
	s.display_name = boss.display_name + " Shard"
	s.category = EnemyDef.Category.BOSS
	s.max_hp = boss.shard_hp
	s.armor = boss.shard_armor
	s.speed = boss.shard_speed
	s.base_damage = boss.shard_base_damage
	s.bounty = 10
	s.radius = 12.0
	s.color = boss.color
	s.shape = EnemyDef.Shape.HEXAGON
	_shard_cache[key] = s
	return s
