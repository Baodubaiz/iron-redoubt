extends SceneTree
## Dev tool: one fast bot run per level with the strategy the campaign test uses (no search).
##   godot --headless --path . -s res://tools/sim/quick_check.gd -- --levels=1,2,3
## Prints: CHECK <level_id> <position> <WON|LOST> hp=<x>/<max>
const SIM := preload("res://tools/sim/campaign_sim.gd")
const TEST := preload("res://tests/integration/test_campaign_levels.gd")
const DT := 1.0 / 60.0


func _initialize() -> void:
	var levels: Array[int] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			for s in a.substr(9).split(","):
				levels.append(int(s))
	var c: CampaignDef = load("res://data/campaign.tres")
	for n in levels:
		var lvl := c.levels[n - 1]
		var meta := n - 1 >= TEST.META_FROM
		var m := MatchController.new()
		m.auto_process = false
		root.add_child(m)
		var mods := SIM.no_meta_modifiers(c, n - 1)
		if meta:
			mods.unlocks = UpgradeRules.Unlocks.everything()
			mods.start_currency_bonus = 50
			mods.base_hp_bonus = 3
			mods.early_bonus_multiplier = 1.25
		m.setup(lvl, 1, null, mods)
		var old: bool = SIM.crosspath
		SIM.crosspath = meta
		var bot: SimBot = SIM.make_bot(m, TEST.WINNING[String(lvl.id)])
		SIM.crosspath = old
		for k in range(int(2400.0 / DT)):
			if m.is_over():
				break
			bot.step(DT)
			m.step(DT)
		print("CHECK %s %d %s hp=%d/%d" % [lvl.id, n, "WON" if m.state == MatchController.State.WON else "LOST", m.base.hp, m.base.max_hp])
		m.free()
	quit(0)
