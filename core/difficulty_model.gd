class_name DifficultyModel
extends RefCounted
## Formula-based difficulty: how much enemy "pressure" a wave puts on the best defence the player can
## afford at that point. Independent of individual towers: the player's power is
## money x the best damage-per-credit any owned tower can reach, and every tower is capped by its rank
## (tests/unit/test_new_content.gd). So adding towers (as long as they respect their rank cap) or enemies
## (with a `threat_mult` in their data) keeps this valid without re-running bots.
##
##   enemy pressure  = (HP x armour factor + shield) x speed factor x threat_mult        (per enemy)
##   wave pressure   = sum over groups (count x enemy pressure)
##   player power    = money available before the wave x best DPS/credit owned x map coverage
##   level pressure  = max over waves (wave pressure / player power)
## Calibrated against the 40 bot-verified "narrow win" levels (tests/unit/test_difficulty_model.gd).

const REF_HIT := 30.0 ## typical hit used to value armour
const REF_SPEED := 60.0
const REF_COVERAGE := 500.0 ## px of lane one good tower covers on an average map
## Calibration (2026-11-13) on the 40 bot-verified narrow-win levels: score = peak pressure / (base x the
## factor of each map mechanic present). Score 1.0 = narrow win; the 40 levels sit within about 0.5-1.7.
const CALIBRATION := {"base": 11.274, "dual": 0.797, "night": 0.933, "gates": 0.756, "nodes": 1.134, "meta": 1.367}
const META_FROM := 20 ## campaign index from which the player is assumed to own the research

static var _coverage_cache: Dictionary = {}
static var _eff_cache: Dictionary = {}


static func enemy_pressure(e: EnemyDef, hp_mult: float = 1.0) -> float:
	var hp := e.max_hp * hp_mult
	var armor_f := REF_HIT / maxf(REF_HIT - e.armor, REF_HIT * 0.25)
	var shield := e.shield * (1.0 + e.shield_regen_rate / 100.0)
	var speed_f := pow(maxf(e.speed, 1.0) / REF_SPEED, 0.7)
	return (hp * armor_f + shield) * speed_f * e.threat_mult


static func wave_pressure(w: WaveDef) -> float:
	var p := 0.0
	for g in w.groups:
		if g.enemy != null:
			p += g.count * enemy_pressure(g.enemy, g.hp_multiplier)
	return p


static func wave_income(w: WaveDef, econ: EconomyConfig = null) -> int:
	var b := 0
	for g in w.groups:
		if g.enemy != null:
			var bounty := econ.kill_bounty(g.enemy.bounty) if econ != null else maxi(1, int(round(g.enemy.bounty * 0.90)))
			b += g.count * bounty
	return b


## Best single-target damage per second per credit this tower reaches (any branch, any tier).
static func tower_efficiency(def: TowerDef) -> float:
	if _eff_cache.has(def.id):
		return _eff_cache[def.id]
	var best := _eff(def, -1, 0, false)
	for b in range(def.branches.size()):
		for k in range(1, 4):
			best = maxf(best, _eff(def, b, k, false))
		best = maxf(best, _eff(def, b, 3, true))
	_eff_cache[def.id] = best
	return best


static func _eff(def: TowerDef, branch: int, tiers: int, evolved: bool) -> float:
	var t := Tower.new()
	t.setup(def, 1, 0)
	for i in range(tiers):
		t.add_tier(branch)
	t.evolved = evolved
	t.recompute()
	var cost := def.cost
	if branch >= 0:
		for i in range(tiers):
			cost += def.branches[branch].tiers[i].cost
		if evolved:
			cost += def.branches[branch].evolution.cost
	var dmg := t.pf("damage")
	var crit_every := int(t.pf("crit_every"))
	if crit_every > 0:
		dmg *= 1.0 + (maxf(t.pf("crit_mult"), 1.0) - 1.0) / crit_every
	var dps := dmg * t.pf("fire_rate") + t.pf("beam_dps") * maxf(t.pf("ramp_max"), 1.0)
	dps += t.pf("venom_dps") * maxf(t.pf("venom_stacks"), 1.0) + t.pf("trap_dps") + t.pf("burn_dps")
	t.free()
	return dps / maxf(cost, 1.0)


## Towers the player owns when starting campaign level `index` (no research): start + level unlocks.
static func owned_towers(campaign: CampaignDef, index: int) -> Array[TowerDef]:
	var ids: Array[StringName] = campaign.starting_towers.duplicate()
	for i in range(mini(index + 1, campaign.levels.size())):
		var l := campaign.levels[i]
		if l.unlock_tower_on_start != null and not ids.has(l.unlock_tower_on_start.id):
			ids.append(l.unlock_tower_on_start.id)
		if i < index and l.unlock_tower_on_clear != null and not ids.has(l.unlock_tower_on_clear.id):
			ids.append(l.unlock_tower_on_clear.id)
	var out: Array[TowerDef] = []
	for t in campaign.levels[index].available_towers:
		if ids.has(t.id):
			out.append(t)
	return out


## Lane length one well-placed tower covers (avg of the 20 best spots, per lane), relative to REF_COVERAGE.
static func map_coverage(m: MapDef) -> float:
	if _coverage_cache.has(m.id):
		return _coverage_cache[m.id]
	var rules := PlacementRules.new(m)
	var samples := PackedVector2Array()
	for r in m.routes:
		var rp := RoutePath.new(r)
		var d := 0.0
		while d <= rp.total_length:
			samples.append(rp.position_at(d, rp.segment_for(d, 0)))
			d += 12.0
	var scores: Array = []
	var y := 86.0
	while y < 700.0:
		var x := 22.0
		while x < 1138.0:
			var p := Vector2(x, y)
			if rules.validate(p, 22.0, []) == PlacementRules.Result.OK:
				var c := 0
				for s in samples:
					if s.distance_squared_to(p) <= 150.0 * 150.0:
						c += 1
				scores.append(c)
			x += 24.0
		y += 24.0
	scores.sort()
	scores.reverse()
	var avg := 0.0
	var n := mini(20, scores.size())
	for i in range(n):
		avg += scores[i]
	var cov := (avg / maxf(n, 1.0)) * 12.0 / maxf(m.routes.size(), 1.0) / REF_COVERAGE
	_coverage_cache[m.id] = cov
	return cov


## [peak pressure, pressure per wave] for a campaign level.
static func level_pressure(campaign: CampaignDef, index: int) -> Array:
	var l := effective_level(campaign.levels[index])
	var eff := 0.0
	for t in owned_towers(campaign, index):
		eff = maxf(eff, tower_efficiency(t))
	var cov := map_coverage(l.map)
	var econ := l.economy if l.economy != null else EconomyConfig.new()
	var money := float(econ.seed_money(l.starting_currency))
	var per_wave: Array = []
	var peak := 0.0
	for i in range(l.waves.size()):
		var w := l.waves[i]
		var p := wave_pressure(w) / maxf(money * eff * cov, 1.0)
		per_wave.append(p)
		peak = maxf(peak, p)
		money += wave_income(w, econ) + econ.wave_reward(i + 1)
	return [peak, per_wave]


## Calibrated difficulty score of a campaign level: 1.0 = narrow win (10-30% Base HP left).
static func level_score(campaign: CampaignDef, index: int) -> float:
	return float(level_pressure(campaign, index)[0]) / mechanic_k(campaign, index)


## Calibration divisor of a level: base x the factor of each map mechanic present (+ research from META_FROM).
static func mechanic_k(campaign: CampaignDef, index: int) -> float:
	var m := campaign.levels[index].map
	var k: float = CALIBRATION["base"]
	if m.routes.size() > 1 and not m.dynamic_routes:
		k *= CALIBRATION["dual"]
	if m.day_night:
		k *= CALIBRATION["night"]
	if m.dynamic_routes:
		k *= CALIBRATION["gates"]
	if m.range_bonus_zones.size() > 0:
		k *= CALIBRATION["nodes"]
	if index >= META_FROM:
		k *= CALIBRATION["meta"]
	return k


# ---------------------------------------------------------------- threat budget (tools/gen_waves.gd)
## Waves are planned as "which enemies + % of the level's peak" (tools/level_plan.gd). Threat is summed in
## Drones (enemy_threat). The level's PEAK = its last wave (2026-11-18, user): level 1 = 70, +50 every
## 5 levels up to level 40 (420), then +50 every 10 levels; earlier waves ramp up to it.
const PEAK_BASE := 70.0
const PEAK_STEP := 50.0
const PEAK_STEP_EVERY := 5
const PEAK_STEP_EVERY_LATE := 10
const PEAK_LATE_FROM := 40


static func level_peak_threat(level_number: int) -> float:
	var early := (mini(level_number, PEAK_LATE_FROM) - 1) / PEAK_STEP_EVERY
	var late := maxi(level_number - PEAK_LATE_FROM, 0) / PEAK_STEP_EVERY_LATE
	return PEAK_BASE + PEAK_STEP * float(early + late)


## Threat of one enemy in "Drones" (Drone = 1.0): HP, armor, shield, speed and its skill multiplier.
static func enemy_threat(e: EnemyDef, hp_mult: float = 1.0) -> float:
	var drone: EnemyDef = load("res://data/enemies/drone.tres")
	return enemy_pressure(e, hp_mult) / maxf(enemy_pressure(drone), 0.001)


## The level as it is played = the level as written (2026-11-18, user: no %-based rules at all; every wave is
## hand-authored in tools/level_waves.gd and spawns exactly as written). The old match-start rules
## (mid-wave ramp, last-wave share, boss-level bonus, special->regular swap, crowd-cap stretch) were baked
## into those lines once. Kept as a function so callers (match start, pressure analysis) stay unchanged.
static func effective_level(l: LevelDef) -> LevelDef:
	return l


## Most enemies spawned within any 25 s window of a wave (rough "on screen at once" estimate).
static func wave_peak(w: WaveDef) -> int:
	var times: Array = []
	for g in w.groups:
		for k in range(g.count):
			times.append(g.start_delay + k * g.interval)
	times.sort()
	var j := 0
	var peak := 0
	for i in range(times.size()):
		while times[j] < times[i] - 25.0:
			j += 1
		peak = maxi(peak, i - j + 1)
	return peak
