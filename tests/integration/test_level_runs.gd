extends TestCase
## Full headless level runs using the real data files and the scripted SimBot.
## These prove the loop is completable/losable end to end; they are NOT balance validation.

const MAX_SECONDS := 1800.0


func _simulate(level_path: String, order_ids: Array[StringName], seed_value: int, early: bool = false) -> MatchController:
	var level: LevelDef = load(level_path)
	var m := make_match(level, seed_value)
	var order: Array[TowerDef] = []
	for id in order_ids:
		for d in level.available_towers:
			if d.id == id:
				order.append(d)
	var bot := SimBot.new(m, order)
	bot.start_early = early
	var steps := int(MAX_SECONDS / DT)
	for i in range(steps):
		if m.is_over():
			break
		bot.step(DT)
		m.step(DT)
	print("    [sim] %s seed=%d order=%s early=%s -> %s  hp=%d/%d  waves=%d/%d  towers=%d  money=%d  t=%ds" % [
		level.id, seed_value, str(order_ids), str(early), MatchController.State.keys()[m.state],
		m.base.hp, m.base.max_hp, m.waves.index + 1, m.waves.wave_count(), m.towers.size(),
		m.economy.currency, int(m.match_time)])
	return m


func test_level1_no_towers_is_lost() -> void:
	var m := _simulate("res://data/levels/level_01.tres", [], 1)
	eq(m.state, MatchController.State.LOST, "undefended base falls")
	eq(m.base.hp, 0)


func test_level1_bot_wins() -> void:
	for s in [1, 2, 3]:
		var m := _simulate("res://data/levels/level_01.tres", [&"pulse", &"pulse", &"nova"], s)
		eq(m.state, MatchController.State.WON, "L1 seed %d" % s)


func test_level1_bot_wins_with_early_starts() -> void:
	var m := _simulate("res://data/levels/level_01.tres", [&"pulse", &"pulse", &"nova"], 4, true)
	eq(m.state, MatchController.State.WON, "L1 early-start bot")


func test_level2_draft_bot_result() -> void:
	# Draft level: we only assert the run terminates; the outcome is logged for Phase 4 tuning.
	var m := _simulate("res://data/levels/level_02.tres", [&"pulse", &"nova", &"pulse"], 1)
	check(m.is_over(), "L2 run terminates")
