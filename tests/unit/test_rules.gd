extends TestCase
## Pure rules: geometry, damage formula, economy ledger, base HP, economy formulas.


func test_point_segment_distance() -> void:
	near(sqrt(GeoUtil.dist_sq_point_segment(Vector2(5, 3), Vector2(0, 0), Vector2(10, 0))), 3.0, 0.001)
	near(sqrt(GeoUtil.dist_sq_point_segment(Vector2(-4, 3), Vector2(0, 0), Vector2(10, 0))), 5.0, 0.001, "clamped to endpoint")
	near(GeoUtil.dist_point_polyline(Vector2(20, 5), PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])), 10.0, 0.001)


func test_armor_formula() -> void:
	near(Damage.resolve(80, Damage.Type.ENERGY, 6, 8), 78.0, 0.001, "pen reduces armor")
	near(Damage.resolve(12, Damage.Type.KINETIC, 0, 8), 4.0, 0.001, "flat reduction")
	near(Damage.resolve(10, Damage.Type.KINETIC, 0, 20), 2.5, 0.001, "25% floor")
	# resolve() is type-agnostic now (Enemy.effective_armor_for resolves True's armor to 0, not
	# this formula) -- 0 armor passed in still proves "nothing blocks a hit with no armor".
	near(Damage.resolve(10, Damage.Type.TRUE, 0, 0), 10.0, 0.001, "0 armor -> full damage")
	near(Damage.resolve(30, Damage.Type.EXPLOSIVE, 0, 0), 30.0, 0.001, "no armor")


func test_economy_idempotent_credit() -> void:
	var e := MatchEconomy.new(100, EconomyConfig.new())
	check(e.credit(10, "kill:1"), "first credit accepted")
	check(not e.credit(10, "kill:1"), "duplicate key rejected")
	eq(e.currency, 110, "currency after dup")
	check(not e.credit(0, "x"), "zero credit rejected")
	check(not e.credit(-5, "y"), "negative credit rejected")


func test_economy_spend_never_negative() -> void:
	var e := MatchEconomy.new(100, EconomyConfig.new())
	check(not e.try_spend(101, "build"), "cannot overspend")
	eq(e.currency, 100)
	check(e.try_spend(100, "build"), "exact spend ok")
	eq(e.currency, 0)
	check(not e.try_spend(-10, "neg"), "negative spend rejected")
	eq(e.currency, 0)


func test_economy_locked_after_end() -> void:
	var e := MatchEconomy.new(100, EconomyConfig.new())
	e.locked = true
	check(not e.credit(10, "kill:9"), "no credit when locked")
	check(not e.try_spend(10, "b"), "no spend when locked")
	eq(e.currency, 100)


func test_passive_income_only_during_waves() -> void:
	var cfg := EconomyConfig.new()
	var e := MatchEconomy.new(0, cfg)
	for i in range(1200):
		e.step_passive(DT, false)
	eq(e.currency, 0, "no passive in prep")
	for i in range(1201): # 20.0167 s
		e.step_passive(DT, true)
	eq(e.currency, cfg.passive_amount * 2, "two ticks in 20s")


func test_economy_formulas() -> void:
	var cfg := EconomyConfig.new()
	eq(cfg.wave_reward(1), 24)
	eq(cfg.wave_reward(8), 52)
	eq(cfg.early_bonus(10.0), 15)
	eq(cfg.early_bonus(19.9), 29)
	eq(cfg.early_bonus(100.0), 30, "capped")
	eq(cfg.early_bonus(-1.0), 0)
	eq(cfg.sell_refund(275), 192, "floor(275*0.7)")
	eq(cfg.sell_refund(100), 70)


func test_base_hp_clamps_and_signals_once() -> void:
	var b := BaseCore.new(5)
	var count := [0]
	b.destroyed.connect(func() -> void: count[0] += 1)
	b.apply_damage(3)
	eq(b.hp, 2)
	b.apply_damage(10)
	eq(b.hp, 0, "clamped at 0")
	b.apply_damage(1)
	eq(count[0], 1, "destroyed emitted once")
	eq(b.damage_taken, 5)


func test_route_path_progress() -> void:
	var r := RoutePath.new(PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 50)]))
	near(r.total_length, 150.0, 0.001)
	var seg := r.segment_for(120.0, 0)
	eq(seg, 1)
	check(r.position_at(120.0, seg).is_equal_approx(Vector2(100, 20)), "position on 2nd segment")
