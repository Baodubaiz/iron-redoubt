extends TestCase
## Formula difficulty (DifficultyModel): no bots. Score 1.0 = narrow win, calibrated on the 40
## bot-verified levels. Guards new content: a level whose waves or enemies push it far outside the
## calibrated band fails here immediately.

## Threat-budget design (2026-11-18): each level's last wave = its peak threat (in Drones): level 1 = 70,
## +50 every 5 levels (DifficultyModel.level_peak_threat); waves come from tools/gen_waves.gd.
const PEAK_TOLERANCE := 0.15 # rounding to whole enemies (min 1 per group) + a fixed boss can overshoot


func _wave_threat(w: WaveDef) -> float:
	var t := 0.0
	for g in w.groups:
		t += g.count * DifficultyModel.enemy_threat(g.enemy, g.hp_multiplier)
	return t


func test_every_level_peaks_at_its_threat_budget() -> void:
	var c: CampaignDef = load("res://data/campaign.tres")
	for l in c.levels:
		var peak := DifficultyModel.level_peak_threat(l.level_number)
		var last := _wave_threat(l.waves[l.waves.size() - 1])
		check(absf(last - peak) <= peak * PEAK_TOLERANCE, "%s last wave threat %.0f ~ peak %.0f (run tools/gen_waves.gd)" % [
			l.id, last, peak])


func test_peak_threat_steps() -> void:
	eq(DifficultyModel.level_peak_threat(1), 70.0)
	eq(DifficultyModel.level_peak_threat(5), 70.0)
	eq(DifficultyModel.level_peak_threat(6), 120.0)
	eq(DifficultyModel.level_peak_threat(40), 420.0)
	eq(DifficultyModel.level_peak_threat(50), 470.0, "after 40: +50 every 10 levels")


func test_score_follows_the_waves() -> void:
	var c: CampaignDef = load("res://data/campaign.tres")
	var i := 10
	var before := DifficultyModel.level_score(c, i)
	var per_wave: Array = DifficultyModel.level_pressure(c, i)[1]
	var top := 0
	for k in range(per_wave.size()):
		if per_wave[k] > per_wave[top]:
			top = k
	var w: WaveDef = c.levels[i].waves[top]
	var saved: Array = []
	for g in w.groups:
		saved.append(g.count)
		g.count *= 3
	var after := DifficultyModel.level_score(c, i)
	for k in range(w.groups.size()):
		w.groups[k].count = saved[k]
	check(after > before, "tripling the hardest wave raises the score (%.2f -> %.2f)" % [before, after])


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


## 2026-11-21: every enemy waits for its earliest wave (level_plan.gd FIRST_WAVE), e.g. no Gliders in waves 1-2,
## no Vanguard before wave 5.
func test_enemies_respect_their_earliest_wave() -> void:
	var first: Dictionary = preload("res://tools/level_plan.gd").FIRST_WAVE
	eq(int(first.get("glider", 1)), 3, "Gliders from wave 3")
	var c: CampaignDef = load("res://data/campaign.tres")
	for l in c.levels:
		for wi in range(l.waves.size()):
			for g in l.waves[wi].groups:
				var need := int(first.get(String(g.enemy.id), 1))
				check(wi + 1 >= need, "%s wave %d: %s only from wave %d" % [l.id, wi + 1, g.enemy.id, need])
