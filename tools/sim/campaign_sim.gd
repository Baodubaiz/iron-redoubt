extends SceneTree
## Headless campaign simulator for balancing. Runs every level with several scripted strategies
## and a NO-META profile (no research: branch C and evolutions locked, base stats only).
##   godot --headless --path . -s res://tools/sim/campaign_sim.gd [-- --levels=1,2 --seeds=1,2]
## Output is evidence for tuning, not proof of fun or fairness.

const DT := 1.0 / 60.0
static var trace := false
static var full_meta := false
static var crosspath := false
const MAX_SECONDS := 2400.0

const STRATEGIES := {
	"balanced": {"order": [&"pulse", &"nova", &"pulse", &"lance", &"beacon", &"nova", &"lance", &"pulse"],
		"prefs": {&"pulse": 0, &"nova": 0, &"lance": 0, &"beacon": 1}},
	"heavy": {"order": [&"lance", &"nova", &"pulse", &"lance", &"beacon", &"nova"],
		"prefs": {&"pulse": 1, &"nova": 1, &"lance": 1, &"beacon": 0}},
	"swarm": {"order": [&"nova", &"pulse", &"nova", &"pulse", &"beacon", &"lance"],
		"prefs": {&"pulse": 0, &"nova": 0, &"lance": 0, &"beacon": 1}},
}


func _initialize() -> void:
	var only_levels: Array[int] = []
	var seeds: Array[int] = [1]
	var only_strategy := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			for s in a.substr(9).split(","):
				only_levels.append(int(s))
		if a == "--trace":
			trace = true
		if a == "--meta":
			full_meta = true
		if a == "--crosspath":
			crosspath = true
		if a.begins_with("--strategy="):
			only_strategy = a.substr(11)
		if a.begins_with("--seeds="):
			seeds.clear()
			for s in a.substr(8).split(","):
				seeds.append(int(s))
	var campaign: CampaignDef = load("res://data/campaign.tres")
	print("level      strategy  seed  result  hp      leaked  waves  t(s)  money")
	for i in range(campaign.levels.size()):
		if not only_levels.is_empty() and not only_levels.has(i + 1):
			continue
		var lvl := campaign.levels[i]
		for sname in STRATEGIES:
			if only_strategy != "" and sname != only_strategy:
				continue
			for sd in seeds:
				var r := run_level(lvl, sname, sd, campaign, i)
				print("%-10s %-9s %-5d %-7s %3d/%-3d %-7d %2d/%-3d %-5d %d" % [lvl.id, sname, sd, r["result"],
					r["hp"], r["max_hp"], r["leaked"], r["waves"], r["total"], r["t"], r["money"]])
	quit(0)


## Towers owned at this point of a fresh campaign (no research purchased).
static func no_meta_modifiers(campaign: CampaignDef, level_index: int) -> MatchModifiers:
	var m := MatchModifiers.new()
	m.unlocks = UpgradeRules.Unlocks.new()
	for t in campaign.starting_towers:
		m.owned_towers.append(t)
	for i in range(level_index):
		var u := campaign.levels[i].unlock_tower_on_clear
		if u != null:
			m.owned_towers.append(u.id)
	for i in range(mini(level_index + 1, campaign.levels.size())): # granted when the level starts
		var s := campaign.levels[i].unlock_tower_on_start
		if s != null and not m.owned_towers.has(s.id):
			m.owned_towers.append(s.id)
	return m


func run_level(lvl: LevelDef, strategy: String, sd: int, campaign: CampaignDef, index: int) -> Dictionary:
	var m := MatchController.new()
	m.auto_process = false
	root.add_child(m)
	var mods := no_meta_modifiers(campaign, index)
	if full_meta: # every research owned: branch C + evolutions, +50 currency, +3 HP, +25% early bonus
		mods.unlocks = UpgradeRules.Unlocks.everything()
		mods.start_currency_bonus = 50
		mods.base_hp_bonus = 3
		mods.early_bonus_multiplier = 1.25
	m.setup(lvl, sd, null, mods)
	var bot := make_bot(m, strategy)
	var leaks := {}
	if trace:
		m.enemy_escaped.connect(func(e: Enemy) -> void:
			var k := "w%d:%s" % [m.waves.index + 1, e.def.id]
			leaks[k] = int(leaks.get(k, 0)) + e.base_damage)
	var steps := int(MAX_SECONDS / DT)
	for k in range(steps):
		if m.is_over():
			break
		bot.step(DT)
		m.step(DT)
	var r := {"result": MatchController.State.keys()[m.state], "hp": m.base.hp, "max_hp": m.base.max_hp,
		"leaked": m.base.damage_taken, "waves": m.waves.index + 1, "total": m.waves.wave_count(),
		"t": int(m.match_time), "money": m.economy.currency, "won": m.state == MatchController.State.WON}
	if trace and not leaks.is_empty():
		print("    leaks: ", leaks)
		var counts := {}
		for t in m.towers:
			var key := "%s/%s" % [t.def.id, t.tier]
			counts[key] = int(counts.get(key, 0)) + 1
		print("    towers: ", counts)
	m.free()
	return r


static func make_bot(m: MatchController, strategy: String) -> SimBot:
	var s: Dictionary = STRATEGIES[strategy]
	var order: Array[TowerDef] = []
	for id in s["order"]:
		for d in m.available_towers():
			if d.id == id:
				order.append(d)
	var bot := SimBot.new(m, order)
	bot.branch_pref = s["prefs"]
	if crosspath: # also buy a secondary branch (main A/B, secondary the other of A/B)
		var cp := {}
		for k in s["prefs"]:
			var main: int = s["prefs"][k]
			cp[k] = [main, 1 - main if main < 2 else 0]
		bot.branch_pref = cp
	bot.air_weight = 3
	bot.adaptive = true
	bot.min_towers_before_upgrade = 6
	return bot
