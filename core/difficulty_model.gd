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
	var l := campaign.levels[index]
	var m := l.map
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
	return float(level_pressure(campaign, index)[0]) / k


const CROWD_CAP := 100 ## max enemies spawned in any 25 s window (phones)
static var _effective: Dictionary = {}


## Target share of enemies that gather in the level's final wave (50-60%).
## The head waves remain light and un-swarmed (authored baseline counts) so that
## difficulty is forced by the climactic last-wave gathering rather than crushing
## the player on early waves with 20-40 enemies.
const LAST_WAVE_SHARE_MIN := 0.50
const LAST_WAVE_SHARE_MAX := 0.60
const LAST_WAVE_SHARE := 0.55


## The level as it is played:
## 1. Head waves (first 30-35%) remain at authored counts (mult = 1.0) so players have room to build.
## 2. Mid waves smoothly scale up to build momentum.
## 3. The level's climax adds enough enemies that the final stretch holds 50-60% of the level's total,
##    but (2026-11-18, user: one giant last wave lagged) that extra is spread evenly over the last
##    waves in the second half of the level (SPREAD_FRACTION) instead of piling into the final one. A boss
##    wave keeps its authored escorts; its share goes to the waves before it. Added enemies keep the
##    authored spawn interval (the wave just lasts longer), so the screen never floods.
## Any wave with more than CROWD_CAP spawns in a 25 s window is spread out over time.
const BOSS_LEVEL_BONUS := 0.05 ## extra enemies on mid-chapter boss levels (5, 15, 25, 35)
const BOSS_LEVEL_BONUS_FINALE := 0.10 ## extra enemies on chapter-finale boss levels (10, 20, 30, 40)
const SPREAD_FRACTION := 0.5 ## share of the level's waves (the last ones) that split the climax


static func effective_level(l: LevelDef) -> LevelDef:
	if l == null:
		return l
	var d := l.difficulty
	var key := "%d|%.4f" % [l.get_instance_id(), d]
	if _effective.has(key):
		return _effective[key]
	var e: LevelDef = l.duplicate(false)
	var waves: Array[WaveDef] = []
	var n := l.waves.size()
	var prev_total := 0

	for wi in range(n):
		var w: WaveDef = l.waves[wi]
		var progress := float(wi) / float(maxi(n - 1, 1))
		# Head waves stay at 1.0x; mid waves scale gently up to 1.35x; the final wave keeps its authored counts
		# here and gets its share of the climax below.
		var mult := 1.0 if (progress <= 0.35 or wi == n - 1) else lerpf(1.0, 1.35, (progress - 0.35) / 0.65)
		var nw: WaveDef = w.duplicate(false)
		var groups: Array[SpawnGroupDef] = []
		for g in w.groups:
			var ng: SpawnGroupDef = g.duplicate(false)
			if not g.enemy.is_boss and absf(mult - 1.0) > 0.0001:
				ng.count = maxi(1, int(round(g.count * mult)))
			if wi < n - 1:
				prev_total += ng.count
			groups.append(ng)
		nw.groups = groups
		waves.append(nw)

	# Climax: same total as "final wave = share of the level", spread over the last few waves.
	if n > 1 and prev_total > 0:
		var raw_last := _non_boss_count(waves[n - 1])
		var share := clampf(LAST_WAVE_SHARE + (d - 1.0) * 0.02, LAST_WAVE_SHARE_MIN, LAST_WAVE_SHARE_MAX)
		var target_last_cnt := maxi(1, int(round(prev_total * (share / (1.0 - share)))))
		var extra := target_last_cnt - raw_last
		# Boss levels carry more (2026-11-18, user): +5% enemies on x5 boss levels, +10% on x0 chapter finales,
		# spread over the same second-half waves.
		if _has_boss(waves[n - 1]):
			var bonus := BOSS_LEVEL_BONUS_FINALE if l.level_number % 10 == 0 else BOSS_LEVEL_BONUS
			extra += int(round((prev_total + raw_last + maxi(extra, 0)) * bonus))
		if extra > 0:
			var targets: Array[int] = []
			var spread := maxi(1, int(ceil(n * SPREAD_FRACTION)))
			for wi in range(n - 1, n - 1 - spread, -1):
				if wi == n - 1 and _has_boss(waves[wi]):
					continue
				if _non_boss_count(waves[wi]) > 0:
					targets.append(wi)
			for i in range(targets.size()):
				var add := extra / targets.size() + (1 if i < extra % targets.size() else 0)
				_add_enemies(waves[targets[i]], add)

	for nw in waves:
		for _i in range(6): # overlapping groups: one stretch may not be enough, repeat until under the cap
			var peak := wave_peak(nw)
			if peak <= CROWD_CAP:
				break
			var stretch := float(peak) / CROWD_CAP
			for g in nw.groups:
				if not g.enemy.is_boss:
					g.interval *= stretch
					g.start_delay *= stretch

	e.waves = waves
	_effective[key] = e
	return e


static func _non_boss_count(w: WaveDef) -> int:
	var c := 0
	for g in w.groups:
		if not g.enemy.is_boss:
			c += g.count
	return c


static func _has_boss(w: WaveDef) -> bool:
	for g in w.groups:
		if g.enemy.is_boss:
			return true
	return false


## Grows a wave's non-boss groups proportionally by `add` enemies; spawn interval unchanged (wave lasts longer).
static func _add_enemies(w: WaveDef, add: int) -> void:
	var base := _non_boss_count(w)
	if add <= 0 or base <= 0:
		return
	var f := float(base + add) / float(base)
	for g in w.groups:
		if not g.enemy.is_boss:
			g.count = maxi(1, int(round(g.count * f)))


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
