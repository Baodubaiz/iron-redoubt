extends TestCase
## Targeting, cooldowns, air restriction, splash, kill/escape exactly-once.


func _setup(tdef: TowerDef, enemy: EnemyDef, count: int = 1, money: int = 1000, hp: int = 10) -> MatchController:
	var towers: Array[TowerDef] = [tdef]
	var waves: Array[WaveDef] = [make_wave(enemy, count, 1.0), make_wave(enemy, 1)]
	return make_match(make_level(waves, towers, money, hp))


func test_cooldown_fire_rate() -> void:
	var tdef := make_tower_def(100, 0.001, 2.0, 2000.0) # negligible damage, huge range
	var m := _setup(tdef, make_enemy_def(1000, 10))
	var t := m.try_build(tdef, Vector2(300, 400))
	m.request_next_wave()
	m.step(DT) # spawn + first shot
	eq(t.shots_fired, 1, "fires immediately on acquire")
	for i in range(58):
		m.step(DT) # total 59 frames < 1s
	eq(t.shots_fired, 2, "2 shots/s -> 2 shots in <1s")
	for i in range(61):
		m.step(DT) # 120 frames = 2.0s
	check(t.shots_fired == 4 or t.shots_fired == 5, "4-5 shots by 2.0s, got %d" % t.shots_fired)


func test_target_first_in_range() -> void:
	var tdef := make_tower_def(100, 0.001, 1.0, 120.0)
	var m := _setup(tdef, make_enemy_def(1000, 0))
	var t := m.try_build(tdef, Vector2(300, 380))
	var a := m.spawn_enemy(make_enemy_def(1000, 0), 0)
	var b := m.spawn_enemy(make_enemy_def(1000, 0), 0)
	var c := m.spawn_enemy(make_enemy_def(1000, 0), 0)
	a.progress = 250; b.progress = 330; c.progress = 600 # c out of range (dist ~ 309)
	for e in [a, b, c]:
		e.position = e.route.position_at(e.progress, 0)
	m.request_next_wave()
	m.step(DT)
	check(t.target == b, "targets furthest along within range")


func test_ground_only_tower_ignores_air() -> void:
	var tdef := make_tower_def(100, 50.0, 1.0, 300.0, 0.0, false)
	var flyer := make_enemy_def(100, 0, 0, 5, 1, true)
	var m := _setup(tdef, flyer)
	var t := m.try_build(tdef, Vector2(300, 400))
	m.request_next_wave()
	run(m, 1.0)
	check(t.target == null, "no air target")
	eq(t.shots_fired, 0)


func test_kill_bounty_paid_once() -> void:
	var tdef := make_tower_def(100, 1000.0, 5.0, 400.0)
	var m := _setup(tdef, make_enemy_def(50, 10, 0, 7))
	m.try_build(tdef, Vector2(150, 400))
	var before := m.economy.currency
	m.request_next_wave()
	run(m, 0.5)
	eq(m.kills(), 1)
	# the single-enemy wave also clears, paying the wave reward once
	eq(m.economy.currency - before, m.economy.config.kill_bounty(7) + m.level.economy.wave_reward(1), "bounty once + wave reward")
	check(m.economy.was_paid("kill:%d" % 2) or m.economy.was_paid("kill:%d" % 3), "kill ledger key recorded")


func test_damage_after_death_is_ignored() -> void:
	var tdef := make_tower_def()
	var m := _setup(tdef, make_enemy_def(10, 0, 0, 7))
	m.request_next_wave()
	m.step(DT)
	var e := m.enemies[0]
	var before := m.economy.currency
	m.damage_enemy(e, 100, Damage.Type.KINETIC, 0)
	m.damage_enemy(e, 100, Damage.Type.KINETIC, 0)
	eq(m.economy.currency - before, m.economy.config.kill_bounty(7), "second hit pays nothing")
	eq(m.kills(), 1)


func test_splash_hits_group_and_respects_armor() -> void:
	var tdef := make_tower_def(100, 30.0, 0.5, 300.0, 55.0, false, TowerDef.TargetRule.DENSEST)
	var armored := make_enemy_def(1000, 0, 10)
	var m := _setup(tdef, armored)
	m.try_build(tdef, Vector2(300, 400))
	var es: Array[Enemy] = []
	for x in [280.0, 300.0, 320.0, 420.0]:
		var e := m.spawn_enemy(armored, 0)
		e.progress = x
		e.position = e.route.position_at(x, 0)
		es.append(e)
	m.request_next_wave()
	m.step(DT)
	m.step(DT)
	near(es[0].hp, 980.0, 0.01, "30-10 armor")
	near(es[1].hp, 980.0, 0.01)
	near(es[2].hp, 980.0, 0.01)
	near(es[3].hp, 1000.0, 0.01, "outside splash")


func test_escape_damages_base_once_no_bounty() -> void:
	var tdef := make_tower_def()
	var m := _setup(tdef, make_enemy_def(100, 500, 0, 9, 3), 1, 1000, 10)
	var before := m.economy.currency
	m.request_next_wave()
	run(m, 2.5) # 1000px at 500px/s
	eq(m.base.hp, 7, "base damage 3 once")
	eq(m.alive_enemy_count(), 0, "escaped enemy removed")
	eq(m.economy.currency - before, m.level.economy.wave_reward(1) + 0, "only wave reward, no bounty")
