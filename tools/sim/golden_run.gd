class_name GoldenRun
extends RefCounted
## Deterministic gameplay fingerprint of every campaign level, used to prove visual-only changes do
## not change gameplay. Two runs per level:
##   "base":  no research, "balanced" bot (base towers, main branches)
##   "full":  every research, "heavy" bot with main + secondary branches (evolutions, branch C)
## Record:  godot --headless --path . -s res://tools/sim/golden_record.gd
## Check:   tests/integration/test_golden.gd

const PATH := "res://tests/golden/gameplay_golden.json"
const DT := 1.0 / 60.0
const MAX_SECONDS := 2400.0
const SIM := preload("res://tools/sim/campaign_sim.gd")


static func run_all(host: Node) -> Dictionary:
	var campaign: CampaignDef = load("res://data/campaign.tres")
	var out := {}
	for i in range(campaign.levels.size()):
		var lvl := campaign.levels[i]
		out["%s/base" % lvl.id] = run_one(host, campaign, i, false)
		out["%s/full" % lvl.id] = run_one(host, campaign, i, true)
	return out


static func run_one(host: Node, campaign: CampaignDef, index: int, full: bool) -> Dictionary:
	var lvl := campaign.levels[index]
	var m := MatchController.new()
	m.auto_process = false
	host.add_child(m)
	var mods := SIM.no_meta_modifiers(campaign, index)
	if full:
		mods.unlocks = UpgradeRules.Unlocks.everything()
		mods.start_currency_bonus = 50
		mods.base_hp_bonus = 3
		mods.early_bonus_multiplier = 1.25
	m.setup(lvl, 1, null, mods)
	var old_cp: bool = SIM.crosspath
	SIM.crosspath = full
	var bot: SimBot = SIM.make_bot(m, "heavy" if full else "balanced")
	SIM.crosspath = old_cp
	for k in range(int(MAX_SECONDS / DT)):
		if m.is_over():
			break
		bot.step(DT)
		m.step(DT)
	var towers: Array[String] = []
	for t in m.towers:
		towers.append("%s@%d,%d:%s" % [t.def.id, int(t.position.x), int(t.position.y), str(t.tiers)])
	towers.sort()
	var kills := 0
	var by: Dictionary = m.build_result()["kills_by_enemy"]
	for k in by:
		kills += int(by[k])
	var r := {"state": MatchController.State.keys()[m.state], "hp": m.base.hp, "leaked": m.base.damage_taken,
		"wave": m.waves.index, "time": "%.4f" % m.match_time, "money": m.economy.currency, "kills": kills,
		"towers": "|".join(towers).sha256_text().substr(0, 16), "tower_count": towers.size()}
	m.free()
	return r
