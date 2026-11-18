extends TestCase
## Free placement: footprint validation and currency deduction only on success.

var tdef: TowerDef
var m: MatchController


func before_each() -> void:
	tdef = make_tower_def(100)
	var towers: Array[TowerDef] = [tdef]
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(), 1)]
	m = null
	_level = make_level(waves, towers, 250)

var _level: LevelDef


func _m() -> MatchController:
	if m == null:
		m = make_match(_level)
	return m


func test_valid_open_ground() -> void:
	eq(_m().validate_placement(tdef, Vector2(300, 400)), PlacementRules.Result.OK)


func test_on_path_rejected() -> void:
	# path y=300, half width 26 + footprint 22 = 48
	eq(_m().validate_placement(tdef, Vector2(300, 300)), PlacementRules.Result.ON_PATH)
	eq(_m().validate_placement(tdef, Vector2(300, 347)), PlacementRules.Result.ON_PATH, "47px")
	eq(_m().validate_placement(tdef, Vector2(300, 349)), PlacementRules.Result.OK, "49px")


func test_blocked_and_bounds() -> void:
	eq(_m().validate_placement(tdef, Vector2(550, 550)), PlacementRules.Result.BLOCKED)
	eq(_m().validate_placement(tdef, Vector2(480, 550)), PlacementRules.Result.BLOCKED, "footprint touches block")
	eq(_m().validate_placement(tdef, Vector2(470, 550)), PlacementRules.Result.OK, "just clear of block")
	eq(_m().validate_placement(tdef, Vector2(10, 400)), PlacementRules.Result.OUT_OF_BOUNDS)
	eq(_m().validate_placement(tdef, Vector2(1150, 400)), PlacementRules.Result.OUT_OF_BOUNDS, "palette area")
	eq(_m().validate_placement(tdef, Vector2(300, 70)), PlacementRules.Result.OUT_OF_BOUNDS, "under top bar")


func test_overlap_and_adjacent_towers() -> void:
	var mm := _m()
	check(mm.try_build(tdef, Vector2(300, 400)) != null, "first build")
	eq(mm.validate_placement(tdef, Vector2(320, 400)), PlacementRules.Result.OVERLAP_TOWER, "overlap")
	eq(mm.validate_placement(tdef, Vector2(344, 400)), PlacementRules.Result.OK, "touching footprints allowed")


func test_currency_deducted_only_on_success() -> void:
	var mm := _m()
	eq(mm.economy.currency, 250)
	check(mm.try_build(tdef, Vector2(300, 300)) == null, "invalid spot fails")
	eq(mm.economy.currency, 250, "no charge for invalid spot")
	check(mm.try_build(tdef, Vector2(300, 400)) != null, "valid build")
	eq(mm.economy.currency, 150)
	check(mm.try_build(tdef, Vector2(300, 400)) == null, "same spot again fails (overlap)")
	eq(mm.economy.currency, 150)
	check(mm.try_build(tdef, Vector2(400, 400)) != null, "second build")
	eq(mm.economy.currency, 50)
	check(mm.try_build(tdef, Vector2(500, 400)) == null, "unaffordable")
	eq(mm.economy.currency, 50)
	eq(mm.towers.size(), 2)
	eq(mm.towers[0].total_invested, 100)


func test_unavailable_tower_rejected() -> void:
	var other := make_tower_def(10)
	check(_m().try_build(other, Vector2(300, 400)) == null, "not in level roster")
	eq(_m().economy.currency, 250)
