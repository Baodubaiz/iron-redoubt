extends SceneTree
## Dev tool: finds, per level, a difficulty factor d so the best bot strategy wins narrowly.
## d multiplies the level's difficulty knob (regular enemy counts; stats never change); multiply the chosen d
## into author_data.gd's DIFFICULTY table. Target: regular levels keep 10-30% Base HP,
## boss levels 8-25%. Bot = the 4 classic towers. Levels 1-20 no research, 21-40 full research.
##   godot --headless --path . -s res://tools/sim/difficulty_tuner.gd -- --levels=1,2,3
## Prints every attempt (TRY ...); the caller picks the factor.

const SIM := preload("res://tools/sim/campaign_sim.gd")
const DT := 1.0 / 60.0


func _initialize() -> void:
	var levels: Array[int] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			for s in a.substr(9).split(","):
				levels.append(int(s))
	var campaign: CampaignDef = load("res://data/campaign.tres")
	for n in levels:
		_tune(campaign, n)
	quit(0)


static func is_boss_level(l: LevelDef) -> bool:
	for w in l.waves:
		if w.is_boss:
			return true
	return false


func _tune(campaign: CampaignDef, n: int) -> void:
	var lvl: LevelDef = campaign.levels[n - 1]
	var boss := is_boss_level(lvl)
	var lo := 0.08 if boss else 0.10
	var hi := 0.25 if boss else 0.30
	var base := []
	for w in lvl.waves:
		var row := []
		for g in w.groups:
			row.append([g.count, g.hp_multiplier])
		base.append(row)
	var easy := 0.0 ## largest d known too easy
	var hard := 99.0 ## smallest d known too hard
	var d := 1.0
	for it in range(10):
		var r := _run(campaign, n, lvl, base, d)
		print("TRY %s pos%d d=%.3f best=%s hp=%d/%d" % [lvl.id, n, d, r[1], r[2], r[3]])
		var ratio: float = r[0]
		if ratio >= lo and ratio <= hi:
			break
		if ratio > hi:
			easy = maxf(easy, d)
		else:
			hard = minf(hard, d)
		if hard > 50.0:
			d *= 1.3
			if d > 6.0:
				break
		else:
			d = (easy + hard) * 0.5 if easy > 0.0 else d * 0.8
			if d < 0.3:
				break
	_apply(lvl, base, 1.0)


## Trial factor d on top of the level's stored difficulty (the game applies it at match start).
var _base_difficulty := {}


func _apply(lvl: LevelDef, _base: Array, d: float) -> void:
	if not _base_difficulty.has(lvl):
		_base_difficulty[lvl] = lvl.difficulty
	lvl.difficulty = float(_base_difficulty[lvl]) * d


## [best hp ratio (0 if both lost), best strategy, hp, max_hp]
func _run(campaign: CampaignDef, n: int, lvl: LevelDef, base: Array, d: float) -> Array:
	_apply(lvl, base, d)
	var meta := n > 20
	var best := [0.0, "-", 0, 0]
	for st in ["balanced", "heavy"]:
		var m := MatchController.new()
		m.auto_process = false
		root.add_child(m)
		var mods := SIM.no_meta_modifiers(campaign, n - 1)
		if meta:
			mods.unlocks = UpgradeRules.Unlocks.everything()
			mods.start_currency_bonus = 50
			mods.base_hp_bonus = 3
			mods.early_bonus_multiplier = 1.25
		m.setup(lvl, 1, null, mods)
		var old: bool = SIM.crosspath
		SIM.crosspath = meta
		var bot: SimBot = SIM.make_bot(m, st)
		SIM.crosspath = old
		for k in range(int(2400.0 / DT)):
			if m.is_over():
				break
			bot.step(DT)
			m.step(DT)
		if m.state == MatchController.State.WON:
			var r := float(m.base.hp) / float(m.base.max_hp)
			if r > float(best[0]):
				best = [r, st, m.base.hp, m.base.max_hp]
		m.free()
	return best
