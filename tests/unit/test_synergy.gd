extends TestCase
## Stat buffs (strongest only, caps, no Beacon-on-Beacon), effect combinations, special
## interactions, recursion guard, Relay economy, and the Focus beam ramp.


func _beacon_branch(m: MatchController, pos: Vector2, branch: int, tiers: int) -> Tower:
	var b := m.try_build(real_tower("beacon"), pos)
	for i in range(tiers):
		check(m.try_upgrade(b, branch), "beacon upgrade")
	return b


func test_amplifier_strongest_only_and_no_beacon_buff() -> void:
	var m := make_lab()
	var pulse := m.try_build(real_tower("pulse"), Vector2(300, 420))
	var a1 := _beacon_branch(m, Vector2(360, 420), 0, 1) # +10%
	var a2 := _beacon_branch(m, Vector2(240, 420), 0, 2) # +15%
	m.step(DT)
	near(pulse.amp_damage, 0.15, 0.0001, "strongest only, not 0.25")
	eq(pulse.buff_sources.size(), 2)
	near(a1.amp_damage, 0.0, 0.0001, "Beacons never buff Beacons")
	near(pulse.eff_damage(), 12 * 0.9 * 0.5 * 1.15, 0.001) # Pulse damage: -10% nerf, then halved by the remake
	m.try_sell(a2)
	m.step(DT)
	near(pulse.amp_damage, 0.10, 0.0001, "sold Amplifier's buff removed next step")
	eq(pulse.buff_sources.size(), 1)


func test_amp_caps() -> void:
	var m := make_lab()
	var pulse := m.try_build(real_tower("pulse"), Vector2(300, 420))
	var b := m.try_build(real_tower("beacon"), Vector2(360, 420))
	b.params["amp_damage"] = 5.0
	b.params["amp_rate"] = 5.0
	b.params["amp_range"] = 5.0
	m.step(DT)
	near(pulse.amp_damage, MatchController.AMP_DAMAGE_CAP, 0.0001)
	near(pulse.amp_rate, MatchController.AMP_RATE_CAP, 0.0001)
	near(pulse.amp_range, MatchController.AMP_RANGE_CAP, 0.0001)


func test_beacon_slow_applies_and_vanishes_on_sell() -> void:
	var m := make_lab()
	var e := put(m, make_enemy_def(1000, 100), 300)
	var b := m.try_build(real_tower("beacon"), Vector2(300, 380))
	m.step(DT)
	near(e.aura_slow, 0.2, 0.0001)
	near(e.current_speed(), 80, 0.01)
	m.try_sell(b)
	m.step(DT)
	near(e.aura_slow, 0.0, 0.0001, "aura effect removed with the tower")


func test_slow_sources_stack_with_diminishing_returns() -> void:
	var e := Enemy.new()
	e.def = make_enemy_def(1000, 100)
	e.aura_slow = 0.5 # e.g. Beacon Cryo III
	var fx := EffectDef.new()
	fx.id = &"test_slow"
	fx.components = {"speed_mult": 0.5} # another independent 50% source (e.g. Shock Trap Snare III)
	e.apply_effect(fx, 1.0)
	near(e.speed_multiplier(), 1.0 - 0.6, 0.001, "50% + 10% diminishing extra, not 50%*50%=75% multiplicative")
	var fx2 := EffectDef.new()
	fx2.id = &"test_slow_2"
	fx2.components = {"speed_mult": 0.5} # a third independent 50% source
	e.apply_effect(fx2, 1.0)
	near(e.speed_multiplier(), 1.0 - 0.7, 0.001, "50% + 10% + 10%")


func test_inferno_explosions_do_not_chain() -> void:
	var m := make_lab()
	var es: Array[Enemy] = []
	for x in [300.0, 320.0, 340.0, 360.0]:
		var e := put(m, make_enemy_def(10, 0), x)
		e.apply_burn(1.0, 10.0, 30.0) # Inferno-burning, 30 explosion damage
		es.append(e)
	m.registry.rebuild(m.enemies)
	m.damage_enemy(es[0], 100, Damage.Type.KINETIC, 0) # primary kill -> one explosion (radius 50)
	check(not es[1].is_alive() and not es[2].is_alive(), "explosion kills enemies within 50")
	# if secondary kills exploded again, the enemy at 340 would blow up the one at 360
	check(es[3].is_alive(), "no chain reaction reaches 60 px away")
	near(es[3].hp, 10, 0.001)
	eq(int(m.interaction_counts.get("inferno", 0)), 1, "secondary kills never explode again")


func test_shatter_on_frozen_enemies() -> void:
	var m := make_lab()
	var e := put(m, make_enemy_def(1000, 0), 300)
	e.apply_freeze(1.0, 0.5)
	m.damage_enemy(e, 100, Damage.Type.EXPLOSIVE, 0)
	near(e.hp, 850, 0.01, "+50% explosive while frozen")
	m.damage_enemy(e, 100, Damage.Type.KINETIC, 0)
	near(e.hp, 750, 0.01, "kinetic unaffected")
	eq(int(m.interaction_counts.get("shatter", 0)), 1)


func test_cryo_freeze_pulse_skips_boss() -> void:
	var m := make_lab()
	var e := put(m, make_enemy_def(1000, 0), 300)
	var boss := put(m, real_enemy("monolith", 0.0), 320)
	var cryo := _beacon_branch(m, Vector2(300, 380), 1, 3)
	near(cryo.pf("slow"), 0.5, 0.0001)
	run(m, 6.05)
	check(e.is_frozen(), "non-boss frozen")
	check(not boss.is_frozen() and boss.stagger_timer > 0.0, "boss staggered instead")


func test_grounded_lets_nova_hit_marked_fliers() -> void:
	var m := make_lab()
	var g := put(m, real_enemy("glider", 0.0), 300)
	var pulse := m.try_build(real_tower("pulse"), Vector2(300, 420))
	for i in range(3):
		m.try_upgrade(pulse, 2)
	pulse.waves_since_t3 = 2
	check(m.try_evolve(pulse), "Hunter Net")
	var nova := m.try_build(real_tower("nova"), Vector2(420, 420))
	run(m, 1.0)
	check(g.mark_timer > 0.0, "marked")
	check(not g.is_flying(), "grounded")
	check(nova.shots_fired > 0, "Nova fires at a grounded flier")
	check(int(m.interaction_counts.get("grounded", 0)) > 0, "interaction counted")


func test_conductive_chain_prefers_chilled() -> void:
	var m := make_lab()
	var lance := m.try_build(real_tower("lance"), Vector2(300, 420))
	for i in range(3):
		m.try_upgrade(lance, 1)
	var primary := put(m, make_enemy_def(1.0e6, 0), 300)
	var plain := put(m, make_enemy_def(1.0e6, 0), 330) # nearer, not chilled
	var cold: Array[Enemy] = []
	for x in [250.0, 200.0, 160.0, 120.0, 80.0]:
		cold.append(put(m, make_enemy_def(1.0e6, 0), x))
	primary.aura_slow = 0.3
	for c in cold:
		c.aura_slow = 0.3
	m.registry.rebuild(m.enemies)
	m._chain(lance, primary, 100.0)
	for c in cold:
		check(c.hp < c.max_hp, "chilled enemy chained (incl. bonus jump)")
	near(plain.hp, plain.max_hp, 0.01, "chilled preferred over nearer plain target")
	eq(int(m.interaction_counts.get("conductive", 0)), 1, "one bonus jump at T3")


func test_meltdown_boosts_burn_on_shredded() -> void:
	var m := make_lab()
	var a := put(m, make_enemy_def(1000, 0, 0), 300)
	var b := put(m, make_enemy_def(1000, 0, 0), 600)
	a.apply_burn(10, 5)
	b.apply_burn(10, 5)
	a.apply_shred(4, 6, 10)
	run(m, 1.0)
	near(1000 - a.hp, 15, 0.3, "burn x1.5 with >=4 shred")
	near(1000 - b.hp, 10, 0.3, "normal burn")
	check(int(m.interaction_counts.get("meltdown", 0)) > 0, "counted")


func test_relay_income_diminishing_once_per_wave() -> void:
	var m := make_lab()
	var r1 := _beacon_branch(m, Vector2(300, 420), 2, 1)
	var r2 := _beacon_branch(m, Vector2(400, 420), 2, 1)
	var r3 := _beacon_branch(m, Vector2(500, 420), 2, 1)
	var before := m.economy.currency
	m._on_wave_cleared(0, 0)
	eq(m.economy.currency - before, 10 + 7 + 5, "100% / 75% / 50%")
	m._on_wave_cleared(0, 0)
	eq(m.economy.currency - before, 22, "same wave never pays twice")


func test_focus_beam_ramps_and_resets() -> void:
	var m := make_lab()
	var lance := m.try_build(real_tower("lance"), Vector2(300, 420))
	m.try_upgrade(lance, 2)
	var e := put(m, make_enemy_def(1.0e6, 0), 300)
	run(m, 1.0)
	var first := e.max_hp - e.hp
	var hp1 := e.hp
	run(m, 2.5)
	var later := hp1 - e.hp
	# Focus I beam_dps 40 -> 18 (-10% nerf, then halved by the remake: 40*0.9*0.5)
	check(first > 18 * 1.0 and later / 2.5 > first, "ramps up (%.1f then %.1f/s)" % [first, later / 2.5])
	near(lance.beam_ramp(), 3.0, 0.01, "ramp capped at x3")
