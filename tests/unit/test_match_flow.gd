extends TestCase
## Waves (first start, prep countdown, auto start, early bonus once), victory/defeat, pause gating.


func _level(waves: Array[WaveDef], hp: int = 10, money: int = 500) -> LevelDef:
	var towers: Array[TowerDef] = [make_tower_def(100, 1000.0, 10.0, 2000.0)]
	return make_level(waves, towers, money, hp)


func _kill_all(m: MatchController) -> void:
	for e in m.enemies:
		m.damage_enemy(e, 1.0e9, Damage.Type.TRUE, 0)


func test_first_wave_waits_for_player() -> void:
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(), 2), make_wave(make_enemy_def(), 2)]
	var m := make_match(_level(waves))
	run(m, 60.0)
	eq(m.state, MatchController.State.WAITING_FIRST_WAVE)
	eq(m.enemies.size(), 0)
	check(m.request_next_wave(), "start accepted")
	check(not m.request_next_wave(), "second press during active wave rejected")
	eq(m.state, MatchController.State.WAVE_ACTIVE)


func test_wave_clear_reward_once_and_prep_autostart() -> void:
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(10, 10, 0, 0), 2, 0.5), make_wave(make_enemy_def(), 1)]
	var m := make_match(_level(waves))
	var start := m.economy.currency
	m.request_next_wave()
	run(m, 0.6) # both spawned
	_kill_all(m)
	m.step(DT)
	m.step(DT)
	eq(m.state, MatchController.State.PREP)
	eq(m.economy.currency - start, m.level.economy.wave_reward(1), "wave reward once (bounty 0)")
	m.step(DT)
	eq(m.economy.currency - start, m.level.economy.wave_reward(1), "no repeat reward")
	near(m.waves.prep_remaining, 20.0 - DT, 0.05)
	run(m, 20.1)
	eq(m.state, MatchController.State.WAVE_ACTIVE, "auto start after countdown")
	eq(m.waves.index, 1)


func test_early_start_bonus_granted_once() -> void:
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(10, 10, 0, 0), 1), make_wave(make_enemy_def(), 1), make_wave(make_enemy_def(), 1)]
	var m := make_match(_level(waves))
	m.request_next_wave()
	m.step(DT)
	_kill_all(m)
	m.step(DT)
	eq(m.state, MatchController.State.PREP)
	run(m, 10.0) # ~10s remaining -> floor(10*1.5)=15 (allow 14-15 for frame rounding)
	var expected := m.waves.current_early_bonus()
	check(expected >= 14 and expected <= 15, "bonus %d" % expected)
	var before := m.economy.currency
	check(m.request_next_wave(), "early start")
	check(not m.request_next_wave(), "spam rejected")
	check(not m.request_next_wave(), "spam rejected 2")
	eq(m.economy.currency - before, expected, "bonus once")
	check(m.economy.was_paid("early:1"), "ledger key")
	eq(m.waves.index, 1)


func test_victory_after_last_wave() -> void:
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(10, 10), 1)]
	var m := make_match(_level(waves))
	var ended := [false, false]
	m.match_ended.connect(func(won: bool) -> void:
		ended[0] = true
		ended[1] = won)
	m.request_next_wave()
	m.step(DT)
	_kill_all(m)
	m.step(DT)
	check(ended[0] and ended[1], "won")
	eq(m.state, MatchController.State.WON)
	check(not m.can_issue_commands(), "no commands after end")


func test_defeat_at_zero_and_no_rewards_after() -> void:
	var fast := make_enemy_def(100, 1000, 0, 50, 4)
	var waves: Array[WaveDef] = [make_wave(fast, 5, 0.01), make_wave(fast, 1)]
	var m := make_match(_level(waves, 10))
	m.request_next_wave()
	run(m, 3.0)
	eq(m.state, MatchController.State.LOST)
	eq(m.base.hp, 0)
	var money := m.economy.currency
	for e in m.enemies:
		m.damage_enemy(e, 1e9, Damage.Type.TRUE, 0)
	run(m, 5.0)
	eq(m.economy.currency, money, "no rewards after defeat")
	check(m.try_build(m.level.available_towers[0], Vector2(300, 400)) == null, "no build after defeat")


func test_pause_freezes_simulation_and_commands() -> void:
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(100, 50), 3, 1.0), make_wave(make_enemy_def(), 1)]
	var m := make_match(_level(waves))
	m.request_next_wave()
	run(m, 0.5)
	var e := m.enemies[0]
	var p := e.progress
	var money := m.economy.currency
	m.set_paused(true)
	check(m.paused, "match paused")
	if m.is_inside_tree():
		check(tree.paused, "scene tree paused")
	run(m, 5.0)
	near(e.progress, p, 0.0001, "enemy frozen")
	eq(m.enemies.size(), 1, "no spawns while paused")
	check(m.try_build(m.level.available_towers[0], Vector2(300, 400)) == null, "build blocked while paused")
	check(not m.request_next_wave(), "wave start blocked while paused")
	eq(m.economy.currency, money)
	m.set_paused(false)
	run(m, 0.5)
	check(e.progress > p, "resumes")


func test_wave_variance_bounded_and_seeded() -> void:
	var counts := {}
	for s in range(20):
		var waves: Array[WaveDef] = [make_wave(make_enemy_def(), 20, 0.01, 0.15), make_wave(make_enemy_def(), 1)]
		var m := make_match(_level(waves), s)
		m.request_next_wave()
		run(m, 1.0)
		var n := m.enemies.size()
		check(n >= 17 and n <= 23, "count %d within +/-15%%" % n)
		counts[s] = n
	var waves2: Array[WaveDef] = [make_wave(make_enemy_def(), 20, 0.01, 0.15), make_wave(make_enemy_def(), 1)]
	var again := make_match(_level(waves2), 7)
	again.request_next_wave()
	run(again, 1.0)
	eq(again.enemies.size(), counts[7], "same seed -> same count")


func test_special_wave_not_randomized() -> void:
	var w := make_wave(make_enemy_def(), 20, 0.01, 0.15)
	w.is_special = true
	for s in range(10):
		var waves: Array[WaveDef] = [w, make_wave(make_enemy_def(), 1)]
		var m := make_match(_level(waves), s)
		m.request_next_wave()
		run(m, 1.0)
		eq(m.enemies.size(), 20)


# ---------------------------------------------------------------- mid-match save (MatchSnapshot)

func test_mid_match_snapshot_round_trip() -> void:
	var lvl: LevelDef = load("res://data/levels/level_01.tres")
	var a := make_match(lvl, 11)
	var pulse := real_tower("pulse")
	a.economy.credit(2000, "test")
	var t := a.try_build(pulse, Vector2(560, 560))
	if t == null: # find any legal spot
		for x in range(200, 1100, 40):
			for y in range(120, 680, 40):
				if t == null:
					t = a.try_build(pulse, Vector2(x, y))
	check(t != null, "built a tower")
	a.try_upgrade(t, 0)
	a.try_upgrade(t, 1)
	a.set_targeting(t, TowerDef.TargetRule.STRONGEST)
	a.base.max_hp = 1000 # survive wave 1 whatever leaks
	a.base.hp = 1000
	a.request_next_wave()
	for i in range(int(240.0 / DT)):
		a.step(DT)
		if a.state == MatchController.State.PREP:
			break
	eq(a.state, MatchController.State.PREP, "first wave cleared")
	var d := MatchSnapshot.capture(a, "m-1", [&"pulse"])
	d = JSON.parse_string(JSON.stringify(d)) # through JSON like the real file
	var b := make_match(lvl, int(d["seed"]))
	check(MatchSnapshot.apply(b, d), "snapshot applies")
	eq(b.state, MatchController.State.PREP)
	eq(b.waves.index, a.waves.index)
	eq(b.economy.currency, a.economy.currency)
	eq(b.base.hp, a.base.hp)
	eq(b.kills(), a.kills())
	eq(b.towers.size(), 1)
	var bt := b.towers[0]
	eq(bt.tiers, t.tiers)
	eq(bt.branch, t.branch)
	eq(bt.total_invested, t.total_invested)
	eq(bt.targeting_override, t.targeting_override)
	near(bt.damage, t.damage, 0.0001, "same stats after rebuild")
	check(bt.get_node_or_null("Visual") != null, "restored tower is drawn (has its TowerVisual)")
	check(b.economy.was_paid("wave:0"), "wave 1 reward is not paid twice")
	eq(b.rng.state, a.rng.state, "random state restored (same spawn variance)")
	eq(bt.shots_fired, t.shots_fired, "shot counter restored (crit rhythm)")
	for k in d["paid"]:
		check(not String(k).begins_with("kill:"), "per-kill keys are not stored")
	check(b.request_next_wave(), "can start the next wave")
	eq(b.waves.index, a.waves.index + 1)


func test_mid_match_snapshot_rejects_changed_level() -> void:
	var lvl: LevelDef = load("res://data/levels/level_01.tres")
	var a := make_match(lvl, 3)
	a.base.max_hp = 1000
	a.base.hp = 1000
	a.request_next_wave()
	for i in range(int(240.0 / DT)):
		a.step(DT)
		if a.state == MatchController.State.PREP:
			break
	var d := MatchSnapshot.capture(a, "m", [])
	d["fingerprint"] = "other"
	check(not MatchSnapshot.is_compatible(d, lvl), "different waves -> not applied")
	var other: LevelDef = load("res://data/levels/level_02.tres")
	d = MatchSnapshot.capture(a, "m", [])
	check(not MatchSnapshot.is_compatible(d, other), "different level -> not applied")


func test_mid_match_snapshot_file_round_trip() -> void:
	var path := "user://test_match_resume.json"
	MatchSnapshot.save({"version": MatchSnapshot.VERSION, "x": 1}, path)
	eq(int(MatchSnapshot.load_saved(path).get("x", 0)), 1)
	MatchSnapshot.clear(path)
	check(MatchSnapshot.load_saved(path).is_empty(), "cleared")
