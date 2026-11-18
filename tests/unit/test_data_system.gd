extends TestCase
## Data-driven stats / effects / boss skills: new content is added as data, without code changes.


func test_every_tower_stat_key_is_in_the_catalog() -> void:
	var cat := StatCatalog.get_default()
	check(cat.stats.size() >= 50, "catalog loaded (%d stats)" % cat.stats.size())
	for t in all_real_towers():
		for k in t.base_params:
			check(cat.has(StringName(k)), "%s base param '%s' registered" % [t.id, k])
		for b in t.branches:
			var tiers: Array = b.tiers.duplicate()
			if b.evolution != null:
				tiers.append(b.evolution)
			for tier in tiers:
				for k in (tier as TierDef).stats:
					check(cat.has(StringName(k)), "%s/%s stat '%s' registered (typo?)" % [t.id, b.id, k])


func test_damage_catalog_matches_the_rules() -> void:
	eq(Damage.defs().size(), 6)
	near(Damage.shield_mult(Damage.Type.ENERGY), 2.0, 0.0001, "energy x2 vs shields")
	near(Damage.shield_mult(Damage.Type.KINETIC), 1.0, 0.0001)
	# resolve() itself is type-agnostic now: the "ignores armor" behaviour for Poison/True comes
	# from Enemy.effective_armor_for() resolving their armor to 0, not from a case here.
	near(Damage.resolve(100, Damage.Type.TRUE, 0, 0), 100.0, 0.0001, "0 armor -> nothing to block")
	near(Damage.resolve(10, Damage.Type.KINETIC, 0, 50), 2.5, 0.0001, "25% always passes")
	eq(Damage.type_from_id("explosive"), Damage.Type.EXPLOSIVE)
	eq(Damage.type_from_id("poison"), Damage.Type.POISON)


func test_per_type_armor_override_and_true_is_unconditional() -> void:
	var e := Enemy.new()
	e.def = make_enemy_def(100.0, 50.0, 8.0) # armor 8
	eq(e.effective_armor_for(Damage.Type.KINETIC), 8.0, "no override -> falls back to flat armor")
	eq(e.effective_armor_for(Damage.Type.POISON), 0.0, "Poison defaults to 0 (no override)")
	e.def.armor_by_type = {"poison": 6.0}
	eq(e.effective_armor_for(Damage.Type.POISON), 6.0, "override now applies")
	eq(e.effective_armor_for(Damage.Type.KINETIC), 8.0, "unrelated type unaffected")
	eq(e.effective_armor_for(Damage.Type.TRUE), 0.0, "True ignores any override, always 0")


func test_plasma_skips_shields_and_explosive_has_innate_pierce() -> void:
	check(Damage.ignores_shield(Damage.Type.PLASMA), "Plasma skips the shield bar entirely")
	check(not Damage.ignores_shield(Damage.Type.ENERGY), "Energy still goes through the shield bar (just x2)")
	# Explosive's flat_pierce is baked into the type, on top of whatever pierce the tower itself has.
	var plain := Damage.resolve(10.0, Damage.Type.KINETIC, 0.0, 8.0)
	var explosive := Damage.resolve(10.0, Damage.Type.EXPLOSIVE, 0.0, 8.0)
	check(explosive > plain, "Explosive's innate shrapnel pierce beats Kinetic at the same armor (%.2f > %.2f)" % [explosive, plain])


func test_resolve_mixed_splits_damage_between_two_types() -> void:
	var e := Enemy.new()
	e.def = make_enemy_def(1000.0, 50.0, 50.0) # heavy armor against generic types
	e.def.armor_by_type = {"poison": 0.0}
	var armor_for := func(t: int) -> float: return e.effective_armor_for(t)
	# half Kinetic (heavily armored, mostly blocked), half Poison (armor_by_type 0, goes through)
	var mixed := Damage.resolve_mixed(100.0, Damage.Type.KINETIC, Damage.Type.POISON, 0.5, 0.0, armor_for)
	var pure_kinetic := Damage.resolve(100.0, Damage.Type.KINETIC, 0.0, e.effective_armor_for(Damage.Type.KINETIC))
	check(mixed > pure_kinetic, "the poison half bypasses armor, so mixed beats pure kinetic (%.1f > %.1f)" % [mixed, pure_kinetic])


func test_data_only_effect_poison_on_a_tower() -> void:
	# A tower variant made purely from data: its tier stats add the "poison" effect on hit.
	var m := make_lab()
	var e := put(m, real_enemy("brute", 0.0), 400)
	var t := m.try_build(real_tower("pulse"), Vector2(400, 400))
	t.params["on_hit_effects"] = ["poison"] # what a tier with {"on_hit_effects": ["poison"]} merges in
	run(m, 1.0)
	check(e.has_effect(&"poison"), "poison applied by data")
	var stacks := int(e.effects[&"poison"]["stacks"])
	check(stacks >= 2 and stacks <= 5, "stacks (max 5): %d" % stacks)
	t.queue_free()
	m.towers.erase(t)
	var hp := e.hp
	run(m, 1.0)
	check(e.hp < hp, "poison keeps ticking")
	run(m, 5.0)
	check(not e.has_effect(&"poison"), "expires")


func test_effect_components_slow_vulnerable_and_tower_debuff() -> void:
	var m := make_lab()
	var e := put(m, real_enemy("drone"), 300)
	var fx := EffectDef.new()
	fx.id = &"test_frost"
	fx.duration = 2.0
	fx.components = {"speed_mult": 0.5, "damage_taken": 2.0, "armor_add": -3.0}
	var spd := e.current_speed()
	e.apply_effect(fx)
	near(e.current_speed(), spd * 0.5, 0.001, "speed_mult")
	var hp := e.hp
	m.damage_enemy(e, 10, Damage.Type.TRUE, 0)
	near(hp - e.hp, 20.0, 0.001, "damage_taken x2")
	run(m, 2.1)
	near(e.current_speed(), spd, 0.001, "gone after its duration")
	var t := m.try_build(real_tower("pulse"), Vector2(600, 400))
	var r := t.eff_range()
	var tfx := EffectDef.new()
	tfx.id = &"test_fog"
	tfx.target = EffectDef.Target.TOWER
	tfx.duration = 3.0
	tfx.components = {"range_mult": 0.5}
	m.effect_towers(t.position, 10.0, tfx)
	near(t.eff_range(), r * 0.5, 0.001, "tower range_mult")


func test_tag_multiplier() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("pulse"), Vector2(400, 400))
	t.params["tag_mult"] = {"armored": 3.0} # what a tier with {"tag_mult": {"armored": 3.0}} merges in
	var plated := put(m, real_enemy("plated", 0.0), 900)
	var drone := put(m, real_enemy("drone", 0.0), 950)
	near(m._hit_mult(t, plated), 3.0, 0.001, "x3 vs armored")
	near(m._hit_mult(t, drone), 1.0, 0.001, "normal vs others")


func test_data_only_boss() -> void:
	# A brand-new boss built only from data: generic actions effect_area / summon / heal_area + aura passive.
	var b := TestCase.make_enemy_def(2000, 0.0, 0, 50, 10)
	b.id = &"test_boss"
	b.is_boss = true
	b.boss_kit = &"custom"
	b.boss_phase_count = 2
	b.boss_params = {"first_skill": 1.0}
	var weaken := EffectDef.new()
	weaken.id = &"test_weaken"
	weaken.target = EffectDef.Target.TOWER
	weaken.duration = 4.0
	weaken.components = {"fire_rate_mult": 0.5}
	EffectDef._cache["test_weaken"] = weaken
	var s1 := BossSkillDef.new()
	s1.action = &"effect_area"
	s1.interval = 5.0
	s1.telegraph = 0.5
	s1.params = {"effect": "test_weaken", "on": "towers", "radius": 300.0}
	var s2 := BossSkillDef.new()
	s2.action = &"summon"
	s2.min_phase = 2
	s2.interval = 5.0
	s2.telegraph = 0.5
	s2.params = {"enemy": "res://data/enemies/drone.tres", "count": 2.0, "spacing": -20.0}
	b.boss_skills = [s1, s2]
	var m := make_lab()
	var boss := put(m, b, 400)
	var t := m.try_build(real_tower("pulse"), Vector2(boss.position.x, boss.position.y + 100.0))
	run(m, 1.6)
	check(t.effects.has(&"test_weaken"), "phase I: tower weakened by data skill")
	m.damage_enemy(boss, 1500, Damage.Type.TRUE, 0)
	m.step(DT)
	eq(boss.boss_phase, 2)
	var n := m.enemies.size()
	run(m, 2.5)
	eq(m.enemies.size(), n + 2, "phase II opens with the data summon")
	EffectDef._cache.erase("test_weaken")


func test_tower_ranks() -> void:
	var rc := RarityCatalog.get_default()
	eq(rc.ranks.size(), 5, "C, B, A, S, SS")
	var order := ""
	for r in rc.ranks:
		order += String(r.id)
	eq(order, "CBASSS", "ranks in order")
	for t in all_real_towers():
		check(rc.find(t.rarity) != null, "%s has a valid rank (%s)" % [t.id, t.rarity])
	eq(String(real_tower("pulse").rarity), "C")
	eq(String(real_tower("lance").rarity), "A")
