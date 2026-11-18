extends SceneTree
## Dev tool: closed-loop difficulty tuning, one bot run per try (the campaign test's strategy, no search).
## Adjusts each level's difficulty knob (enemy counts only) until the bot wins with 5-10% Base HP left.
##   godot --headless --path . -s res://tools/sim/auto_tune.gd -- --levels=1,2,3 [--tries=5] [--max-step=0.45]
## The bot has a cliff (a few % more enemies can turn a comfortable win into a loss): use --max-step=0.04
## for a second, fine round.
## Prints TRY lines and one FINAL <level_id> <d> <WON|LOST> hp=<x>/<max> per level; copy d into
## author_data.gd's DIFFICULTY table.
const SIM := preload("res://tools/sim/campaign_sim.gd")
const TEST := preload("res://tests/integration/test_campaign_levels.gd")
const DT := 1.0 / 60.0
const LO := 0.05
const HI := 0.10


func _initialize() -> void:
	var levels: Array[int] = []
	var tries := 5
	var max_step := 0.45
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			for s in a.substr(9).split(","):
				levels.append(int(s))
		elif a.begins_with("--tries="):
			tries = int(a.substr(8))
		elif a.begins_with("--max-step="):
			max_step = float(a.substr(11))
	var c: CampaignDef = load("res://data/campaign.tres")
	for n in levels:
		_tune(c, n, tries, max_step)
	quit(0)


func _tune(c: CampaignDef, n: int, tries: int, max_step: float) -> void:
	var lvl := c.levels[n - 1]
	var d0 := lvl.difficulty
	var d := d0
	var won_d := -1.0 ## largest d known to win
	var lost_d := 99.0 ## smallest d known to lose
	var best := [-1.0, d0, false, 0, 0] ## [score, d, won, hp, max]
	for it in range(tries):
		var r := _run(c, n, lvl, d)
		var won: bool = r[0]
		var hp: int = r[1]
		var mx: int = r[2]
		var ratio := float(hp) / float(mx)
		print("TRY %s pos%d d=%.3f %s hp=%d/%d" % [lvl.id, n, d, "WON" if won else "LOST", hp, mx])
		var hi_hp := maxi(2, int(ceil(HI * mx)))
		var ok := won and hp >= 1 and hp <= hi_hp
		# score: in band best, then winning (fewer HP left better), losing worst
		var score := 3.0 if ok else (2.0 - ratio if won else 0.0)
		if score > float(best[0]):
			best = [score, d, won, hp, mx]
		if ok:
			break
		if won:
			won_d = maxf(won_d, d)
		else:
			lost_d = minf(lost_d, d)
		if lost_d < 50.0 and won_d > 0.0:
			d = (won_d + lost_d) * 0.5
		elif won:
			d *= 1.0 + clampf((ratio - 0.075) * 0.9, minf(0.04, max_step * 0.5), max_step)
		else:
			d *= 0.92
		d = snappedf(d, 0.001)
	lvl.difficulty = d0
	print("FINAL %s %.3f %s hp=%d/%d" % [lvl.id, best[1], "WON" if best[2] else "LOST", best[3], best[4]])


func _run(c: CampaignDef, n: int, lvl: LevelDef, d: float) -> Array:
	lvl.difficulty = d
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
	var res := [m.state == MatchController.State.WON, m.base.hp, m.base.max_hp]
	m.free()
	return res
