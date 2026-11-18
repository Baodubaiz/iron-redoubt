extends TestCase
## Simulation evidence that every threat has an accessible counter, that the boss can be
## defeated through legitimate play, and that the Combat Lab runs end to end.
## Same budget per comparison; outcomes are logged. Not balance validation.

const MAX_SECONDS := 2400.0


func _circuit_level(waves: Array[WaveDef], towers: Array[TowerDef], money: int, hp: int = 100) -> LevelDef:
	var l := make_level(waves, towers, money, hp)
	l.map = load("res://data/maps/circuit.tres")
	return l


func _sim(level: LevelDef, order_ids: Array, prefs: Dictionary = {}, max_towers: int = -1, label: String = "") -> MatchController:
	var m := make_match(level, 7)
	var order: Array[TowerDef] = []
	for id in order_ids:
		for d in level.available_towers:
			if d.id == id:
				order.append(d)
	var bot := SimBot.new(m, order)
	bot.branch_pref = prefs
	bot.max_towers = max_towers
	var steps := int(MAX_SECONDS / DT)
	for i in range(steps):
		if m.is_over():
			break
		bot.step(DT)
		m.step(DT)
	print("    [sim] %-28s %s -> %s  hp=%d/%d  leaked=%d  kills=%d  towers=%d  t=%ds" % [label, str(order_ids),
		MatchController.State.keys()[m.state], m.base.hp, m.base.max_hp, m.base.damage_taken, m.kills(),
		m.towers.size(), int(m.match_time)])
	return m


func _one_wave(enemy: EnemyDef, count: int, interval: float) -> Array[WaveDef]:
	var w: Array[WaveDef] = [make_wave(enemy, count, interval)]
	return w


func test_armor_counter_lance_beats_pulse_spam() -> void:
	var waves := _one_wave(real_enemy("plated"), 12, 1.2)
	var pulse_only := _sim(_circuit_level(waves, all_real_towers(), 450), [&"pulse"], {}, 4, "plated vs 4x Pulse")
	var lance := _sim(_circuit_level(waves, all_real_towers(), 450), [&"lance"], {}, 2, "plated vs 2x Lance")
	check(lance.base.damage_taken < pulse_only.base.damage_taken, "Lance leaks less vs armor")


func test_flying_counter_pulse_vs_nova() -> void:
	var waves := _one_wave(real_enemy("glider"), 12, 1.0)
	var nova := _sim(_circuit_level(waves, all_real_towers(), 400), [&"nova"], {}, 2, "glider vs Nova")
	var pulse := _sim(_circuit_level(waves, all_real_towers(), 400), [&"pulse"], {}, 4, "glider vs Pulse")
	eq(nova.kills(), 0, "ground-only Nova cannot touch fliers")
	check(pulse.base.damage_taken < nova.base.damage_taken, "Pulse counters fliers")


func test_stealth_counter_beacon_reveal() -> void:
	var waves := _one_wave(real_enemy("phantom"), 10, 1.0)
	var blind := _sim(_circuit_level(waves, all_real_towers(), 450), [&"pulse"], {}, 4, "phantom vs Pulse only")
	var seen := _sim(_circuit_level(waves, all_real_towers(), 450), [&"beacon", &"pulse", &"pulse", &"pulse"], {}, 4, "phantom vs Beacon+Pulse")
	eq(blind.kills(), 0, "unrevealed phantoms cannot be targeted")
	var blind_shots := 0
	var seen_shots := 0
	for t in blind.towers:
		blind_shots += t.shots_fired
	for t in seen.towers:
		seen_shots += t.shots_fired
	eq(blind_shots, 0, "Pulse alone never fires at stealth")
	# Mechanism check only (Phantom's HP / kinetic resist are balance, not tested here): Beacon reveal
	# lets the Pulses engage at all.
	check(seen_shots > 0, "Beacon reveal enables a defence")


func test_shield_counter_lance_energy() -> void:
	var waves := _one_wave(real_enemy("aegis"), 10, 1.3)
	var nova := _sim(_circuit_level(waves, all_real_towers(), 450), [&"nova"], {}, 2, "aegis vs 2x Nova")
	var lance := _sim(_circuit_level(waves, all_real_towers(), 450), [&"lance"], {}, 2, "aegis vs 2x Lance")
	check(lance.base.damage_taken <= nova.base.damage_taken, "Lance (energy x2 vs shield) does at least as well")


func test_boss_defeatable_with_legitimate_play() -> void:
	var waves := _one_wave(real_enemy("monolith"), 1, 1.0)
	var lvl := _circuit_level(waves, all_real_towers(), 9000, 30)
	var m := _sim(lvl, [&"lance", &"nova", &"beacon", &"lance", &"pulse"], {&"lance": 0, &"nova": 2, &"beacon": 0, &"pulse": 0}, 14, "Monolith alone, 9000$ budget")
	eq(m.state, MatchController.State.WON, "Monolith (incl. fracture shards) defeated")
	check(m.base.hp > 0, "base survives")


func test_combat_lab_runs_to_completion() -> void:
	var lvl: LevelDef = load("res://data/levels/combat_lab.tres")
	var m := _sim(lvl, [&"pulse", &"nova", &"beacon", &"lance", &"pulse", &"lance"],
		{&"lance": 0, &"nova": 1, &"beacon": 0, &"pulse": 0}, -1, "Combat Lab, mixed bot")
	check(m.is_over(), "terminates")
	print("    [sim] interactions: ", m.interaction_counts)
