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
