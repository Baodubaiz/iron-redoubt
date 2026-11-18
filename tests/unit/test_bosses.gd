extends TestCase
## Region bosses (content update): every boss has its own skill kit, all telegraphed and deterministic.
## Monolith behaviour is covered in test_enemies.gd.


func _boss(m: MatchController, id: String, x: float = 400.0) -> Enemy:
	return put(m, real_enemy(id, 0.0), x)


func _skill_fires(m: MatchController, boss: Enemy, kind: int, max_s: float = 30.0) -> bool:
	var seen := false
	var steps := int(max_s / DT)
	for i in range(steps):
		if boss.telegraph_kind == kind:
			seen = true
		elif seen:
			return true # the telegraph finished: the skill fired this step
		m.step(DT)
	return false


func test_every_region_boss_has_a_unique_kit() -> void:
	var c: CampaignDef = load("res://data/campaign.tres")
	var kits := {}
	for l in c.levels:
		for w in l.waves:
			for g in w.groups:
				if g.enemy.is_boss:
					check(not kits.has(g.enemy.boss_kit) or kits[g.enemy.boss_kit] == g.enemy.id, "kit %s reused" % g.enemy.boss_kit)
					kits[g.enemy.boss_kit] = g.enemy.id
	eq(kits.size(), 8)
	# each region: the 10th-level boss outclasses the 5th-level one
	for pair in [["warden", "dynamo"], ["carrier", "leviathan"], ["refractor", "monolith"], ["chimera", "colossus"]]:
		var a := real_enemy(pair[0])
		var b := real_enemy(pair[1])
		check(b.max_hp > a.max_hp and b.radius > a.radius and b.boss_phase_count >= a.boss_phase_count,
			"%s (level 10) is bigger and tougher than %s (level 5)" % [pair[1], pair[0]])
	var colossus := real_enemy("colossus")
	for k in kits:
		var e := real_enemy(String(kits[k]))
		if e.id != &"colossus":
			check(colossus.max_hp > e.max_hp and colossus.radius > e.radius, "Colossus is the biggest, toughest boss")


func test_warden_shell_absorbs_then_sprints_in_phase_two() -> void:
	var m := make_lab()
	var boss := _boss(m, "warden")
	check(_skill_fires(m, boss, EnemyAbilities.SHELL_KIND), "Carapace fires")
	near(boss.overshield, boss.max_hp * 0.15, 0.01, "shell = 15% max HP")
	var hp := boss.hp
	m.damage_enemy(boss, 100, Damage.Type.TRUE, 0)
	near(boss.hp, hp, 0.001, "shell absorbs first")
	run(m, 5.1)
	near(boss.overshield, 0.0, 0.001, "shell expires")
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.5, Damage.Type.TRUE, 0)
	m.step(DT)
	eq(boss.boss_phase, 2)
	var spd := boss.speed_multiplier()
	check(_skill_fires(m, boss, EnemyAbilities.SPRINT_KIND, 5.0), "phase II opens with Overclock")
	near(boss.speed_multiplier(), spd * 1.8, 0.001, "sprints x1.8")
	run(m, 2.6)
	near(boss.speed_multiplier(), spd, 0.001, "sprint ends")
	eq(boss.max_boss_phases, 2, "two phases")


func test_carrier_launches_fighters_and_cloaks() -> void:
	var m := make_lab()
	var boss := _boss(m, "carrier")
	check(_skill_fires(m, boss, EnemyAbilities.HANGAR_KIND), "Hangar fires")
	var fighters := 0
	for e in m.enemies:
		if e != boss:
			check(e.summoned and e.def.flying, "launched fighters fly and give no bounty")
			fighters += 1
	eq(fighters, 3)
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.5, Damage.Type.TRUE, 0)
	m.step(DT)
	check(_skill_fires(m, boss, EnemyAbilities.CLOAK_KIND, 5.0), "phase II: cloak")
	check(not boss.is_targetable(), "cloaked boss cannot be targeted")
	var hp := boss.hp
	m._explode(null, boss.position, 60.0, 50.0, Damage.Type.EXPLOSIVE, 0.0, false, false, false)
	check(boss.hp < hp, "splash still hits a cloaked boss")
	m.try_build(real_tower("beacon"), Vector2(boss.position.x, boss.position.y + 70.0))
	m.step(DT)
	check(boss.is_targetable(), "Beacon reveals it")


func test_chimera_swaps_plating_and_jams_towers() -> void:
	var m := make_lab()
	var boss := _boss(m, "chimera")
	near(boss.effective_armor(), boss.def.armor + 8.0, 0.001, "starts in armour mode (4 + 8)")
	eq(boss.shield_max, 0.0)
	check(_skill_fires(m, boss, EnemyAbilities.ADAPT_KIND), "Adaptive plating")
	near(boss.effective_armor(), boss.def.armor, 0.001, "shield mode drops the armour bonus")
	near(boss.shield, boss.max_hp * 0.12, 0.01, "full regenerating shield")
	var near_t := m.try_build(real_tower("pulse"), Vector2(boss.position.x, boss.position.y + 120.0))
	var far_t := m.try_build(real_tower("pulse"), Vector2(boss.position.x + 500.0, boss.position.y + 120.0))
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.5, Damage.Type.TRUE, 0)
	m.step(DT)
	eq(boss.boss_phase, 2)
	check(_skill_fires(m, boss, EnemyAbilities.JAM_KIND, 5.0), "Jammer fires in phase II")
	check(near_t.is_jammed() and not far_t.is_jammed(), "only towers in range are jammed")


func test_jammed_tower_fires_at_half_rate() -> void:
	var m := make_lab()
	var target := put(m, real_enemy("brute", 0.0), 400)
	target.hp = 1e9
	target.max_hp = 1e9
	var t := m.try_build(real_tower("pulse"), Vector2(400, 400))
	run(m, 5.0)
	var normal := t.shots_fired
	t.jam_timer = 100.0
	t.jam_factor = 0.5
	var before := t.shots_fired
	run(m, 5.0)
	var jammed := t.shots_fired - before
	check(absi(jammed * 2 - normal) <= 2, "half rate while jammed (%d vs %d)" % [jammed, normal])


func test_colossus_bulwark_blink_and_overdrive() -> void:
	var m := make_lab()
	var boss := _boss(m, "colossus", 200)
	var ally := put(m, real_enemy("drone", 0.0), 260)
	check(_skill_fires(m, boss, EnemyAbilities.BULWARK_KIND), "Bulwark")
	near(ally.overshield, 150.0, 0.01, "escort overshielded")
	eq(boss.overshield, 0.0, "not itself")
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.5, Damage.Type.TRUE, 0)
	m.step(DT)
	var p := boss.progress
	check(_skill_fires(m, boss, EnemyAbilities.BLINK_KIND, 5.0), "phase II opens with Rift blink")
	near(boss.progress, p + 160.0, 0.5, "jumps 160 px down its lane")
	boss.place_at_progress(boss.route.total_length - 300.0)
	check(_skill_fires(m, boss, EnemyAbilities.BLINK_KIND, 40.0), "blinks again (skills alternate with Bulwark)")
	check(boss.remaining_distance() >= 259.0, "never blinks closer than 260 px to the base (%.0f)" % boss.remaining_distance())
	ally.place_at_progress(boss.progress - 40.0)
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.3, Damage.Type.TRUE, 0)
	m.step(DT)
	eq(boss.boss_phase, 3)
	m.step(DT)
	check(ally.haste_timer > 0.0 and ally.speed_multiplier() > 1.2, "overdrive speeds up escorts")
	var hp := boss.hp
	run(m, 1.0)
	check(boss.hp > hp, "regenerates in overdrive")


func test_new_bosses_do_not_fracture() -> void:
	var m := make_lab()
	for id in ["warden", "carrier", "chimera", "colossus"]:
		var b := _boss(m, id)
		m.damage_enemy(b, b.max_hp * 0.8, Damage.Type.TRUE, 0)
		m.step(DT)
		m.damage_enemy(b, 1e9, Damage.Type.TRUE, 0)
	for e in m.enemies:
		check(not (e.is_alive() and String(e.def.id).ends_with("_shard")), "no shards")


func test_dynamo_static_field_capacitor_and_overload() -> void:
	var m := make_lab()
	var boss := _boss(m, "dynamo")
	var t := m.try_build(real_tower("pulse"), Vector2(boss.position.x, boss.position.y + 120.0))
	var r := t.eff_range()
	check(_skill_fires(m, boss, EnemyAbilities.STATIC_KIND), "Static field")
	check(t.is_static(), "tower in range is hit")
	near(t.eff_range(), r * 0.65, 0.01, "range -35%")
	run(m, 5.1)
	near(t.eff_range(), r, 0.01, "range back after 5 s")
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.5, Damage.Type.TRUE, 0)
	m.step(DT)
	check(_skill_fires(m, boss, EnemyAbilities.CAPACITOR_KIND, 5.0), "phase II opens with Capacitor")
	var hp := boss.hp
	m.damage_enemy(boss, 500, Damage.Type.TRUE, 0)
	near(hp - boss.hp, 50.0, 0.01, "a 500 hit is capped at 50")
	var spd := boss.speed_multiplier()
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.3, Damage.Type.TRUE, 0)
	boss.hit_cap_timer = 0.0
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.3, Damage.Type.TRUE, 0)
	m.step(DT)
	eq(boss.boss_phase, 3)
	m.step(DT)
	near(boss.speed_multiplier(), spd * 1.35, 0.001, "overload: permanently +35%")


func test_leviathan_submerge_and_revive() -> void:
	var m := make_lab()
	var boss := _boss(m, "leviathan")
	check(_skill_fires(m, boss, EnemyAbilities.SUBMERGE_KIND), "Submerge")
	check(not boss.is_targetable(), "untargetable while submerged")
	var hp := boss.hp
	m.damage_enemy(boss, 1000, Damage.Type.TRUE, 0)
	m._explode(null, boss.position, 80.0, 500.0, Damage.Type.EXPLOSIVE, 0.0, false, false, false)
	near(boss.hp, hp, 0.001, "immune to everything, splash included")
	run(m, 2.6)
	check(boss.is_targetable(), "surfaces after 2.5 s")
	var d1 := put(m, real_enemy("brute", 0.0), boss.progress - 60.0)
	var d2 := put(m, real_enemy("plated", 0.0), boss.progress - 90.0)
	m.damage_enemy(d1, 1e6, Damage.Type.TRUE, 0)
	m.damage_enemy(d2, 1e6, Damage.Type.TRUE, 0)
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.5, Damage.Type.TRUE, 0)
	m.step(DT)
	var before := m.economy.currency
	check(_skill_fires(m, boss, EnemyAbilities.REVIVE_KIND, 5.0), "phase II opens with Revive")
	var risen := 0
	for e in m.enemies:
		if e.is_alive() and e != boss:
			check(e.summoned, "revived units give no bounty")
			risen += 1
	eq(risen, 2, "both recent kills rise again")
	eq(m.economy.currency, before, "no money from reviving")


func test_refractor_decoys_and_prismatic_shield() -> void:
	var m := make_lab()
	var boss := _boss(m, "refractor")
	check(_skill_fires(m, boss, EnemyAbilities.DECOY_KIND), "Mirror decoys")
	var decoys := 0
	for e in m.enemies:
		if e != boss:
			decoys += 1
			check(e.summoned and not e.def.is_boss and e.progress > boss.progress, "decoys run ahead, no bounty, not a boss")
			near(e.max_hp, boss.max_hp * 0.05, 0.01, "fragile")
			eq(e.base_damage, 1)
	eq(decoys, 2)
	m.damage_enemy(boss, boss.hp - boss.max_hp * 0.5, Damage.Type.TRUE, 0)
	m.step(DT)
	check(_skill_fires(m, boss, EnemyAbilities.PRISM_KIND, 5.0), "phase II opens with the prismatic shield")
	check(boss.immune_type >= 0, "resists one damage type")
	var hp := boss.hp
	m.damage_enemy(boss, 100, boss.immune_type, 100)
	near(hp - boss.hp, 10.0, 0.01, "90% resisted")
	var other := Damage.Type.TRUE
	hp = boss.hp
	m.damage_enemy(boss, 100, other, 100)
	near(hp - boss.hp, 100.0, 0.01, "other types hit normally")
