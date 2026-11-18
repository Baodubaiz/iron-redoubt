extends TestCase
## Enemy mechanics: armor, shield, flying, stealth, healing, status policy, boss phases.


func test_armor_vs_pulse_and_lance() -> void:
	var m := make_lab()
	var plated := put(m, real_enemy("plated", 0.0), 300)
	var ar := plated.def.armor # 8 x1.05 enemy stat bonus
	var hp0 := plated.max_hp
	m.damage_enemy(plated, 12, Damage.Type.KINETIC, 0) # Pulse hit
	near(plated.hp, hp0 - (12 - ar), 0.01, "12 - armor")
	m.damage_enemy(plated, 80, Damage.Type.ENERGY, 6) # Lance hit
	near(plated.hp, hp0 - (12 - ar) - (80 - (ar - 6)), 0.01, "80 - (armor-6)")


func test_shield_energy_double_and_regen() -> void:
	var m := make_lab()
	var a := put(m, real_enemy("aegis", 0.0), 300)
	m.damage_enemy(a, 100, Damage.Type.KINETIC, 0)
	near(a.shield, 50, 0.01, "shield absorbs kinetic")
	var hp0 := a.max_hp
	near(a.hp, hp0, 0.01, "hp untouched")
	m.damage_enemy(a, 80, Damage.Type.ENERGY, 0)
	near(a.shield, 0, 0.01, "energy x2 breaks shield")
	near(a.hp, hp0 - Damage.resolve(55, Damage.Type.ENERGY, 0, a.def.armor), 0.01, "leftover (160-50)/2 through armor")
	run(m, 2.9)
	near(a.shield, 0, 0.01, "no regen before 3 s")
	run(m, 1.1)
	check(a.shield > 0 and a.shield <= 150, "regenerates after 3 s idle (%.1f)" % a.shield)
	run(m, 10.0)
	near(a.shield, 150, 0.01, "capped at max")


func test_flier_uses_air_route_and_ground_towers_ignore_it() -> void:
	var m := make_lab()
	var g := m.spawn_enemy(real_enemy("glider", 0.0))
	check(g.route == m.air_routes[0], "air route")
	g.place_at_progress(300)
	var nova := m.try_build(real_tower("nova"), Vector2(300, 400))
	var pulse := m.try_build(real_tower("pulse"), Vector2(400, 400))
	run(m, 1.0)
	eq(nova.shots_fired, 0, "Nova can't target air")
	check(pulse.shots_fired > 0, "Pulse can")


func test_stealth_needs_reveal_and_splash_still_hits() -> void:
	var m := make_lab()
	var ph := put(m, real_enemy("phantom", 0.0), 300)
	var pulse := m.try_build(real_tower("pulse"), Vector2(300, 400))
	run(m, 1.0)
	eq(pulse.shots_fired, 0, "hidden: not targetable")
	var beacon := m.try_build(real_tower("beacon"), Vector2(380, 355))
	run(m, 0.5)
	check(ph.is_revealed(), "revealed by Beacon")
	check(pulse.shots_fired > 0, "now targeted")
	m.try_sell(beacon)
	run(m, 0.2)
	check(ph.is_revealed(), "reveal lingers")
	run(m, 1.5)
	check(not ph.is_revealed(), "linger expired")
	# splash: Nova aims at a visible drone; the blast also hurts the hidden phantom
	var m2 := make_lab()
	var ph2 := put(m2, real_enemy("phantom", 0.0), 300)
	put(m2, make_enemy_def(1.0e6, 0), 310)
	m2.try_build(real_tower("nova"), Vector2(300, 400))
	run(m2, 1.5)
	check(ph2.hp < ph2.max_hp, "splash damaged hidden phantom")


func test_mender_heals_five_most_damaged_not_self() -> void:
	var m := make_lab()
	var mender := put(m, real_enemy("mender", 0.0), 300)
	mender.hp = 100
	var allies: Array[Enemy] = []
	for i in range(7):
		var a := put(m, make_enemy_def(200, 0), 280 + i * 8)
		a.hp = 200 - 10 * (i + 1) # missing 10..70
		allies.append(a)
	var burning := allies[6] # missing 70
	burning.apply_burn(0.0001, 10.0)
	var far := put(m, make_enemy_def(200, 0), 600)
	far.hp = 50
	run(m, 2.4)
	near(allies[6].hp, 130, 0.01, "no heal before 2.5 s")
	run(m, 0.2)
	near(mender.hp, 100, 0.01, "does not heal itself")
	near(far.hp, 50, 0.01, "out of radius")
	near(burning.hp, 130 + 15, 0.05, "burning: half heal")
	near(allies[5].hp, 140 + 30, 0.05)
	near(allies[2].hp, 170 + 30, 0.05, "5th most damaged healed")
	near(allies[1].hp, 180, 0.05, "6th not healed (max 5 targets)")


func test_status_policy_refresh_max_and_shred_cap() -> void:
	var m := make_lab()
	var e := put(m, make_enemy_def(1000, 0, 10), 300)
	e.apply_mark(0.25, 1.0)
	e.apply_mark(0.15, 3.0)
	near(e.mark_value, 0.25, 0.0001, "keeps highest magnitude")
	near(e.mark_timer, 3.0, 0.0001, "refreshes duration")
	for i in range(5):
		e.apply_shred(2.0, 6.0)
	near(e.shred, 6.0, 0.0001, "shred capped at 6")
	near(e.effective_armor(), 4.0, 0.0001)
	e.apply_burn(6, 3)
	e.apply_burn(10, 1)
	near(e.burn_dps, 10, 0.0001)
	near(e.burn_timer, 3, 0.0001)
	run(m, 4.1)
	near(e.shred, 0.0, 0.0001, "shred expires")
	near(e.mark_value, 0.0, 0.0001, "mark expires")
	check(not e.is_burning(), "burn expires")
	# 10 dps x 3 s, ignores armor; Meltdown x1.5 (shred >= 4) and Mark +25% both apply
	near(e.hp, 1000 - (10 * 3 * 1.5 * 1.25), 0.6, "burn keeps max dps for its duration")


func test_boss_summon_after_telegraph() -> void:
	var m := make_lab()
	var boss := put(m, real_enemy("monolith", 0.0), 400)
	run(m, 8.0 + 1.4)
	eq(m.enemies.size(), 1, "telegraph first (1.5 s)")
	check(boss.telegraph_kind == EnemyAbilities.SUMMON_KIND, "telegraphing summon")
	run(m, 0.2)
	eq(m.enemies.size(), 5, "4 swarmlings summoned")
	var before := m.economy.currency
	for e in m.enemies:
		if e != boss:
			check(e.summoned, "flagged summoned")
			m.damage_enemy(e, 1e6, Damage.Type.TRUE, 0)
	eq(m.economy.currency, before, "summons grant no bounty")


func test_boss_emp_disrupts_nearby_towers_only() -> void:
	var m := make_lab()
	var boss := put(m, real_enemy("monolith", 0.0), 300)
	var near_t := m.try_build(real_tower("pulse"), Vector2(300, 400))
	var far_t := m.try_build(real_tower("pulse"), Vector2(700, 400))
	m.damage_enemy(boss, boss.max_hp * 0.4, Damage.Type.TRUE, 0) # -> 60%: phase II
	near_t.damage = 0.0001
	m.step(DT)
	eq(boss.boss_phase, 2)
	run(m, 5.5) # half of the 10 s interval, then 2 s telegraph
	check(boss.telegraph_kind == EnemyAbilities.EMP_KIND, "EMP telegraphed")
	check(not near_t.is_disrupted(), "not yet")
	run(m, 1.6)
	check(near_t.is_disrupted(), "near tower disrupted")
	check(not far_t.is_disrupted(), "far tower fine")
	var shots := near_t.shots_fired
	run(m, 2.5)
	eq(near_t.shots_fired, shots, "disrupted tower does not fire")
	run(m, 1.0)
	check(not near_t.is_disrupted(), "disruption ends after 3 s")


func test_boss_fracture_speed_and_split() -> void:
	var m := make_lab()
	var def := real_enemy("monolith", 10.0)
	var boss := put(m, def, 300)
	m.damage_enemy(boss, boss.max_hp * 0.7, Damage.Type.TRUE, 0)
	m.step(DT)
	eq(boss.boss_phase, 3)
	near(boss.current_speed(), 13.0, 0.001, "+30% speed")
	boss.aura_slow = 0.6
	near(boss.speed_multiplier(), (1.0 - 0.25) * 1.3, 0.001, "boss slow cap 25%")
	boss.aura_slow = 0.0
	boss.apply_stun(1.0)
	check(boss.speed_multiplier() > 0.0, "stun immune -> stagger")
	var bounty_before := m.economy.currency
	m.damage_enemy(boss, 1e9, Damage.Type.TRUE, 0)
	var shards := 0
	for e in m.enemies:
		if e.is_alive() and String(e.def.id).ends_with("_shard"):
			shards += 1
			near(e.max_hp, 400, 0.01)
	eq(shards, 3, "splits into 3 shards")
	eq(m.economy.currency - bounty_before, m.economy.config.kill_bounty(def.bounty), "boss bounty once")


func test_boss_l6_variant_two_phases_no_split() -> void:
	var m := make_lab()
	var g := SpawnGroupDef.new()
	g.enemy = real_enemy("monolith", 0.0)
	g.hp_multiplier = 0.375
	g.max_boss_phases = 2
	g.base_damage_override = 15
	m._spawn_from_group(g)
	var boss := m.enemies[0]
	near(boss.max_hp, g.enemy.max_hp * 0.375, 0.01)
	eq(boss.base_damage, 15)
	m.damage_enemy(boss, 4400, Damage.Type.TRUE, 0)
	m.step(DT)
	eq(boss.boss_phase, 2, "never enters phase III")
	m.damage_enemy(boss, 1e6, Damage.Type.TRUE, 0)
	eq(m.alive_enemy_count(), 0, "no shards")
