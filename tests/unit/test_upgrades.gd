extends TestCase
## Branch purchase (main up to T3 + one secondary up to T2), research locks, evolution requirements and
## cap, and upgrades changing actual behaviour.


func test_main_plus_secondary_branch_rules() -> void:
	var m := make_lab(5000)
	var t := m.try_build(real_tower("pulse"), Vector2(300, 400))
	check(m.try_upgrade(t, 0), "Rapid I")
	eq(t.branch, 0)
	eq(t.tier, 1)
	near(t.fire_rate, 2.6, 0.001, "Rapid I rate")
	var A := t.def.branches[0].tiers
	var B := t.def.branches[1].tiers
	eq(t.total_invested, t.def.cost + A[0].cost)
	check(m.try_upgrade(t, 1), "Penetrator I as second branch")
	check(not m.try_upgrade(t, 2), "third branch locked")
	eq(m.upgrade_block_reason(t, 2), "Locked: 2 branches chosen")
	check(m.try_upgrade(t, 0), "Rapid II")
	check(m.try_upgrade(t, 1), "Penetrator II")
	check(m.try_upgrade(t, 0), "Rapid III -> main branch")
	eq(t.branch, 0)
	eq(t.secondary_branch(), 1)
	check(not m.try_upgrade(t, 1), "secondary capped at tier 2")
	eq(m.upgrade_block_reason(t, 1), "Secondary max (tier 2)")
	check(not m.try_upgrade(t, 0), "no tier 4")
	eq(m.upgrade_block_reason(t, 0), "Max tier")
	# combined stats ADD UP: base + (Rapid III - base) + (Penetrator II - base)
	var base_rate := t.def.fire_rate
	var base_dmg := t.def.damage
	near(t.fire_rate, base_rate + (A[2].stats["fire_rate"] - base_rate) + (B[1].stats["fire_rate"] - base_rate), 0.001,
		"rate: Rapid's + and Penetrator's - both count")
	near(t.damage, base_dmg + (A[2].stats["damage"] - base_dmg) + (B[1].stats["damage"] - base_dmg), 0.001, "damage adds up")
	near(t.armor_pen, 4.0, 0.001, "Penetrator II pen")
	eq(t.total_invested, t.def.cost + A[0].cost + A[1].cost + A[2].cost + B[0].cost + B[1].cost)


func test_either_branch_can_become_main() -> void:
	var m := make_lab(5000)
	var t := m.try_build(real_tower("pulse"), Vector2(300, 400))
	for b in [0, 1, 0, 1]:
		check(m.try_upgrade(t, b), "2/2 split")
	check(m.try_upgrade(t, 1), "Penetrator III first -> it becomes main")
	eq(t.branch, 1)
	check(not m.try_upgrade(t, 0), "Rapid now capped at 2")
	t.waves_since_t3 = 2
	check(m.try_evolve(t), "evolution follows the main branch")
	eq(int(t.pf("pierce")), 3, "Railspike (Penetrator evolution)")


func test_beacon_secondary_combines_slow_and_buff() -> void:
	var m := make_lab(5000)
	var b := m.try_build(real_tower("beacon"), Vector2(300, 400))
	check(m.try_upgrade(b, 0), "Amplifier I (slow 0)")
	near(b.pf("slow"), 0.0, 0.0001, "Amplifier alone removes slow")
	check(m.try_upgrade(b, 1), "Cryo I as secondary")
	var base_slow := float(b.def.base_params["slow"])
	near(b.pf("slow"), base_slow + (0.0 - base_slow) + (float(b.def.branches[1].tiers[0].stats["slow"]) - base_slow), 0.0001,
		"Amplifier's -slow and Cryo's +slow add up")
	near(b.pf("amp_damage"), 0.10, 0.0001, "buff kept")


func test_speed_x2_runs_two_steps_per_frame() -> void:
	var m := make_lab()
	m.auto_process = true
	m.request_next_wave()
	for i in range(60):
		m._physics_process(DT)
	near(m.match_time, 1.0, 0.01, "x1: one second")
	m.set_speed(2)
	for i in range(60):
		m._physics_process(DT)
	near(m.match_time, 3.0, 0.01, "x2: two seconds per real second")
	m.set_speed(5)
	eq(m.speed, 2, "speed capped at x2")
	m.set_paused(true)
	var t := m.match_time
	m._physics_process(DT)
	near(m.match_time, t, 0.0001, "paused stays frozen at x2")
	m.set_paused(false)
	m.auto_process = false


func test_upgrade_requires_currency_and_unpaused() -> void:
	var m := make_lab(84) # Pulse base 58 leaves 26 (< 40 Rapid I)
	var t := m.try_build(real_tower("pulse"), Vector2(300, 400))
	check(not m.try_upgrade(t, 0), "26 < 40")
	eq(t.branch, -1, "nothing committed on failure")
	eq(m.economy.currency, 84 - t.def.cost)
	m.economy.credit(100, "test")
	m.set_paused(true)
	check(not m.try_upgrade(t, 0), "blocked while paused")
	eq(m.upgrade_block_reason(t, 0), "Paused")
	m.set_paused(false)
	check(m.try_upgrade(t, 0), "ok after resume")


func test_branch_c_requires_research() -> void:
	var u := UpgradeRules.Unlocks.new()
	var m := make_lab(5000, u)
	var t := m.try_build(real_tower("pulse"), Vector2(300, 400))
	eq(m.upgrade_block_reason(t, 2), "Requires research")
	check(not m.try_upgrade(t, 2), "Sensor locked without research")
	check(m.upgrade_block_reason(t, 0) == "", "A/B open")
	u.branch_c[&"pulse"] = true
	check(m.try_upgrade(t, 2), "Sensor after research")


func test_upgrade_changes_behaviour_flak_hits_air() -> void:
	var m := make_lab()
	var nova := m.try_build(real_tower("nova"), Vector2(300, 400))
	var g := put(m, real_enemy("glider", 0.0), 320)
	run(m, 1.0)
	eq(nova.shots_fired, 0, "base Nova ignores air")
	for i in range(3):
		check(m.try_upgrade(nova, 0), "Cluster %d" % (i + 1))
	check(nova.can_target_air, "Flak")
	run(m, 2.0)
	check(nova.shots_fired > 0, "now fires at air")
	check(g.hp < g.max_hp, "glider damaged")


func test_evolution_requirements_and_cap() -> void:
	var u := UpgradeRules.Unlocks.new()
	var m := make_lab(100000, u)
	var towers: Array[Tower] = []
	for x in [300.0, 360.0, 420.0]:
		var t := m.try_build(real_tower("pulse"), Vector2(x, 400))
		towers.append(t)
	var t0 := towers[0]
	eq(m.evolution_block_reason(t0), "Choose a branch first")
	m.try_upgrade(t0, 0)
	eq(m.evolution_block_reason(t0), "Requires tier 3")
	m.try_upgrade(t0, 0)
	m.try_upgrade(t0, 0)
	eq(m.evolution_block_reason(t0), "Requires research")
	u.evolutions[&"pulse"] = true
	check(m.evolution_block_reason(t0).begins_with("Calibrating"), "needs 2 waves at T3")
	for t in towers.slice(1):
		for i in range(3):
			m.try_upgrade(t, 1)
	# simulate two cleared waves
	m._on_wave_cleared(0, 0)
	m._on_wave_cleared(1, 0)
	eq(t0.waves_since_t3, 2)
	var before := m.economy.currency
	check(m.try_evolve(t0), "evolve #1")
	eq(before - m.economy.currency, 276) # Storm Array evolution cost +38% (200 * 1.15 * 1.20 = 276)
	check(t0.evolved, "flag")
	eq(int(t0.pf("burst_every")), 20, "Storm Array param applied")
	near(t0.fire_rate, 4.5, 0.001, "tier stats kept")
	check(not m.try_evolve(t0), "no double evolve")
	var base1 := towers[1].branch_def().evolution.cost
	eq(m.evolution_cost(towers[1]), int(round(base1 * 1.15)), "2nd pulse evolution +15%")
	before = m.economy.currency
	check(m.try_evolve(towers[1]), "evolve #2")
	eq(before - m.economy.currency, int(round(base1 * 1.15)), "charged the raised price")
	eq(m.evolution_cost(towers[2]), int(round(base1 * 1.30)), "3rd pulse evolution +30%")
	check(m.try_evolve(towers[2]), "evolve #3 - all towers can evolve in level")
	# another tower type starts from its own base price
	var n := m.try_build(real_tower("nova"), Vector2(480, 400))
	m.try_upgrade(n, 0)
	m.try_upgrade(n, 0)
	m.try_upgrade(n, 0)
	eq(m.evolution_cost(n), n.branch_def().evolution.cost, "counted per tower type")


func test_storm_array_burst_fires_extra_shots() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("pulse"), Vector2(300, 400))
	for i in range(3):
		m.try_upgrade(t, 0)
	t.waves_since_t3 = 2
	check(m.try_evolve(t), "evolve")
	for x in [250.0, 300.0, 350.0]:
		put(m, make_enemy_def(1.0e7, 0), x)
	t.shots_fired = 19
	m.step(DT) # 20th shot -> 1 + 6 burst projectiles
	check(m.projectiles.active_count() >= 7 or m.interaction_counts.get("storm_array", 0) == 1, "burst fired")
	eq(int(m.interaction_counts.get("storm_array", 0)), 1)


## 2026-11-19: Focus is a firing mode only as the MAIN branch; as a secondary it ramps normal shots, and a
## secondary Overcharge raises the beam.
func test_lance_branches_work_together() -> void:
	var m := make_lab(100000)
	var oc := m.try_build(real_tower("lance"), Vector2(300, 420))
	m.try_upgrade(oc, 0)
	m.try_upgrade(oc, 0) # Overcharge II (main)
	m.try_upgrade(oc, 2) # Focus I (secondary)
	eq(oc.branch, 0)
	near(oc.pf("beam_dps"), 0.0, 0.0001, "secondary Focus does not turn the tower into a beam")
	check(oc.pf("ramp_max") > 1.0, "but lends its ramp")
	var e := put(m, make_enemy_def(1.0e6, 0), 300)
	run(m, 4.0)
	check(oc.shots_fired > 0, "still fires shots")
	check(oc.shot_ramp() > 1.5, "shots ramp on the same target")
	check(e.hp < e.max_hp, "and hit")
	var fo := m.try_build(real_tower("lance"), Vector2(600, 420))
	m.try_upgrade(fo, 2)
	m.try_upgrade(fo, 2) # Focus II (main)
	var plain := fo.beam_dps()
	m.try_upgrade(fo, 0) # Overcharge I (secondary)
	check(fo.pf("beam_dps") > 0.0, "main Focus keeps the beam")
	check(fo.beam_dps() > plain * 1.2, "secondary Overcharge raises the beam (%.1f -> %.1f)" % [plain, fo.beam_dps()])
