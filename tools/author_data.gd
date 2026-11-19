extends SceneTree
## Authoring helper: (re)generates the .tres data files with correct Godot serialization.
## The generated .tres files are the canonical data; edit them in the editor or here and re-run:
##   godot --headless --path . -s res://tools/author_data.gd
## WARNING: re-running overwrites the listed files. All numbers are provisional (Phase 7 balancing).


func _initialize() -> void:
	_enemies()
	_towers()
	var econ_cfg := EconomyConfig.new()
	econ_cfg.kill_bounty_ratio = 0.90
	econ_cfg.seed_money_multiplier = 1.10
	_save(econ_cfg, "res://data/economy_default.tres")
	_maps()
	_levels()
	_meta()
	_catalogs()
	print("author_data: done")
	quit(0)


# ================================================================ enemies

func _enemies() -> void:
	var E := EnemyDef.Shape
	var C := EnemyDef.Category
	var drone := _enemy(&"drone", "Drone", C.BASIC, 60, 70, 0, 4, 1, 10, "8fb8ff", E.CIRCLE)
	# Demonstrates the new per-type armor system (2026-11-16): a machine, so poison (biological by
	# nature) barely works on it even though its base `armor` is 0 -- Venom should feel noticeably
	# weaker specifically against Drones, same base HP/armor otherwise.
	drone.armor_by_type = {"poison": 6.0}
	_save(drone, "res://data/enemies/drone.tres")
	_save(_enemy(&"dart", "Dart", C.BASIC, 35, 130, 0, 3, 1, 9, "ffe08f", E.ARROW), "res://data/enemies/dart.tres")
	var brute := _enemy(&"brute", "Brute", C.BASIC, 300, 45, 0, 12, 3, 16, "ff8f8f", E.HEAVY_CIRCLE)
	# Dense mass (2026-11-16): resists Plasma specifically, same per-type-armor idea as Drone/Poison
	# and Sludge/Energy, just going the other direction (a tanky brawler, not a support type).
	brute.armor_by_type = {"plasma": 8.0}
	# Reactive armor (2026-11-18, user: give Marksman a counter target without a new enemy): hits under
	# 30 raw damage deal 40%. Big single shots (Marksman, Lance Overcharge, Nova shells) are unaffected;
	# poison / burn / beams are continuous and never reduced.
	brute.reactive_threshold = 30.0
	brute.reactive_mult = 0.4
	_save(brute, "res://data/enemies/brute.tres")
	_save(_enemy(&"swarmling", "Swarmling", C.BASIC, 18, 90, 0, 1, 1, 5, "c9b8ff", E.DOT), "res://data/enemies/swarmling.tres")
	_save(_enemy(&"plated", "Plated", C.DEFENSIVE, 220, 55, 8, 14, 2, 13, "d9d9d9", E.BRACKET_SQUARE), "res://data/enemies/plated.tres")
	var aegis := _enemy(&"aegis", "Aegis", C.DEFENSIVE, 160, 60, 2, 15, 2, 13, "8fd3ff", E.PENTAGON)
	aegis.shield = 150
	aegis.shield_regen_delay = 3.0
	aegis.shield_regen_rate = 40.0
	_save(aegis, "res://data/enemies/aegis.tres")
	var glider := _enemy(&"glider", "Glider", C.SPECIAL, 90, 85, 0, 8, 2, 12, "9effc9", E.CHEVRON)
	glider.flying = true
	_save(glider, "res://data/enemies/glider.tres")
	var phantom := _enemy(&"phantom", "Phantom", C.SPECIAL, 110, 80, 0, 10, 2, 12, "e0a8ff", E.DASHED_TRIANGLE)
	phantom.stealth = true
	# Ghostly: partially phases through plain Kinetic hits (2026-11-16, user: a % damage-reduction
	# layer, separate from flat armor_by_type, countered by the tower's own %-damage bonuses rather
	# than armor_pen). 0 regular armor, so this is purely the new mechanic, not armor in disguise.
	phantom.resist_pct = {"kinetic": 0.3}
	_save(phantom, "res://data/enemies/phantom.tres")
	var mender := _enemy(&"mender", "Mender", C.SPECIAL, 180, 55, 1, 14, 2, 13, "6be08a", E.CROSS)
	mender.heal_amount = 30
	mender.heal_radius = 120
	mender.heal_interval = 2.5
	mender.heal_max_targets = 5
	mender.heal_boss_fraction = 0.01
	_save(mender, "res://data/enemies/mender.tres")
	# Buffed +20% HP / +15% damage, EMP a bit more frequent (2026-11-16, "boss yếu quá"). No new
	# skill here -- Monolith's summon+EMP+fracture kit is hardcoded in enemy_abilities.gd, not the
	# data-driven boss_skills rotation the other 7 bosses use, so adding one needs code, not data;
	# left for a follow-up rather than risking that bespoke path at this pass.
	var mono := _enemy(&"monolith", "Monolith", C.BOSS, 14400, 32 * BOSS_SPEED_MULT, 4, 250, 23, 28, "ff5c6c", E.HEXAGON)
	mono.is_boss = true
	mono.slow_cap = 0.25
	mono.summon_enemy = load("res://data/enemies/swarmling.tres")
	mono.summon_interval = 8.0
	mono.summon_count = 4
	mono.summon_telegraph = 1.5
	mono.emp_interval = 10.0
	mono.emp_radius = 170.0
	mono.emp_duration = 3.0
	mono.emp_telegraph = 2.0
	mono.fracture_speed_bonus = 0.3
	mono.shard_count = 3
	mono.shard_hp = 400
	mono.shard_armor = 2
	mono.shard_speed = 60
	mono.shard_base_damage = 3
	_save(mono, "res://data/enemies/monolith.tres")

	# Region bosses (one per region, never the same skills). Skills are data (BossSkillDef): see
	# EnemyAbilities for the action ids. A new boss = a new block like these, no code.
	var S := func(action: StringName, mn: int, mx: int, interval: float, tele: float, prm: Dictionary,
			pm: Dictionary = {}) -> BossSkillDef:
		var k := BossSkillDef.new()
		k.action = action
		k.min_phase = mn
		k.max_phase = mx
		k.interval = interval
		k.telegraph = tele
		k.params = prm
		k.phase_interval_mult = pm
		return k
	# Spread tower-debuffs across more regular enemies, not just Jammer+bosses (2026-11-16, user:
	# "quái ít hiệu ứng quá"). Reuses the boss-skill engine the same way escort/sludge/sprinter/
	# jammer/prismling/diver already do (single phase, smaller numbers than a real boss).
	aegis.boss_params = {"first_skill": 5.0}
	aegis.boss_skills = [S.call(&"jam", 1, 3, 11.0, 1.2, {"radius": 140.0, "duration": 2.5, "factor": 0.75})]
	_save(aegis, "res://data/enemies/aegis.tres") # re-save: the first _save() above already ran before S existed
	glider.boss_params = {"first_skill": 4.0}
	glider.boss_skills = [S.call(&"static", 1, 3, 10.0, 1.0, {"radius": 150.0, "duration": 3.0, "factor": 0.85})]
	_save(glider, "res://data/enemies/glider.tres")
	# Buffed +20% HP / +~15% damage (2026-11-16, user: "boss yếu quá") and a 3rd skill each, mostly
	# reusing another boss's existing skill kind rather than inventing new ones (keeps scope/risk
	# bounded) -- joins the phase 1-2 rotation here since Warden only has 2 phases.
	var warden := _boss(&"warden", "Warden", 2880, 34, 3, 120, 17, 22, "ffb84d", &"warden", 2, {"first_skill": 3.0})
	warden.boss_skills = [S.call(&"shell", 1, 3, 9.0, 1.2, {"fraction": 0.15, "duration": 5.0}),
		S.call(&"sprint", 2, 3, 6.0, 0.8, {"mult": 1.8, "duration": 2.5}),
		S.call(&"jam", 1, 3, 10.0, 1.3, {"radius": 150.0, "duration": 3.0, "factor": 0.65})]
	_save(warden, "res://data/enemies/warden.tres")
	var carrier := _boss(&"carrier", "Carrier", 5280, 30, 4, 200, 17, 26, "7fa8ff", &"carrier", 2, {"first_skill": 4.0})
	carrier.summon_enemy = load("res://data/enemies/glider.tres")
	carrier.boss_skills = [S.call(&"hangar", 1, 3, 9.0, 1.5, {"enemy": "res://data/enemies/glider.tres", "count": 3.0, "spacing": -18.0}),
		S.call(&"cloak", 2, 3, 7.0, 1.0, {"duration": 4.0, "radius": 120.0}),
		S.call(&"decoy", 1, 3, 10.0, 1.3, {"count": 2.0, "hp": 0.05})]
	_save(carrier, "res://data/enemies/carrier.tres")
	var chimera := _boss(&"chimera", "Chimera", 10200, 28, 4, 300, 23, 30, "c77dff", &"chimera", 3, {"first_skill": 6.0})
	chimera.shield_regen_delay = 2.0
	chimera.shield_regen_rate = 150.0
	chimera.boss_skills = [S.call(&"adapt", 1, 3, 8.0, 1.0, {"armor_bonus": 8.0, "shield_fraction": 0.12}, {3: 0.5}),
		S.call(&"jam", 2, 3, 7.0, 1.5, {"radius": 190.0, "duration": 4.0, "factor": 0.5}),
		S.call(&"effect_area", 3, 3, 8.0, 1.2, {"effect": "haste", "radius": 200.0, "duration": 4.0, "self": true})]
	_save(chimera, "res://data/enemies/chimera.tres")
	var colossus := _boss(&"colossus", "Colossus", 20400, 20, 8, 600, 58, 44, "ff5c6c", &"colossus", 3, {"first_skill": 5.0})
	colossus.boss_skills = [S.call(&"bulwark", 1, 2, 9.0, 1.2, {"radius": 220.0, "amount": 150.0, "duration": 6.0}),
		S.call(&"blink", 2, 3, 8.0, 1.8, {"distance": 160.0, "keep": 260.0}),
		S.call(&"capacitor", 3, 3, 8.0, 1.2, {"cap": 70.0, "duration": 5.0})]
	colossus.boss_passives = [{"kind": "overdrive", "min_phase": 3, "radius": 180.0, "haste": 0.3, "regen": 0.0015}]
	colossus.resist_pct = {"kinetic": 0.15} # a golem this size shrugs off plain bullets, on top of its armor
	_save(colossus, "res://data/enemies/colossus.tres")
	var dynamo := _boss(&"dynamo", "Dynamo", 5040, 32, 3, 200, 23, 30, "38d9f5", &"dynamo", 3, {"first_skill": 4.0})
	dynamo.boss_skills = [S.call(&"static", 1, 3, 8.0, 1.2, {"radius": 200.0, "duration": 5.0, "factor": 0.65}),
		S.call(&"capacitor", 2, 3, 7.0, 1.0, {"cap": 50.0, "duration": 4.0}),
		S.call(&"shell", 3, 3, 8.0, 1.2, {"fraction": 0.2, "duration": 5.0})]
	dynamo.boss_passives = [{"kind": "overload", "min_phase": 3, "mult": 1.35}]
	_save(dynamo, "res://data/enemies/dynamo.tres")
	var leviathan := _boss(&"leviathan", "Leviathan", 5760, 26, 4, 300, 29, 34, "4d8cff", &"leviathan", 3, {"first_skill": 4.0})
	leviathan.boss_skills = [S.call(&"submerge", 1, 3, 9.0, 1.0, {"duration": 2.5}, {3: 0.5}),
		S.call(&"revive", 2, 3, 7.0, 1.5, {"count": 3.0, "radius": 260.0, "window": 12.0}),
		S.call(&"bulwark", 3, 3, 8.0, 1.2, {"radius": 220.0, "amount": 120.0, "duration": 6.0})]
	leviathan.resist_pct = {"poison": 0.25} # aquatic: toxins dilute in the water around it
	_save(leviathan, "res://data/enemies/leviathan.tres")
	var refractor := _boss(&"refractor", "Refractor", 4320, 32, 2, 200, 17, 24, "a66bff", &"refractor", 2, {"first_skill": 3.0})
	refractor.boss_skills = [S.call(&"decoy", 1, 3, 9.0, 1.2, {"count": 2.0, "hp": 0.05}),
		S.call(&"prism", 2, 3, 6.0, 1.0, {"duration": 4.0}),
		S.call(&"adapt", 1, 3, 10.0, 1.2, {"armor_bonus": 5.0, "shield_fraction": 0.1})]
	_save(refractor, "res://data/enemies/refractor.tres")
	# Level-x0 bosses walk 30% slower than the level-x5 boss before them (2026-11-18, user): they are the
	# chapter finales with the biggest HP pools, so they get more time under fire.
	for pair in [[dynamo, warden], [leviathan, carrier], [mono, refractor], [colossus, chimera]]:
		(pair[0] as EnemyDef).speed = snappedf((pair[1] as EnemyDef).speed * 0.7, 0.1)
		_save(pair[0], "res://data/enemies/%s.tres" % (pair[0] as EnemyDef).id)

	# ---- 7 new regular enemies: special skills reuse the boss skill engine (one phase, small numbers).
	var C2 := EnemyDef.Category
	var SH := EnemyDef.Shape
	var escort := _enemy(&"escort", "Escort", C2.DEFENSIVE, 200, 55, 2, 12, 2, 13, "8fe0ff", SH.PENTAGON)
	escort.boss_params = {"first_skill": 3.0}
	escort.boss_skills = [S.call(&"bulwark", 1, 3, 8.0, 0.8, {"radius": 120.0, "amount": 50.0, "duration": 4.0})]
	escort.armor_by_type = {"poison": 5.0} # a drone escort, same idea as Drone
	_save(escort, "res://data/enemies/escort.tres")
	var sludge := _enemy(&"sludge", "Sludge", C2.DEFENSIVE, 360, 42, 0, 14, 2, 14, "9be07a", SH.HEAVY_CIRCLE)
	sludge.boss_params = {"first_skill": 1.0}
	sludge.boss_skills = [S.call(&"effect_area", 1, 3, 3.0, 0.2, {"effect": "sludge_regen", "on": "self", "radius": 1.0, "duration": 3.2})]
	# Goo doesn't conduct (2026-11-16): resists Energy specifically, demonstrating per-type armor
	# the other way round from Drone/Poison.
	sludge.armor_by_type = {"energy": 8.0}
	_save(sludge, "res://data/enemies/sludge.tres")
	var shade := _enemy(&"shade", "Shade", C2.SPECIAL, 80, 85, 0, 10, 2, 11, "b38cff", SH.CHEVRON)
	shade.flying = true
	shade.stealth = true
	shade.resist_pct = {"explosive": 0.2} # ghostly: blast mostly passes through it
	_save(shade, "res://data/enemies/shade.tres")
	var sprinter := _enemy(&"sprinter", "Sprinter", C2.BASIC, 130, 68, 0, 8, 1, 10, "ffd06b", SH.ARROW)
	sprinter.boss_params = {"first_skill": 2.5}
	sprinter.boss_skills = [S.call(&"sprint", 1, 3, 5.0, 0.5, {"mult": 2.0, "duration": 1.5})]
	_save(sprinter, "res://data/enemies/sprinter.tres")
	var jammer := _enemy(&"jammer", "Jammer", C2.SPECIAL, 260, 50, 3, 14, 2, 13, "ffaa45", SH.BRACKET_SQUARE)
	jammer.boss_params = {"first_skill": 4.0}
	jammer.boss_skills = [S.call(&"jam", 1, 3, 9.0, 1.2, {"radius": 130.0, "duration": 3.0, "factor": 0.6})]
	_save(jammer, "res://data/enemies/jammer.tres")
	var prismling := _enemy(&"prismling", "Prismling", C2.SPECIAL, 220, 60, 1, 12, 2, 12, "c7a6ff", SH.DASHED_TRIANGLE)
	prismling.boss_params = {"first_skill": 2.0}
	prismling.boss_skills = [S.call(&"prism", 1, 3, 5.0, 0.6, {"duration": 3.0})]
	_save(prismling, "res://data/enemies/prismling.tres")
	var diver := _enemy(&"diver", "Diver", C2.SPECIAL, 300, 60, 2, 14, 2, 13, "6fb7ff", SH.CHEVRON)
	diver.boss_params = {"first_skill": 3.0}
	diver.boss_skills = [S.call(&"submerge", 1, 3, 6.0, 0.8, {"duration": 1.5})]
	_save(diver, "res://data/enemies/diver.tres")

	# ---- 7 new skill enemies (2026-11-17): 3 tower-debuffers + 4 team-buffers.
	# All reuse the boss_skills engine (single-phase rotation, no new code needed).

	# -- Tower-debuff trio --
	# Disruptor: jams nearby towers (45% attack speed for 3.5 s).
	var disruptor := _enemy(&"disruptor", "Disruptor", C2.SPECIAL, 260, 50, 2, 18, 2, 13, "ff9f43", SH.BRACKET_SQUARE)
	disruptor.boss_params = {"first_skill": 5.0}
	disruptor.boss_skills = [S.call(&"jam", 1, 3, 7.0, 1.2, {"radius": 160.0, "duration": 3.5, "factor": 0.45})]
	disruptor.threat_mult = 1.5
	_save(disruptor, "res://data/enemies/disruptor.tres")

	# Static Crawler: heavy tank that shrinks tower range (40% loss for 4 s).
	var static_crawler := _enemy(&"static_crawler", "Static Crawler", C2.DEFENSIVE, 380, 38, 6, 22, 3, 16, "38d9f5", SH.HEAVY_CIRCLE)
	static_crawler.boss_params = {"first_skill": 6.0}
	static_crawler.boss_skills = [S.call(&"static", 1, 3, 9.0, 1.5, {"radius": 200.0, "duration": 4.0, "factor": 0.60})]
	static_crawler.threat_mult = 1.6
	_save(static_crawler, "res://data/enemies/static_crawler.tres")

	# Wraith: stealthy fast unit that bursts an EMP disabling nearby towers (1.5 s).
	var wraith := _enemy(&"wraith", "Wraith", C2.SPECIAL, 140, 90, 0, 16, 2, 11, "df9fff", SH.DASHED_TRIANGLE)
	wraith.stealth = true
	wraith.boss_params = {"first_skill": 7.0}
	wraith.boss_skills = [S.call(&"effect_area", 1, 3, 10.0, 0.8, {"effect": "emp", "on": "towers", "radius": 130.0, "duration": 1.5})]
	wraith.threat_mult = 1.8
	_save(wraith, "res://data/enemies/wraith.tres")

	# -- Team-buff quartet --
	# Vanguard: armored frontliner that overshields nearby allies (100 HP, 5 s).
	var vanguard := _enemy(&"vanguard", "Vanguard", C2.DEFENSIVE, 480, 42, 10, 28, 4, 17, "8fd3ff", SH.PENTAGON)
	vanguard.boss_params = {"first_skill": 5.0}
	vanguard.boss_skills = [S.call(&"bulwark", 1, 3, 10.0, 1.5, {"radius": 180.0, "amount": 100.0, "duration": 5.0})]
	vanguard.threat_mult = 1.7
	_save(vanguard, "res://data/enemies/vanguard.tres")

	# Rallier: fast runner that grants nearby allies a haste burst (+30% speed, 3 s).
	var rallier := _enemy(&"rallier", "Rallier", C2.SPECIAL, 200, 65, 1, 15, 2, 12, "ffe08f", SH.ARROW)
	rallier.boss_params = {"first_skill": 4.0}
	rallier.boss_skills = [S.call(&"effect_area", 1, 3, 8.0, 1.0, {"effect": "haste", "on": "allies", "radius": 150.0, "duration": 3.0})]
	rallier.threat_mult = 1.4
	_save(rallier, "res://data/enemies/rallier.tres")

	# Cloaker: cloaks itself and all allies in radius for 4 s.
	var cloaker := _enemy(&"cloaker", "Cloaker", C2.SPECIAL, 180, 60, 0, 20, 2, 12, "df9fff", SH.DASHED_TRIANGLE)
	cloaker.boss_params = {"first_skill": 5.0}
	cloaker.boss_skills = [S.call(&"cloak", 1, 3, 12.0, 1.2, {"radius": 140.0, "duration": 4.0})]
	cloaker.threat_mult = 1.9
	_save(cloaker, "res://data/enemies/cloaker.tres")

	# Mender Elite: heals allies in a burst (12% max HP, 160 px) + passive trickle.
	var mender_elite := _enemy(&"mender_elite", "Mender Elite", C2.SPECIAL, 250, 50, 2, 22, 2, 14, "4de6a1", SH.CROSS)
	mender_elite.heal_amount = 20
	mender_elite.heal_radius = 100
	mender_elite.heal_interval = 3.5
	mender_elite.heal_max_targets = 3
	mender_elite.heal_boss_fraction = 0.008
	mender_elite.boss_params = {"first_skill": 5.0}
	mender_elite.boss_skills = [S.call(&"heal_area", 1, 3, 6.0, 1.0, {"radius": 160.0, "frac": 0.12, "self": true})]
	mender_elite.threat_mult = 1.5
	_save(mender_elite, "res://data/enemies/mender_elite.tres")


## Every boss walks 25% slower (2026-11-18, user: bosses felt as fast as regular enemies, so they left
## range before towers could finish them). Applies to base speed; skill speed-ups scale off it.
const BOSS_SPEED_MULT := 0.75


func _boss(id: StringName, n: String, hp: float, spd: float, armor: float, bounty: int, dmg: int, radius: float,
		col: String, kit: StringName, phases: int, params: Dictionary) -> EnemyDef:
	var b := _enemy(id, n, EnemyDef.Category.BOSS, hp, spd * BOSS_SPEED_MULT, armor, bounty, dmg, radius, col, EnemyDef.Shape.HEXAGON)
	b.is_boss = true
	b.slow_cap = 0.25
	b.boss_kit = kit
	b.boss_phase_count = phases
	b.boss_params = params
	b.fracture_speed_bonus = 0.0
	b.shard_count = 0
	return b


# ================================================================ towers

func _towers() -> void:
	var pulse := _tower(&"pulse", "Pulse", "Cheap single-target DPS. Hits air. Weak vs armor.", 100, 12, Damage.Type.KINETIC,
		2.0, 150, 0, 650, true, true, TowerDef.TargetRule.FIRST, "4fd8ff", TowerDef.Shape.TRIANGLE)
	pulse.branches = [
		_branch(&"rapid", "Rapid", "Highest DPS, still weak vs armor.", false, [
			_tier("Rapid I", "Fire rate 2.6/s", 70, {"fire_rate": 2.6}),
			_tier("Rapid II", "Fire rate 3.4/s", 130, {"fire_rate": 3.4}),
			_tier("Rapid III", "Fire rate 4.5/s, damage 14", 240, {"fire_rate": 4.5, "damage": 14.0}),
		], _tier("Storm Array", "Every 20th shot fires a 6-shot burst at enemies in range", 400, {"burst_every": 20, "burst_count": 6})),
		_branch(&"penetrator", "Penetrator", "Heavy armor-piercing rounds, lower fire rate.", false, [
			_tier("Penetrator I", "Damage 20, armor pen 2", 70, {"damage": 20.0, "armor_pen": 2.0}),
			_tier("Penetrator II", "Damage 30, pen 4, rate 1.6/s", 130, {"damage": 30.0, "armor_pen": 4.0, "fire_rate": 1.6}),
			_tier("Penetrator III", "Damage 45, pen 6, range 180", 240, {"damage": 45.0, "armor_pen": 6.0, "attack_range": 180.0}),
		], _tier("Railspike", "Shots pierce up to 3 enemies in a line", 400, {"pierce": 3})),
		_branch(&"sensor", "Sensor", "Reveals stealth and marks targets for the team.", true, [
			_tier("Sensor I", "Reveals stealth within 90", 70, {"reveal_radius": 90.0}),
			_tier("Sensor II", "Hits Mark: +15% damage taken (3 s)", 130, {"mark": 0.15, "mark_duration": 3.0}),
			_tier("Sensor III", "Mark +25%, +50% damage vs air", 240, {"mark": 0.25, "air_damage_mult": 1.5}),
		], _tier("Hunter Net", "Marked fliers are Grounded for 3 s (ground towers can hit them)", 400, {"ground_marked_fliers": 3.0})),
	]
	pulse.rarity = &"C"
	_nerf_tower_damage(pulse)
	_remake_scale_tower(pulse)
	_save(pulse, "res://data/towers/pulse.tres")

	var nova := _tower(&"nova", "Nova", "Splash crowd control. Ground only. Splash hurts hidden stealth units.", 175, 30,
		Damage.Type.EXPLOSIVE, 0.6, 170, 55, 380, false, false, TowerDef.TargetRule.DENSEST, "ff9f43", TowerDef.Shape.SQUARE)
	nova.branches = [
		_branch(&"cluster", "Cluster", "Bigger blasts and bomblets. Flak at tier 3.", false, [
			_tier("Cluster I", "Splash radius 70", 120, {"splash_radius": 70.0}),
			_tier("Cluster II", "+3 bomblets (10 dmg each)", 230, {"bomblets": 3, "bomblet_damage": 10.0}),
			# Radius trimmed 85->75 (2026-11-15, user feedback: Nova "feels OP" even though its
			# single-target DPS/credit sits exactly at the B-rank cap test. The cap formula only
			# values damage against one target; Nova's real power is splash hitting many enemies at
			# once, which the cap can't see. This is the actual lever for Nova's strength, not base DPS.
			_tier("Cluster III", "Radius 75, damage 45, Flak: can target air", 420, {"splash_radius": 75.0, "damage": 45.0, "can_target_air": true}),
		], _tier("Cascade", "Every 4th shell detonates again after 0.5 s", 700, {"echo_every": 4, "echo_delay": 0.5})),
		_branch(&"incendiary", "Incendiary", "Burn ignores armor; burning enemies heal 50% less.", false, [
			_tier("Incendiary I", "Burn 6/s for 3 s (ignores armor)", 120, {"burn_dps": 6.0, "burn_duration": 3.0}),
			_tier("Incendiary II", "Burn 10/s", 230, {"burn_dps": 10.0}),
			_tier("Incendiary III", "Leaves a fire patch (2 s, radius 40)", 420, {"fire_patch_duration": 2.0, "fire_patch_radius": 40.0}),
		], _tier("Inferno", "Burning enemies explode on death (30 splash, no chain reactions)", 700, {"death_explosion": 30.0})),
		_branch(&"siege", "Siege", "Shreds armor, long range, staggers.", true, [
			_tier("Siege I", "Shred -2 armor per hit (stacks to -6)", 120, {"shred": 2.0, "shred_cap": 6.0}),
			_tier("Siege II", "Range 220", 230, {"attack_range": 220.0}),
			_tier("Siege III", "Damage 60, Stagger 0.3 s", 420, {"damage": 60.0, "stagger": 0.3}),
		], _tier("Quake", "Every 4th shell stuns ground enemies 0.8 s (bosses: slow)", 700, {"stun_every": 4, "stun_duration": 0.8})),
	]
	nova.rarity = &"B"
	_nerf_tower_damage(nova)
	_remake_scale_tower(nova)
	_save(nova, "res://data/towers/nova.tres")

	var lance := _tower(&"lance", "Lance", "Long-range armor-piercing energy. Targets the strongest. Energy x2 vs shields.", 225, 80,
		Damage.Type.ENERGY, 0.4, 240, 0, 1400, true, true, TowerDef.TargetRule.STRONGEST, "ff6bd6", TowerDef.Shape.DIAMOND)
	lance.armor_pen = 6
	lance.branches = [
		_branch(&"overcharge", "Overcharge", "Massive single hits. Overkill on small enemies.", false, [
			_tier("Overcharge I", "Damage 120", 160, {"damage": 120.0}),
			_tier("Overcharge II", "Damage 170, pen 8", 300, {"damage": 170.0, "armor_pen": 8.0}),
			_tier("Overcharge III", "Damage 240, +25% vs boss", 540, {"damage": 240.0, "boss_mult": 1.25}),
		], _tier("Annihilator", "Every 4th shot deals x3 damage", 900, {"crit_every": 4, "crit_mult": 3.0})),
		_branch(&"arc", "Arc", "Chains between enemies (60% damage per jump).", false, [
			_tier("Arc I", "Chains to 2 more enemies", 160, {"chain": 2, "chain_falloff": 0.6}),
			_tier("Arc II", "Chains to 3", 300, {"chain": 3}),
			_tier("Arc III", "Chains to 4, x3 vs shields; Conductive: +1 jump between Chilled", 540, {"chain": 4, "chain_shield_mult": 3.0, "conductive": true, "conductive_bonus": 1}),
		], _tier("Tesla Web", "Conductive +2 jumps; chain hits Stagger 0.4 s", 900, {"conductive_bonus": 2, "chain_stagger": 0.4})),
		_branch(&"focus", "Focus", "Continuous beam that ramps up on one target.", true, [
			_tier("Focus I", "Beam 40 dps, ramps to x3 over 3 s", 160, {"beam_dps": 40.0, "ramp_max": 3.0, "ramp_time": 3.0}),
			_tier("Focus II", "Range 280", 300, {"attack_range": 280.0}),
			_tier("Focus III", "Ramp up to x4", 540, {"ramp_max": 4.0}),
		], _tier("Phase Beam", "The beam pierces every enemy along its line", 900, {"beam_pierce": true})),
	]
	lance.rarity = &"A"
	_nerf_tower_damage(lance)
	_remake_scale_tower(lance)
	_save(lance, "res://data/towers/lance.tres")

	var beacon := _tower(&"beacon", "Beacon", "Support aura: reveals stealth; base aura slows 20%. No damage.", 150, 0,
		Damage.Type.KINETIC, 1.0, 130, 0, 0, true, true, TowerDef.TargetRule.NONE, "6be08a", TowerDef.Shape.CIRCLE)
	beacon.attack_mode = TowerDef.AttackMode.AURA
	beacon.base_params = {"slow": 0.2}
	beacon.branches = [
		_branch(&"amplifier", "Amplifier", "Buffs nearby towers (strongest Amplifier only). Slightly weaker slow.", false, [
			_tier("Amplifier I", "Nearby towers +10% damage (slow -5%)", 100, {"slow": 0.15, "amp_damage": 0.10}),
			_tier("Amplifier II", "+15% damage", 190, {"amp_damage": 0.15}),
			_tier("Amplifier III", "+20% damage, +10% range", 350, {"amp_damage": 0.20, "amp_range": 0.10}),
		], _tier("Overclock Core", "Also +15% attack rate", 600, {"amp_rate": 0.15})),
		_branch(&"cryo", "Cryo", "Stronger slow; periodic freeze.", false, [
			_tier("Cryo I", "Slow 30%", 100, {"slow": 0.3}),
			_tier("Cryo II", "Slow 40%", 190, {"slow": 0.4}),
			_tier("Cryo III", "Slow 50%; Freeze 1 s every 6 s (non-boss)", 350, {"slow": 0.5, "freeze_every": 6.0, "freeze_duration": 1.0}),
		], _tier("Absolute Zero", "Frozen enemies take +50% explosive damage (Shatter)", 600, {"shatter": 0.5})),
		_branch(&"relay", "Relay", "Economy. Diminishing returns per extra Relay. Slightly weaker slow.", true, [
			_tier("Relay I", "+10 per cleared wave (slow -5%)", 100, {"slow": 0.15, "wave_income": 10.0}),
			_tier("Relay II", "+16 per wave, aura 160", 190, {"wave_income": 16.0, "attack_range": 160.0}),
			_tier("Relay III", "+24 per wave; kills in aura +1", 350, {"wave_income": 24.0, "bounty_bonus": 1}),
		], _tier("Mint", "+4 every 10 s during waves", 600, {"mint_amount": 4, "mint_interval": 10.0})),
	]
	beacon.rarity = &"B"
	_nerf_tower_damage(beacon)
	_remake_scale_tower(beacon)
	_save(beacon, "res://data/towers/beacon.tres")

	# ---- 4 new towers. Power rule: never above the strongest existing tower of the same rank
	# (C <= Pulse, B <= Nova/Beacon, A <= Lance) at base, tier 3 or evolution; S/SS keep the headroom.
	# trap_* / venom_* / field_* params build their effect at runtime (MatchController._param_effect).
	var trap := _tower(&"trap", "Shock Trap", "Lobs shock traps onto the lane: enemies on them are slowed and zapped. Ground only.", 90, 6,
		Damage.Type.EXPLOSIVE, 0.5, 150, 30, 360, false, false, TowerDef.TargetRule.FIRST, "ffd84d", TowerDef.Shape.SQUARE)
	trap.rarity = &"C"
	trap.base_params = {"trap_duration": 2.0, "trap_radius": 34.0, "trap_slow_pct": 0.40, "trap_dps": 3.0}
	trap.branches = [
		# Slow trimmed 45/55/65%->40/45/50% (2026-11-16, user: new multi-source slow stacking should
		# reward combining towers, not let one maxed Trap alone approach the old single-source cap).
		_branch(&"snare", "Snare", "Stronger, longer-lasting slow.", false, [
			_tier("Snare I", "Slow 45%", 60, {"trap_slow_pct": 0.45}),
			_tier("Snare II", "Traps last 3 s", 110, {"trap_duration": 3.0}),
			_tier("Snare III", "Slow 50%", 200, {"trap_slow_pct": 0.50}),
		], _tier("Stasis Net", "Traps hold enemies in place (bosses only slowed)", 340, {"trap_stop": true})),
		_branch(&"livewire", "Live Wire", "Traps zap harder.", false, [
			_tier("Live Wire I", "Trap damage 6/s", 60, {"trap_dps": 6.0}),
			_tier("Live Wire II", "Trap damage 9/s", 110, {"trap_dps": 9.0}),
			_tier("Live Wire III", "Trap damage 13/s, shell damage 14", 200, {"trap_dps": 13.0, "damage": 14.0}),
		], _tier("Arc Mine", "Trap damage 18/s; zapped enemies take +10% damage", 340, {"trap_dps": 18.0, "trap_vuln": 1.1})),
		_branch(&"minefield", "Minefield", "Bigger traps, thrown more often.", true, [
			_tier("Minefield I", "Trap radius 42", 60, {"trap_radius": 42.0}),
			_tier("Minefield II", "Fire rate 0.7/s", 110, {"fire_rate": 0.7}),
			_tier("Minefield III", "Trap radius 50", 200, {"trap_radius": 50.0}),
		], _tier("Carpet", "Fire rate 1/s", 340, {"fire_rate": 1.0})),
	]
	_nerf_tower_damage(trap)
	_remake_scale_tower(trap)
	_save(trap, "res://data/towers/trap.tres")

	# Buffed (2026-11-15, user feedback: "Nova makes Venom pointless"): fire_rate 1.2->1.5 stacks
	# poison faster (full stacks in ~2.2s instead of ~3.5s) and raises its DPS/credit from ~90% to
	# ~99% of the B-rank cap.
	# Default targeting STRONGEST, not FIRST (2026-11-15, user feedback: pick the mode that makes the
	# most of Venom's niche): poison's value is armor-ignore + sustained DPS, which is wasted on weak
	# fodder any tower one-shots anyway. The player can still switch targeting for free at any time
	# (tower_panel.gd), this is only the default a freshly built Venom starts on.
	# Nerfed (2026-11-15, user feedback: "độc hơi bá" -- multi-target + air + armor shred + anti-tank
	# all at once, no real weakness left). Removed the always-on venom_armor base bonus added earlier:
	# armor shred is now ONLY from the Corrosion branch again (an investment, not free on every Venom),
	# on top of poison's own innate armor-ignore (which was never the thing being nerfed here).
	# Direct-hit damage_type KINETIC->POISON (2026-11-16): Venom's own tiny poke was never typed as
	# its namesake damage before now; "pure poison" tower, consistent with its DoT ticks below.
	var venom := _tower(&"venom", "Venom", "Stacking poison that ignores armor. Slow to kill, great against tough or regenerating enemies.", 160, 5,
		Damage.Type.POISON, 1.5, 160, 0, 520, true, true, TowerDef.TargetRule.STRONGEST, "8be36a", TowerDef.Shape.CIRCLE)
	venom.rarity = &"B"
	venom.base_params = {"venom_dps": 2.2, "venom_stacks": 4, "venom_duration": 4.0}
	venom.branches = [
		_branch(&"potency", "Potency", "Stronger poison.", false, [
			_tier("Potency I", "Poison 3.2/s per stack", 100, {"venom_dps": 3.2}),
			_tier("Potency II", "Poison 4/s per stack", 190, {"venom_dps": 4.0}),
			_tier("Potency III", "Poison 5/s per stack", 340, {"venom_dps": 5.0}),
		], _tier("Neurotoxin", "Up to 6 stacks; poisoned enemies are slowed 15%", 560, {"venom_stacks": 6, "venom_slow_pct": 0.15})),
		_branch(&"corrosion", "Corrosion", "Poison eats armor.", false, [
			_tier("Corrosion I", "-0.5 armor per stack", 100, {"venom_armor": 0.5}),
			_tier("Corrosion II", "-1 armor per stack", 190, {"venom_armor": 1.0}),
			_tier("Corrosion III", "-1.5 armor per stack", 340, {"venom_armor": 1.5}),
		], _tier("Acid Bath", "Each stack: +3% damage taken", 560, {"venom_vuln": 1.03})),
		# Reworked from an instant splash to a lingering cloud (2026-11-15, user feedback: wanted
		# Venom's AoE to feel different from Nova's instant burst). Every shot leaves a poison cloud at
		# the impact point; any enemy standing in it stacks poison at the tower's own pace (1/fire_rate
		# per enemy, applied in MatchController._step_zones), not faster just because more stand in it.
		# Radii trimmed 30/40/50->22/28/36 (same day, "độc hơi bá" follow-up): combined with Venom's
		# already-high sustained DPS and armor-ignore, full-size radii made it a multi-target AND
		# anti-tank tower with no real weakness. Smaller cloud still rewards grouped enemies without
		# matching a dedicated AoE tower's coverage.
		_branch(&"spray", "Spray", "Shots leave a lingering poison cloud instead of hitting one target.", true, [
			_tier("Spray I", "Cloud radius 22, lasts 3 s", 100, {"venom_patch_radius": 22.0, "venom_patch_duration": 3.0}),
			_tier("Spray II", "Cloud radius 28, lasts 4 s", 190, {"venom_patch_radius": 28.0, "venom_patch_duration": 4.0}),
			_tier("Spray III", "Cloud radius 36, lasts 5 s", 340, {"venom_patch_radius": 36.0, "venom_patch_duration": 5.0}),
		], _tier("Plague Cloud", "Fire rate 1.6/s", 560, {"fire_rate": 1.6})),
	]
	_remake_scale_tower(venom)
	_save(venom, "res://data/towers/venom.tres")

	# Spotter (C, support): weak shots that mark enemies; marked enemies take more damage from every tower.
	# Damage type ENERGY->PLASMA (2026-11-16): Spotter's own hits are weak either way (it's a mark
	# support tool, not a damage dealer), so this is a low-risk way to give Plasma -- "skips shields
	# entirely" -- a real, testable tower instead of sitting unused in the catalog.
	var spotter := _tower(&"spotter", "Marker", "Support. Weak shots explode on impact (AOE 60) and mark all enemies hit: marked enemies take +8% damage from every tower. Hits air. Shots skip shields entirely (Plasma).", 90, 4,
		Damage.Type.PLASMA, 1.0, 170, 60, 620, true, true, TowerDef.TargetRule.FIRST, "ff7a9a", TowerDef.Shape.TRIANGLE)
	# splash 0 -> 60 (2026-11-18, user): the description always promised an AOE-60 burst that marks every
	# enemy hit, but the data had no splash, so it marked one target at a time.
	spotter.rarity = &"C"
	# Buff (2026-11-18, user), kept within rank C: max mark 14% stays under Chronos (S, field up to 16%)
	# and Beacon (B, +20% amp); Beacon stays the main stealth counter (Tracer reveal is only 2 s).
	spotter.base_params = {"spot_vuln": 1.08, "spot_duration": 4.0} # 8% = rank-C cap (test_new_content)
	spotter.branches = [
		_branch(&"lockon", "Lock-On", "Stronger marks.", false, [
			_tier("Lock-On I", "Mark +11% damage taken", 60, {"spot_vuln": 1.11}),
			_tier("Lock-On II", "Mark +12% damage taken", 110, {"spot_vuln": 1.12}),
			_tier("Lock-On III", "Mark +14% damage taken", 200, {"spot_vuln": 1.14}),
		], _tier("Kill Mark", "Marked enemies also lose 2 armor", 340, {"spot_armor": 2.0})),
		_branch(&"tracer", "Tracer", "Hunts special enemies.", false, [
			_tier("Tracer I", "+30% damage vs stealth", 60, {"tag_mult": {"stealth": 1.3}}),
			_tier("Tracer II", "+20% damage vs flying", 110, {"tag_mult": {"stealth": 1.3, "flying": 1.2}}),
			_tier("Tracer III", "Blasts reveal stealth for 2 s", 200, {"spot_reveal": 2.0}),
		], _tier("Lead Mark", "Marked enemies are slowed 15%", 340, {"spot_slow_pct": 0.15})),
		_branch(&"widescan", "Wide Scan", "Marks more enemies.", true, [
			_tier("Wide Scan I", "Fire rate 1.4/s", 60, {"fire_rate": 1.4}),
			_tier("Wide Scan II", "Fire rate 1.8/s", 110, {"fire_rate": 1.8}),
			_tier("Wide Scan III", "Range 200", 200, {"attack_range": 200.0}),
		], _tier("Piercing Beam", "Shots pierce up to 3 enemies in a line", 340, {"pierce": 3})),
	]
	_nerf_tower_damage(spotter)
	_remake_scale_tower(spotter)
	_save(spotter, "res://data/towers/spotter.tres")

	var sniper := _tower(&"sniper", "Marksman", "Very long range, slow and heavy shots. Bonus damage against bosses.", 260, 120,
		Damage.Type.KINETIC, 0.25, 330, 0, 1600, true, true, TowerDef.TargetRule.STRONGEST, "ff6b8a", TowerDef.Shape.DIAMOND)
	sniper.rarity = &"A"
	sniper.armor_pen = 4
	sniper.base_params = {"tag_mult": {"boss": 1.2}}
	sniper.branches = [
		_branch(&"deadeye", "Deadeye", "Critical hits.", false, [
			_tier("Deadeye I", "Every 4th shot x2", 170, {"crit_every": 4, "crit_mult": 2.0}),
			_tier("Deadeye II", "Every 3rd shot x2", 320, {"crit_every": 3}),
			_tier("Deadeye III", "Crits x2.5", 560, {"crit_mult": 2.5}),
		], _tier("Executioner", "Every 2nd shot is a crit", 900, {"crit_every": 2})),
		_branch(&"penetrator", "Penetrator", "Rounds pass through enemies.", false, [
			_tier("Penetrator I", "Pierces 2 enemies, pen 6", 170, {"pierce": 2, "armor_pen": 6.0}),
			_tier("Penetrator II", "Pierces 3", 320, {"pierce": 3}),
			_tier("Penetrator III", "Damage 150", 560, {"damage": 150.0}),
		], _tier("Railgun", "Pierces 5, pen 10", 900, {"pierce": 5, "armor_pen": 10.0})),
		_branch(&"spotter", "Spotter", "Marks targets for the team.", true, [
			_tier("Spotter I", "Hits Mark: +10% damage taken (4 s)", 170, {"mark": 0.10, "mark_duration": 4.0}),
			_tier("Spotter II", "Reveals stealth within 120", 320, {"reveal_radius": 120.0}),
			_tier("Spotter III", "Mark +15%", 560, {"mark": 0.15}),
		], _tier("Overwatch", "Range 420", 900, {"attack_range": 420.0})),
	]
	_nerf_tower_damage(sniper)
	_remake_scale_tower(sniper)
	_save(sniper, "res://data/towers/sniper.tres")

	var bastion := _tower(&"bastion", "Bastion", "Field generator: towers inside are immune to EMP, jamming and other tower debuffs. No attack.", 240, 0,
		Damage.Type.KINETIC, 1.0, 140, 0, 0, true, true, TowerDef.TargetRule.NONE, "7fb2ff", TowerDef.Shape.CIRCLE)
	bastion.rarity = &"A"
	bastion.attack_mode = TowerDef.AttackMode.AURA
	bastion.base_params = {"field": true}
	bastion.branches = [
		_branch(&"expanse", "Expanse", "A wider field.", false, [
			_tier("Expanse I", "Field 170", 140, {"attack_range": 170.0}),
			_tier("Expanse II", "Field 200", 260, {"attack_range": 200.0}),
			_tier("Expanse III", "Field 230", 460, {"attack_range": 230.0}),
		], _tier("Citadel", "Field 280", 760, {"attack_range": 280.0})),
		_branch(&"gravity", "Gravity", "Enemies inside the field are slowed.", false, [
			_tier("Gravity I", "Slow 10% in the field", 140, {"field_slow_pct": 0.10}),
			_tier("Gravity II", "Slow 15%", 260, {"field_slow_pct": 0.15}),
			_tier("Gravity III", "Slow 20%", 460, {"field_slow_pct": 0.20}),
		], _tier("Gravity Well", "Slow 30%", 760, {"field_slow_pct": 0.30})),
		_branch(&"exposure", "Exposure", "Enemies inside the field take more damage.", true, [
			_tier("Exposure I", "+5% damage taken in the field", 140, {"field_vuln": 1.05}),
			_tier("Exposure II", "+8%", 260, {"field_vuln": 1.08}),
			_tier("Exposure III", "+12%", 460, {"field_vuln": 1.12}),
		], _tier("Overexposure", "+16%", 760, {"field_vuln": 1.16})),
	]
	_nerf_tower_damage(bastion)
	_remake_scale_tower(bastion)
	_save(bastion, "res://data/towers/bastion.tres")

	# ---- Rank S (not unlockable yet: listed in the Codex only). Rule: stronger than every A tower, but at most
	# ~1.5x the A cap on a single target, leaving the top tier for SS.
	var storm := _tower(&"storm", "Stormcaller", "Chain lightning: every shot jumps to 3 more enemies. Every 5th shot is a x2.3 critical. Chained enemies stagger briefly.", 420, 58,
		Damage.Type.ENERGY, 1.0, 220, 0, 1400, true, true, TowerDef.TargetRule.FIRST, "ff5ce1", TowerDef.Shape.DIAMOND)
	storm.rarity = &"S"
	# Nerfed (2026-11-14, user feedback: "OP"): chain_falloff 0.7->0.65, crit 4/x2.5->5/x2.3,
	# chain_stagger 0.3->0.15 (half the free CC, which the DPS/cost formula below never priced in
	# — chain-wide stagger on every hit was a big part of the real-match power, not just raw damage),
	# damage 60->58, cost 400->420. Brings its base power from ~1.32x the A-rank cap to ~1.03x.
	storm.base_params = {"chain": 3, "chain_falloff": 0.65, "crit_every": 5, "crit_mult": 2.3, "chain_stagger": 0.15}
	storm.branches = [
		_branch(&"tempest", "Tempest", "Lightning jumps further.", false, [
			_tier("Tempest I", "Chains to 4", 220, {"chain": 4}),
			_tier("Tempest II", "Chain damage 75% per jump", 400, {"chain_falloff": 0.75}),
			_tier("Tempest III", "Chains to 5", 700, {"chain": 5}),
		], _tier("Thunderhead", "Chains to 6", 1100, {"chain": 6})),
		_branch(&"overload", "Overload", "Heavier critical strikes.", false, [
			_tier("Overload I", "Damage 75", 220, {"damage": 75.0}),
			_tier("Overload II", "Every 3rd shot is a crit", 400, {"crit_every": 3}),
			_tier("Overload III", "Crits x3", 700, {"crit_mult": 3.0}),
		], _tier("Superconductor", "Every 2nd shot is a crit", 1100, {"crit_every": 2})),
		_branch(&"ion", "Ion", "Breaks shields and exposes enemies.", false, [
			_tier("Ion I", "Chains x2 vs shields", 220, {"chain_shield_mult": 2.0}),
			_tier("Ion II", "Hits Mark: +10% damage taken (3 s)", 400, {"mark": 0.10, "mark_duration": 3.0}),
			_tier("Ion III", "Conductive: +1 jump between chilled enemies", 700, {"conductive": true, "conductive_bonus": 1}),
		], _tier("Ion Storm", "Conductive +2 jumps, Mark +15%", 1100, {"conductive_bonus": 2, "mark": 0.15})),
	]
	_nerf_tower_damage(storm)
	_remake_scale_tower(storm)
	_save(storm, "res://data/towers/storm.tres")

	var chronos := _tower(&"chronos", "Chronos", "Time field: enemies inside are slowed 30% and take +6% damage; towers inside are immune to EMP and debuffs and fire 7% faster. Every 8 s it freezes regular enemies for 1 s.", 380, 0,
		Damage.Type.KINETIC, 1.0, 170, 0, 0, true, true, TowerDef.TargetRule.NONE, "5cffd8", TowerDef.Shape.CIRCLE)
	chronos.rarity = &"S"
	chronos.attack_mode = TowerDef.AttackMode.AURA
	# field_vuln / amp_rate stack multiplicatively across every tower standing in the field, so each
	# point is worth more than it looks (3-4 towers inside = the buff applies 3-4x over). Kept well below
	# Storm's single-tower 1.3x-A-cap benchmark for that reason.
	chronos.base_params = {"field": true, "field_slow_pct": 0.30, "field_vuln": 1.06, "amp_rate": 0.07,
		"freeze_every": 8.0, "freeze_duration": 1.0}
	chronos.branches = [
		_branch(&"expanse", "Expanse", "A wider time field.", false, [
			_tier("Expanse I", "Field 200", 200, {"attack_range": 200.0}),
			_tier("Expanse II", "Field 230", 380, {"attack_range": 230.0}),
			_tier("Expanse III", "Field 260", 650, {"attack_range": 260.0}),
		], _tier("Eternity", "Field 300", 1000, {"attack_range": 300.0})),
		_branch(&"stasis", "Stasis", "Freezes more often and for longer.", false, [
			_tier("Stasis I", "Freeze every 6.5 s", 200, {"freeze_every": 6.5}),
			_tier("Stasis II", "Freeze 1.3 s", 380, {"freeze_duration": 1.3}),
			_tier("Stasis III", "Freeze every 5 s", 650, {"freeze_every": 5.0}),
		], _tier("Time Lock", "Freeze 2 s", 1000, {"freeze_duration": 2.0})),
		_branch(&"haste", "Acceleration", "Towers in the field fire faster.", false, [
			_tier("Acceleration I", "Towers +10% fire rate", 200, {"amp_rate": 0.10}),
			_tier("Acceleration II", "Towers +12%", 380, {"amp_rate": 0.12}),
			_tier("Acceleration III", "Towers +14%", 650, {"amp_rate": 0.14}),
		], _tier("Overclock Field", "Towers +18%", 1000, {"amp_rate": 0.18})),
	]
	_nerf_tower_damage(chronos)
	_remake_scale_tower(chronos)
	_save(chronos, "res://data/towers/chronos.tres")


# ================================================================ maps & levels

func _maps() -> void:
	var circuit := MapDef.new()
	circuit.id = &"circuit"
	circuit.display_name = "Circuit"
	circuit.routes = [PackedVector2Array([
		Vector2(-40, 150), Vector2(1000, 150), Vector2(1000, 330), Vector2(200, 330),
		Vector2(200, 520), Vector2(1060, 520), Vector2(1060, 655)])]
	circuit.region = &"circuit"
	var circuit_air := _from_farthest_corner(PackedVector2Array([Vector2(-40, 240), Vector2(1100, 240), Vector2(1100, 600), Vector2(1060, 655)]))
	circuit.air_routes = [_lengthen_air_static(circuit_air, _air_factor(circuit.routes, circuit_air), _centroid(circuit.routes))]
	circuit.blocked_rects = [Rect2(420, 200, 80, 80), Rect2(600, 385, 90, 90)]
	circuit.range_bonus_zones = PackedVector3Array([Vector3(760, 240, 38), Vector3(420, 425, 38), Vector3(640, 615, 38)])
	_save(circuit, "res://data/maps/circuit.tres")

	var delta := MapDef.new()
	delta.id = &"delta"
	delta.display_name = "Delta"
	var tail := [Vector2(420, 380), Vector2(720, 380), Vector2(720, 560), Vector2(980, 560), Vector2(980, 230),
		Vector2(1100, 230), Vector2(1100, 655)]
	var ra := PackedVector2Array([Vector2(-40, 150), Vector2(420, 150)])
	var rb := PackedVector2Array([Vector2(-40, 665), Vector2(420, 665)])
	for p in tail:
		ra.append(p)
		rb.append(p)
	delta.routes = [ra, rb]
	var delta_air := _from_farthest_corner(PackedVector2Array([Vector2(-40, 300), Vector2(600, 300), Vector2(860, 460), Vector2(1100, 655)]))
	delta.air_routes = [_lengthen_air_static(delta_air, _air_factor(delta.routes, delta_air), _centroid(delta.routes))]
	delta.blocked_rects = [Rect2(180, 250, 90, 70), Rect2(800, 260, 100, 110), Rect2(520, 470, 90, 80)]
	delta.day_night = true
	delta.region = &"delta"
	delta.background_color = Color("0d1014")
	_save(delta, "res://data/maps/delta.tres")

	var prism := MapDef.new()
	prism.id = &"prism"
	prism.display_name = "Prism"
	prism.routes = [
		PackedVector2Array([Vector2(-40, 360), Vector2(260, 360), Vector2(260, 140), Vector2(900, 140),
			Vector2(900, 360), Vector2(1080, 360), Vector2(1080, 655)]),
		PackedVector2Array([Vector2(-40, 360), Vector2(260, 360), Vector2(260, 580), Vector2(900, 580),
			Vector2(900, 360), Vector2(1080, 360), Vector2(1080, 655)]),
	]
	var prism_air := _from_farthest_corner(PackedVector2Array([Vector2(-40, 690), Vector2(560, 690), Vector2(700, 470), Vector2(1000, 470), Vector2(1080, 655)]))
	prism.air_routes = [_lengthen_air_static(prism_air, _air_factor(prism.routes, prism_air), _centroid(prism.routes))]
	prism.blocked_rects = [Rect2(530, 310, 100, 100), Rect2(60, 160, 120, 90)]
	prism.dynamic_routes = true
	prism.region = &"prism"
	prism.background_color = Color("0f0e15")
	_save(prism, "res://data/maps/prism.tres")

	# ---- one distinct map per level (Reforged content update). Each keeps its region's mechanic.
	# Circuit: single lane + overload nodes
	_save(_map(&"circuit_b", "Circuit — Turbine Hall", &"circuit",
		[[[160, -40], [160, 580], [500, 580], [500, 190], [840, 190], [840, 580], [1060, 580], [1060, 380]]],
		[[[-40, 400], [600, 420], [1060, 380]]],
		[Rect2(290, 120, 80, 80), Rect2(620, 440, 90, 80)],
		[Vector3(330, 380, 38), Vector3(670, 400, 38), Vector3(950, 300, 38)]), "res://data/maps/circuit_b.tres")
	_save(_map(&"circuit_c", "Circuit — Core Spiral", &"circuit",
		[[[-40, 120], [1080, 120], [1080, 620], [120, 620], [120, 280], [900, 280], [900, 460], [420, 460]]],
		[[[-40, 360], [420, 460]]],
		[Rect2(220, 170, 90, 70), Rect2(640, 500, 100, 80)],
		[Vector3(600, 370, 38), Vector3(990, 370, 38), Vector3(260, 540, 38)]), "res://data/maps/circuit_c.tres")
	# Delta: two entrances + day/night
	var d2 := _map(&"delta_b", "Delta — Floodgate", &"delta",
		_merge([[300, -40], [300, 360]], [[300, 760], [300, 360]],
			[[300, 360], [500, 360], [500, 170], [700, 170], [700, 540], [900, 540], [900, 250], [1100, 250]]),
		[[[-40, 200], [500, 250], [1100, 250]]],
		[Rect2(120, 180, 90, 90), Rect2(560, 250, 80, 100), Rect2(400, 470, 90, 80), Rect2(770, 280, 80, 140)], [])
	d2.day_night = true
	_save(d2, "res://data/maps/delta_b.tres")
	var d3 := _map(&"delta_c", "Delta — Night Harbor", &"delta",
		_merge([[-40, 140], [240, 140], [240, 330]], [[-40, 580], [240, 580], [240, 330]],
			[[240, 330], [480, 330], [480, 130], [720, 130], [720, 560], [940, 560], [940, 180], [1100, 180]]),
		[[[-40, 360], [500, 450], [1100, 180]]],
		[Rect2(80, 300, 100, 100), Rect2(560, 420, 90, 90), Rect2(1000, 300, 90, 120), Rect2(800, 200, 80, 90)], [])
	d3.day_night = true
	_save(d3, "res://data/maps/delta_c.tres")
	# Prism: shifting gates
	var p2 := _map(&"prism_b", "Prism — Twin Halls", &"prism",
		[[[-40, 600], [220, 600], [220, 360], [380, 360], [380, 170], [700, 170], [700, 360], [860, 360], [860, 560],
			[1080, 560], [1080, 300]],
			[[-40, 600], [220, 600], [220, 360], [380, 360], [380, 550], [700, 550], [700, 360], [860, 360], [860, 560],
			[1080, 560], [1080, 300]]],
		[[[-40, 140], [560, 300], [1080, 300]]],
		[Rect2(960, 380, 70, 120), Rect2(40, 380, 100, 90)], [])
	p2.dynamic_routes = true
	_save(p2, "res://data/maps/prism_b.tres")
	var p3 := _map(&"prism_c", "Prism — Mirror Core", &"prism",
		[[[-40, 360], [180, 360], [180, 140], [500, 140], [500, 360], [760, 360], [760, 140], [1060, 140], [1060, 400]],
			[[-40, 360], [180, 360], [180, 580], [500, 580], [500, 360], [760, 360], [760, 580], [1060, 580], [1060, 400]]],
		[[[-40, 250], [620, 420], [1060, 400]]],
		[Rect2(570, 170, 120, 90), Rect2(840, 250, 120, 60)], [])
	p3.dynamic_routes = true
	_save(p3, "res://data/maps/prism_c.tres")

	# Rift: 10 maps mixing every mechanic
	_save(_map(&"rift_01", "Rift — Breach", &"rift",
		[[[100, -40], [100, 600], [400, 600], [400, 140], [700, 140], [700, 600], [1000, 600], [1000, 140]]],
		[[[-40, 360], [1000, 140]]],
		[Rect2(510, 300, 80, 120)],
		[Vector3(250, 370, 38), Vector3(550, 500, 38), Vector3(850, 370, 38)]), "res://data/maps/rift_01.tres")
	var r2 := _map(&"rift_02", "Rift — Twin Fault", &"rift",
		_merge([[-40, 130], [300, 130], [300, 360], [500, 360]], [[1000, -40], [1000, 130], [700, 130], [700, 360], [500, 360]],
			[[500, 360], [500, 600], [900, 600], [900, 420], [1080, 420]]),
		[[[-40, 660], [600, 660], [1080, 420]]],
		[Rect2(120, 220, 90, 90), Rect2(780, 220, 100, 80), Rect2(640, 460, 90, 80)], [])
	r2.day_night = true
	_save(r2, "res://data/maps/rift_02.tres")
	var r3 := _map(&"rift_03", "Rift — Fault Lines", &"rift",
		[[[-40, 620], [160, 620], [160, 140], [620, 140], [620, 380], [900, 380], [900, 160], [1080, 160]],
			[[-40, 620], [160, 620], [620, 620], [620, 380], [900, 380], [900, 160], [1080, 160]]],
		[[[-40, 300], [500, 250], [1080, 160]]],
		[Rect2(720, 460, 120, 90), Rect2(280, 230, 80, 80)],
		[Vector3(400, 400, 38), Vector3(1000, 270, 38)])
	r3.dynamic_routes = true
	_save(r3, "res://data/maps/rift_03.tres")
	var r4 := _map(&"rift_04", "Rift — Dark Spiral", &"rift",
		[[[1100, -40], [1100, 130], [140, 130], [140, 300], [1000, 300], [1000, 470], [140, 470], [140, 630], [600, 630]]],
		[[[-40, 200], [400, 400], [600, 630]]],
		[Rect2(1040, 330, 80, 110), Rect2(260, 520, 100, 70)],
		[Vector3(570, 215, 38), Vector3(570, 385, 38)])
	r4.day_night = true
	_save(r4, "res://data/maps/rift_04.tres")
	_save(_map(&"rift_05", "Rift — Chimera Den", &"rift",
		_merge([[-40, 150], [560, 150], [560, 360]], [[-40, 580], [560, 580], [560, 360]],
			[[560, 360], [820, 360], [820, 150], [1060, 150], [1060, 560]]),
		[[[-40, 360], [560, 300], [1060, 560]]],
		[Rect2(240, 230, 90, 60), Rect2(650, 190, 80, 90)],
		[Vector3(300, 365, 38), Vector3(940, 360, 38), Vector3(690, 520, 38)]), "res://data/maps/rift_05.tres")
	var r6 := _map(&"rift_06", "Rift — Three Gates", &"rift",
		[[[-40, 600], [160, 600], [160, 360], [160, 130], [700, 130], [700, 360], [940, 360], [940, 600], [1080, 600], [1080, 300]],
			[[-40, 600], [160, 600], [160, 360], [700, 360], [940, 360], [940, 600], [1080, 600], [1080, 300]],
			[[-40, 600], [160, 600], [160, 360], [360, 360], [360, 580], [560, 580], [560, 360], [700, 360], [940, 360],
			[940, 600], [1080, 600], [1080, 300]]],
		[[[-40, 250], [560, 250], [1080, 300]]],
		[Rect2(400, 200, 100, 80), Rect2(760, 440, 100, 100), Rect2(20, 250, 90, 80)], [])
	r6.dynamic_routes = true
	r6.day_night = true
	_save(r6, "res://data/maps/rift_06.tres")
	_save(_map(&"rift_07", "Rift — Pincer", &"rift",
		_merge([[160, -40], [160, 280], [400, 280], [400, 110], [640, 110], [640, 360]],
			[[160, 760], [160, 440], [400, 440], [400, 610], [640, 610], [640, 360]],
			[[640, 360], [860, 360], [860, 560], [1080, 560], [1080, 250]]),
		[[[-40, 360], [1080, 250]]],
		[Rect2(470, 160, 100, 70), Rect2(470, 490, 100, 70), Rect2(940, 400, 80, 100)],
		[Vector3(520, 360, 38), Vector3(280, 195, 38), Vector3(760, 525, 38)]), "res://data/maps/rift_07.tres")
	var r8 := _map(&"rift_08", "Rift — Shortcut", &"rift",
		[[[-40, 130], [140, 130], [1060, 130], [1060, 300], [140, 300], [140, 560], [500, 560], [500, 420], [860, 420],
			[860, 600], [1080, 600], [1080, 380]],
			[[-40, 130], [140, 130], [140, 300], [140, 560], [500, 560], [500, 420], [860, 420], [860, 600], [1080, 600],
			[1080, 380]]],
		[[[-40, 690], [800, 690], [1080, 380]]],
		[Rect2(900, 180, 90, 80), Rect2(960, 460, 70, 100)],
		[Vector3(600, 215, 38), Vector3(680, 500, 38), Vector3(300, 430, 38)])
	r8.dynamic_routes = true
	_save(r8, "res://data/maps/rift_08.tres")
	var r9 := _map(&"rift_09", "Rift — Eclipse", &"rift",
		[[[-40, 100], [1060, 100], [1060, 280], [360, 280], [360, 360], [620, 360]],
			[[-40, 620], [1060, 620], [1060, 440], [360, 440], [360, 360], [620, 360]]],
		[[[-40, 360], [620, 360]]],
		[Rect2(560, 160, 120, 70), Rect2(560, 490, 120, 70), Rect2(40, 330, 90, 60)],
		[Vector3(850, 360, 38), Vector3(200, 190, 38), Vector3(200, 530, 38)])
	r9.day_night = true
	_save(r9, "res://data/maps/rift_09.tres")
	var r10 := _map(&"rift_10", "Rift — Colossus Gate", &"rift",
		[[[-40, 620], [160, 620], [160, 120], [420, 120], [420, 520], [680, 520], [680, 120], [940, 120],
			[940, 520], [1100, 520], [1100, 300]]],
		[[[-40, 240], [1100, 300]]],
		[Rect2(240, 600, 120, 80), Rect2(1000, 140, 100, 80)],
		[Vector3(290, 320, 38), Vector3(550, 320, 38), Vector3(810, 320, 38)])
	r10.day_night = true
	_save(r10, "res://data/maps/rift_10.tres")


	# ---- regions extended to 10 levels each (7 more maps per original region)
	var Z := func(x: float, y: float) -> Vector3: return Vector3(x, y, 38)
	_save(_map(&"circuit_d", "Circuit — Relay Yard", &"circuit",
		[[[-40, 140], [260, 140], [460, 560], [660, 140], [860, 560], [1060, 560], [1060, 300]]],
		[[[-40, 360], [1060, 300]]], [Rect2(40, 300, 80, 100), Rect2(940, 380, 80, 80)],
		[Z.call(460, 260), Z.call(660, 440), Z.call(860, 260)]), "res://data/maps/circuit_d.tres")
	_save(_map(&"circuit_e", "Circuit — Coil Maze", &"circuit",
		[[[-40, 600], [160, 600], [160, 120], [400, 120], [400, 480], [640, 480], [640, 120], [880, 120], [880, 480],
			[1080, 480], [1080, 200]]],
		[[[-40, 300], [1080, 200]]], [Rect2(470, 140, 100, 60), Rect2(980, 280, 60, 120)],
		[Z.call(280, 300), Z.call(760, 300), Z.call(520, 260)]), "res://data/maps/circuit_e.tres")
	_save(_map(&"circuit_f", "Circuit — Crossroads", &"circuit",
		[[[-40, 200], [940, 200], [940, 600], [320, 600], [320, 360], [1080, 360]]],
		[[[-40, 460], [1080, 360]]], [Rect2(1000, 420, 80, 120), Rect2(400, 420, 100, 60)],
		[Z.call(630, 280), Z.call(630, 480), Z.call(160, 420)]), "res://data/maps/circuit_f.tres")
	_save(_map(&"circuit_g", "Circuit — Step Down", &"circuit",
		[[[-40, 100], [260, 100], [260, 240], [520, 240], [520, 380], [780, 380], [780, 520], [1040, 520], [1040, 640],
			[160, 640], [160, 420]]],
		[[[-40, 400], [500, 500], [160, 420]]], [Rect2(40, 200, 100, 90), Rect2(860, 180, 100, 80)],
		[Z.call(390, 140), Z.call(650, 280), Z.call(910, 420), Z.call(400, 520)]), "res://data/maps/circuit_g.tres")
	_save(_map(&"circuit_h", "Circuit — Grid Lock", &"circuit",
		[[[-40, 120], [1000, 120], [1000, 290], [160, 290], [160, 460], [1000, 460], [1000, 630], [400, 630]]],
		[[[-40, 380], [400, 630]]], [Rect2(1060, 300, 80, 140), Rect2(40, 520, 90, 90)],
		[Z.call(580, 205), Z.call(580, 375), Z.call(700, 545)]), "res://data/maps/circuit_h.tres")
	_save(_map(&"circuit_i", "Circuit — Arc Furnace", &"circuit",
		[[[560, 760], [560, 560], [160, 560], [160, 140], [960, 140], [960, 560], [760, 560], [760, 320], [400, 320]]],
		[[[-40, 660], [400, 320]]], [Rect2(240, 200, 100, 60), Rect2(620, 420, 80, 80)],
		[Z.call(360, 440), Z.call(860, 350), Z.call(560, 230)]), "res://data/maps/circuit_i.tres")
	_save(_map(&"circuit_j", "Circuit — Dynamo Core", &"circuit",
		[[[-40, 620], [180, 620], [180, 110], [1060, 110], [1060, 290], [400, 290], [400, 470], [1060, 470], [1060, 620],
			[860, 620]]],
		[[[-40, 360], [860, 620]]], [Rect2(240, 520, 100, 80), Rect2(1080, 330, 70, 100)],
		[Z.call(700, 200), Z.call(700, 380), Z.call(290, 380), Z.call(600, 560)]), "res://data/maps/circuit_j.tres")

	var dl := [
		[&"delta_d", "Delta — Marsh Fork", _merge([[-40, 120], [120, 120], [240, 360]], [[-40, 600], [120, 600], [240, 360]],
			[[240, 360], [520, 360], [520, 140], [780, 140], [780, 580], [1040, 580], [1040, 300]]),
			[[[-40, 360], [1040, 300]]], [Rect2(40, 300, 80, 120), Rect2(600, 220, 100, 100), Rect2(860, 220, 90, 100)]],
		[&"delta_e", "Delta — Twin Canal", _merge([[200, -40], [200, 300]], [[-40, 500], [200, 500], [200, 300]],
			[[200, 300], [460, 300], [460, 600], [720, 600], [720, 140], [980, 140], [980, 520], [1100, 520]]),
			[[[-40, 300], [460, 300], [720, 400], [1100, 520]]], [Rect2(40, 160, 100, 80), Rect2(540, 220, 100, 100), Rect2(800, 300, 100, 120)]],
		[&"delta_f", "Delta — Flood Plain", _merge([[160, -40], [160, 200], [580, 200]], [[1000, -40], [1000, 200], [580, 200]],
			[[580, 200], [580, 400], [200, 400], [200, 620], [960, 620], [960, 400], [760, 400]]),
			[[[-40, 300], [760, 400]]], [Rect2(300, 240, 120, 80), Rect2(380, 470, 120, 80), Rect2(820, 250, 100, 80)]],
		[&"delta_g", "Delta — Reed Maze", _merge([[120, 760], [120, 520], [560, 520]], [[1000, 760], [1000, 520], [560, 520]],
			[[560, 520], [560, 300], [300, 300], [300, 120], [820, 120], [820, 330]]),
			[[[-40, 200], [820, 330]]], [Rect2(380, 380, 100, 80), Rect2(640, 200, 100, 80), Rect2(900, 300, 90, 120)]],
		[&"delta_h", "Delta — Delta Bridge", _merge([[-40, 240], [160, 240], [160, 360]], [[-40, 480], [160, 480], [160, 360]],
			[[160, 360], [400, 120], [640, 600], [880, 120], [1060, 360]]),
			[[[-40, 600], [1060, 360]]], [Rect2(40, 330, 70, 60), Rect2(600, 180, 80, 90), Rect2(860, 450, 90, 80)]],
		[&"delta_i", "Delta — Mangrove", _merge([[600, -40], [600, 360]], [[600, 760], [600, 360]],
			[[600, 360], [840, 360], [840, 160], [1060, 160], [1060, 580], [320, 580], [320, 160], [440, 160]]),
			[[[-40, 360], [440, 160]]], [Rect2(380, 300, 80, 100), Rect2(900, 240, 90, 100), Rect2(160, 300, 80, 120)]],
		[&"delta_j", "Delta — Leviathan Lagoon", _merge([[-40, 140], [200, 140], [200, 380]], [[-40, 620], [200, 620], [200, 380]],
			[[200, 380], [420, 380], [420, 130], [660, 130], [660, 560], [880, 560], [880, 130], [1080, 130], [1080, 460]]),
			[[[-40, 380], [1080, 460]]], [Rect2(480, 200, 100, 100), Rect2(720, 260, 100, 120), Rect2(940, 250, 80, 120), Rect2(40, 330, 100, 90)]],
	]
	for d in dl:
		var dm := _map(d[0], d[1], &"delta", d[2], d[3], d[4], [])
		dm.day_night = true
		_save(dm, "res://data/maps/%s.tres" % d[0])

	var pl := [
		[&"prism_d", "Prism — Facet Hall",
			[[[-40, 360], [200, 360], [380, 200], [800, 200], [980, 360], [1080, 360], [1080, 640], [300, 640]],
				[[-40, 360], [200, 360], [380, 520], [800, 520], [980, 360], [1080, 360], [1080, 640], [300, 640]]],
			[[[-40, 120], [300, 640]]], [Rect2(540, 320, 100, 80), Rect2(40, 420, 100, 90)]],
		[&"prism_e", "Prism — Lens Array",
			[[[-40, 600], [160, 600], [160, 360], [300, 170], [620, 170], [760, 360], [960, 360], [960, 120], [1080, 120], [1080, 600], [860, 600]],
				[[-40, 600], [160, 600], [160, 360], [300, 550], [620, 550], [760, 360], [960, 360], [960, 120], [1080, 120], [1080, 600], [860, 600]]],
			[[[-40, 120], [860, 600]]], [Rect2(420, 320, 80, 80), Rect2(1000, 300, 40, 100)]],
		[&"prism_f", "Prism — Refraction Core",
			[[[-40, 600], [160, 600], [160, 360], [360, 160], [560, 360], [760, 160], [960, 360], [1080, 360], [1080, 120]],
				[[-40, 600], [160, 600], [160, 360], [360, 560], [560, 360], [760, 560], [960, 360], [1080, 360], [1080, 120]]],
			[[[-40, 120], [1080, 120]]], [Rect2(320, 330, 80, 60), Rect2(720, 330, 80, 60)]],
		[&"prism_g", "Prism — Split Beam",
			[[[-40, 320], [300, 320], [300, 520], [700, 520], [700, 320], [1060, 320], [1060, 620], [820, 620]],
				[[-40, 320], [300, 320], [300, 130], [700, 130], [700, 320], [1060, 320], [1060, 620], [820, 620]]],
			[[[-40, 640], [300, 420], [700, 420], [820, 620]]], [Rect2(460, 280, 80, 80), Rect2(860, 400, 100, 140)]],
		[&"prism_h", "Prism — Kaleidoscope",
			[[[-40, 620], [200, 620], [200, 420], [200, 140], [640, 140], [640, 420], [860, 420], [860, 140], [1060, 140], [1060, 560]],
				[[-40, 620], [200, 620], [200, 420], [640, 420], [860, 420], [860, 140], [1060, 140], [1060, 560]]],
			[[[-40, 300], [1060, 560]]], [Rect2(360, 220, 120, 100), Rect2(920, 240, 80, 120), Rect2(400, 500, 120, 80)]],
		[&"prism_i", "Prism — Spectrum",
			[[[-40, 360], [140, 360], [140, 120], [1040, 120], [1040, 600], [380, 600], [380, 360], [700, 360]],
				[[-40, 360], [140, 360], [140, 600], [380, 600], [380, 360], [700, 360]]],
			[[[-40, 680], [700, 360]]], [Rect2(520, 180, 140, 100), Rect2(820, 300, 100, 160)]],
		[&"prism_j", "Prism — Helix",
			[[[-40, 360], [160, 360], [160, 120], [1060, 120], [1060, 360], [900, 360], [900, 240], [300, 240], [300, 480], [740, 480], [740, 360]],
				[[-40, 360], [160, 360], [160, 600], [1060, 600], [1060, 360], [900, 360], [900, 240], [300, 240], [300, 480], [740, 480], [740, 360]]],
			[[[-40, 700], [740, 360]]], [Rect2(500, 300, 100, 60)]],
	]
	for d in pl:
		var pm := _map(d[0], d[1], &"prism", d[2], d[3], d[4], [])
		pm.dynamic_routes = true
		_save(pm, "res://data/maps/%s.tres" % d[0])


func _pts(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in a:
		out.append(Vector2(q[0], q[1]))
	return out


## Two entrance routes that merge into a shared tail (tail[0] = merge point).
func _merge(head_a: Array, head_b: Array, tail: Array) -> Array:
	var ra := head_a.slice(0, head_a.size() - 1) + tail
	var rb := head_b.slice(0, head_b.size() - 1) + tail
	return [ra, rb]


## General rule (2026-11-16, user: no more one-off custom air-route tuning per level): every map's
## air route targets this fraction of its OWN longest ground route, computed per map instead of a
## single fixed multiplier for every map. Replaces the old flat AIR_LENGTHEN=1.65 (which measured
## ~0.577 average air/ground ratio across the 40 maps -- close to this by coincidence, but now exact
## and automatic for any map added later). _air_factor() can only lengthen (never shrink an air
## route already past the target, since _lengthen_air_static only adds wobble, it can't remove it).
const AIR_TARGET_RATIO := 0.6


static func _path_length(pts: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, pts.size()):
		length += pts[i - 1].distance_to(pts[i])
	return length


static func _air_factor(ground_routes: Array, air_pts: PackedVector2Array) -> float:
	var longest := 0.0
	for r in ground_routes:
		longest = maxf(longest, _path_length(r))
	var original := _path_length(air_pts)
	if original < 1.0:
		return 1.0
	return maxf(1.0, longest * AIR_TARGET_RATIO / original)


## The visible play field, clear of the in-match HUD that's always on screen: the top bar (0-62px)
## and the right tower palette (x >= 1168). The bottom-left item toolbar is collapsible (Hud's
## items-panel toggle) so it no longer needs its own carve-out here. Ground routes are allowed to
## start off this, at x=-40, so the enemy visibly walks in; air routes no longer do.
const AIR_FRAME := Rect2(40.0, 70.0, 1100.0, 630.0)

## Reworked from a small repeated zigzag to a smooth, sweeping loop (2026-11-16, user feedback: the
## zigzag's bows were getting clamped right at AIR_FRAME's edge on some maps, hugging the border
## instead of curving well clear of it). AIR_INSET keeps every bow at least this far from the frame
## edge -- a real margin, not a last-resort clamp -- and AIR_MAX_LOOPS keeps the curve to at most a
## couple of big, round sweeps per segment instead of many small ripples.
const AIR_INSET := 60.0
const AIR_MAX_LOOPS := 3
const AIR_SAMPLE_SPACING := 18.0 ## px between sampled points along a loop, for a smooth-looking curve


## Whichever AIR_FRAME corner is farthest from `p`.
static func _farthest_frame_corner(p: Vector2) -> Vector2:
	var corners := [AIR_FRAME.position, Vector2(AIR_FRAME.end.x, AIR_FRAME.position.y),
		AIR_FRAME.end, Vector2(AIR_FRAME.position.x, AIR_FRAME.end.y)]
	var best: Vector2 = corners[0]
	var best_d := -1.0
	for c in corners:
		var d: float = c.distance_to(p)
		if d > best_d:
			best_d = d
			best = c
	return best


## Overrides an air route's start with whichever AIR_FRAME corner is farthest from its end, so
## flying enemies cross the most ground possible before the loop-and-60%-of-ground-route method
## below takes over (user request, 2026-11-16: start from the point opposite the destination,
## THEN apply the looping + 60% rule).
static func _from_farthest_corner(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var out := pts.duplicate()
	out[0] = _farthest_frame_corner(out[out.size() - 1])
	return out


## Average of every point across a set of ground routes: used as the point air-route loops bow
## toward, so they sweep in over the play field instead of out toward the screen edge.
static func _centroid(routes: Array) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for r in routes:
		for p in r:
			sum += p
			n += 1
	return sum / maxf(float(n), 1.0)


## Pulls every point of an air route fully inside AIR_FRAME, then bows each segment into a smooth
## half-sine loop (one big sweep in and back, not a zigzag) to reach roughly `factor` x its original
## length. Every sampled point -- start, end, and the loop in between -- stays at least AIR_INSET
## away from AIR_FRAME's edge. `bias` (the ground routes' centroid) picks which side each segment
## bows toward: always inward, over the play field the ground route winds through, never out
## toward the screen border (user feedback, 2026-11-16: "đừng cho nó lượn ở ngoài rìa").
static func _lengthen_air_static(pts: PackedVector2Array, factor: float, bias: Vector2 = AIR_FRAME.get_center()) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var inset := AIR_FRAME.grow(-AIR_INSET)
	var clamped := PackedVector2Array()
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		# The true start/end may sit right on the frame (that's the entry/exit point); every
		# original waypoint IN BETWEEN also gets pulled off the edge, same as the new loop points
		# below -- otherwise a hand-authored corner near the border would still hug it.
		var bounds := AIR_FRAME if (i == 0 or i == pts.size() - 1) else inset
		clamped.append(Vector2(clampf(p.x, bounds.position.x, bounds.end.x),
			clampf(p.y, bounds.position.y, bounds.end.y)))
	if factor <= 1.001:
		return clamped
	var out := PackedVector2Array([clamped[0]])
	for i in range(1, clamped.size()):
		var a: Vector2 = clamped[i - 1]
		var b: Vector2 = clamped[i]
		var seg_len := a.distance_to(b)
		if seg_len > 1.0:
			var normal := (b - a).orthogonal().normalized()
			# Bow toward `bias`, not whichever side happens to have more empty room -- that room
			# is usually toward the screen edge, since the ground route (and bias) sit inward.
			var mid := a.lerp(b, 0.5)
			var side := 1.0 if normal.dot(bias - mid) >= 0.0 else -1.0
			var room := _bow_room(a, b, normal, inset)
			var room_amp := room.x if side > 0.0 else room.y
			var target_len := seg_len * factor
			var loops := 1
			var best_pts: Array[Vector2] = []
			# For each loop count, binary-search the SMALLEST amplitude (up to the room ceiling)
			# that reaches target_len, instead of always bowing out the full room -- a generous
			# room on the biased side (e.g. a long, mostly-empty segment) was overshooting the
			# target by a lot otherwise. Only adds more loops if even the full room isn't enough.
			while loops <= AIR_MAX_LOOPS:
				best_pts = _loop_samples(a, b, normal, room_amp, side, loops)
				if _polyline_len(a, b, best_pts) < target_len and loops < AIR_MAX_LOOPS:
					loops += 1
					continue
				var lo := 0.0
				var hi := room_amp
				for _iter in range(16):
					var mid_amp := (lo + hi) * 0.5
					var pts_mid := _loop_samples(a, b, normal, mid_amp, side, loops)
					if _polyline_len(a, b, pts_mid) < target_len:
						lo = mid_amp
					else:
						hi = mid_amp
				best_pts = _loop_samples(a, b, normal, hi, side, loops)
				break
			for p in best_pts:
				out.append(Vector2(clampf(p.x, inset.position.x, inset.end.x),
					clampf(p.y, inset.position.y, inset.end.y)))
		out.append(b)
	return out


## Length of a->mid_pts[0]->mid_pts[1]->...->b.
static func _polyline_len(a: Vector2, b: Vector2, mid_pts: Array[Vector2]) -> float:
	if mid_pts.is_empty():
		return a.distance_to(b)
	var len := a.distance_to(mid_pts[0])
	var prev := mid_pts[0]
	for i in range(1, mid_pts.size()):
		len += prev.distance_to(mid_pts[i])
		prev = mid_pts[i]
	len += prev.distance_to(b)
	return len


## Room to bow out on each side of segment a->b (along `normal` and its opposite) before crossing
## `inset`'s edge, sampled at a few points along the segment (not just the middle).
static func _bow_room(a: Vector2, b: Vector2, normal: Vector2, inset: Rect2) -> Vector2:
	var pos_room := INF
	var neg_room := INF
	for t in [0.25, 0.5, 0.75]:
		var p: Vector2 = a.lerp(b, t)
		pos_room = minf(pos_room, _room_along(p, normal, inset))
		neg_room = minf(neg_room, _room_along(p, -normal, inset))
	return Vector2(maxf(pos_room, 0.0), maxf(neg_room, 0.0))


## How far `p` can move along `dir` before leaving `rect`.
static func _room_along(p: Vector2, dir: Vector2, rect: Rect2) -> float:
	var room := INF
	if dir.x > 0.001: room = minf(room, (rect.end.x - p.x) / dir.x)
	elif dir.x < -0.001: room = minf(room, (rect.position.x - p.x) / dir.x)
	if dir.y > 0.001: room = minf(room, (rect.end.y - p.y) / dir.y)
	elif dir.y < -0.001: room = minf(room, (rect.position.y - p.y) / dir.y)
	return room


## Densely-sampled points for `loops` half-sine sweeps of amplitude `amp` (to one side only, so it
## reads as a single looping detour rather than a side-to-side zigzag) along segment a->b.
static func _loop_samples(a: Vector2, b: Vector2, normal: Vector2, amp: float, side: float, loops: int) -> Array[Vector2]:
	var seg_len := a.distance_to(b)
	var n := maxi(loops * 6, int(seg_len / AIR_SAMPLE_SPACING))
	var out: Array[Vector2] = []
	for s in range(1, n):
		var t := float(s) / float(n)
		var p: Vector2 = a.lerp(b, t)
		var off := sin(t * loops * PI) * amp * side
		out.append(p + normal * off)
	return out


func _map(id: StringName, n: String, region: StringName, routes: Array, air: Array, blocked: Array,
		zones: Array) -> MapDef:
	var m := MapDef.new()
	m.id = id
	m.display_name = n
	m.region = region
	var rs: Array[PackedVector2Array] = []
	for r in routes:
		rs.append(_pts(r))
	m.routes = rs
	var ground_center := _centroid(rs)
	var ars: Array[PackedVector2Array] = []
	for r in air:
		var pts := _from_farthest_corner(_pts(r))
		ars.append(_lengthen_air_static(pts, _air_factor(rs, pts), ground_center))
	m.air_routes = ars
	var br: Array[Rect2] = []
	for b in blocked:
		br.append(b)
	m.blocked_rects = br
	m.range_bonus_zones = PackedVector3Array(zones)
	return m


const LEVEL_WAVES = preload("res://tools/level_waves.gd")
var E := {}
var ORDER: Array = []
## level id -> wave-count factor from the difficulty pass (1.0 = unchanged)
## Shop ranks: [blueprint shards, Cores price]. S costs a bit more than the dearest research (35);
## SS is reserved for later content.
const SHOP_RANKS := {"S": [100, 150], "SS": [250, 400]}
## Boss shard drops: 5th level (mid boss) and 10th level (region boss) of every region.
const SHARD_DROPS := {
	"mid": [0.15, 1, 2, 0.02, 5, 8],
	"final": [0.22, 1, 3, 0.03, 8, 12],
}

const DIFFICULTY := {
	"level_01": 5.917, "level_02": 3.192, "level_03": 4.363, "level_04": 2.134, "level_05": 3.093, "level_06": 3.406,
	"level_07": 5.185, "level_08": 6.071, "level_09": 6.574, "level_10": 11.652, "level_11": 8.35, "level_12": 7.207,
	"level_13": 3.901, "level_14": 5.553, "level_15": 5.609, "level_16": 6.601, "level_17": 6.735, "level_18": 3.502,
	"level_19": 8.803, "level_20": 5.711, "level_21": 1.831, "level_22": 3.779, "level_23": 3.538, "level_24": 4.072,
	"level_25": 5.122, "level_26": 4.523, "level_27": 1.077, "level_28": 3.744, "level_29": 0.616, "level_30": 1.549,
	"level_31": 1.188, "level_32": 1.641, "level_33": 1.679, "level_34": 7.104, "level_35": 5.194, "level_36": 5.146,
	"level_37": 10.669, "level_38": 4.298, "level_39": 4.717, "level_40": 4.724
}


func _levels() -> void:
	for id in ["drone", "dart", "brute", "swarmling", "plated", "aegis", "glider", "phantom", "mender", "monolith",
			"warden", "carrier", "chimera", "colossus", "dynamo", "leviathan", "refractor",
			"escort", "sludge", "shade", "sprinter", "jammer", "prismling", "diver",
			"disruptor", "static_crawler", "wraith", "vanguard", "rallier", "cloaker", "mender_elite"]:
		E[id] = load("res://data/enemies/%s.tres" % id)
	E["swarm"] = E["swarmling"]
	E["crawler"] = E["static_crawler"]
	E["mender2"] = E["mender_elite"]
	var circuit: MapDef = load("res://data/maps/circuit.tres")
	var delta: MapDef = load("res://data/maps/delta.tres")
	var prism: MapDef = load("res://data/maps/prism.tres")
	var M := func(id: String) -> MapDef: return load("res://data/maps/%s.tres" % id)
	var pulse: TowerDef = load("res://data/towers/pulse.tres")
	var nova: TowerDef = load("res://data/towers/nova.tres")
	var lance: TowerDef = load("res://data/towers/lance.tres")
	var beacon: TowerDef = load("res://data/towers/beacon.tres")
	var econ: EconomyConfig = load("res://data/economy_default.tres")
	var t2: Array[TowerDef] = [pulse, nova]
	var t3: Array[TowerDef] = [pulse, nova, lance]
	var rookie: Array[TowerDef] = []
	var all: Array[TowerDef] = [pulse, nova, lance, beacon, load("res://data/towers/trap.tres"),
		load("res://data/towers/venom.tres"), load("res://data/towers/sniper.tres"), load("res://data/towers/bastion.tres"),
		load("res://data/towers/spotter.tres"), load("res://data/towers/storm.tres"), load("res://data/towers/chronos.tres")]
	t2 = all
	t3 = all

	var levels: Array[LevelDef] = []

	var l1 := _level(&"level_01", "1 — First Contact", 1, circuit, t2, econ, 350, 20)
	l1.objective = "Learn to build: survive 8 waves of Drones and Darts."
	l1.cores_first_clear = 10
	l1.waves = _waves([
		"drone*6@1.4",
		"drone*9@1.2",
		"drone*6@1.3, dart*5@0.8+6",
		"drone*12@1.0",
		"dart*10@0.7, drone*6@1.0+4",
		"drone*14@0.8, dart*6@0.6+8",
		"drone*16@0.7, dart*10@0.5+5",
		"dart*22@0.45, drone*10@0.8+6 | special",
	])
	levels.append(l1)

	var l2 := _level(&"level_02", "2 — Heavy Traffic", 2, M.call("circuit_b"), t2, econ, 350, 20)
	l2.objective = "Brutes soak damage, Swarmlings come in floods. Splash matters."
	l2.cores_first_clear = 10
	l2.waves = _waves([
		"drone*8@1.2",
		"swarm*12@0.35, dart*6@0.7+5",
		"brute*2@3.0, drone*8@1.0+2",
		"drone*14@0.8, swarm*15@0.3+6",
		"brute*4@2.5, dart*8@0.6+4",
		"drone*18@0.7, brute*3@2.5+6",
		"swarm*24@0.25, brute*4@2.0+5",
		"brute*6@1.8, drone*16@0.6+3",
		"drone*24@0.5, dart*14@0.4+6, brute*4@2.0+10",
		"brute*8@1.5, swarm*30@0.2+4, drone*20@0.5+8 | special",
	])
	levels.append(l2)

	var l3 := _level(&"level_03", "3 — Iron Convoy", 3, M.call("circuit_c"), t3, econ, 400, 20)
	l3.objective = "Armor and the first fliers arrive. The Warden guards wave 12: it hardens its shell, then sprints."
	l3.cores_first_clear = 15
	l3.waves = _waves([
		"drone*10@0.9",
		"drone*8@0.8, dart*8@0.5+4",
		"plated*3@2.0, drone*8@0.8+2",
		"brute*3@2.5, swarm*15@0.25+3",
		"drone*12@0.7, plated*4@1.6+5",
		"glider*6@1.2, drone*10@0.7+2",
		"plated*6@1.4, dart*10@0.45+4",
		"glider*8@1.0, swarm*20@0.2+3",
		"brute*5@1.8, plated*5@1.3+4",
		"drone*20@0.5, glider*8@0.8+6",
		"plated*7@1.1, brute*4@2.0+5, dart*12@0.4+8",
		"warden*1@1.0, plated*6@1.4+6, drone*12@0.6+3 | boss",
	])
	levels.append(l3)

	var l4 := _level(&"level_04", "4 — Twin Rivers", 4, delta, all, econ, 500, 20)
	l4.objective = "Two entrances merge. Night waves hide Phantoms and dim towers outside Beacon light."
	l4.cores_first_clear = 15
	l4.waves = _waves([
		"drone*8@1.0#0, drone*8@1.0#1",
		"dart*8@0.6#0, drone*10@0.8#1",
		"plated*2@1.8#0, swarm*16@0.25#1",
		"phantom*5@1.4#0, drone*10@0.8#1 | night",
		"brute*3@2.5#0, glider*6@1.2, dart*8@0.5#1",
		"plated*6@1.4#1, drone*12@0.6#0",
		"glider*8@1.0, swarm*18@0.2#0, swarm*18@0.2#1",
		"phantom*7@1.1#1, plated*5@1.5#0 | night",
		"brute*5@1.8#0, brute*4@1.8#1",
		"drone*16@0.5#0, dart*14@0.4#1, glider*6@1.0+4",
		"plated*7@1.2#0, plated*7@1.2#1",
		"phantom*9@0.9#0, phantom*7@1.0#1, brute*4@2.0+5#0 | night, special",
	], 0.75)
	levels.append(l4)

	var l5 := _level(&"level_05", "5 — Shield Wall", 5, M.call("delta_b"), all, econ, 500, 20)
	l5.objective = "Aegis shields regenerate. Energy breaks them twice as fast."
	l5.cores_first_clear = 20
	l5.waves = _waves([
		"drone*10@0.8#0, dart*8@0.5#1",
		"aegis*2@1.8#0, drone*8@0.8#1",
		"plated*5@1.5#1, swarm*20@0.2#0",
		"glider*8@1.0, brute*3@2.0#0",
		"phantom*7@1.2#0, aegis*4@1.8#1 | night",
		"aegis*6@1.4#0, plated*5@1.4#1",
		"swarm*22@0.18#0, swarm*22@0.18#1, glider*6@1.0+5",
		"brute*6@1.6#0, dart*16@0.35#1",
		"aegis*8@1.2#1, glider*8@0.9",
		"phantom*10@1.0#1, plated*6@1.3#0 | night",
		"brute*5@1.6#0, aegis*6@1.3#1, drone*16@0.5+6#0",
		"glider*12@0.8, plated*8@1.1#0",
		"phantom*10@0.9#0, aegis*8@1.1#1 | night",
		"aegis*10@0.9#0, aegis*10@0.9#1, brute*4@2.0+6#0 | special",
	], 0.55)
	levels.append(l5)

	var l6 := _level(&"level_06", "6 — Night Carrier", 6, M.call("delta_c"), all, econ, 550, 25)
	l6.objective = "Menders heal their escorts. The Carrier arrives in wave 15: it launches fighters and cloaks — keep Beacons by the lane."
	l6.cores_first_clear = 30
	l6.waves = _waves([
		"drone*12@0.7#0, drone*12@0.7#1",
		"mender*1@3.0#0, brute*2@2.0#0",
		"aegis*3@1.4#1, dart*12@0.45#0",
		"glider*10@0.9, swarm*20@0.2#1",
		"plated*8@1.2#0, mender*2@3.0+2#0",
		"phantom*7@1.0#1, phantom*4@1.2#0 | night",
		"brute*6@1.5#0, aegis*6@1.4#1",
		"swarm*28@0.15#0, glider*10@0.8",
		"plated*8@1.1#1, mender*3@2.5+2#1, brute*4@2.0+4#1",
		"mender*4@2.0#0, brute*7@1.3+1#0, aegis*6@1.4#1 | special",
		"glider*14@0.7, dart*20@0.35#1",
		"phantom*12@0.8#0, plated*8@1.1#1 | night",
		"aegis*10@1.1#0, mender*3@2.5+3#0, swarm*25@0.18#1",
		"brute*9@1.2#1, plated*9@1.0#0",
		"carrier*1@1.0#0, drone*12@1.0+5#1 | boss",
	], 0.58)
	levels.append(l6)

	var l7 := _level(&"level_07", "7 — Shifting Gates", 7, prism, all, econ, 550, 20)
	l7.objective = "Gates switch the open route at waves 6 and 11. Fliers take the southern corridor."
	l7.cores_first_clear = 25
	l7.prep_time = 22.0 # was shorter than the (now-raised) 30s default; kept proportionally tighter
	l7.waves = _waves([
		"drone*12@0.7#-1, glider*4@1.5 | route=0",
		"dart*12@0.45#-1, glider*6@1.2",
		"plated*3@1.4#-1, swarm*20@0.2+4#-1",
		"glider*10@0.9, aegis*4@1.6#-1",
		"brute*5@1.8#-1, mender*2@3.0+2#-1",
		"glider*12@0.8, drone*14@0.6#-1 | route=1",
		"phantom*8@1.1#-1, plated*6@1.3#-1",
		"aegis*8@1.2#-1, glider*10@0.8+3",
		"swarm*30@0.15#-1, brute*5@1.6+4#-1",
		"glider*16@0.6, mender*3@2.5#-1",
		"plated*10@1.0#-1, aegis*6@1.3+4#-1 | route=0",
		"phantom*12@0.9#-1, glider*10@0.8+3",
		"brute*8@1.3#-1, mender*3@2.5+3#-1",
		"glider*20@0.5, dart*20@0.35+4#-1",
		"glider*24@0.45, aegis*10@1.0+5#-1, plated*8@1.1+8#-1 | special",
	], 0.7)
	levels.append(l7)

	var l8 := _level(&"level_08", "8 — Prism Storm", 8, M.call("prism_b"), all, econ, 600, 20)
	l8.objective = "Elite mixes and three gate switches. Hedge your coverage."
	l8.cores_first_clear = 30
	l8.prep_time = 22.0
	l8.waves = _waves([
		"drone*14@0.6#-1, dart*10@0.4+3#-1 | route=1",
		"plated*3@1.3#-1, glider*6@1.0",
		"aegis*6@1.3#-1, swarm*24@0.18+3#-1",
		"phantom*8@1.0#-1, brute*4@1.8#-1",
		"glider*12@0.7, mender*2@3.0#-1 | route=0",
		"plated*10@1.0#-1, dart*16@0.35+4#-1",
		"aegis*10@1.0#-1, glider*10@0.7+3",
		"brute*8@1.3#-1, mender*3@2.5+2#-1",
		"swarm*36@0.12#-1, phantom*8@1.0+4#-1",
		"glider*18@0.5, plated*8@1.0+4#-1 | route=1",
		"aegis*12@0.9#-1, brute*6@1.5+5#-1",
		"phantom*14@0.8#-1, mender*3@2.5+3#-1",
		"glider*20@0.5, swarm*30@0.15+3#-1",
		"plated*14@0.8#-1, aegis*8@1.1+6#-1 | route=0",
		"brute*12@1.0#-1, mender*4@2.2+2#-1",
		"glider*24@0.4, dart*24@0.3+3#-1",
		"aegis*14@0.8#-1, plated*12@0.9+5#-1, phantom*10@0.9+10#-1",
		"phantom*16@0.6#-1, glider*20@0.45+2 | special",
	], 0.6)
	levels.append(l8)

	var l9 := _level(&"level_09", "9 — Monolith Awakened", 9, M.call("prism_c"), all, econ, 650, 30)
	l9.objective = "Everything you have learned. Defeat the awakened Monolith in wave 20."
	l9.cores_first_clear = 35 # 2026-11-18: was 50 (boss levels ~1.3x their neighbours)
	l9.prep_time = 22.0
	l9.waves = _waves([
		"drone*16@0.6#-1, dart*12@0.4+3#-1 | route=0",
		"plated*4@1.2#-1, glider*8@0.9",
		"aegis*4@1.2#-1, swarm*26@0.16+3#-1",
		"phantom*10@0.9#-1, mender*2@3.0+2#-1",
		"brute*8@1.4#-1, glider*10@0.8+3",
		"plated*10@1.0#-1, aegis*6@1.2+4#-1",
		"glider*16@0.6, swarm*30@0.15#-1 | route=1",
		"phantom*12@0.8#-1, brute*6@1.4+4#-1",
		"aegis*12@0.9#-1, mender*3@2.5+3#-1",
		"brute*16@0.8#-1, mender*4@2.0+2#-1 | special",
		"glider*20@0.5, plated*10@1.0+3#-1",
		"swarm*40@0.12#-1, phantom*10@0.8+4#-1",
		"aegis*14@0.8#-1, brute*8@1.2+5#-1",
		"plated*16@0.8#-1, glider*16@0.5+4 | route=0",
		"phantom*16@0.6#-1, mender*4@2.2+3#-1",
		"glider*26@0.4, aegis*10@1.0+4#-1",
		"brute*14@0.9#-1, plated*12@0.9+5#-1, mender*4@2.2+8#-1",
		"swarm*50@0.1#-1, glider*20@0.45+3, phantom*12@0.7+6#-1",
		"aegis*18@0.7#-1, plated*14@0.8+4#-1, glider*18@0.5+8",
		"monolith*1@1.0#-1!hp=0.42, aegis*6@1.5+6#-1, mender*3@3.0+10#-1, glider*12@0.8+15 | boss",
	], 0.5)
	levels.append(l9)

	_rift_levels(levels, all, econ, M)
	_region_levels(levels, t3, all, econ, M)

	# Campaign order: 4 regions x 10 levels. Old level ids are kept (saves stay valid); new ids 20-40.
	var UNLOCK := {"level_02": "nova", "level_20": "lance", "level_04": "beacon", "level_27": "venom",
		"level_34": "trap", "level_35": "bastion", "level_10": "sniper", "level_12": "spotter"}
	for l in levels:
		if UNLOCK.has(String(l.id)):
			l.unlock_tower_on_start = load("res://data/towers/%s.tres" % UNLOCK[String(l.id)])
	ORDER = ["level_01", "level_02", "level_20", "level_21", "level_03", "level_22", "level_23", "level_24", "level_25", "level_26",
		"level_04", "level_05", "level_27", "level_28", "level_06", "level_29", "level_30", "level_31", "level_32", "level_33",
		"level_07", "level_08", "level_34", "level_35", "level_36", "level_37", "level_38", "level_39", "level_40", "level_09",
		"level_10", "level_11", "level_12", "level_13", "level_14", "level_15", "level_16", "level_17", "level_18", "level_19"]
	var by_id := {}
	for l in levels:
		by_id[String(l.id)] = l
	for i in range(ORDER.size()):
		var l: LevelDef = by_id[ORDER[i]]
		l.level_number = i + 1
		var name := l.display_name
		var cut := name.find("— ")
		if cut >= 0:
			name = name.substr(cut + 2)
		l.display_name = "%d — %s" % [i + 1, name]
	# Difficulty pass (tools/sim/difficulty_tuner.gd): the best bot strategy wins narrowly
	# (10-30% Base HP; boss levels 8-25%). Factor d: regular counts x d^0.6, HP x d^0.4; boss HP x d^0.5.
	# Difficulty = numbers, never stats: regular enemies keep their base HP. Any HP multiplier a wave had
	# (level ramp, Rift HP) becomes extra enemies instead (same pressure), spawns get closer (interval /
	# sqrt(k)). The per-level difficulty knob (DIFFICULTY) is stored on the level and applied when the match
	# starts (DifficultyModel.effective_level), together with the on-screen crowd cap.
	for l in levels:
		var boss := false
		for w in l.waves:
			boss = boss or w.is_boss
		if boss:
			var r: Array = SHARD_DROPS["final" if l.level_number % 10 == 0 else "mid"]
			var sd := ShardDropDef.new()
			sd.chance = r[0]
			sd.min_shards = r[1]
			sd.max_shards = r[2]
			sd.jackpot_chance = r[3]
			sd.jackpot_min = r[4]
			sd.jackpot_max = r[5]
			l.shard_drop = sd
		else:
			l.shard_drop = null
	# Waves come from tools/level_waves.gd, generated by tools/gen_waves.gd from tools/level_plan.gd
	# (2026-11-18, user: plan = enemies + threat per wave; no runtime %-rules, every wave spawns exactly as
	# written). The inline _waves([...]) lines above are only a fallback for a level missing from the file.
	for l in levels:
		l.difficulty = 1.0
		if LEVEL_WAVES.WAVES.has(String(l.id)):
			l.waves = _waves(LEVEL_WAVES.WAVES[String(l.id)])
		else:
			push_warning("level %s has no entry in tools/level_waves.gd; using its inline waves" % l.id)
	for l in levels:
		l.cores_first_clear = int(round(l.cores_first_clear * CORES_MULT))
		_save(l, "res://data/levels/%s.tres" % l.id)

	# Combat Lab — dev test bed (not part of the campaign).
	var lab := _level(&"combat_lab", "Combat Lab (dev test)", 0, circuit, all, econ, 2500, 40)
	lab.waves = _waves([
		"drone*10@0.8, swarm*15@0.25+4",
		"plated*8@1.4, brute*3@2.5+3",
		"aegis*8@1.3, dart*10@0.5+4",
		"glider*10@1.0, drone*8@0.8+3",
		"phantom*10@1.0, drone*6@1.0+2",
		"mender*4@2.5, brute*6@1.5+1, plated*4@1.5+4",
		"glider*8@0.8, phantom*8@0.9+2, aegis*6@1.2+4 | special",
		"monolith*1@1.0!hp=0.375!ph=2!dmg=15, drone*10@1.0+3 | boss",
		"mender*4@2.0, plated*10@0.9, glider*10@0.7+5, phantom*10@0.8+8",
		"monolith*1@1.0, aegis*6@1.5+4, mender*3@3.0+6 | boss",
	])
	_save(lab, "res://data/levels/combat_lab.tres")


# ---------------------------------------------------------------- Rift (levels 10-19)
## Rift waves come from a seeded authoring-time generator (output data is concrete): a per-level theme
## weights which enemies appear; counts grow over the level; every 6th wave is special; night and gate
## switches follow the map's mechanic. Boss levels (5th and 10th of the region) end on the boss wave.

const RIFT_GROUPS := {
	"drone": [16, 0.55], "dart": [14, 0.38], "brute": [5, 1.5], "swarm": [30, 0.14], "plated": [6, 1.1],
	"aegis": [6, 1.1], "glider": [10, 0.7], "phantom": [8, 0.9], "mender": [2, 2.6],
	"escort": [3, 1.3], "sludge": [4, 1.4], "shade": [6, 0.9], "sprinter": [8, 0.7], "jammer": [2, 1.8],
	"prismling": [5, 1.1], "diver": [5, 1.0],
	"vanguard": [3, 2.0], "disruptor": [2, 1.8], "static_crawler": [3, 1.8],
	"rallier": [4, 1.2], "cloaker": [2, 2.2], "wraith": [3, 1.4], "mender_elite": [2, 2.5],
}
## New enemies: where each is introduced (level number before the 40-level reorder = its id) and
## which later levels also use it (theme weight).
const INTRO := {
	22: "escort", 23: "vanguard", 24: "disruptor", 25: "static_crawler",
	27: "sludge", 28: "rallier", 29: "cloaker", 30: "shade", 31: "wraith",
	34: "sprinter", 35: "jammer", 37: "mender_elite", 38: "prismling",
	10: "diver",
}
const EXTRA_THEME := {
	23: {"escort": 1},
	24: {"escort": 1, "vanguard": 1},
	25: {"escort": 1, "vanguard": 1, "disruptor": 1},
	26: {"escort": 1, "vanguard": 1, "disruptor": 1, "static_crawler": 1},
	28: {"sludge": 1},
	29: {"sludge": 1, "rallier": 1},
	30: {"rallier": 1, "cloaker": 1},
	31: {"sludge": 1, "shade": 1, "cloaker": 1, "rallier": 1},
	32: {"shade": 1, "sludge": 1, "wraith": 1, "cloaker": 1},
	33: {"shade": 1, "wraith": 1, "vanguard": 1},
	35: {"sprinter": 1},
	36: {"sprinter": 1, "jammer": 1, "disruptor": 1},
	37: {"jammer": 1, "sprinter": 1},
	38: {"mender_elite": 1, "static_crawler": 1},
	39: {"prismling": 1, "jammer": 1, "mender_elite": 1, "wraith": 1},
	40: {"prismling": 1, "sprinter": 1, "vanguard": 1, "mender_elite": 1},
	11: {"diver": 1, "shade": 1, "wraith": 1, "rallier": 1},
	12: {"sprinter": 1, "jammer": 1, "disruptor": 1},
	13: {"sludge": 1, "shade": 1, "static_crawler": 1, "cloaker": 1},
	14: {"prismling": 1, "disruptor": 1, "mender_elite": 1},
	15: {"diver": 1, "escort": 1, "vanguard": 1, "rallier": 1},
	16: {"escort": 1, "sludge": 1, "static_crawler": 1, "mender_elite": 1},
	17: {"sprinter": 1, "jammer": 1, "disruptor": 1, "rallier": 1},
	18: {"shade": 1, "prismling": 1, "wraith": 1, "cloaker": 1, "vanguard": 1},
	19: {"diver": 1, "escort": 1, "vanguard": 2, "mender_elite": 1, "static_crawler": 1, "disruptor": 1},
}


func _rift_levels(levels: Array[LevelDef], all: Array[TowerDef], econ: EconomyConfig, M: Callable) -> void:
	# [n, name, objective, waves, start money, base hp, cores, theme, count scale, hp mult, boss line]
	var specs := [
		[10, "Rift Breach", "The Rift opens. Every enemy type at once — overload nodes are your edge.", 18, 700, 25, 30,
			{"drone": 3, "plated": 2, "glider": 2, "aegis": 2, "phantom": 1, "brute": 2, "swarm": 2, "mender": 1}, 0.6, 1.15, ""],
		[11, "Twin Fault", "Two entrances meet at the core. Night falls every third wave.", 18, 700, 25, 30,
			{"phantom": 3, "drone": 2, "dart": 2, "aegis": 2, "brute": 1, "glider": 1, "swarm": 2, "mender": 1}, 0.6, 1.2, ""],
		[12, "Fault Lines", "Gates switch between a long and a short lane. Fliers cut straight across.", 18, 720, 25, 30,
			{"glider": 3, "dart": 2, "plated": 2, "aegis": 2, "swarm": 2, "brute": 1, "phantom": 1, "mender": 1}, 0.6, 1.25, ""],
		[13, "Dark Spiral", "A long spiral in the dark. Light the lane with Beacons.", 20, 720, 25, 35,
			{"phantom": 3, "swarm": 3, "brute": 2, "plated": 2, "glider": 1, "aegis": 1, "mender": 2}, 0.6, 1.75, ""],
		[14, "Chimera", "The Chimera swaps armor for shields and jams your towers. Mix damage types.", 20, 750, 25, 45,
			{"aegis": 3, "plated": 3, "brute": 2, "glider": 2, "phantom": 1, "swarm": 1, "mender": 2}, 0.6, 1.3,
			"chimera*1@1.0#0, aegis*6@1.4+6#1, mender*3@2.6+10#0"],
		[15, "Three Gates", "Three lanes, one open at a time — and the middle one is short.", 20, 750, 25, 35,
			{"dart": 3, "drone": 2, "brute": 2, "aegis": 2, "phantom": 2, "glider": 2, "swarm": 1, "mender": 1}, 0.6, 1.15, ""],
		[16, "Pincer", "Two columns close in from north and south.", 20, 760, 25, 35,
			{"brute": 3, "plated": 2, "swarm": 2, "drone": 2, "glider": 2, "aegis": 2, "mender": 1, "phantom": 1}, 0.6, 1.8, ""],
		[17, "Shortcut", "A gate opens a shortcut straight to the core. Guard both.", 22, 780, 25, 40,
			{"dart": 3, "glider": 3, "drone": 2, "aegis": 2, "plated": 2, "phantom": 1, "swarm": 1, "mender": 1}, 0.6, 1.75, ""],
		[18, "Eclipse", "Darkness, stealth and shields from both flanks.", 22, 800, 25, 40,
			{"phantom": 3, "aegis": 3, "mender": 2, "plated": 2, "glider": 2, "brute": 1, "swarm": 1}, 0.6, 2.1, ""],
		[19, "Colossus", "The Colossus shields its escort, jumps through the Rift and overdrives in its last phase.", 25, 850, 30, 45, # first clear was 80
			{"brute": 2, "plated": 2, "aegis": 2, "glider": 2, "phantom": 1, "swarm": 2, "mender": 2, "dart": 1}, 0.6, 1.35,
			"colossus*1@1.0, plated*8@1.2+8, aegis*8@1.2+16, glider*14@0.7+24"],
	]
	for sp in specs:
		var n: int = sp[0]
		var map: MapDef = M.call("rift_%02d" % (n - 9))
		var l := _level(StringName("level_%02d" % n), "%d — %s" % [n, sp[1]], n, map, all, econ, sp[4], sp[5])
		l.objective = sp[2]
		l.cores_first_clear = sp[6]
		l.prep_time = 22.0
		l.waves = _waves(_rift_lines(n, map, sp[3], sp[7], sp[10], sp[9]), sp[8])
		levels.append(l)


const RIFT_OPENERS := ["drone", "dart", "swarm", "glider", "plated", "brute"]


## Levels 20-40: the 7 extra levels of Circuit, Delta and Prism (same generator as the Rift).
func _region_levels(levels: Array[LevelDef], t3: Array[TowerDef], all: Array[TowerDef], econ: EconomyConfig, M: Callable) -> void:
	var basic := {"drone": 3, "dart": 2, "swarm": 2, "brute": 2, "plated": 1, "glider": 1}
	# [id, map, name, objective, waves, money, hp, cores, towers, theme, scale, hp mult, boss line]
	var specs := [
		[20, "circuit_d", "Relay Yard", "Zig-zag lines meet at sharp corners. Build in the corners.", 12, 400, 20, 12, t3,
			{"drone": 3, "dart": 2, "swarm": 2, "brute": 1, "plated": 1}, 0.75, 0.9, ""],
		[21, "circuit_e", "Coil Maze", "A tight coil: one tower can cover two lanes.", 12, 400, 20, 12, t3,
			{"drone": 2, "dart": 2, "swarm": 2, "brute": 2, "plated": 2, "glider": 1}, 0.75, 0.95, ""],
		[22, "circuit_f", "Crossroads", "The lane crosses itself. Towers at the crossing hit twice.", 14, 450, 20, 15, all,
			{"drone": 2, "dart": 2, "swarm": 2, "brute": 2, "plated": 2, "glider": 2}, 0.7, 1.0, ""],
		[23, "circuit_g", "Step Down", "A staircase of short lanes with overload nodes. The armored Vanguard arrives to shield allied lines.", 14, 450, 20, 15, all,
			{"drone": 2, "dart": 2, "brute": 2, "plated": 2, "glider": 2, "swarm": 1}, 0.7, 1.05, ""],
		[24, "circuit_h", "Grid Lock", "Four long rows. The Disruptor arrives, jamming tower recharge rates along the corridors.", 15, 450, 20, 18, all,
			{"drone": 2, "dart": 1, "swarm": 2, "brute": 2, "plated": 2, "glider": 3}, 0.7, 1.05, ""],
		[25, "circuit_i", "Arc Furnace", "The lane wraps around the furnace. The Static Crawler pulses static fields, shrinking tower range.", 15, 450, 20, 18, all,
			{"drone": 2, "dart": 2, "swarm": 2, "brute": 2, "plated": 3, "glider": 2}, 0.34, 1.1, ""],
		[26, "circuit_j", "Dynamo", "The Dynamo shortens your towers' range, caps every hit and overloads at the end. Spread out and use many fast hits.", 16, 500, 25, 24, all, # first clear was 30
			{"drone": 2, "dart": 2, "swarm": 2, "brute": 2, "plated": 3, "glider": 2}, 0.6, 1.1,
			"dynamo*1@1.0, plated*6@1.4+6, brute*3@2.0+12"],
		[27, "delta_d", "Marsh Fork", "Two diagonal entrances meet early. Night falls every third wave.", 14, 500, 20, 18, all,
			{"drone": 3, "dart": 2, "plated": 2, "aegis": 2, "phantom": 1, "swarm": 1, "glider": 1}, 0.40, 1.0, ""],
		[28, "delta_e", "Twin Canal", "One column from north, one from west. The Rallier deploys speed haste bursts to advancing troops.", 14, 500, 20, 18, all,
			{"drone": 2, "brute": 2, "aegis": 2, "phantom": 2, "swarm": 2, "glider": 1, "mender": 1}, 0.32, 0.9, ""],
		[29, "delta_f", "Flood Plain", "Both columns pour in from top. The Cloaker shrouds nearby enemy packs in optical invisibility.", 15, 520, 20, 20, all,
			{"drone": 2, "dart": 2, "plated": 2, "aegis": 2, "phantom": 2, "glider": 2, "mender": 1}, 0.6, 1.0, ""],
		[30, "delta_g", "Reed Maze", "They rise from the south. Keep Beacons on the shared lane.", 15, 520, 20, 20, all,
			{"drone": 2, "swarm": 2, "brute": 2, "aegis": 2, "phantom": 3, "glider": 1, "mender": 1}, 0.65, 1.05, ""],
		[31, "delta_h", "Delta Bridge", "Steep diagonal bridges. The stealth Wraith darts in with tower-disabling EMP pulse charges.", 16, 540, 20, 22, all,
			{"drone": 2, "dart": 2, "plated": 2, "aegis": 2, "phantom": 2, "brute": 2, "glider": 2, "mender": 1}, 0.6, 1.05, ""],
		[32, "delta_i", "Mangrove", "The lane crosses the southern entrance. Watch both.", 16, 540, 20, 22, all,
			{"drone": 2, "swarm": 2, "plated": 2, "aegis": 3, "phantom": 2, "glider": 2, "mender": 2}, 0.55, 1.0, ""],
		[33, "delta_j", "Leviathan", "The Leviathan dives out of reach and raises your kills again. Hit hard while it surfaces.", 16, 560, 25, 32, all, # first clear was 40
			{"drone": 2, "dart": 2, "plated": 2, "aegis": 2, "phantom": 2, "brute": 2, "glider": 2, "mender": 2}, 0.45, 0.95,
			"leviathan*1@1.0#0, aegis*5@1.4+6#1, mender*2@2.6+10#0"],
		[34, "prism_d", "Facet Hall", "Two angled lanes around a crystal hall. Gates switch every five waves.", 16, 560, 20, 25, all,
			{"drone": 2, "dart": 2, "plated": 2, "aegis": 2, "phantom": 1, "glider": 2, "brute": 2, "mender": 1}, 0.6, 1.1, ""],
		[35, "prism_e", "Lens Array", "Two lens-shaped lanes around a crystal. The gate picks one.", 16, 560, 20, 25, all,
			{"drone": 3, "swarm": 2, "plated": 2, "aegis": 2, "brute": 2, "phantom": 1, "mender": 1}, 0.6, 1.2, ""],
		[36, "prism_f", "Refractor", "The Refractor sends mirror decoys ahead and resists one damage type at a time. Mix your towers.", 17, 580, 25, 33, all, # first clear was 35
			{"drone": 2, "dart": 2, "plated": 2, "aegis": 2, "phantom": 2, "glider": 2, "brute": 1, "mender": 1}, 0.6, 1.15,
			"refractor*1@1.0#-1, glider*8@0.8+5, plated*5@1.3+8#-1"],
		[37, "prism_g", "Split Beam", "The beam splits around the crystal. Mender Elites project wide restorative wave pulses.", 17, 580, 20, 25, all,
			{"drone": 3, "dart": 2, "brute": 2, "aegis": 2, "plated": 2, "glider": 1, "swarm": 1, "mender": 1}, 0.5, 1.0, ""],
		[38, "prism_h", "Kaleidoscope", "A loop or a shortcut through its middle, then a long tail.", 18, 600, 20, 28, all,
			{"drone": 2, "plated": 2, "aegis": 2, "phantom": 2, "glider": 2, "brute": 2, "swarm": 1, "mender": 1}, 0.6, 1.2, ""],
		[39, "prism_i", "Spectrum", "The northern gate adds a long detour; the southern one does not.", 18, 600, 20, 28, all,
			{"dart": 2, "plated": 2, "aegis": 2, "phantom": 2, "glider": 2, "brute": 2, "swarm": 2, "mender": 1}, 0.6, 1.45, ""],
		[40, "prism_j", "Helix", "North or south around the ring, then a spiral into the core.", 18, 620, 20, 30, all,
			{"drone": 2, "plated": 2, "aegis": 2, "phantom": 2, "glider": 2, "brute": 2, "swarm": 2, "mender": 2}, 0.6, 1.25, ""],
	]
	for sp in specs:
		var n: int = sp[0]
		var map: MapDef = M.call(sp[1])
		var l := _level(StringName("level_%02d" % n), "%d — %s" % [n, sp[2]], n, map, sp[8], econ, sp[5], sp[6])
		l.objective = sp[3]
		l.cores_first_clear = sp[7]
		if map.region_id() != &"circuit":
			l.prep_time = 22.0
		l.waves = _waves(_rift_lines(n, map, sp[4], sp[9], sp[12], sp[11]), sp[10])
		levels.append(l)


func _rift_lines(seed_n: int, map: MapDef, count: int, theme_in: Dictionary, boss_line: String, hp: float) -> Array:
	var theme := theme_in.duplicate()
	for k in EXTRA_THEME.get(seed_n, {}):
		theme[k] = EXTRA_THEME[seed_n][k]
	var intro: String = INTRO.get(seed_n, "")
	if intro != "":
		theme[intro] = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * seed_n
	var gates := map.dynamic_routes
	var dual := map.routes.size() > 1 and not gates
	var pool: Array[String] = []
	var openers: Array[String] = []
	for k in theme:
		for i in range(int(theme[k])):
			pool.append(k)
			if RIFT_OPENERS.has(k):
				openers.append(k)
	var lines: Array = []
	var waves := count - (1 if boss_line != "" else 0)
	var gate := 0
	for i in range(waves):
		var f := float(i) / maxf(waves - 1, 1)
		var special := i % 6 == 5 or i == waves - 1
		var n_groups := 2 if i < waves / 3 else 3
		var from := openers if i < 3 else pool # the first waves only use basic enemies
		var picked: Array[String] = []
		if intro != "" and (i == 3 or i == waves - 3 or (i > 3 and i % 4 == 0)): # the new enemy is introduced here
			picked.append(intro)
		var guard := 0
		while picked.size() < n_groups and guard < 100:
			guard += 1
			var k := from[rng.randi_range(0, from.size() - 1)]
			if picked.has(k) or (k == "mender" and picked.is_empty()):
				continue
			picked.append(k)
		var groups: Array[String] = []
		for gi in range(picked.size()):
			var k := picked[gi]
			var base: Array = RIFT_GROUPS[k]
			var c := int(round(float(base[0]) * (0.7 + 1.6 * f) * (1.25 if special else 1.0)))
			var g := "%s*%d@%s" % [k, maxi(c, 1), str(base[1])]
			if gi > 0:
				g += "+%d" % (3 * gi + rng.randi_range(0, 2))
			if k != "glider":
				if gates:
					g += "#-1"
				elif dual:
					g += "#%d" % ((i + gi) % 2)
			var whp := snappedf(hp * (0.7 + 0.5 * f), 0.01)
			if whp != 1.0:
				g += "!hp=%s" % str(whp)
			groups.append(g)
		var flags: Array[String] = []
		if special:
			flags.append("special")
		if map.day_night and i % 3 == 2:
			flags.append("night")
		if gates:
			var want := gate
			if i == 0:
				want = 0
			elif i % 5 == 0:
				want = (gate + 1) % map.routes.size()
			if i == 0 or want != gate:
				flags.append("route=%d" % want)
				gate = want
		lines.append(", ".join(groups) + (" | " + ", ".join(flags) if not flags.is_empty() else ""))
	if boss_line != "":
		var fl := "boss"
		if map.day_night:
			fl += ", night"
		lines.append(boss_line + " | " + fl)
	return lines


func _meta() -> void:
	# Tower research: one BRANCH_C (unlocks the 3rd branch) + one EVOLUTION node per tower whose
	# branches actually need it (checked against each tower's `requires_research` flags above).
	# Cost scales with rank, and varies a bit within a rank by how strong/central that tower is.
	var research: Array[ResearchDef] = [
		# C
		_research(&"branch_pulse_sensor", "Sensor Array", "Unlocks Pulse branch: Sensor.", ResearchDef.Kind.BRANCH_C, 45, &"pulse"),
		_research(&"evo_pulse", "Pulse Evolution", "Unlocks evolutions for Pulse branches.", ResearchDef.Kind.EVOLUTION, 90, &"pulse"),
		_research(&"branch_trap_minefield", "Minefield Protocol", "Unlocks Shock Trap branch: Minefield.", ResearchDef.Kind.BRANCH_C, 35, &"trap", 0, [], &"trap"),
		_research(&"evo_trap", "Shock Trap Evolution", "Unlocks evolutions for Shock Trap branches.", ResearchDef.Kind.EVOLUTION, 75, &"trap", 0, [], &"trap"),
		_research(&"branch_spotter_widescan", "Wide Scan Protocol", "Unlocks Marker branch: Wide Scan.", ResearchDef.Kind.BRANCH_C, 30, &"spotter", 0, [], &"spotter"),
		_research(&"evo_spotter", "Marker Evolution", "Unlocks evolutions for Marker branches.", ResearchDef.Kind.EVOLUTION, 65, &"spotter", 0, [], &"spotter"),
		# B
		_research(&"branch_nova_siege", "Siege Protocol", "Unlocks Nova branch: Siege.", ResearchDef.Kind.BRANCH_C, 55, &"nova"),
		_research(&"evo_nova", "Nova Evolution", "Unlocks evolutions for Nova branches.", ResearchDef.Kind.EVOLUTION, 110, &"nova"),
		_research(&"branch_beacon_relay", "Relay Network", "Unlocks Beacon branch: Relay.", ResearchDef.Kind.BRANCH_C, 50, &"beacon", 0, [], &"beacon"),
		_research(&"evo_beacon", "Beacon Evolution", "Unlocks evolutions for Beacon branches.", ResearchDef.Kind.EVOLUTION, 100, &"beacon", 0, [], &"beacon"),
		_research(&"branch_venom_spray", "Spray Protocol", "Unlocks Venom branch: Spray.", ResearchDef.Kind.BRANCH_C, 60, &"venom", 0, [], &"venom"),
		_research(&"evo_venom", "Venom Evolution", "Unlocks evolutions for Venom branches.", ResearchDef.Kind.EVOLUTION, 120, &"venom", 0, [], &"venom"),
		# A
		_research(&"branch_lance_focus", "Focus Lens", "Unlocks Lance branch: Focus.", ResearchDef.Kind.BRANCH_C, 70, &"lance", 0, [], &"lance"),
		_research(&"evo_lance", "Lance Evolution", "Unlocks evolutions for Lance branches.", ResearchDef.Kind.EVOLUTION, 140, &"lance", 0, [], &"lance"),
		_research(&"branch_sniper_spotter", "Spotter Protocol", "Unlocks Marksman branch: Spotter.", ResearchDef.Kind.BRANCH_C, 75, &"sniper", 0, [], &"sniper"),
		_research(&"evo_sniper", "Marksman Evolution", "Unlocks evolutions for Marksman branches.", ResearchDef.Kind.EVOLUTION, 150, &"sniper", 0, [], &"sniper"),
		_research(&"branch_bastion_exposure", "Exposure Protocol", "Unlocks Bastion branch: Exposure.", ResearchDef.Kind.BRANCH_C, 65, &"bastion", 0, [], &"bastion"),
		_research(&"evo_bastion", "Bastion Evolution", "Unlocks evolutions for Bastion branches.", ResearchDef.Kind.EVOLUTION, 130, &"bastion", 0, [], &"bastion"),
		# S (branches are already open; only the evolution needs research)
		_research(&"evo_storm", "Stormcaller Evolution", "Unlocks evolutions for Stormcaller branches.", ResearchDef.Kind.EVOLUTION, 220, &"storm", 0, [], &"storm"),
		_research(&"evo_chronos", "Chronos Evolution", "Unlocks evolutions for Chronos branches.", ResearchDef.Kind.EVOLUTION, 200, &"chronos", 0, [], &"chronos"),
		_research(&"reserve_1", "Reserve Funds I", "+25 starting currency.", ResearchDef.Kind.START_CURRENCY, 50, &"", 25),
		_research(&"reserve_2", "Reserve Funds II", "+25 more starting currency (+50 total).", ResearchDef.Kind.START_CURRENCY, 90, &"", 25, [&"reserve_1"]),
		_research(&"reinforced_core", "Reinforced Core", "+3 Base HP.", ResearchDef.Kind.BASE_HP, 60, &"", 3),
		_research(&"quick_deploy", "Quick Deploy", "Early-start bonus +25%.", ResearchDef.Kind.EARLY_BONUS, 40, &"", 0.25),
		_research(&"field_scanner", "Field Scanner", "Shows the next wave's composition during preparation.", ResearchDef.Kind.WAVE_PREVIEW, 25),
	]
	for r in research:
		_save(r, "res://data/meta/research/%s.tres" % r.id)

	var K := AchievementDef.Kind
	var achievements: Array[AchievementDef] = [
		_ach(&"flawless_circuit", "Clean Circuit", "Clear levels 1, 2 and 5 without losing Base HP.", K.FLAWLESS_LEVELS, {"levels": ["level_01", "level_02", "level_03"]}, 10),
		_ach(&"flawless_delta", "Night Watch", "Clear any Delta level without losing Base HP.", K.FLAWLESS_ON_MAP, {"map": "delta"}, 10),
		_ach(&"boss_sprint", "Monolith Breaker", "Defeat a boss within 90 s of its arrival.", K.BOSS_FAST, {"seconds": 90}, 15),
		_ach(&"duo", "Minimalist", "Win a level building only 2 tower types.", K.WIN_MAX_TOWER_TYPES, {"count": 2}, 10),
		_ach(&"no_nova", "No Fireworks", "Win level 5 or later without building Nova.", K.WIN_WITHOUT_TOWER, {"tower": "nova", "min_level": 5}, 10),
		_ach(&"evolver", "Full Evolution", "Evolve every tower type (lifetime).", K.LIFETIME_SET, {"counter": "evolved_types", "values": ["pulse", "nova", "lance", "beacon"]}, 15),
		_ach(&"synergist", "Synergist", "Trigger Grounded, Conductive, Shatter and Meltdown (lifetime).", K.LIFETIME_SET, {"counter": "interactions", "values": ["grounded", "conductive", "shatter", "meltdown"]}, 15),
		_ach(&"exterminator", "Exterminator", "Defeat 1000 Swarmlings (lifetime).", K.LIFETIME_COUNT, {"counter": "kills_swarmling", "target": 1000}, 10),
		_ach(&"close_call", "Close Call", "Win a level with exactly 1 Base HP left.", K.WIN_AT_MOST_HP, {"hp": 1}, 10),
		_ach(&"eager", "Eager", "Start 10 waves early in one level.", K.MATCH_COUNT, {"stat": "early_starts", "target": 10}, 5),
		_ach(&"campaign_clear", "Monolith Fallen", "Clear level 30.", K.CLEAR_LEVEL, {"level": "level_09"}, 20),
		_ach(&"rift_sealed", "Rift Sealed", "Clear level 40.", K.CLEAR_LEVEL, {"level": "level_19"}, 30),
		_ach(&"frugal", "Frugal Commander", "Clear level 30 without owning Reserve Funds I.", K.CLEAR_LEVEL_WITHOUT_RESEARCH, {"level": "level_09", "research": "reserve_1"}, 20),
	]
	for a in achievements:
		_save(a, "res://data/meta/achievements/%s.tres" % a.id)

	var L := func(n: int) -> LevelDef: return load("res://data/levels/level_%02d.tres" % n)
	var D := ChallengeDef.Period.DAILY
	var W := ChallengeDef.Period.WEEKLY
	var daily: Array[ChallengeDef] = [
		_chal(&"d_pulse_purist", "Pulse Purist", "Clear level 2 without Nova.", D, L.call(2), [&"nova"], -1, 1.0, false, -1, 10),
		_chal(&"d_glass_1", "Glass Core", "Clear level 1 with at most 5 Base HP.", D, L.call(1), [], 5, 1.0, false, -1, 8),
		_chal(&"d_lean_3", "Lean Budget", "Clear level 3 with 80% starting currency.", D, L.call(3), [], -1, 0.8, false, -1, 10),
		_chal(&"d_nosell_4", "No Refunds", "Clear level 4 without selling.", D, L.call(4), [], -1, 1.0, true, -1, 10),
		_chal(&"d_speed_2", "Rush Hour", "Clear level 2 within 8 minutes.", D, L.call(2), [], -1, 1.0, false, 480, 10),
		_chal(&"d_no_lance_4", "Blunt Force", "Clear level 4 without Lance.", D, L.call(4), [&"lance"], -1, 1.0, false, -1, 12),
		_chal(&"d_glass_5", "Thin Shield", "Clear level 5 with at most 8 Base HP.", D, L.call(5), [], 8, 1.0, false, -1, 12),
		_chal(&"d_lean_6", "Austerity", "Clear level 6 with 85% starting currency.", D, L.call(6), [], -1, 0.85, false, -1, 14),
		_chal(&"d_nosell_7", "Commitment", "Clear level 7 without selling.", D, L.call(7), [], -1, 1.0, true, -1, 12),
		_chal(&"d_no_pulse_3", "Heavy Metal", "Clear level 3 without Pulse.", D, L.call(3), [&"pulse"], -1, 1.0, false, -1, 12),
		_chal(&"d_glass_8", "Brittle", "Clear level 8 with at most 10 Base HP.", D, L.call(8), [], 10, 1.0, false, -1, 15),
		_chal(&"d_speed_1", "Sprint", "Clear level 1 within 6 minutes.", D, L.call(1), [], -1, 1.0, false, 360, 8),
	]
	var weekly: Array[ChallengeDef] = [
		_chal(&"w_glass_6", "Monolith on a Thread", "Clear level 6 with at most 10 Base HP.", W, L.call(6), [], 10, 1.0, false, -1, 30),
		_chal(&"w_nosell_9", "No Second Thoughts", "Clear level 9 without selling.", W, L.call(9), [], -1, 1.0, true, -1, 40),
		_chal(&"w_lean_7", "Short Supply", "Clear level 7 with 80% starting currency.", W, L.call(7), [], -1, 0.8, false, -1, 30),
		_chal(&"w_no_nova_8", "Precision Only", "Clear level 8 without Nova.", W, L.call(8), [&"nova"], -1, 1.0, false, -1, 35),
		_chal(&"w_glass_9", "Last Stand", "Clear level 9 with at most 15 Base HP.", W, L.call(9), [], 15, 1.0, false, -1, 40),
		_chal(&"w_lean_nosell_5", "Iron Discipline", "Clear level 5 with 85% currency and no selling.", W, L.call(5), [], -1, 0.85, true, -1, 30),
		_chal(&"w_speed_6", "Blitz", "Clear level 6 within 14 minutes.", W, L.call(6), [], -1, 1.0, false, 840, 30),
		_chal(&"w_no_pulse_4", "Ground War", "Clear level 4 without Pulse.", W, L.call(4), [&"pulse"], -1, 1.0, false, -1, 30),
	]
	for c in daily + weekly:
		_save(c, "res://data/meta/challenges/%s.tres" % c.id)

	var campaign := CampaignDef.new()
	var start_t: Array[StringName] = [&"pulse"]
	campaign.starting_towers = start_t
	var lv: Array[LevelDef] = []
	for id in ORDER:
		lv.append(load("res://data/levels/%s.tres" % id))
	campaign.levels = lv
	var rs: Array[ResearchDef] = []
	for r in research:
		rs.append(load("res://data/meta/research/%s.tres" % r.id))
	campaign.research = rs
	var ac: Array[AchievementDef] = []
	for a in achievements:
		ac.append(load("res://data/meta/achievements/%s.tres" % a.id))
	campaign.achievements = ac
	var dp: Array[ChallengeDef] = []
	for c in daily:
		dp.append(load("res://data/meta/challenges/%s.tres" % c.id))
	var wp: Array[ChallengeDef] = []
	for c in weekly:
		wp.append(load("res://data/meta/challenges/%s.tres" % c.id))
	campaign.daily_pool = dp
	campaign.weekly_pool = wp
	# Armory: every tower of a shop rank (S, SS) is sold there, in rank order
	var shop: Array[TowerDef] = []
	for rank in SHOP_RANKS:
		for f in DirAccess.get_files_at("res://data/towers"):
			if f.ends_with(".tres"):
				var td: TowerDef = load("res://data/towers/" + f)
				if td.rarity == StringName(rank):
					shop.append(td)
	campaign.shop_towers = shop
	campaign.flawless_bonus = int(round(5 * CORES_MULT))
	campaign.consumables = _consumables()
	_save(campaign, "res://data/campaign.tres")


## Armory consumables: one-shot items, no cooldown, bought with Cores, one use per item per match.
func _consumables() -> Array[ConsumableDef]:
	var defs := [
		# id, name, desc, icon, cost, kind, damage, radius, heal, freeze_dur, haste_mult, haste_dur
		[&"airstrike", "Airstrike", "Tap the map: instant 150 explosive damage in the area you pick.",
			"blast", 40, ConsumableDef.Kind.AIRSTRIKE, 150.0, 90.0, 0, 0.0, 1.0, 0.0],
		[&"repair_kit", "Repair Kit", "Instantly restores 3 Base HP.",
			"heart", 60, ConsumableDef.Kind.HEAL, 0.0, 0.0, 3, 0.0, 1.0, 0.0],
		[&"stasis_charge", "Stasis Charge", "Tap the map: freezes regular enemies in the area for 2 s (bosses only stagger).",
			"frost", 50, ConsumableDef.Kind.FREEZE, 0.0, 130.0, 0, 2.0, 1.0, 0.0],
		[&"overclock", "Overclock", "Every tower fires 25% faster for 8 s.",
			"fast", 35, ConsumableDef.Kind.HASTE, 0.0, 0.0, 0, 0.0, 1.25, 8.0],
	]
	var out: Array[ConsumableDef] = []
	for r in defs:
		var c := ConsumableDef.new()
		c.id = r[0]
		c.display_name = r[1]
		c.description = r[2]
		c.icon = r[3]
		c.cost = r[4]
		c.kind = r[5]
		c.damage = r[6]
		c.radius = r[7]
		c.heal_amount = r[8]
		c.freeze_duration = r[9]
		c.haste_mult = r[10]
		c.haste_duration = r[11]
		c.targeted = c.kind == ConsumableDef.Kind.AIRSTRIKE or c.kind == ConsumableDef.Kind.FREEZE
		_save(c, "res://data/meta/items/%s.tres" % c.id)
		out.append(c)
	return out


# ================================================================ data catalogs
## Stats, damage types and effects live in data so new content only adds entries.

## Difficulty-model threat factors (DifficultyModel): a new enemy declares its own here.
const THREAT := {
	"glider": 1.2, "phantom": 1.3, "mender": 1.3, "escort": 1.2, "sludge": 1.3, "shade": 1.5, "sprinter": 1.15,
	"jammer": 1.2, "prismling": 1.2, "diver": 1.25, "warden": 1.3, "carrier": 1.3, "monolith": 1.3, "chimera": 1.3,
	"colossus": 1.4, "dynamo": 1.3, "leviathan": 1.35, "refractor": 1.3,
	"aegis": 1.2, # jam skill (2026-11-18): its shield was counted, the skill was not
	"brute": 2.5, # reactive armor: small hits deal 40% -> up to 2.5x tankier (2026-11-18: was 1.3, L2 too dense)
}


func _catalogs() -> void:
	var T := StatDef.Owner.TOWER
	var EN := StatDef.Owner.ENEMY
	var MX := StatDef.Stack.MAX
	var OR := StatDef.Stack.OR
	# [id, label, owner, stack, unit, percent, shown]
	var rows := [
		["damage", "Damage", T, MX, "", false, true], ["fire_rate", "Fire rate", T, MX, "/s", false, true],
		["attack_range", "Range", T, MX, "px", false, true], ["armor_pen", "Armor pen", T, MX, "", false, true],
		["splash_radius", "Splash", T, MX, "px", false, true], ["can_target_air", "Hits air", T, OR, "", false, true],
		["air_damage_mult", "Vs air", T, MX, "x", false, true], ["boss_mult", "Vs boss", T, MX, "x", false, true],
		["tag_mult", "Vs tag", T, StatDef.Stack.OVERRIDE, "x", false, true],
		["on_hit_effects", "On hit", T, StatDef.Stack.OVERRIDE, "", false, true],
		["amp_damage", "Buff dmg", T, MX, "", true, true], ["amp_range", "Buff range", T, MX, "", true, true],
		["amp_rate", "Buff rate", T, MX, "", true, true], ["slow", "Slow", T, MX, "", true, true],
		["beam_dps", "Beam", T, MX, "/s", false, true], ["beam_pierce", "Beam pierce", T, OR, "", false, true],
		["ramp_max", "Ramp", T, MX, "x", false, true], ["ramp_time", "Ramp time", T, MX, "s", false, false],
		["bomblets", "Bomblets", T, MX, "", false, true], ["bomblet_damage", "Bomblet dmg", T, MX, "", false, true],
		["burn_dps", "Burn", T, MX, "/s", false, true], ["burn_duration", "Burn time", T, MX, "s", false, false],
		["fire_patch_duration", "Fire patch", T, MX, "s", false, true], ["fire_patch_radius", "Patch size", T, MX, "px", false, false],
		["death_explosion", "Death blast", T, MX, "", false, true], ["shred", "Shred", T, MX, "", false, true],
		["shred_cap", "Shred cap", T, MX, "", false, false], ["stagger", "Stagger", T, MX, "s", false, true],
		["stun_every", "Stun every", T, MX, "", false, true], ["stun_duration", "Stun", T, MX, "s", false, true],
		["echo_every", "Echo every", T, MX, "", false, true], ["echo_delay", "Echo delay", T, MX, "s", false, false],
		["crit_every", "Crit every", T, MX, "", false, true], ["crit_mult", "Crit", T, MX, "x", false, true],
		["burst_every", "Burst every", T, MX, "", false, true], ["burst_count", "Burst", T, MX, "", false, true],
		["pierce", "Pierce", T, MX, "", false, true], ["chain", "Chain", T, MX, "", false, true],
		["chain_falloff", "Chain dmg", T, MX, "", true, false], ["chain_shield_mult", "Chain vs shield", T, MX, "x", false, true],
		["chain_stagger", "Chain stagger", T, MX, "s", false, true], ["conductive", "Conductive", T, OR, "", false, true],
		["conductive_bonus", "Conductive jumps", T, MX, "", false, true], ["mark", "Mark", T, MX, "", true, true],
		["mark_duration", "Mark time", T, MX, "s", false, false], ["ground_marked_fliers", "Ground fliers", T, MX, "s", false, true],
		["reveal_radius", "Reveal", T, MX, "px", false, true], ["freeze_every", "Freeze every", T, MX, "s", false, true],
		["freeze_duration", "Freeze", T, MX, "s", false, true], ["shatter", "Shatter", T, MX, "", true, true],
		["wave_income", "Wave income", T, MX, "", false, true], ["bounty_bonus", "Kill bonus", T, MX, "", false, true],
		["mint_amount", "Mint", T, MX, "", false, true], ["mint_interval", "Mint every", T, MX, "s", false, false],
		["trap_duration", "Trap time", T, MX, "s", false, true], ["trap_radius", "Trap size", T, MX, "px", false, true],
		["trap_slow_pct", "Trap slow", T, MX, "", true, true], ["trap_dps", "Trap damage", T, MX, "/s", false, true],
		["trap_stop", "Trap hold", T, OR, "", false, true], ["trap_vuln", "Trap exposure", T, MX, "x", false, true],
		["venom_dps", "Poison", T, MX, "/s", false, true], ["venom_stacks", "Poison stacks", T, MX, "", false, true],
		["venom_duration", "Poison time", T, MX, "s", false, false], ["venom_armor", "Corrode", T, MX, "", false, true],
		["venom_vuln", "Poison exposure", T, MX, "x", false, true], ["venom_slow_pct", "Poison slow", T, MX, "", true, true],
		["venom_patch_radius", "Cloud size", T, MX, "px", false, true], ["venom_patch_duration", "Cloud time", T, MX, "s", false, true],
		["spot_vuln", "Mark", T, MX, "x", false, true], ["spot_duration", "Mark time", T, MX, "s", false, false],
		["spot_armor", "Mark armor break", T, MX, "", false, true], ["spot_slow_pct", "Mark slow", T, MX, "", true, true],
		["spot_reveal", "Reveal", T, MX, "s", false, true],
		["field", "Field", T, OR, "", false, false], ["field_slow_pct", "Field slow", T, MX, "", true, true],
		["field_vuln", "Field exposure", T, MX, "x", false, true],
		["max_hp", "HP", EN, MX, "", false, true], ["speed", "Speed", EN, MX, "px/s", false, true],
		["armor", "Armor", EN, MX, "", false, true], ["shield", "Shield", EN, MX, "", false, true],
		["reactive_threshold", "Reactive armor", EN, MX, "", false, true],
		["bounty", "Bounty", EN, MX, "", false, true], ["base_damage", "Base damage", EN, MX, "", false, true],
	]
	var cat := StatCatalog.new()
	var list: Array[StatDef] = []
	for r in rows:
		var d := StatDef.new()
		d.id = StringName(r[0])
		d.label = r[1]
		d.owner = r[2]
		d.stack = r[3]
		d.unit = r[4]
		d.percent = r[5]
		d.shown = r[6]
		list.append(d)
	cat.stats = list
	_save(cat, StatCatalog.PATH)

	var rc := RarityCatalog.new()
	var ranks: Array[RarityDef] = []
	var rk := [["C", "Common", "Standard issue: cheap and simple.", "9fb0cf", "62738f"],
		["B", "Uncommon", "Specialised: strong at one job.", "4de6a1", "2a9d6c"],
		["A", "Rare", "Powerful specialists.", "4d8cff", "2d5bbf"],
		["S", "Epic", "Elite towers: collect blueprint shards from bosses or ads, then buy them in the Armory.", "a66bff", "ff5ce1"],
		["SS", "Legendary", "The rarest towers. Reserved for the hardest challenges.", "ffaa45", "ff5368"]]
	for i in range(rk.size()):
		var r := RarityDef.new()
		r.id = StringName(rk[i][0])
		r.display_name = rk[i][1]
		r.description = rk[i][2]
		r.color = Color(rk[i][3])
		r.accent = Color(rk[i][4])
		r.order = i
		r.shard_cost = int(SHOP_RANKS.get(rk[i][0], [0, 0])[0])
		r.core_price = int(SHOP_RANKS.get(rk[i][0], [0, 0])[1])
		ranks.append(r)
	rc.ranks = ranks
	_save(rc, RarityCatalog.PATH)

	var dmg := DamageCatalog.new()
	var types: Array[DamageTypeDef] = []
	# Poison and Plasma added before True (2026-11-16, user: real elemental diversity, not one
	# formula reskinned): ignores_armor means "defaults to 0 armor unless an enemy's armor_by_type
	# overrides it" (True is the only unconditional one, a special case in code). Columns:
	# [id, name, color, vs_shield, ignores_armor, ignores_shield, flat_pierce]. Explosive's
	# flat_pierce is its own innate shrapnel pierce, independent of whatever tower fires it.
	for r in [["kinetic", "Kinetic", "e6ebf5", 1.0, false, false, 0.0],
			["explosive", "Explosive", "ffaa45", 1.0, false, false, 3.0],
			["energy", "Energy", "a66bff", 2.0, false, false, 0.0],
			["poison", "Poison", "8be36a", 1.0, true, false, 0.0],
			["plasma", "Plasma", "5be3ff", 1.0, false, true, 0.0],
			["true", "True", "ff5368", 1.0, true, false, 0.0]]:
		var t := DamageTypeDef.new()
		t.id = StringName(r[0])
		t.display_name = r[1]
		t.color = Color(r[2])
		t.vs_shield = r[3]
		t.ignores_armor = r[4]
		t.ignores_shield = r[5]
		t.flat_pierce = r[6]
		types.append(t)
	dmg.types = types
	_save(dmg, DamageCatalog.PATH)

	# built-in statuses (rules in code; listed for UI / Codex) + data-only effects
	var fx := [
		["slow", "Slow", "Moves slower inside a Beacon aura (Cryo: stronger).", "slow", "8fd3ff", true, {}],
		["mark", "Mark", "Takes extra damage from every source.", "mark", "ff5368", true, {}],
		["burn", "Burn", "Damage over time that ignores armor; heals 50% less.", "burn", "ffaa45", true, {}],
		["shred", "Shred", "Armor reduced; stacks up to a cap.", "shred", "ffe07a", true, {}],
		["stun", "Stun", "Cannot move. Bosses only stagger.", "stun", "ffe07a", true, {}],
		["freeze", "Freeze", "Frozen solid; explosive hits shatter it for bonus damage.", "freeze", "8fd3ff", true, {}],
		["stagger", "Stagger", "Briefly slowed (what bosses get instead of stun).", "stun", "ffe07a", true, {}],
		["grounded", "Grounded", "A flier forced down: ground towers can hit it.", "grounded", "4de6a1", true, {}],
		["reveal", "Revealed", "A stealthed enemy that towers can now target.", "revealed", "ffffff", true, {}],
		["haste", "Haste", "Runs faster (Colossus overdrive).", "fast", "ff5368", true, {}],
		["overshield", "Overshield", "Temporary shield that absorbs damage first.", "heart", "ffaa45", true, {}],
		["cloak", "Cloak", "Untargetable until revealed; splash still hits.", "night", "a66bff", true, {}],
		["submerge", "Submerged", "Untargetable and immune to all damage.", "night", "4d8cff", true, {}],
		["hit_cap", "Capacitor", "Every hit deals at most a fixed amount.", "bolt", "38d9f5", true, {}],
		["prismatic", "Prismatic shield", "Resists one damage type at a time.", "star", "a66bff", true, {}],
		["emp", "EMP", "Tower cannot attack.", "bolt", "ff5368", true, {}],
		["jam", "Jammed", "Tower recharges at half speed.", "clock", "ffaa45", true, {}],
		["static", "Static", "Tower range reduced.", "range", "38d9f5", true, {}],
		# data-only sample (not used by any level yet): proves new effects need no code
		["sludge_regen", "Regeneration", "Heals a little every second.", "heart", "9be07a", true, {"regen_frac": 0.035, "duration": 3.2}],
		["shock", "Shock", "Slowed and zapped while standing on a trap.", "bolt", "ffd84d", true, {}],
		["venom", "Venom", "Stacking poison that ignores armor (Venom tower).", "burn", "8be36a", true, {}],
		["spot", "Spotted", "Marked by a Marker: takes extra damage from every tower.", "mark", "ff7a9a", true, {}],
		["field", "Field", "Bastion field: towers inside ignore EMP, jamming and debuffs.", "upgrade", "7fb2ff", true, {}],
		["poison", "Poison", "Damage over time; stacks up to 5 times.", "burn", "7ee06b", false,
			{"dot_dps": 4.0, "dot_type": "true", "stacking": 2, "max_stacks": 5, "duration": 4.0}],
	]
	for r in fx:
		var e := EffectDef.new()
		e.id = StringName(r[0])
		e.display_name = r[1]
		e.description = r[2]
		e.icon = r[3]
		e.color = Color(r[4])
		e.builtin = r[5]
		var comp: Dictionary = (r[6] as Dictionary).duplicate()
		if comp.has("stacking"):
			e.stacking = int(comp["stacking"])
			comp.erase("stacking")
		if comp.has("max_stacks"):
			e.max_stacks = int(comp["max_stacks"])
			comp.erase("max_stacks")
		if comp.has("duration"):
			e.duration = float(comp["duration"])
			comp.erase("duration")
		if r[0] in ["emp", "jam", "static"]:
			e.target = EffectDef.Target.TOWER
		e.components = comp
		_save(e, "res://data/effects/%s.tres" % r[0])


# ================================================================ wave DSL
## Wave string: "<group>, <group> | flag, flag"
## group: enemy*count@interval[+delay][~variance][#route][!hp=x][!ph=n][!dmg=n]
##   #-1 = the currently open gate route (Prism). Fliers use the air route.
## flags: special, boss, night, route=N (open gate N from this wave), prep=S
## Non-special groups with count >= 6 get a default ±10% count variance and ±10% interval jitter.

var _rx: RegEx


var _count_scale := 1.0


## `scale` multiplies every non-boss group count (authoring-time tuning knob; output data is concrete).
func _waves(lines: Array, scale: float = 1.0, hp: float = 1.0) -> Array[WaveDef]:
	_count_scale = scale
	var out: Array[WaveDef] = []
	for line in lines:
		var w := _parse_wave(line)
		if hp != 1.0:
			for g in w.groups:
				if not g.enemy.is_boss:
					g.hp_multiplier *= hp
		out.append(w)
	_count_scale = 1.0
	return out


func _parse_wave(line: String) -> WaveDef:
	if _rx == null:
		_rx = RegEx.new()
		_rx.compile("^(\\w+)\\*(\\d+)@([\\d.]+)(?:\\+([\\d.]+))?(?:~([\\d.]+))?(?:#(-?\\d+))?(.*)$")
	var parts := line.split("|")
	var w := WaveDef.new()
	if parts.size() > 1:
		for f in parts[1].split(","):
			var flag := f.strip_edges()
			if flag == "special": w.is_special = true
			elif flag == "boss": w.is_boss = true
			elif flag == "night": w.night = true
			elif flag.begins_with("route="): w.active_route = int(flag.substr(6))
			elif flag.begins_with("prep="): w.prep_time_override = float(flag.substr(5))
			elif flag != "": push_error("unknown wave flag: " + flag)
	var groups: Array[SpawnGroupDef] = []
	for gs in parts[0].split(","):
		var m := _rx.search(gs.strip_edges())
		if m == null:
			push_error("bad group: " + gs)
			continue
		var g := SpawnGroupDef.new()
		g.enemy = E[m.get_string(1)]
		g.count = int(m.get_string(2))
		if g.enemy.is_boss == false:
			g.count = maxi(1, int(round(g.count * _count_scale)))
		g.interval = float(m.get_string(3))
		if m.get_string(4) != "": g.start_delay = float(m.get_string(4))
		if m.get_string(5) != "":
			g.count_variance = float(m.get_string(5))
		elif not (w.is_special or w.is_boss) and g.count >= 6:
			g.count_variance = 0.1
		g.interval_jitter = 0.1 if g.count_variance > 0.0 else 0.0
		if m.get_string(6) != "": g.route_index = int(m.get_string(6))
		for opt in m.get_string(7).split("!", false):
			var kv := opt.split("=")
			match kv[0]:
				"hp": g.hp_multiplier = float(kv[1])
				"ph": g.max_boss_phases = int(kv[1])
				"dmg": g.base_damage_override = int(kv[1])
		groups.append(g)
	w.groups = groups
	return w


# ================================================================ helpers

## +5% kill money (user request, 2026-11-14): picked over +10% because the 40 levels were just
## tuned to win narrowly (5-10% Base HP); a bigger income bump risks loosening several of them past
## that band. Applied here (not per-enemy) so every enemy's listed bounty below is still its base
## design value.
## Lowered 1.05->1.0185 (2026-11-15, user feedback: wants 3% less money from kills on top of the
## existing +5%, alongside a -10% tower damage nerf, and will playtest the result themselves).
const BOUNTY_MULT := 1.0185


## +5% HP / speed / armor on every enemy. It was in the generated .tres but not in this script, so a regen
## (2026-11-18) wiped it; restored here so it survives future regens.
const ENEMY_STAT_MULT := 1.05
## +30% on every Core reward: first clears (so replays / defeats too), achievements, challenges
## (2026-11-18, user: research took too long to afford).
const CORES_MULT := 1.3


func _enemy(id: StringName, n: String, cat: EnemyDef.Category, hp: float, spd: float, armor: float, bounty: int,
		dmg: int, radius: float, col: String, shape: EnemyDef.Shape) -> EnemyDef:
	var e := EnemyDef.new()
	e.id = id
	e.display_name = n
	e.category = cat
	e.max_hp = snappedf(hp * ENEMY_STAT_MULT, 0.1)
	e.speed = snappedf(spd * ENEMY_STAT_MULT, 0.1)
	e.armor = snappedf(armor * ENEMY_STAT_MULT, 0.1)
	e.bounty = maxi(1, int(round(bounty * BOUNTY_MULT)))
	e.base_damage = dmg
	e.radius = radius
	e.color = Color(col)
	e.shape = shape
	return e


func _tower(id: StringName, n: String, role: String, cost: int, dmg: float, type: int, rate: float, rng: float,
		splash: float, proj_speed: float, homing: bool, air: bool, rule: TowerDef.TargetRule, col: String,
		shape: TowerDef.Shape) -> TowerDef:
	var t := TowerDef.new()
	t.id = id
	t.display_name = n
	t.role = role
	t.cost = cost
	t.damage = dmg
	t.damage_type = type
	t.fire_rate = rate
	t.attack_range = rng
	t.splash_radius = splash
	t.projectile_speed = proj_speed
	t.homing = homing
	t.can_target_air = air
	t.targeting = rule
	t.color = Color(col)
	t.shape = shape
	return t


func _branch(id: StringName, n: String, desc: String, research: bool, tiers: Array, evo: TierDef) -> BranchDef:
	var b := BranchDef.new()
	b.id = id
	b.display_name = n
	b.description = desc
	b.requires_research = research
	var typed: Array[TierDef] = []
	for t in tiers:
		typed.append(t)
	b.tiers = typed
	b.evolution = evo
	return b


func _tier(n: String, desc: String, cost: int, stats: Dictionary) -> TierDef:
	var t := TierDef.new()
	t.display_name = n
	t.description = desc
	t.cost = cost
	t.stats = stats
	return t


## Flat -10% to every tower's damage output, base + every branch tier/evolution override, except
## Venom (2026-11-15, user feedback: Nova/other towers still feel too strong vs Venom; user wants to
## test a broad damage nerf on everything but Venom rather than another one-off Nova tweak).
const DAMAGE_NERF := 0.9
const DAMAGE_STAT_KEYS := ["damage", "beam_dps", "trap_dps", "burn_dps", "bomblet_damage"]


func _nerf_tower_damage(t: TowerDef) -> void:
	t.damage *= DAMAGE_NERF
	for k in DAMAGE_STAT_KEYS:
		if t.base_params.has(k):
			t.base_params[k] = t.base_params[k] * DAMAGE_NERF
	for b in t.branches:
		for tier in b.tiers:
			for k in DAMAGE_STAT_KEYS:
				if tier.stats.has(k):
					tier.stats[k] = tier.stats[k] * DAMAGE_NERF
		for k in DAMAGE_STAT_KEYS:
			if b.evolution.stats.has(k):
				b.evolution.stats[k] = b.evolution.stats[k] * DAMAGE_NERF


## Big "more towers" remake (2026-11-15): base cost, tier/evolution costs, and every damage-output
## stat (base + branch tiers/evolution) all scaled by the SAME factor, for every tower including
## Venom. Originally tier/evolution COSTS were left untouched on purpose (so maxing a tower became a
## worse deal than spreading money across more towers, without needing to re-tune any level's
## difficulty); the user explicitly asked to scale upgrade costs down too ("giảm luôn đi") despite
## that trade-off, so the asymmetry no longer applies -- this is now a flat economy-wide halving.
## A bot-sim check of the cost+damage halving alone already wiped out nearly every campaign level;
## the user has explicitly accepted that risk and wants to playtest it themselves rather than wait on
## another multi-hour balance sim. Only correctness tests (parse/crash/assert regressions) are run
## for this change, not a balance/completability check.
const REMAKE_SCALE := 0.5
const BASE_COST_SCALE := 1.15
const UPGRADE_SCALE := 1.15
const REMAKE_DAMAGE_KEYS := ["damage", "beam_dps", "trap_dps", "burn_dps", "bomblet_damage", "venom_dps"]


func _remake_scale_tower(t: TowerDef) -> void:
	t.cost = maxi(1, int(round(t.cost * REMAKE_SCALE * BASE_COST_SCALE)))
	t.damage *= REMAKE_SCALE
	for k in REMAKE_DAMAGE_KEYS:
		if t.base_params.has(k):
			t.base_params[k] = t.base_params[k] * REMAKE_SCALE
	for b in t.branches:
		for i in range(b.tiers.size()):
			var tier = b.tiers[i]
			var tier_mult := 1.0
			if i == 1:
				tier_mult = 1.05 # tier 2: +5%
			elif i == 2:
				tier_mult = 1.10 # tier 3: +10%
			tier.cost = maxi(1, int(round(tier.cost * REMAKE_SCALE * UPGRADE_SCALE * tier_mult)))
			for k in REMAKE_DAMAGE_KEYS:
				if tier.stats.has(k):
					tier.stats[k] = tier.stats[k] * REMAKE_SCALE
		b.evolution.cost = maxi(1, int(round(b.evolution.cost * REMAKE_SCALE * UPGRADE_SCALE * 1.20))) # evolution: +20%
		for k in REMAKE_DAMAGE_KEYS:
			if b.evolution.stats.has(k):
				b.evolution.stats[k] = b.evolution.stats[k] * REMAKE_SCALE


func _level(id: StringName, n: String, num: int, map: MapDef, towers: Array[TowerDef], econ: EconomyConfig,
		money: int, hp: int) -> LevelDef:
	var l := LevelDef.new()
	l.id = id
	l.display_name = n
	l.level_number = num
	l.map = map
	l.available_towers = towers
	l.economy = econ
	l.starting_currency = money
	l.base_hp = hp
	return l


func _research(id: StringName, n: String, desc: String, kind: ResearchDef.Kind, cost: int, tower: StringName = &"",
		value: float = 0.0, requires: Array[StringName] = [], requires_tower: StringName = &"") -> ResearchDef:
	var r := ResearchDef.new()
	r.id = id
	r.display_name = n
	r.description = desc
	r.kind = kind
	r.cost = cost
	r.tower_id = tower
	r.value = value
	r.requires = requires
	r.requires_tower = requires_tower
	r.category = &"tower" if tower != &"" else &"support"
	return r


func _ach(id: StringName, n: String, desc: String, kind: AchievementDef.Kind, params: Dictionary, cores: int) -> AchievementDef:
	var a := AchievementDef.new()
	a.id = id
	a.display_name = n
	a.description = desc
	a.kind = kind
	a.params = params
	a.cores = int(round(cores * CORES_MULT))
	return a


func _chal(id: StringName, n: String, desc: String, period: ChallengeDef.Period, level: LevelDef,
		banned: Array[StringName], hp_cap: int, cur_mult: float, no_sell: bool, max_s: float, cores: int) -> ChallengeDef:
	var c := ChallengeDef.new()
	c.id = id
	c.display_name = n
	var rx := RegEx.new() # the level's campaign position (ids are stable, positions moved in the 40-level order)
	rx.compile("level \\d+")
	c.description = rx.sub(desc, "level %d" % level.level_number)
	c.period = period
	c.level = level
	c.banned_towers = banned
	c.base_hp_cap = hp_cap
	c.currency_multiplier = cur_mult
	c.no_selling = no_sell
	c.max_seconds = max_s
	c.cores = int(round(cores * CORES_MULT))
	return c


## Tankier = slower (2026-11-18, user: applies to every regular enemy). Effective HP (HP x armour factor
## + shield, same as DifficultyModel.enemy_pressure) caps the speed: speed <= SPEED_CAP_K * sqrt(SPEED_CAP_REF / ehp),
## never below SPEED_CAP_FLOOR. Light enemies sit under the curve and keep their speed. Bosses have their own rule.
const SPEED_CAP_K := 42.0
const SPEED_CAP_REF := 300.0
const SPEED_CAP_FLOOR := 30.0
const SPEED_CAP_FROM_EHP := 120.0


static func speed_cap(e: EnemyDef) -> float:
	var armor_f := DifficultyModel.REF_HIT / maxf(DifficultyModel.REF_HIT - e.armor, DifficultyModel.REF_HIT * 0.25)
	var ehp := e.max_hp * armor_f + e.shield
	if ehp < SPEED_CAP_FROM_EHP:
		return INF
	return maxf(SPEED_CAP_FLOOR, SPEED_CAP_K * sqrt(SPEED_CAP_REF / ehp))


func _save(res: Resource, path: String) -> void:
	if res is EnemyDef and THREAT.has(String((res as EnemyDef).id)):
		(res as EnemyDef).threat_mult = THREAT[String((res as EnemyDef).id)]
	if res is EnemyDef and (res as EnemyDef).category != EnemyDef.Category.BOSS:
		var en := res as EnemyDef
		en.speed = minf(en.speed, snappedf(speed_cap(en), 0.1))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, error_string(err)])
	else:
		res.take_over_path(path)
