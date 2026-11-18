extends TestCase
## Player-facing targeting priority (tower_panel.gd): free, instant, same 3 choices (First /
## Strongest / Cluster) for every tower role, never changes power — only which enemy is picked.


func test_default_is_the_tower_defs_own_rule() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("pulse"), Vector2(400, 380))
	eq(t.targeting_override, -1, "no override by default")
	eq(t.targeting_override if t.targeting_override >= 0 else t.def.targeting, t.def.targeting)


func test_set_targeting_overrides_and_picks_accordingly() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("pulse"), Vector2(400, 380))
	var ahead := put(m, make_enemy_def(50.0), 450.0) # furthest along, weak
	var tough := put(m, make_enemy_def(500.0), 300.0) # closer to spawn, but tankiest
	m.registry.rebuild(m.enemies)

	check(m.set_targeting(t, TowerDef.TargetRule.FIRST), "sets First")
	eq(t.targeting_override, TowerDef.TargetRule.FIRST)
	var picked: Enemy = Targeting.pick(t.position, t.targeting_override, t.eff_range(), t.can_target_air, t.splash_radius, m.registry)
	eq(picked, ahead, "First picks the one furthest along")

	check(m.set_targeting(t, TowerDef.TargetRule.STRONGEST), "sets Strongest")
	picked = Targeting.pick(t.position, t.targeting_override, t.eff_range(), t.can_target_air, t.splash_radius, m.registry)
	eq(picked, tough, "Strongest picks the highest HP")

	var flyer := put(m, make_enemy_def(10.0, 50.0, 0.0, 5, 1, true), 350.0) # weak, behind both, but flying
	m.registry.rebuild(m.enemies)
	check(m.set_targeting(t, TowerDef.TargetRule.AIR_FIRST), "sets Air")
	picked = Targeting.pick(t.position, t.targeting_override, t.eff_range(), t.can_target_air, t.splash_radius, m.registry)
	eq(picked, flyer, "Air picks the flier even though it's weak and behind")


func test_set_targeting_is_free_and_does_not_touch_power() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("pulse"), Vector2(400, 380))
	var before := m.economy.currency
	var dmg := t.eff_damage()
	var rate := t.eff_rate()
	check(m.set_targeting(t, TowerDef.TargetRule.DENSEST), "sets Cluster")
	eq(m.economy.currency, before, "no cost")
	eq(t.eff_damage(), dmg, "damage unchanged")
	eq(t.eff_rate(), rate, "fire rate unchanged")


func test_set_targeting_rejects_sold_or_null_towers() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("pulse"), Vector2(400, 380))
	check(not m.set_targeting(null, TowerDef.TargetRule.FIRST), "no tower")
	m.try_sell(t)
	check(not m.set_targeting(t, TowerDef.TargetRule.FIRST), "sold tower")


func test_aura_towers_have_nothing_to_target() -> void:
	var beacon := real_tower("beacon")
	check(beacon.targeting == TowerDef.TargetRule.NONE, "Beacon never aims (tower_panel hides the picker for it)")
