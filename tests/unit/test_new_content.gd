extends TestCase
## 8 towers / 16 enemies content: rank power rule, new tower mechanics, new enemy skills, unlock on entry.


## Single-target damage per second per credit spent, with every tier of `branch` (+ evolution) bought.
static func _dps_per_cost(def: TowerDef, branch: int, tiers: int, evolved: bool) -> float:
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
	var rate := t.pf("fire_rate")
	var crit_every := int(t.pf("crit_every"))
	if crit_every > 0:
		dmg *= 1.0 + (maxf(t.pf("crit_mult"), 1.0) - 1.0) / crit_every
	var dps := dmg * rate + t.pf("beam_dps") * maxf(t.pf("ramp_max"), 1.0)
	dps += t.pf("venom_dps") * maxf(t.pf("venom_stacks"), 1.0) + t.pf("trap_dps") + t.pf("burn_dps")
	t.free()
	return dps / cost


static func _best(def: TowerDef) -> float:
	var best := _dps_per_cost(def, -1, 0, false)
	for b in range(def.branches.size()):
		for k in range(1, 4):
			best = maxf(best, _dps_per_cost(def, b, k, false))
		best = maxf(best, _dps_per_cost(def, b, 3, true))
	return best


func test_new_towers_never_beat_the_strongest_of_their_rank() -> void:
	var peers := {&"C": [&"pulse"], &"B": [&"nova", &"beacon"], &"A": [&"lance"]}
	# Venom is exempt (2026-11-15, user feedback): every tower but Venom took a flat -10% damage
	# nerf, so Venom now legitimately sits above the rank-B cap derived from the nerfed peers —
	# that's the intended outcome, not power creep.
	for id in [&"trap", &"sniper", &"spotter"]:
		var d := real_tower(String(id))
		var cap := 0.0
		for p in peers[d.rarity]:
			cap = maxf(cap, _best(real_tower(String(p))))
		var mine := _best(d)
		check(mine <= cap + 0.0001, "%s (rank %s) best DPS/credit %.3f <= rank cap %.3f" % [id, d.rarity, mine, cap])
	eq(real_tower("bastion").damage, 0.0, "Bastion deals no damage")
	for t in ["trap", "venom", "sniper", "bastion", "spotter"]:
		check(real_tower(t).rarity in [&"C", &"B", &"A"], "first release: no S / SS towers")


func test_shock_trap_slows_and_zaps_ground_only() -> void:
	var m := make_lab()
	var e := put(m, real_enemy("brute", 0.0), 400)
	e.def = e.def.duplicate()
	e.def.speed = 40.0
	var t := m.try_build(real_tower("trap"), Vector2(400, 360))
	var spd := e.def.speed
	run(m, 3.0)
	check(not m.zones.is_empty(), "a trap is on the lane")
	check(e.current_speed() < spd * 0.7, "slowed on the trap (%.1f)" % e.current_speed())
	check(e.hp < e.max_hp, "zapped")
	check(not real_tower("trap").can_target_air, "ground only")


func test_venom_stacks_and_ignores_armor() -> void:
	var m := make_lab()
	var e := put(m, real_enemy("plated", 0.0), 400)
	var t := m.try_build(real_tower("venom"), Vector2(400, 380))
	run(m, 4.0)
	var inst: Variant = null
	for k in e.effects:
		if String(k).begins_with("venom"):
			inst = e.effects[k]
	check(inst != null, "poisoned")
	eq(int(inst["stacks"]), 4, "4 stacks at base")
	check(e.hp < e.max_hp - 8.0, "poison ignores Plated's 8 armor") # venom_dps halved by the tower-spam remake


## Regression: Drone has an armor_by_type override (resists Poison specifically) to demonstrate
## the per-type armor system end to end -- Venom should do noticeably less to a Drone than to an
## enemy with the same HP/armor but no override.
func test_venom_does_less_to_an_enemy_with_a_poison_armor_override() -> void:
	var m := make_lab()
	var drone := put(m, real_enemy("drone", 0.0), 400) # armor_by_type = {"poison": 6.0}
	var drone_hp: float = drone.def.max_hp
	var drone_armor: float = drone.def.armor
	var plain := put(m, make_enemy_def(drone_hp, 0.0, drone_armor), 900) # same hp/armor, no override
	m.try_build(real_tower("venom"), Vector2(400, 380))
	m.try_build(real_tower("venom"), Vector2(900, 380)) # far apart: each tower only reaches its own target
	m.registry.rebuild(m.enemies)
	run(m, 4.0)
	var drone_drop := drone.max_hp - drone.hp
	var plain_drop := plain.max_hp - plain.hp
	check(drone_drop < plain_drop, "poison does less to the resistant Drone (%.1f < %.1f)" % [drone_drop, plain_drop])


## Regression: Spotter's Plasma shots must skip the shield bar entirely (straight to HP), not just
## multiply into it like Energy does.
func test_spotter_plasma_bypasses_shield_straight_to_hp() -> void:
	var m := make_lab()
	var e := put(m, real_enemy("aegis", 0.0), 400)
	var shield_before := e.shield
	m.try_build(real_tower("spotter"), Vector2(400, 380))
	run(m, 1.0)
	check(e.shield >= shield_before - 0.01, "shield untouched (regen may even have topped it up)")
	check(e.hp < e.max_hp, "HP dropped directly instead")


## Regression: EnemyDef.resist_pct is a PERCENT cut, separate from flat armor_by_type -- Phantom
## (0 armor) should still take noticeably less from a plain Kinetic hit than an identical enemy
## with no resist, and a tower's own %-damage bonus should still scale the final hit up despite it.
func test_phantom_resist_pct_is_a_percent_cut_separate_from_armor() -> void:
	var m := make_lab()
	var phantom := put(m, real_enemy("phantom", 0.0), 400) # resist_pct = {"kinetic": 0.3}
	var plain := put(m, make_enemy_def(phantom.max_hp, 0.0, 0.0), 900) # same HP/armor, no resist
	m.try_build(real_tower("pulse"), Vector2(400, 380)) # Kinetic
	m.try_build(real_tower("pulse"), Vector2(900, 380))
	m.registry.rebuild(m.enemies)
	run(m, 1.0)
	var phantom_drop := phantom.max_hp - phantom.hp
	var plain_drop := plain.max_hp - plain.hp
	check(phantom_drop < plain_drop, "Phantom takes less from the same Kinetic hits (%.1f < %.1f)" % [phantom_drop, plain_drop])


func test_venom_spray_leaves_a_poison_cloud_for_bystanders() -> void:
	var u := UpgradeRules.Unlocks.new()
	u.branch_c[&"venom"] = true
	var m := make_lab(100000, u)
	var t := m.try_build(real_tower("venom"), Vector2(400, 420))
	for i in range(3):
		check(m.try_upgrade(t, 2), "Spray tier %d" % (i + 1))
	var strong := put(m, make_enemy_def(500.0), 400) # tankiest: Venom's STRONGEST targeting hits this one
	var bystander := put(m, make_enemy_def(50.0), 415) # just standing nearby, never the direct target
	m.registry.rebuild(m.enemies)
	run(m, 3.0)
	var strong_poisoned := false
	var bystander_poisoned := false
	for k in strong.effects:
		if String(k).begins_with("venom"): strong_poisoned = true
	for k in bystander.effects:
		if String(k).begins_with("venom"): bystander_poisoned = true
	check(strong_poisoned, "direct target poisoned")
	check(bystander_poisoned, "bystander caught poison from the cloud, not a direct hit")


## Regression: the cloud's query hardcoded ground-only, so flying enemies never stacked poison from
## it even though Venom itself can hit (and poison) air directly.
func test_venom_spray_cloud_also_stacks_on_flying_enemies() -> void:
	var u := UpgradeRules.Unlocks.new()
	u.branch_c[&"venom"] = true
	var m := make_lab(100000, u)
	var t := m.try_build(real_tower("venom"), Vector2(400, 420))
	for i in range(3):
		check(m.try_upgrade(t, 2), "Spray tier %d" % (i + 1))
	var strong := put(m, make_enemy_def(500.0, 50.0, 0.0, 5, 1, true), 400) # flying, targeted (STRONGEST)
	var flyer := put(m, make_enemy_def(50.0, 50.0, 0.0, 5, 1, true), 415) # flying bystander in the cloud
	m.registry.rebuild(m.enemies)
	run(m, 3.0)
	var flyer_poisoned := false
	for k in flyer.effects:
		if String(k).begins_with("venom"): flyer_poisoned = true
	check(flyer_poisoned, "flying bystander also caught poison from the cloud")


func test_bastion_field_blocks_emp_and_jam() -> void:
	var m := make_lab()
	var inside := m.try_build(real_tower("pulse"), Vector2(400, 400))
	var outside := m.try_build(real_tower("pulse"), Vector2(800, 400))
	m.try_build(real_tower("bastion"), Vector2(460, 400))
	m.step(DT)
	check(inside.protected and not outside.protected, "field covers only nearby towers")
	m.disrupt_towers(Vector2(600, 400), 600.0, 3.0)
	m.jam_towers(Vector2(600, 400), 600.0, 3.0, 0.5)
	check(not inside.is_disrupted() and not inside.is_jammed(), "protected tower ignores EMP and jamming")
	check(outside.is_disrupted() and outside.is_jammed(), "unprotected tower is hit")


func test_marksman_bonus_vs_boss() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("sniper"), Vector2(400, 400))
	var boss := put(m, real_enemy("warden", 0.0), 900)
	var drone := put(m, real_enemy("drone", 0.0), 950)
	near(m._hit_mult(t, boss), 1.2, 0.001, "x1.2 vs bosses")
	near(m._hit_mult(t, drone), 1.0, 0.001)


func test_new_enemy_skills() -> void:
	var m := make_lab()
	var escort := put(m, real_enemy("escort", 0.0), 400)
	var ally := put(m, real_enemy("drone", 0.0), 430)
	var sludge := put(m, real_enemy("sludge", 0.0), 600)
	var sprinter := put(m, real_enemy("sprinter", 0.0), 700)
	var prism := put(m, real_enemy("prismling", 0.0), 800)
	var diver := put(m, real_enemy("diver", 0.0), 900)
	sludge.hp = sludge.max_hp * 0.5
	var hp := sludge.hp
	var shielded := false
	var sprinted := false
	var resisted := false
	var dived := false
	for i in range(int(6.0 / DT)):
		m.step(DT)
		shielded = shielded or ally.overshield > 0.0
		sprinted = sprinted or sprinter.sprint_timer > 0.0
		resisted = resisted or prism.immune_timer > 0.0
		dived = dived or diver.submerge_timer > 0.0
	check(shielded, "Escort shields its allies")
	check(sludge.hp > hp, "Sludge regenerates")
	check(sprinted, "Sprinter sprints")
	check(resisted, "Prismling resists a damage type")
	check(dived, "Diver submerges")
	var shade := real_enemy("shade")
	check(shade.flying and shade.stealth, "Shade flies and is stealthed")
	var t := m.try_build(real_tower("pulse"), Vector2(900, 400))
	t.damage = 0.0001 # observe the skill, do not kill the Jammer
	var jammer := put(m, real_enemy("jammer", 0.0), 900)
	var jammed := false
	for i in range(int(10.0 / DT)):
		m.step(DT)
		jammed = jammed or t.is_jammed()
	check(jammed, "Jammer jams towers nearby")
	escort.free()


## Regression: debuffs spread to more regular enemies, not just Jammer+bosses (2026-11-16, user:
## "quái ít hiệu ứng quá").
func test_aegis_and_glider_also_debuff_towers() -> void:
	var m := make_lab()
	var t1 := m.try_build(real_tower("pulse"), Vector2(400, 400))
	t1.damage = 0.0001 # observe the skill, do not kill the enemy
	var aegis := put(m, real_enemy("aegis", 0.0), 400)
	var t2 := m.try_build(real_tower("pulse"), Vector2(700, 400))
	t2.damage = 0.0001
	var glider := put(m, real_enemy("glider", 0.0), 700)
	var jammed := false
	var slowed_range := false
	for i in range(int(12.0 / DT)):
		m.step(DT)
		jammed = jammed or t1.is_jammed()
		slowed_range = slowed_range or t2.is_static()
	check(jammed, "Aegis jams nearby towers' fire rate")
	check(slowed_range, "Glider shortens nearby towers' range")
	check(aegis.is_alive() and glider.is_alive(), "both still around to have fired their skill")


func test_towers_unlock_when_their_counter_enemy_arrives() -> void:
	var c: CampaignDef = load("res://data/campaign.tres")
	eq(str(c.starting_towers), str([&"pulse"]), "only Pulse at the start")
	var per_region := {}
	var first := {}
	for l in c.levels:
		for w in l.waves:
			for g in w.groups:
				if not first.has(g.enemy.id):
					first[g.enemy.id] = l.level_number
		if l.unlock_tower_on_start != null:
			var rg := l.map.region_id()
			per_region[rg] = int(per_region.get(rg, 0)) + 1
	for rg in per_region:
		check(per_region[rg] <= 2, "%s unlocks at most 2 towers" % rg)
	var expect := {&"nova": &"swarmling", &"lance": &"plated", &"beacon": &"phantom", &"venom": &"sludge",
		&"trap": &"sprinter", &"bastion": &"jammer", &"sniper": &"diver"}
	var before := {&"spotter": &"chimera"} # support tower: unlocked a little before the boss it prepares for
	for l in c.levels:
		if l.unlock_tower_on_start != null:
			var id := l.unlock_tower_on_start.id
			if before.has(id):
				check(l.level_number < first[before[id]], "%s unlocks before %s" % [id, before[id]])
				continue
			var foe: StringName = expect[id]
			eq(first[foe], l.level_number, "%s unlocks where %s first appears" % [id, foe])
	eq(first.size(), 16 + 8, "16 enemies + 8 bosses appear in the campaign")


func test_rank_s_is_above_a_but_leaves_room_for_ss() -> void:
	var a_cap := _best(real_tower("lance"))
	var storm := real_tower("storm")
	eq(String(storm.rarity), "S")
	eq(String(real_tower("chronos").rarity), "S")
	# Stormcaller's power is its chain: total damage on a group = single hit x (1 + f + f^2 + ...)
	var falloff := float(storm.base_params["chain_falloff"])
	var group := 0.0
	for k in range(int(storm.base_params["chain"]) + 1):
		group += pow(falloff, k)
	var power := _dps_per_cost(storm, -1, 0, false) * group
	check(power > a_cap, "Stormcaller (group damage) beats the A cap (%.3f > %.3f)" % [power, a_cap])
	check(power <= a_cap * 1.5, "but stays within 1.5x the A cap (%.3f <= %.3f)" % [power, a_cap * 1.5])
	var c: CampaignDef = load("res://data/campaign.tres")
	for l in c.levels: # S / SS come only from the Armory, never from a level
		for t in [l.unlock_tower_on_start, l.unlock_tower_on_clear]:
			if t != null:
				check(t.rarity != &"S" and t.rarity != &"SS", "%s does not unlock an S tower" % l.id)
	check(not c.starting_towers.has(&"storm") and not c.starting_towers.has(&"chronos"), "S towers are not owned at start")


func test_stormcaller_chains_and_staggers() -> void:
	var m := make_lab()
	var a := put(m, real_enemy("brute", 0.0), 400)
	var b := put(m, real_enemy("brute", 0.0), 440)
	var c2 := put(m, real_enemy("brute", 0.0), 480)
	m.try_build(real_tower("storm"), Vector2(440, 400))
	run(m, 2.0)
	check(a.hp < a.max_hp and b.hp < b.max_hp and c2.hp < c2.max_hp, "one tower hits three enemies")


func test_chronos_field_slows_hastes_and_freezes() -> void:
	var m := make_lab()
	var e := put(m, real_enemy("drone", 0.0), 400)
	var t := m.try_build(real_tower("pulse"), Vector2(400, 420))
	t.damage = 0.0001
	m.try_build(real_tower("chronos"), Vector2(420, 380))
	m.step(DT)
	check(t.protected, "towers in the field are protected")
	near(t.amp_rate, 0.07, 0.001, "towers in the field fire 7% faster")
	var frozen := false
	for i in range(int(9.0 / DT)):
		m.step(DT)
		frozen = frozen or e.is_frozen()
	check(frozen, "regular enemies are frozen every 8 s")


func test_spotter_marks_enemies_for_every_tower() -> void:
	var m := make_lab()
	var e := put(m, real_enemy("brute", 0.0), 400)
	m.try_build(real_tower("spotter"), Vector2(400, 380))
	var marked := false
	for k in range(120):
		m.step(1.0 / 60.0)
		for id in e.effects:
			if String(id).begins_with("spot"):
				marked = true
	check(marked, "Spotter applies its mark")
	var d := real_tower("spotter")
	eq(String(d.rarity), "C")
	check(float(d.base_params["spot_vuln"]) <= 1.08, "base mark stays C level")
