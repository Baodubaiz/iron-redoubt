extends TestCase
## Fixed 70% sell refund (build + upgrades + evolution), exactly once, removal of the tower's
## effects and footprint, and pause gating.


func test_refund_includes_upgrades_and_evolution() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("nova"), Vector2(300, 420))
	eq(m.sell_refund(t), int(floor(t.def.cost * 0.7)), "70% of the Nova build cost")
	for i in range(3):
		m.try_upgrade(t, 1)
	t.waves_since_t3 = 2
	check(m.try_evolve(t), "evolve")
	var br := t.def.branches[1]
	var invested := t.def.cost + br.tiers[0].cost + br.tiers[1].cost + br.tiers[2].cost + br.evolution.cost
	eq(t.total_invested, invested)
	var before := m.economy.currency
	var refund := m.try_sell(t)
	eq(refund, int(floor(invested * 0.7)))
	eq(m.economy.currency - before, refund, "credited")
	eq(m.try_sell(t), -1, "cannot sell twice")
	eq(m.economy.currency - before, refund, "credited once")
	check(not m.towers.has(t), "removed")


func test_sell_frees_footprint_and_removes_projectiles() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("nova"), Vector2(300, 420))
	put(m, make_enemy_def(1.0e6, 0), 300)
	m.step(DT)
	check(m.projectiles.active_count() > 0, "shell in flight")
	m.try_sell(t)
	eq(m.projectiles.active_count(), 0, "in-flight shots removed")
	eq(m.validate_placement(real_tower("pulse"), Vector2(300, 420)), PlacementRules.Result.OK, "footprint released")


func test_sell_removes_fire_patches() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("nova"), Vector2(300, 420))
	for i in range(3):
		m.try_upgrade(t, 1)
	put(m, make_enemy_def(1.0e6, 0), 300)
	run(m, 1.0)
	check(m.zones.size() > 0, "fire patch exists")
	m.try_sell(t)
	eq(m.zones.size(), 0, "patches owned by the tower removed")


func test_sell_disabled_while_paused() -> void:
	var m := make_lab()
	var t := m.try_build(real_tower("pulse"), Vector2(300, 420))
	m.set_paused(true)
	eq(m.try_sell(t), -1)
	check(m.towers.has(t), "still there")
	m.set_paused(false)
	eq(m.try_sell(t), int(floor(t.def.cost * 0.7)))
