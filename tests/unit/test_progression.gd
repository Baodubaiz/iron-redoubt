extends TestCase
## Persistence & meta progression: unlocks, replay, duplicate submissions, research, ledger,
## interrupted saves, stale/conflicting saves, corrupted data, achievements, challenges.

var campaign: CampaignDef


func before_each() -> void:
	campaign = load("res://data/campaign.tres")


func _model(store: ProgressionStore = null) -> ProgressionModel:
	var pm := ProgressionModel.new(campaign, store if store != null else MemoryStore.new())
	pm.load_profile()
	return pm


func _win(level_index: int, hp_lost: int = 0, extra: Dictionary = {}) -> Dictionary:
	var l := campaign.levels[level_index]
	var r := {"level_id": String(l.id), "won": true, "base_hp": l.base_hp - hp_lost, "max_base_hp": l.base_hp,
		"damage_taken": hp_lost, "duration": 400.0, "tower_types": ["pulse", "nova", "lance"],
		"kills_by_enemy": {}, "evolved_types": [], "interactions": [], "early_starts": 0, "boss_kill_seconds": [],
		"challenge_id": "", "challenge_period": ""}
	r.merge(extra, true)
	return r


func test_fresh_profile_unlocks() -> void:
	var pm := _model()
	check(pm.is_level_unlocked(campaign.levels[0]), "L1 open")
	check(not pm.is_level_unlocked(campaign.levels[1]), "L2 locked")
	check(pm.profile.owns_tower(&"pulse"), "starts with Pulse")
	check(not pm.profile.owns_tower(&"nova") and not pm.profile.owns_tower(&"lance"), "others locked")
	eq(pm.profile.cores(), 0)


func test_clear_unlocks_next_level_and_tower_once() -> void:
	var pm := _model()
	var rep := pm.submit_match(_win(1, 3), "m1") # L2 cleared (needs L1? progression is by previous clear)
	check(rep["first_clear"], "first clear")
	eq(rep["unlocked_tower"], "", "towers now unlock when their level starts, not on clear")
	eq(pm.profile.cores(), campaign.levels[1].cores_first_clear)
	check(pm.is_level_unlocked(campaign.levels[2]), "L3 unlocked")
	var rep2 := pm.submit_match(_win(1, 3), "m2") # replay
	check(not rep2["first_clear"], "not first again")
	eq(rep2["cores"], int(floor(campaign.levels[1].cores_first_clear * 0.25)), "replay reward 25%")
	eq(pm.profile.level_record(&"level_02")["clears"], 2)


func test_level_start_grants_its_counter_tower_once() -> void:
	var pm := _model()
	var l2: LevelDef = campaign.levels[1]
	eq(l2.unlock_tower_on_start.id, &"nova", "level 2 introduces Swarmlings and grants Nova")
	var t := pm.grant_level_start(l2)
	check(t != null and pm.profile.owns_tower(&"nova"), "granted on first start")
	check(pm.grant_level_start(l2) == null, "only once")
	check(pm.grant_level_start(campaign.levels[0]) == null, "level 1 grants nothing")


func test_duplicate_submission_is_ignored() -> void:
	var pm := _model()
	pm.submit_match(_win(0), "same")
	var cores := pm.profile.cores()
	var rep := pm.submit_match(_win(0), "same")
	check(rep["duplicate"], "flagged duplicate")
	eq(pm.profile.cores(), cores, "no double reward")
	eq(pm.profile.level_record(&"level_01")["clears"], 1)


func test_replay_never_regresses_best() -> void:
	var pm := _model()
	pm.submit_match(_win(0, 0), "a")
	pm.submit_match(_win(0, 15), "b")
	var rec := pm.profile.level_record(&"level_01")
	eq(rec["best_hp"], 20, "best kept")
	check(rec["flawless"], "flawless kept")
	check(rec["cleared"], "still cleared")
	pm.submit_match({"level_id": "level_01", "won": false, "damage_taken": 20}, "c")
	check(pm.profile.is_cleared(&"level_01"), "a loss never un-clears")


func test_flawless_bonus_once() -> void:
	var pm := _model()
	var r1 := pm.submit_match(_win(0, 0), "a")
	check(r1["flawless"], "bonus")
	var r2 := pm.submit_match(_win(0, 0), "b")
	check(not r2["flawless"], "only once")


func test_research_purchase_rules() -> void:
	var pm := _model()
	eq(pm.research_block_reason(&"reserve_1"), "Need 50 more Cores")
	check(not pm.buy_research(&"reserve_1"), "cannot afford")
	pm.profile.credit("test:grant", 200)
	eq(pm.research_block_reason(&"reserve_2"), "Requires Reserve Funds I")
	check(pm.buy_research(&"reserve_1"), "buy")
	eq(pm.profile.cores(), 150)
	check(not pm.buy_research(&"reserve_1"), "no double purchase")
	eq(pm.profile.cores(), 150)
	check(pm.buy_research(&"reserve_2"), "prereq met")
	eq(pm.research_block_reason(&"evo_lance"), "Unlock Lance first")
	var mods := pm.build_modifiers()
	eq(mods.start_currency_bonus, 50)
	var u := pm.unlocks()
	check(not u.branch_unlocked(campaign.levels[0].available_towers[0], 2), "branch C still locked")


func test_research_applies_to_match() -> void:
	var pm := _model()
	pm.profile.credit("test:grant", 200)
	pm.buy_research(&"reserve_1")
	pm.buy_research(&"reinforced_core")
	pm.buy_research(&"quick_deploy")
	pm.buy_research(&"branch_pulse_sensor")
	var m := make_match(campaign.levels[0], 1, null)
	m.free()
	_nodes.erase(m)
	var mc := MatchController.new()
	mc.auto_process = false
	tree.root.add_child(mc)
	_nodes.append(mc)
	mc.setup(campaign.levels[0], 1, null, pm.build_modifiers())
	eq(mc.economy.currency, 385 + 25) # 350 * 1.10 seed money + 25 bonus
	eq(mc.base.hp, 20 + 3)
	near(mc.waves.early_bonus_multiplier, 1.25, 0.0001)
	var t := mc.try_build(real_tower("pulse"), Vector2(300, 240))
	check(t != null, "built")
	check(mc.upgrade_block_reason(t, 2) == "" or mc.upgrade_block_reason(t, 2).begins_with("Need"), "Sensor researched")
	check(mc.evolution_block_reason(t) != "", "evolution not researched")
	check(not mc.is_tower_available(real_tower("lance")), "lance not owned")


func test_ledger_cores_and_merge_is_idempotent() -> void:
	var a := Profile.new(Profile.fresh(campaign.starting_towers))
	var b := Profile.new(Profile.fresh(campaign.starting_towers))
	a.credit("clear:level_01", 10)
	b.credit("clear:level_01", 10) # same event seen on both devices
	b.credit("clear:level_02", 10)
	a.spend("research:reserve_1", 5)
	var m := Profile.new(Profile.merge(a.data, b.data))
	eq(m.cores(), 15, "10 + 10 - 5 (shared event counted once)")
	var again := Profile.new(Profile.merge(m.data, b.data))
	eq(again.cores(), 15, "merging twice changes nothing")


func test_interrupted_save_retries() -> void:
	var store := MemoryStore.new()
	var pm := _model(store)
	store.fail_next_saves = 1
	pm.submit_match(_win(0), "x")
	check(pm.pending_save, "pending after failure")
	check(store.stored.is_empty(), "nothing written")
	check(pm.profile.is_cleared(&"level_01"), "kept in memory")
	check(pm.save(), "retry succeeds")
	check(not pm.pending_save, "no longer pending")
	check(Profile.new(store.stored).is_cleared(&"level_01"), "persisted")


func test_stale_save_merges_instead_of_overwriting() -> void:
	var store := MemoryStore.new()
	var dev_a := _model(store)
	var dev_b := _model(store) # both loaded revision 0
	dev_a.submit_match(_win(0), "a1") # writes revision 1
	dev_b.submit_match(_win(1), "b1") # stale base -> conflict -> merge
	var final := Profile.new(store.stored)
	check(final.is_cleared(&"level_01") and final.is_cleared(&"level_02"), "both devices' progress kept")
	eq(final.cores(), campaign.levels[0].cores_first_clear + campaign.levels[1].cores_first_clear + 5 + 5, "no loss, no duplication (+flawless x2)")
	check(int(store.stored["revision"]) >= 2, "revision advanced")


func test_corrupted_and_invalid_data_is_sanitized() -> void:
	var store := MemoryStore.new()
	store.stored = {"schema": 99, "revision": "x", "ledger": {"ok": 10, "bad": "NaN", "inf": INF}, "levels": [],
		"towers": "pulse", "research": [1, "reserve_1"], "achievements": {"a": 1}}
	var pm := _model(store)
	check(pm.recovered, "flagged as repaired")
	eq(pm.profile.cores(), 10, "only valid ledger entries kept")
	check(pm.profile.owns_tower(&"pulse"), "starting towers restored")
	check(pm.profile.has_research(&"reserve_1"), "valid research kept")


func test_local_file_store_roundtrip_and_backup() -> void:
	var path := "user://test_profile_%d.json" % Time.get_ticks_usec()
	var fs := LocalFileStore.new(path)
	var pm := ProgressionModel.new(campaign, fs)
	pm.load_profile()
	pm.submit_match(_win(0), "f1")
	pm.submit_match(_win(1), "f2") # second save creates .bak
	var pm2 := ProgressionModel.new(campaign, LocalFileStore.new(path))
	pm2.load_profile()
	check(pm2.profile.is_cleared(&"level_02"), "reloaded from disk")
	eq(pm2.profile.cores(), pm.profile.cores())
	# corrupt the main file -> backup is used
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var pm3 := ProgressionModel.new(campaign, LocalFileStore.new(path))
	pm3.load_profile()
	check(pm3.profile.is_cleared(&"level_01"), "recovered from backup")
	check(pm3.recovered, "recovery flagged")
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_achievements_from_real_events_once() -> void:
	var pm := _model()
	var rep := pm.submit_match(_win(0, 19, {"base_hp": 1, "tower_types": ["pulse", "nova"]}), "a")
	check(rep["achievements"].has("Close Call"), "won with 1 HP")
	check(rep["achievements"].has("Minimalist"), "2 tower types")
	var cores := pm.profile.cores()
	var rep2 := pm.submit_match(_win(0, 19, {"base_hp": 1, "tower_types": ["pulse", "nova"]}), "b")
	check(not rep2["achievements"].has("Close Call"), "not unlocked twice")
	eq(pm.profile.cores() - cores, int(floor(10 * 0.25)), "only replay reward")
	pm.submit_match(_win(0, 0, {"kills_by_enemy": {"swarmling": 600}}), "c")
	check(not pm.profile.data["achievements"].has("exterminator"), "600 < 1000")
	var rep4 := pm.submit_match(_win(0, 0, {"kills_by_enemy": {"swarmling": 400}}), "d")
	check(rep4["achievements"].has("Exterminator"), "lifetime counter reached")
	var rep5 := pm.submit_match({"level_id": "level_06", "won": false, "boss_kill_seconds": [75.0]}, "e")
	check(rep5["achievements"].has("Monolith Breaker"), "boss killed within 90 s counts even on a loss")


func test_challenge_schedule_deterministic() -> void:
	var t := 1794873600 # 2026-11-17 (Tuesday) 00:00 UTC
	eq(ChallengeSchedule.daily_key(t), "D2026-11-17")
	eq(ChallengeSchedule.weekly_key(t), "W2026-11-16", "week starts Monday")
	eq(ChallengeSchedule.weekly_key(t + 5 * 86400), "W2026-11-16", "Saturday same week")
	eq(ChallengeSchedule.weekly_key(t + 6 * 86400), "W2026-11-23", "next Monday new week")
	var c1 := ChallengeSchedule.pick(campaign.daily_pool, "D2026-11-17")
	var c2 := ChallengeSchedule.pick(campaign.daily_pool, "D2026-11-17")
	check(c1 == c2 and c1 != null, "same key -> same challenge")
	eq(ChallengeSchedule.seconds_left(t + 3600, false), 23 * 3600)


func test_challenge_completion_claimed_once_per_period() -> void:
	var pm := _model()
	var ch := campaign.daily_pool[0]
	var idx := campaign.level_index(ch.level.id)
	var r := _win(idx, 0, {"challenge_id": String(ch.id), "challenge_period": "D2026-11-11"})
	var rep := pm.submit_match(r, "c1")
	check(rep["challenge_completed"], "completed")
	check(pm.profile.has_entry("challenge:D2026-11-11:%s" % ch.id), "reward claimed")
	var cores := pm.profile.cores()
	var rep2 := pm.submit_match(r, "c2")
	check(not rep2["challenge_completed"], "already done this period")
	eq(pm.profile.cores(), cores, "no second claim")
	check(not pm.profile.is_cleared(ch.level.id), "challenge runs don't count as campaign clears")
	var rep3 := pm.submit_match(_win(idx, 0, {"challenge_id": String(ch.id), "challenge_period": "D2026-11-12"}), "c3")
	check(rep3["challenge_completed"], "new period -> new completion")


func test_challenge_modifiers_enforced() -> void:
	var pm := _model()
	var ch := ChallengeDef.new()
	ch.id = &"t"
	ch.level = campaign.levels[0]
	ch.banned_towers = [&"nova"]
	ch.base_hp_cap = 5
	ch.currency_multiplier = 0.8
	ch.no_selling = true
	var mods := pm.build_modifiers(ch, "D1")
	var m := MatchController.new()
	m.auto_process = false
	tree.root.add_child(m)
	_nodes.append(m)
	m.setup(campaign.levels[0], 1, null, mods)
	eq(m.base.hp, 5)
	eq(m.economy.currency, 308) # 350 * 1.10 * 0.8
	check(not m.is_tower_available(real_tower("nova")), "banned")
	var t := m.try_build(real_tower("pulse"), Vector2(300, 240))
	eq(m.try_sell(t), -1, "no selling")
	eq(m.build_result()["challenge_id"], "t")
