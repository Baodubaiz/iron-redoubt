extends TestCase
## Drag & Drop and Tap-to-Place sessions driven by synthetic pointer events (mouse events are
## what Godot delivers for touch when emulate_mouse_from_touch is on, the mobile default).

const PALETTE := Rect2(1168, 64, 112, 656)

var m: MatchController
var p: PlacementController
var tdef: TowerDef


func _setup(money: int = 250) -> void:
	tdef = make_tower_def(100)
	var towers: Array[TowerDef] = [tdef]
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(), 1), make_wave(make_enemy_def(), 1)]
	m = make_match(make_level(waves, towers, money))
	p = PlacementController.new()
	p.controller = m
	p.palette_rect_provider = func() -> Rect2: return PALETTE
	m.add_child(p)
	if not p.is_inside_tree():
		p._ready()


func _motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	p._input(e)


func _release(pos: Vector2, unhandled: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = pos
	if unhandled:
		p._unhandled_input(e)
	else:
		p._input(e)


func test_drag_and_drop_builds_once() -> void:
	_setup()
	p.begin_from_palette(tdef, Vector2(1220, 100))
	_motion(Vector2(800, 300))
	_motion(Vector2(300, 464))
	check(p.ghost_visible, "ghost shown while dragging")
	check(p.ghost_pos.is_equal_approx(Vector2(300, 400)), "ghost floats 64px above the finger")
	check(p.is_valid(), "valid spot")
	eq(m.economy.currency, 250, "nothing charged during preview")
	_release(Vector2(300, 464))
	eq(m.towers.size(), 1, "built on release")
	eq(m.economy.currency, 150)
	eq(p.mode, PlacementController.Mode.NONE, "session ended")
	_release(Vector2(300, 464))
	_release(Vector2(300, 464), true)
	eq(m.towers.size(), 1, "repeated release does not double-place")
	eq(m.economy.currency, 150)


func test_drag_cancel_over_palette_and_invalid_drop() -> void:
	_setup()
	p.begin_from_palette(tdef, Vector2(1220, 100))
	_motion(Vector2(700, 464))
	_release(Vector2(1200, 300)) # back over the palette
	eq(m.towers.size(), 0, "dropping on palette cancels")
	p.begin_from_palette(tdef, Vector2(1220, 100))
	_motion(Vector2(300, 364)) # ghost at y=300: on the path
	check(not p.is_valid(), "invalid on path")
	_release(Vector2(300, 364))
	eq(m.towers.size(), 0, "invalid drop builds nothing")
	eq(m.economy.currency, 250, "no charge")
	eq(p.mode, PlacementController.Mode.NONE)


func test_tap_to_place_reposition_and_confirm() -> void:
	_setup()
	p.begin_from_palette(tdef, Vector2(1220, 100))
	_release(Vector2(1220, 100)) # tap on the palette button, no drag
	eq(p.mode, PlacementController.Mode.TAP)
	check(not p.ghost_visible, "no ghost until the map is tapped")
	_release(Vector2(300, 400), true)
	check(p.ghost_pos.is_equal_approx(Vector2(300, 400)), "tap sets ghost (no finger offset)")
	_release(Vector2(360, 420), true)
	check(p.ghost_pos.is_equal_approx(Vector2(360, 420)), "second tap repositions")
	eq(m.towers.size(), 0, "tapping the map alone never builds")
	p.confirm()
	p.confirm()
	eq(m.towers.size(), 1, "confirm builds exactly once")
	check(m.towers[0].position.is_equal_approx(Vector2(360, 420)), "at the repositioned spot")
	eq(m.economy.currency, 150)


func test_tap_mode_cancel_paths() -> void:
	_setup()
	p.begin_from_palette(tdef, Vector2(1220, 100))
	_release(Vector2(1220, 100))
	p.begin_from_palette(tdef, Vector2(1220, 100)) # same palette button again
	eq(p.mode, PlacementController.Mode.NONE, "re-tapping the palette button cancels")
	p.begin_from_palette(tdef, Vector2(1220, 100))
	_release(Vector2(1220, 100))
	_release(Vector2(300, 300), true) # on path
	p.confirm()
	eq(m.towers.size(), 0, "invalid confirm builds nothing")
	eq(p.mode, PlacementController.Mode.TAP, "tap session stays open for repositioning")
	p.cancel()
	eq(p.mode, PlacementController.Mode.NONE)
	eq(m.economy.currency, 250)


func test_placement_disabled_while_paused_and_cancelled_on_pause() -> void:
	_setup()
	p.begin_from_palette(tdef, Vector2(1220, 100))
	_release(Vector2(1220, 100))
	m.set_paused(true)
	eq(p.mode, PlacementController.Mode.NONE, "pausing cancels the session")
	p.begin_from_palette(tdef, Vector2(1220, 100))
	eq(p.mode, PlacementController.Mode.NONE, "cannot start placing while paused")
	m.set_paused(false)


func test_unaffordable_preview_is_invalid() -> void:
	_setup(50)
	p.begin_from_palette(tdef, Vector2(1220, 100))
	_release(Vector2(1220, 100))
	_release(Vector2(300, 400), true)
	eq(p.ghost_result, PlacementRules.Result.OK, "spot itself is fine")
	check(not p.is_valid(), "but unaffordable -> invalid")
	p.confirm()
	eq(m.towers.size(), 0)
	eq(m.economy.currency, 50)


func test_tap_selects_tower() -> void:
	_setup()
	var t := m.try_build(tdef, Vector2(300, 400))
	_release(Vector2(305, 403), true)
	check(p.selected == t and t.selected, "tap on tower selects it")
	_release(Vector2(700, 600), true)
	check(p.selected == null and not t.selected, "tap elsewhere deselects")
