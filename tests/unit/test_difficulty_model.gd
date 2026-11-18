extends TestCase
## Formula difficulty (DifficultyModel): no bots. Score 1.0 = narrow win, calibrated on the 40
## bot-verified levels. Guards new content: a level whose waves or enemies push it far outside the
## calibrated band fails here immediately.

const LOW := 0.4
const HIGH := 2.8 # level_01 scores 2.64 after the 5-10% HP tuning (formula overrates many weak Drones); the bot wins it


func test_every_level_stays_in_the_calibrated_band() -> void:
	var c: CampaignDef = load("res://data/campaign.tres")
	for i in range(c.levels.size()):
		var s := DifficultyModel.level_score(c, i)
		check(s >= LOW and s <= HIGH, "%s difficulty score %.2f within %.1f-%.1f (run tools/difficulty_report.gd)" % [
			c.levels[i].id, s, LOW, HIGH])


func test_score_follows_the_waves() -> void:
	var c: CampaignDef = load("res://data/campaign.tres")
	var i := 10
	var before := DifficultyModel.level_score(c, i)
	var l := c.levels[i]
	var w: WaveDef = l.waves[l.waves.size() - 1]
	var saved: Array = []
	for g in w.groups:
		saved.append(g.count)
		g.count *= 3
	DifficultyModel._effective.clear() # the effective (played) level is cached per level + difficulty
	var after := DifficultyModel.level_score(c, i)
	for k in range(w.groups.size()):
		w.groups[k].count = saved[k]
	DifficultyModel._effective.clear()
	check(after > before, "tripling the last wave raises the score (%.2f -> %.2f)" % [before, after])


func test_enemy_traits_raise_pressure() -> void:
	var drone := real_enemy("drone")
	var plated := real_enemy("plated")
	var shade := real_enemy("shade")
	check(DifficultyModel.enemy_pressure(plated) > DifficultyModel.enemy_pressure(drone), "armour counts")
	check(shade.threat_mult > 1.0, "special enemies declare a threat factor")
	var c: CampaignDef = load("res://data/campaign.tres")
	for l in c.levels:
		for w in l.waves:
			for g in w.groups:
				check(g.enemy.threat_mult >= 1.0, "%s threat factor set" % g.enemy.id)
