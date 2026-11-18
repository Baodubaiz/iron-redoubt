class_name MatchController
extends Node2D
## Owns one match: world nodes + systems, drives the fixed-step simulation, resolves every
## combat rule (damage pipeline, on-hit effects, synergy, interactions) and exposes the only
## command API the UI may use (build, upgrade, evolve, sell, start wave, pause).

enum State { SETUP, WAITING_FIRST_WAVE, WAVE_ACTIVE, PREP, WON, LOST }

const AMP_DAMAGE_CAP := 0.40
const AMP_RATE_CAP := 0.30
const AMP_RANGE_CAP := 0.30
const CHAIN_RANGE := 110.0
const INFERNO_RADIUS := 50.0
const BOMBLET_RADIUS := 25.0

signal state_changed(state: State)
signal tower_built(tower: Tower)
signal tower_upgraded(tower: Tower)
signal tower_sold(tower: Tower, refund: int)
signal enemy_killed(enemy: Enemy)
signal enemy_escaped(enemy: Enemy)
signal boss_spawned(enemy: Enemy)
signal boss_phase_changed(enemy: Enemy, phase: int)
signal interaction_triggered(name: String)
## Presentation-only signals (audio / VFX). Gameplay never depends on them.
signal shot_fired(tower: Tower)
signal explosion(pos: Vector2, radius: float)
signal towers_disrupted(pos: Vector2)
signal boss_skill_used(enemy: Enemy, kind: int) ## a boss ability fired (EnemyAbilities kinds)
signal match_ended(won: bool)
signal paused_changed(paused: bool)
signal speed_changed(speed: int)

var level: LevelDef
var modifiers: MatchModifiers
var unlocks: UpgradeRules.Unlocks
var is_night: bool = false
var active_route: int = 0
## Per-match statistics for achievements / challenges / results.
var stats := {
	"tower_types": {}, "kills_by_enemy": {}, "evolved_types": {}, "sells": 0, "seen_enemies": {},
	"boss_spawn_time": {}, "boss_kill_seconds": [],
}
var economy: MatchEconomy
var base: BaseCore
var waves: WaveManager
var registry: EnemyRegistry
var rules: PlacementRules
var projectiles: ProjectileSystem
var rng: RandomNumberGenerator
var routes: Array[RoutePath] = []
var air_routes: Array[RoutePath] = []
var enemies: Array[Enemy] = []
var recent_deaths: Array[Dictionary] = [] ## last non-boss kills (Leviathan revive)
var towers: Array[Tower] = []
## Fire patches: {pos, radius, until, source: Tower}
var zones: Array[Dictionary] = []
## Delayed detonations (Cascade): {time, source, pos, radius, damage, type, pen, air}
var delayed: Array[Dictionary] = []
var interaction_counts: Dictionary = {}
var state: State = State.SETUP
var paused: bool = false
var match_time: float = 0.0
var seed_used: int = 0
var stats_healed: float = 0.0
## Tests set this false and call step() manually for fast deterministic simulation.
var auto_process: bool = true

var map_view: MapView
var towers_root: Node2D
var enemies_root: Node2D

var _next_uid: int = 1
var _kills: int = 0
var _buf: Array[Enemy] = []


func setup(lvl: LevelDef, seed_value: int = -1, unlock_state: UpgradeRules.Unlocks = null,
		mods: MatchModifiers = null) -> void:
	lvl = DifficultyModel.effective_level(lvl) # difficulty knob + crowd cap, applied once per match
	level = lvl
	modifiers = mods if mods != null else MatchModifiers.new()
	if unlock_state != null:
		modifiers.unlocks = unlock_state
	unlocks = modifiers.unlocks
	rng = RandomNumberGenerator.new()
	seed_used = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system()) & 0x7fffffff
	rng.seed = seed_used
	economy = MatchEconomy.new(modifiers.start_currency(lvl), lvl.economy)
	base = BaseCore.new(modifiers.start_hp(lvl))
	base.destroyed.connect(_on_base_destroyed)
	registry = EnemyRegistry.new()
	rules = PlacementRules.new(lvl.map)
	for pts in lvl.map.routes:
		routes.append(RoutePath.new(pts))
	for i in range(maxi(1, lvl.map.air_routes.size())):
		air_routes.append(RoutePath.new(lvl.map.air_route(i)))
	waves = WaveManager.new(lvl, economy, rng)
	waves.early_bonus_multiplier = modifiers.early_bonus_multiplier
	waves.spawn_callback = _spawn_from_group
	waves.wave_started.connect(_on_wave_started)
	waves.prep_started.connect(func(_i: int, _s: float) -> void: _set_state(State.PREP))
	waves.wave_cleared.connect(_on_wave_cleared)
	waves.all_waves_cleared.connect(_on_all_waves_cleared)

	map_view = MapView.new()
	map_view.map = lvl.map
	add_child(map_view)
	towers_root = Node2D.new()
	towers_root.name = "Towers"
	add_child(towers_root)
	enemies_root = Node2D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)
	projectiles = ProjectileSystem.new()
	projectiles.impact_callback = _on_impact
	projectiles.zones = zones
	add_child(projectiles)
	_set_state(State.WAITING_FIRST_WAVE)


## Game speed (1 or 2). x2 runs two identical fixed steps per physics frame, so results are the
## same as 1x — only faster.
var speed: int = 1


func set_speed(value: int) -> void:
	speed = clampi(value, 1, 2)
	speed_changed.emit(speed)


func _physics_process(delta: float) -> void:
	if auto_process:
		for i in range(speed):
			step(delta)


# ================================================================ simulation

func step(dt: float) -> void:
	if paused or is_over() or state == State.SETUP:
		return
	match_time += dt
	waves.step(dt)
	# status timers + burn (Meltdown: +50% burn on heavily shredded enemies)
	var n := enemies.size()
	for i in range(n):
		var e := enemies[i]
		if not e.is_alive():
			continue
		var burn := e.tick_statuses(dt)
		if burn > 0.0:
			if e.shred >= 4.0:
				burn *= 1.5
				_interaction("meltdown")
			damage_enemy(e, burn, Damage.Type.TRUE, 0.0)
		if not e.effects.is_empty() and e.is_alive(): # data effects: damage over time
			for d in e.tick_effects(dt):
				damage_enemy(e, float(d[0]), int(d[1]), 0.0)
	for e in enemies:
		if e.advance(dt):
			_on_enemy_reached_base(e)
	if is_over():
		return
	registry.rebuild(enemies)
	_apply_auras(dt)
	n = enemies.size()
	for i in range(n):
		EnemyAbilities.step(enemies[i], dt, self)
	_step_zones()
	_step_delayed()
	for t in towers:
		t.step(dt, self)
	projectiles.step(dt)
	economy.step_passive(dt, waves.is_active())
	_compact_enemies()
	waves.check_cleared(enemies.size())


func _on_wave_started(i: int, _bonus: int) -> void:
	var w := level.waves[i]
	is_night = level.map.day_night and w.night
	if w.active_route >= 0:
		active_route = clampi(w.active_route, 0, routes.size() - 1)
	map_view.set_state(is_night, active_route)
	_set_state(State.WAVE_ACTIVE)


func _spawn_from_group(g: SpawnGroupDef) -> void:
	var ground_index := active_route if g.route_index < 0 else g.route_index
	var route := air_routes[clampi(maxi(g.route_index, 0), 0, air_routes.size() - 1)] if g.enemy.flying \
		else routes[clampi(ground_index, 0, routes.size() - 1)]
	var e := Enemy.new()
	e.setup(g.enemy, route, _take_uid(), g.hp_multiplier, g.base_damage_override, g.max_boss_phases)
	_add_enemy(e)


## Spawns at the start of a route (tests / tools). Fliers use the air route.
func spawn_enemy(def: EnemyDef, route_index: int = 0) -> Enemy:
	var route := air_routes[clampi(route_index, 0, air_routes.size() - 1)] if def.flying \
		else routes[clampi(route_index, 0, routes.size() - 1)]
	var e := Enemy.new()
	e.setup(def, route, _take_uid())
	_add_enemy(e)
	return e


## Spawns on a given route at a given progress (boss summons / shards).
func spawn_enemy_on(def: EnemyDef, route: RoutePath, at_progress: float) -> Enemy:
	var e := Enemy.new()
	e.setup(def, route, _take_uid())
	e.place_at_progress(maxf(at_progress, 0.0))
	_add_enemy(e)
	return e


func _add_enemy(e: Enemy) -> void:
	enemies.append(e)
	enemies_root.add_child(e)
	stats["seen_enemies"][String(e.def.id)] = true # Codex: unlock entries the player has met
	if e.is_boss():
		stats["boss_spawn_time"][e.uid] = match_time
		boss_spawned.emit(e)


# ================================================================ damage pipeline

## Single entry point for damage. Order: Mark -> Shatter -> shield -> armor -> HP.
## Death (bounty, on-death effects) happens exactly once. `secondary` damage (Inferno
## explosions) never triggers on-death effects, which prevents recursive chains.
func damage_enemy(e: Enemy, amount: float, type: int, armor_pen: float, secondary: bool = false,
		shield_mult: float = 1.0) -> void:
	if is_over() or e == null or not e.is_alive() or amount <= 0.0:
		return
	if e.submerge_timer > 0.0:
		return # Leviathan submerged: immune to everything
	if e.immune_timer > 0.0 and type == e.immune_type:
		amount *= 0.1 # Refractor prismatic shield
	if not e.effects.is_empty(): # data effects
		if e.effect_flag("immune"):
			return
		amount *= e.effect_product("damage_taken")
		for k in e.effects:
			var ed: EffectDef = e.effects[k]["def"]
			if ed.components.has("resist_type") and Damage.type_from_id(String(ed.components["resist_type"])) == type:
				amount *= 1.0 - float(ed.components.get("resist_amount", 0.5))
	if e.mark_timer > 0.0:
		amount *= 1.0 + e.mark_value
	# Permanent per-type % resistance (EnemyDef.resist_pct) -- separate from flat armor, countered
	# by the tower's own %-damage bonuses (which already multiplied `amount` up above), not by
	# armor_pen. Applied after mark (a debuff that should still get its full +% first).
	amount *= 1.0 - e.resist_pct_for(type)
	if type == Damage.Type.EXPLOSIVE and e.is_frozen() and e.shatter > 0.0:
		amount *= 1.0 + e.shatter
		_interaction("shatter")
	# Plasma skips the shield bar entirely instead of just multiplying into it (Damage.ignores_shield).
	var rem := amount
	if not Damage.ignores_shield(type):
		var smult := maxf(Damage.shield_mult(type), shield_mult)
		rem = e.absorb_with_shield(amount, smult)
	if rem > 0.0:
		var hit := Damage.resolve(rem, type, armor_pen, e.effective_armor_for(type))
		if e.hit_cap_timer > 0.0:
			hit = minf(hit, e.hit_cap) # Dynamo capacitor
		e.take_damage(hit)
	if e.hp <= 0.0:
		_kill(e, secondary)


func _kill(e: Enemy, secondary: bool) -> void:
	e.state = Enemy.State.DEAD
	_kills += 1
	var kbe: Dictionary = stats["kills_by_enemy"]
	kbe[e.def.id] = int(kbe.get(e.def.id, 0)) + 1
	if e.is_boss() and stats["boss_spawn_time"].has(e.uid):
		stats["boss_kill_seconds"].append(match_time - float(stats["boss_spawn_time"][e.uid]))
	if not e.summoned:
		var raw_bounty: int = e.def.bounty
		var bounty: int = economy.config.kill_bounty(raw_bounty) if economy != null and economy.config != null else maxi(1, int(round(raw_bounty * 0.90)))
		economy.credit(bounty, "kill:%d" % e.uid)
		var relay_bonus := 0
		for t in towers:
			if t.is_beacon() and not t.is_disrupted() and t.pf("bounty_bonus") > 0.0 \
					and t.position.distance_to(e.position) <= t.attack_range:
				relay_bonus = maxi(relay_bonus, int(t.pf("bounty_bonus")))
		if relay_bonus > 0:
			economy.credit(relay_bonus, "relaykill:%d" % e.uid)
	if not e.is_boss() and not e.summoned: # Leviathan can bring these back
		recent_deaths.append({"def": e.def, "route": e.route, "progress": e.progress, "pos": e.position, "t": match_time})
		if recent_deaths.size() > 24:
			recent_deaths.pop_front()
	projectiles.ring(e.position, e.def.radius + 6.0, e.def.color, 0.22)
	projectiles.burst(e.position, e.def.color, e.def.radius)
	enemy_killed.emit(e)
	if not secondary and e.burn_explode > 0.0:
		_interaction("inferno")
		_explode(null, e.position, INFERNO_RADIUS, e.burn_explode, Damage.Type.EXPLOSIVE, 0.0, false, false, true)
	if e.is_boss() and e.boss_phase >= 3:
		EnemyAbilities.fracture(e, self)


func _on_enemy_reached_base(e: Enemy) -> void:
	if not e.is_alive():
		return
	e.state = Enemy.State.ESCAPED # terminal: no bounty, damage once
	enemy_escaped.emit(e)
	base.apply_damage(e.base_damage)


# ================================================================ attacks

## Called by Tower when its cooldown allows a shot.
func fire(t: Tower, target: Enemy) -> void:
	var s := projectiles.spawn(t, target)
	shot_fired.emit(t)
	var n := t.shots_fired
	if _every(t, "crit_every", n):
		s.crit = true
		s.damage *= maxf(t.pf("crit_mult"), 1.0)
	s.quake = _every(t, "stun_every", n)
	s.echo = _every(t, "echo_every", n)
	if _every(t, "burst_every", n):
		registry.query_circle(t.position, t.eff_range(), t.can_target_air, _buf, true)
		var count := int(t.pf("burst_count"))
		if not _buf.is_empty():
			var cands := _buf.duplicate()
			for i in range(count):
				projectiles.spawn(t, cands[i % cands.size()])
			_interaction("storm_array")


func _every(t: Tower, key: String, n: int) -> bool:
	var k := int(t.pf(key))
	return k > 0 and n % k == 0


func _on_impact(s: ProjectileSystem.Shot) -> void:
	var t := s.source
	if t == null or not is_instance_valid(t) or t.sold:
		return
	if s.splash > 0.0:
		_explode(t, s.dest, s.splash, s.damage, s.damage_type, s.armor_pen, s.hits_air, s.quake, false)
		var bomblets := int(t.pf("bomblets"))
		for i in range(bomblets):
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 0.8) * s.splash
			_explode(t, s.dest + off, BOMBLET_RADIUS, t.pf("bomblet_damage") * (1.0 + t.amp_damage),
				s.damage_type, s.armor_pen, s.hits_air, false, false)
		if t.pf("trap_duration") > 0.0: # trap launcher: a field on the lane that applies an effect
			zones.append({"pos": s.dest, "radius": t.pf("trap_radius"), "until": match_time + t.pf("trap_duration"),
				"source": t, "effect": String(t.p("trap_effect", "shock"))})
		if t.pf("fire_patch_duration") > 0.0:
			zones.append({"pos": s.dest, "radius": t.pf("fire_patch_radius"),
				"until": match_time + t.pf("fire_patch_duration"), "source": t})
		if s.echo:
			delayed.append({"time": match_time + maxf(t.pf("echo_delay"), 0.1), "source": t, "pos": s.dest,
				"radius": s.splash, "damage": s.damage, "type": s.damage_type, "pen": s.armor_pen, "air": s.hits_air})
		return
	var e := s.target
	if e == null or not is_instance_valid(e) or not e.is_alive():
		return
	_single_hit(t, e, s.damage, s.damage_type, s.armor_pen)
	projectiles.ring(s.dest, 6.0, s.color)
	_pierce(t, e, s.damage, s.damage_type, s.armor_pen)
	_chain(t, e, s.damage)
	if t.pf("venom_patch_duration") > 0.0: # Venom Spray: a lingering poison cloud at the impact point
		zones.append({"pos": s.dest, "radius": t.pf("venom_patch_radius"), "air": true,
			"until": match_time + t.pf("venom_patch_duration"), "source": t, "venom": true, "last": {}})


func _hit_mult(t: Tower, e: Enemy) -> float:
	var m := 1.0
	if e.is_flying():
		m *= float(t.p("air_damage_mult", 1.0))
	if e.is_boss():
		m *= float(t.p("boss_mult", 1.0))
	var tm: Variant = t.params.get("tag_mult") # data: {"tag": multiplier}
	if tm is Dictionary:
		for tag in tm:
			if e.has_tag(StringName(tag)):
				m *= float(tm[tag])
	if not t.effects.is_empty():
		m *= t.effect_product("damage_mult")
	return m


func _single_hit(t: Tower, e: Enemy, dmg: float, type: int, pen: float) -> void:
	damage_enemy(e, dmg * _hit_mult(t, e), type, pen)
	_apply_on_hit(t, e, false)


## Area damage. Hits stealthed enemies too (splash needs no targeting).
func _explode(t: Tower, pos: Vector2, radius: float, dmg: float, type: int, pen: float, hits_air: bool,
		quake: bool, secondary: bool) -> void:
	var hits: Array[Enemy] = [] # local: explosions can nest through deaths
	registry.query_circle(pos, radius, hits_air, hits)
	for e in hits:
		var mult := _hit_mult(t, e) if t != null else 1.0
		damage_enemy(e, dmg * mult, type, pen, secondary)
		if not secondary and t != null:
			_apply_on_hit(t, e, quake)
	projectiles.ring(pos, radius, t.def.color if t != null else Color("ff9f43"))
	explosion.emit(pos, radius)


func _apply_on_hit(t: Tower, e: Enemy, quake: bool) -> void:
	if t == null or not e.is_alive():
		return
	var mark := t.pf("mark")
	if mark > 0.0:
		e.apply_mark(mark, float(t.p("mark_duration", 3.0)))
		var ground := t.pf("ground_marked_fliers")
		if ground > 0.0 and e.def.flying:
			e.apply_grounded(ground)
			_interaction("grounded")
	var burn := t.pf("burn_dps")
	if burn > 0.0:
		e.apply_burn(burn, float(t.p("burn_duration", 3.0)), t.pf("death_explosion"))
	var shred := t.pf("shred")
	if shred > 0.0:
		e.apply_shred(shred, float(t.p("shred_cap", 6.0)))
	var stagger := t.pf("stagger")
	if stagger > 0.0:
		e.apply_stun(stagger)
	if quake and not e.is_flying():
		e.apply_stun(t.pf("stun_duration"))
	var fx: Variant = t.params.get("on_hit_effects") # data: ["effect_id", ...]
	if fx is Array and e.is_alive():
		for id in fx:
			e.apply_effect(EffectDef.by_id(String(id)))
	if t.pf("venom_dps") > 0.0 and e.is_alive(): # Venom tower: poison built from its params
		e.apply_effect(param_effect(t, "venom"))
	if t.pf("spot_vuln") > 1.0 and e.is_alive(): # Spotter: mark built from its params
		e.apply_effect(param_effect(t, "spot"))


## Railspike: the shot continues through up to (pierce - 1) more enemies in a line.
func _pierce(t: Tower, primary: Enemy, dmg: float, type: int, pen: float) -> void:
	var pierce := int(t.pf("pierce"))
	if pierce <= 1:
		return
	var dir := (primary.position - t.position).normalized()
	var cands: Array[Enemy] = []
	registry.query_circle(primary.position, 160.0, t.can_target_air, cands, true)
	var line: Array = []
	for e in cands:
		if e == primary:
			continue
		var rel := e.position - primary.position
		var along := rel.dot(dir)
		if along > 0.0 and absf(rel.cross(dir)) <= 16.0:
			line.append([along, e])
	line.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in range(mini(pierce - 1, line.size())):
		var e: Enemy = line[i][1]
		_single_hit(t, e, dmg, type, pen)
	if not line.is_empty():
		projectiles.line(primary.position, primary.position + dir * 160.0, t.def.color)


## Arc: chains to nearby targetable enemies. Conductive (Arc T3+): prefers Chilled enemies and
## gets bonus jumps between Chilled enemies.
func _chain(t: Tower, start: Enemy, dmg: float) -> void:
	var jumps := int(t.pf("chain"))
	if jumps <= 0:
		return
	var falloff := float(t.p("chain_falloff", 0.6))
	var smult := float(t.p("chain_shield_mult", 1.0))
	var conductive := bool(t.p("conductive", false))
	var bonus := int(t.pf("conductive_bonus"))
	var stagger := t.pf("chain_stagger")
	var hit := {start.uid: true}
	var cur := start
	var bonus_used := 0
	var cands: Array[Enemy] = []
	while jumps > 0:
		registry.query_circle(cur.position, CHAIN_RANGE, t.can_target_air, cands, true)
		var next: Enemy = null
		var best_d := INF
		var best_chilled := false
		for e in cands:
			if hit.has(e.uid) or not e.is_alive():
				continue
			var d := e.position.distance_squared_to(cur.position)
			var chilled := conductive and e.is_chilled()
			if next == null or (chilled and not best_chilled) or (chilled == best_chilled and d < best_d):
				next = e
				best_d = d
				best_chilled = chilled
		if next == null:
			break
		projectiles.line(cur.position, next.position, t.def.color)
		var from_chilled := cur.is_chilled()
		damage_enemy(next, dmg * falloff * _hit_mult(t, next), Damage.Type.ENERGY, t.armor_pen, false, smult)
		if stagger > 0.0 and next.is_alive():
			next.apply_stun(stagger)
		if conductive and bonus_used < bonus and from_chilled and next.is_chilled():
			bonus_used += 1
			_interaction("conductive")
		else:
			jumps -= 1
		hit[next.uid] = true
		cur = next


## Focus beam: continuous damage that ramps on the same target. Phase Beam pierces the line.
func beam_tick(t: Tower, target: Enemy, dt: float) -> void:
	var dps := t.pf("beam_dps") * (1.0 + t.amp_damage)
	damage_enemy(target, dps * t.beam_ramp() * dt * _hit_mult(t, target), Damage.Type.ENERGY, t.armor_pen)
	if bool(t.p("beam_pierce", false)):
		var dir := (target.position - t.position).normalized()
		var cands: Array[Enemy] = []
		registry.query_circle(t.position, t.eff_range(), t.can_target_air, cands, true)
		for e in cands:
			if e == target:
				continue
			var rel := e.position - t.position
			if rel.dot(dir) > 0.0 and absf(rel.cross(dir)) <= 12.0:
				damage_enemy(e, dps * dt * _hit_mult(t, e), Damage.Type.ENERGY, t.armor_pen)


# ================================================================ auras / synergy

func _apply_auras(dt: float) -> void:
	for e in enemies:
		e.aura_slow = 0.0
		e.aura_reveal = false
	for t in towers:
		t.set_meta("prev_amp", Vector3(t.amp_damage, t.amp_rate, t.amp_range))
		t.amp_damage = 0.0
		t.amp_rate = 0.0
		t.amp_range = 0.0
		t.buff_sources.clear()
		t.protected = false
	for b in towers: # field generators: protect towers in range from disruption / jamming / debuffs
		if b.is_aura() and bool(b.params.get("field", false)) and not b.is_disrupted():
			for t in towers:
				if t.position.distance_to(b.position) <= b.eff_range():
					t.protected = true
			if b.pf("field_slow_pct") > 0.0 or b.pf("field_vuln") > 1.0:
				var ffx := param_effect(b, "field")
				registry.query_circle(b.position, b.eff_range(), true, _buf)
				for e in _buf:
					e.apply_effect(ffx, 0.25)
			var far := b.pf("amp_rate") # field haste for towers inside (strongest source only)
			if far > 0.0:
				for t in towers:
					if t != b and not t.is_aura() and t.position.distance_to(b.position) <= b.eff_range():
						t.amp_rate = maxf(t.amp_rate, far)
						t.buff_sources.append(b)
			var fevery := b.pf("freeze_every") # periodic freeze of regular enemies in the field
			if fevery > 0.0:
				b.aura_timer += dt
				if b.aura_timer >= fevery:
					b.aura_timer -= fevery
					registry.query_circle(b.position, b.eff_range(), true, _buf)
					for e in _buf:
						e.apply_freeze(b.pf("freeze_duration"), b.pf("shatter"))
					projectiles.ring(b.position, b.eff_range(), Color("5cffd8"), 0.35)
	for b in towers:
		if b.is_disrupted():
			continue
		if b.is_beacon():
			var r := b.attack_range
			registry.query_circle(b.position, r, true, _buf) # all enemies, incl. stealth
			var slow := b.pf("slow")
			for e in _buf:
				e.aura_slow = maxf(e.aura_slow, slow)
				e.aura_reveal = true # every Beacon branch keeps stealth reveal
			var every := b.pf("freeze_every")
			if every > 0.0:
				b.aura_timer += dt
				if b.aura_timer >= every:
					b.aura_timer -= every
					for e in _buf:
						e.apply_freeze(b.pf("freeze_duration"), b.pf("shatter"))
					projectiles.ring(b.position, r, Color("bfe9ff"), 0.35)
			var ad := b.pf("amp_damage")
			var ar := b.pf("amp_rate")
			var ag := b.pf("amp_range")
			if ad > 0.0 or ar > 0.0 or ag > 0.0:
				for t in towers:
					if t == b or t.is_aura(): # auras never buff auras (no recursive auras)
						continue
					if t.position.distance_to(b.position) <= r:
						t.amp_damage = maxf(t.amp_damage, ad) # strongest source only, never summed
						t.amp_rate = maxf(t.amp_rate, ar)
						t.amp_range = maxf(t.amp_range, ag)
						t.buff_sources.append(b)
			var mint := int(b.pf("mint_amount"))
			if mint > 0 and waves.is_active():
				b.mint_timer += dt
				var interval := maxf(b.pf("mint_interval"), 1.0)
				while b.mint_timer >= interval:
					b.mint_timer -= interval
					b.mint_count += 1
					economy.credit(mint, "mint:%d:%d" % [b.uid, b.mint_count])
		elif b.pf("reveal_radius") > 0.0:
			registry.query_circle(b.position, b.pf("reveal_radius"), true, _buf)
			for e in _buf:
				e.aura_reveal = true
	if level.map.day_night:
		for t in towers:
			t.night_glow = is_night and t.is_beacon() and not t.is_disrupted()
			var dim := false
			if is_night and not t.is_beacon():
				dim = true
				for b in towers:
					if b.is_beacon() and not b.is_disrupted() and b.position.distance_to(t.position) <= b.attack_range:
						dim = false
						break
			if dim != t.night_dimmed:
				t.night_dimmed = dim
				t.night_penalty = level.map.night_range_penalty
				t.queue_redraw()
	for t in towers:
		t.amp_damage = minf(t.amp_damage, AMP_DAMAGE_CAP)
		t.amp_rate = minf(t.amp_rate, AMP_RATE_CAP)
		t.amp_range = minf(t.amp_range, AMP_RANGE_CAP)
		if t.get_meta("prev_amp") != Vector3(t.amp_damage, t.amp_rate, t.amp_range):
			t.queue_redraw()


func _step_zones() -> void:
	var i := 0
	while i < zones.size():
		var z := zones[i]
		var src: Tower = z["source"]
		if match_time >= z["until"] or src == null or not is_instance_valid(src) or src.sold:
			zones.remove_at(i)
			continue
		# Trap/fire zones are ground-only like their towers; the Venom cloud hits air too, since
		# Venom itself can (bug fix 2026-11-15: this used to hardcode false, so flying enemies never
		# stacked poison from the cloud even though a direct hit from the same tower poisons them).
		registry.query_circle(z["pos"], z["radius"], z.get("air", false), _buf)
		if z.has("effect"): # trap zone: the trap's effect on ground enemies standing in it
			var fx := param_effect(src, "trap")
			for e in _buf:
				e.apply_effect(fx, 0.3)
		elif z.get("venom", false): # Venom Spray cloud: stacks at the tower's own pace, not faster
			var tick := 1.0 / maxf(src.pf("fire_rate"), 0.1)
			var last: Dictionary = z["last"]
			for e in _buf:
				var id := e.get_instance_id()
				if match_time - float(last.get(id, -999.0)) >= tick:
					last[id] = match_time
					e.apply_effect(param_effect(src, "venom"))
		else:
			for e in _buf:
				e.apply_burn(src.pf("burn_dps"), 1.0, src.pf("death_explosion"))
		i += 1


func _step_delayed() -> void:
	var i := 0
	while i < delayed.size():
		var d := delayed[i]
		if match_time < d["time"]:
			i += 1
			continue
		delayed.remove_at(i)
		var src: Tower = d["source"]
		if src != null and is_instance_valid(src) and not src.sold:
			_explode(src, d["pos"], d["radius"], d["damage"], d["type"], d["pen"], d["air"], false, false)
			_interaction("cascade")


## Boss EMP: towers whose centre lies within the radius stop attacking (and auras stop).
func disrupt_towers(pos: Vector2, radius: float, duration: float) -> void:
	for t in towers:
		if t.position.distance_to(pos) <= radius and not t.protected:
			t.disrupted_timer = maxf(t.disrupted_timer, duration)
			t.queue_redraw()
	projectiles.ring(pos, radius, Color("ff5c6c"), 0.4)
	towers_disrupted.emit(pos)


static var _param_fx: Dictionary = {}


## Effect built from a tower's `<prefix>_*` params (Venom poison, Shock Trap, Bastion field):
## dps, stacks, duration, slow_pct, stop, armor (per stack), vuln (damage taken). Cached per config.
static func param_effect(t: Tower, prefix: String) -> EffectDef:
	var keys := ["dps", "stacks", "duration", "slow_pct", "stop", "armor", "vuln"]
	var sig := prefix
	for k in keys:
		sig += "|" + str(t.params.get(prefix + "_" + k, ""))
	if _param_fx.has(sig):
		return _param_fx[sig]
	var e := EffectDef.new()
	e.id = StringName("%s_%d" % [prefix, sig.hash()])
	e.display_name = prefix
	var comp := {}
	var dps := float(t.params.get(prefix + "_dps", 0.0))
	if dps > 0.0:
		comp["dot_dps"] = dps
		# Poison and electric shock are real damage types now (2026-11-16): Venom's ticks resolve
		# as Poison (can be resisted via EnemyDef.armor_by_type), Shock Trap's as Energy (also gets
		# the x2-vs-shield bonus). Anything else (e.g. a future "field" prefix) still defaults to
		# True, same as before this change.
		comp["dot_type"] = {"venom": "poison", "trap": "energy"}.get(prefix, "true")
	var slow := float(t.params.get(prefix + "_slow_pct", 0.0))
	if slow > 0.0:
		comp["speed_mult"] = 1.0 - slow
	if bool(t.params.get(prefix + "_stop", false)):
		comp["stop"] = true
	var armor := float(t.params.get(prefix + "_armor", 0.0))
	if armor > 0.0:
		comp["armor_add"] = -armor
	var vuln := float(t.params.get(prefix + "_vuln", 0.0))
	if vuln > 1.0:
		comp["damage_taken"] = vuln
	e.components = comp
	var stacks := int(t.params.get(prefix + "_stacks", 1))
	if stacks > 1:
		e.stacking = EffectDef.Stacking.STACK
		e.max_stacks = stacks
	e.duration = float(t.params.get(prefix + "_duration", 1.0))
	_param_fx[sig] = e
	return e


## Data effect on every tower within the radius (boss skills, map events...).
## Applies a bought consumable's effect (ProgressionModel.use_item already consumed the stock).
## True if the item actually had an effect (false = no valid target, e.g. Airstrike with no enemies alive).
func apply_consumable(item: ConsumableDef) -> bool:
	match item.kind:
		ConsumableDef.Kind.AIRSTRIKE:
			var target: Enemy = null
			for e in enemies:
				if e.is_alive() and (target == null or e.hp > target.hp):
					target = e
			if target == null:
				return false
			_explode(null, target.position, item.radius, item.damage, Damage.Type.EXPLOSIVE, 0.0, true, false, false)
			return true
		ConsumableDef.Kind.HEAL:
			if base.hp >= base.max_hp:
				return false
			base.heal(item.heal_amount)
			return true
		ConsumableDef.Kind.FREEZE:
			var hit := false
			for e in enemies:
				if e.is_alive():
					e.apply_stun(item.freeze_duration)
					hit = true
			return hit
		ConsumableDef.Kind.HASTE:
			if towers.is_empty():
				return false
			var fx := EffectDef.new()
			fx.components = {"fire_rate_mult": item.haste_mult}
			effect_towers(Vector2(640, 360), 5000.0, fx, item.haste_duration)
			return true
	return false


func effect_towers(pos: Vector2, radius: float, e: EffectDef, duration: float = -1.0) -> void:
	for t in towers:
		if t.position.distance_to(pos) <= radius and not t.protected:
			t.apply_effect(e, duration)
	if e != null:
		projectiles.ring(pos, radius, e.color, 0.4)


## Dynamo static field: towers within the radius lose range for a while.
func static_towers(pos: Vector2, radius: float, duration: float, factor: float) -> void:
	for t in towers:
		if t.position.distance_to(pos) <= radius and not t.protected:
			t.static_timer = maxf(t.static_timer, duration)
			t.static_factor = factor
	projectiles.ring(pos, radius, Color("38d9f5"), 0.4)


## Chimera jam: towers within the radius recharge their attacks at `factor` speed.
func jam_towers(pos: Vector2, radius: float, duration: float, factor: float) -> void:
	for t in towers:
		if t.position.distance_to(pos) <= radius and not t.protected:
			t.jam_timer = maxf(t.jam_timer, duration)
			t.jam_factor = factor
	projectiles.ring(pos, radius, Color("ffaa45"), 0.4)


func _interaction(name: String) -> void:
	interaction_counts[name] = int(interaction_counts.get(name, 0)) + 1
	interaction_triggered.emit(name)


func _on_wave_cleared(index: int, _reward: int) -> void:
	for t in towers:
		if t.tier >= UpgradeRules.MAX_TIER:
			t.waves_since_t3 += 1
	# Relay income, diminishing per additional Relay: 100%, 75%, 50%, 50%...
	var relays: Array[Tower] = []
	for t in towers:
		if t.pf("wave_income") > 0.0:
			relays.append(t)
	relays.sort_custom(func(a: Tower, b: Tower) -> bool: return a.uid < b.uid)
	for i in range(relays.size()):
		var factor := 1.0 if i == 0 else (0.75 if i == 1 else 0.5)
		var amount := int(floor(relays[i].pf("wave_income") * factor))
		economy.credit(amount, "relay:%d:%d" % [relays[i].uid, index])


func _compact_enemies() -> void:
	var i := 0
	while i < enemies.size():
		var e := enemies[i]
		if e.is_alive():
			i += 1
		else:
			enemies.remove_at(i)
			e.queue_free()


func alive_enemy_count() -> int:
	var n := 0
	for e in enemies:
		if e.is_alive():
			n += 1
	return n


# ================================================================ commands (UI-facing)

func can_issue_commands() -> bool:
	return not paused and state in [State.WAITING_FIRST_WAVE, State.WAVE_ACTIVE, State.PREP]


func is_tower_available(def: TowerDef) -> bool:
	return def != null and level.available_towers.has(def) and modifiers.allows_tower(def)


func available_towers() -> Array[TowerDef]:
	var out: Array[TowerDef] = []
	for d in level.available_towers:
		if modifiers.allows_tower(d):
			out.append(d)
	return out


func range_bonus_at(pos: Vector2) -> float:
	for z in level.map.range_bonus_zones:
		if pos.distance_to(Vector2(z.x, z.y)) <= z.z:
			return level.map.range_bonus
	return 0.0


func validate_placement(def: TowerDef, pos: Vector2) -> PlacementRules.Result:
	return rules.validate(pos, def.footprint_radius, towers)


## Builds a tower. Currency is deducted only when the build actually succeeds.
func try_build(def: TowerDef, pos: Vector2) -> Tower:
	if not can_issue_commands() or not is_tower_available(def):
		return null
	if validate_placement(def, pos) != PlacementRules.Result.OK:
		return null
	if not economy.can_afford(def.cost):
		return null
	var t := Tower.new()
	t.setup(def, _take_uid(), def.cost)
	t.position = pos
	t.map_range_bonus = range_bonus_at(pos)
	if not economy.try_spend(def.cost, "build:%d" % t.uid):
		t.free()
		return null
	towers.append(t)
	towers_root.add_child(t)
	stats["tower_types"][def.id] = true
	tower_built.emit(t)
	return t


func upgrade_block_reason(t: Tower, b: int) -> String:
	if not can_issue_commands():
		return I18n.t("Paused") if paused else I18n.t("Match over")
	if t == null or t.sold:
		return I18n.t("No tower")
	return UpgradeRules.upgrade_block_reason(t, b, unlocks, economy.currency)


func try_upgrade(t: Tower, b: int) -> bool:
	if upgrade_block_reason(t, b) != "":
		return false
	var nt := UpgradeRules.next_tier(t, b)
	if not economy.try_spend(nt.cost, "upgrade:%d:%d:%d" % [t.uid, b, t.tiers[b] + 1]):
		return false
	t.add_tier(b) # main + secondary rules are enforced by UpgradeRules
	t.total_invested += nt.cost
	if t.tiers[b] >= UpgradeRules.MAX_TIER:
		t.waves_since_t3 = 0
	t.recompute()
	t.pulse_feedback()
	tower_upgraded.emit(t)
	return true


func evolved_count() -> int:
	var n := 0
	for t in towers:
		if t.evolved:
			n += 1
	return n


func evolution_block_reason(t: Tower) -> String:
	if not can_issue_commands():
		return I18n.t("Paused") if paused else I18n.t("Match over")
	if t == null or t.sold:
		return I18n.t("No tower")
	return UpgradeRules.evolution_block_reason(t, unlocks, economy.currency, evolved_count())


func try_evolve(t: Tower) -> bool:
	if evolution_block_reason(t) != "":
		return false
	var evo := t.branch_def().evolution
	if not economy.try_spend(evo.cost, "evolve:%d" % t.uid):
		return false
	t.evolved = true
	stats["evolved_types"][t.def.id] = true
	t.total_invested += evo.cost
	t.recompute()
	t.pulse_feedback()
	tower_upgraded.emit(t)
	return true


## Free, instant, no economy effect: which enemy this one tower prioritises. Behaviour only (see
## Targeting.pick); never changes a tower's power, so there is no block reason to check.
func set_targeting(t: Tower, rule: int) -> bool:
	if t == null or t.sold or not can_issue_commands():
		return false
	t.targeting_override = rule
	return true


func sell_refund(t: Tower) -> int:
	return level.economy.sell_refund(t.total_invested)


## Sells a tower for floor(total invested x 0.70). Returns the refund, or -1 if not allowed.
## Removes the tower, its in-flight shots, fire patches and pending detonations; auras and
## buffs it provided disappear on the next step.
func can_sell() -> bool:
	return can_issue_commands() and not modifiers.no_selling


func try_sell(t: Tower) -> int:
	if not can_sell() or t == null or t.sold or not towers.has(t):
		return -1
	stats["sells"] += 1
	t.sold = true
	towers.erase(t)
	projectiles.remove_from(t)
	for i in range(zones.size() - 1, -1, -1):
		if zones[i]["source"] == t:
			zones.remove_at(i)
	for i in range(delayed.size() - 1, -1, -1):
		if delayed[i]["source"] == t:
			delayed.remove_at(i)
	for other in towers:
		other.buff_sources.erase(t)
	var refund := sell_refund(t)
	economy.credit(refund, "sell:%d" % t.uid)
	tower_sold.emit(t, refund)
	t.queue_free()
	return refund


func request_next_wave() -> bool:
	if not can_issue_commands():
		return false
	return waves.request_start()


func set_paused(value: bool) -> void:
	if is_over() and value:
		return
	if paused == value:
		return
	paused = value
	if is_inside_tree():
		get_tree().paused = value
	paused_changed.emit(value)


func tower_at(pos: Vector2) -> Tower:
	for t in towers:
		if t.position.distance_to(pos) <= t.def.footprint_radius + 6.0:
			return t
	return null


func current_boss() -> Enemy:
	for e in enemies:
		if e.is_alive() and e.is_boss():
			return e
	return null


# ================================================================ end of match

func is_over() -> bool:
	return state == State.WON or state == State.LOST


func _on_base_destroyed() -> void:
	_end(false)


func _on_all_waves_cleared() -> void:
	if not base.is_destroyed():
		_end(true)


func _end(won: bool) -> void:
	if is_over():
		return
	_set_state(State.WON if won else State.LOST)
	economy.locked = true
	projectiles.clear_all()
	match_ended.emit(won)


func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)


func _take_uid() -> int:
	var u := _next_uid
	_next_uid += 1
	return u


func kills() -> int:
	return _kills


## Summary consumed by ProgressionService (achievements, challenges, rewards).
func build_result() -> Dictionary:
	var types: Array = []
	for k in stats["tower_types"]:
		types.append(String(k))
	var evolved: Array = []
	for k in stats["evolved_types"]:
		evolved.append(String(k))
	var kills_by := {}
	for k in stats["kills_by_enemy"]:
		kills_by[String(k)] = stats["kills_by_enemy"][k]
	return {
		"level_id": String(level.id),
		"won": state == State.WON,
		"base_hp": base.hp,
		"max_base_hp": base.max_hp,
		"damage_taken": base.damage_taken,
		"duration": match_time,
		"waves_cleared": waves.index + (1 if state == State.WON else 0),
		"tower_types": types,
		"kills_by_enemy": kills_by,
		"seen_enemies": stats["seen_enemies"].keys(),
		"evolved_types": evolved,
		"interactions": interaction_counts.keys(),
		"early_starts": waves.early_starts,
		"sells": stats["sells"],
		"boss_kill_seconds": stats["boss_kill_seconds"].duplicate(),
		"challenge_id": String(modifiers.challenge_id),
		"challenge_period": modifiers.challenge_period,
		"seed": seed_used,
	}
