class_name PlacementController
extends Node2D
## Touch-first placement session shared by Drag & Drop and Tap-to-Place, plus tower selection.
## Drag: press a palette button and drag; the ghost floats above the finger; release to build.
## Tap: tap a palette button, tap the map to position the ghost (repeatable), then Build/Cancel.
## Mouse events are used because Godot emulates mouse from touch on mobile by default.

enum Mode { NONE, PRESS, DRAG, TAP }

const DRAG_THRESHOLD := 14.0
const DRAG_OFFSET := Vector2(0, -64)

signal session_changed(def: TowerDef) ## null when the session ends
signal ghost_changed(world_pos: Vector2, visible: bool, valid: bool)
signal message(text: String)
signal selection_changed(tower: Tower)
signal item_target_chosen(item: ConsumableDef, world_pos: Vector2)
signal aim_changed(item: ConsumableDef) ## null when aiming ends

var controller: MatchController
## Returns the palette's screen Rect2; releasing a drag there cancels it.
var palette_rect_provider: Callable

var mode: Mode = Mode.NONE
var def: TowerDef = null
var ghost_pos: Vector2 = Vector2.ZERO
var ghost_visible: bool = false
var ghost_result: PlacementRules.Result = PlacementRules.Result.OK
var can_afford: bool = true
var selected: Tower = null

var _press_pos: Vector2 = Vector2.ZERO
var aim_item: ConsumableDef = null ## a targeted item waiting for a tap on the map
var _aim_pos := Vector2.INF ## world position under the pointer (preview circle)


func _ready() -> void:
	controller.paused_changed.connect(func(p: bool) -> void:
		if p:
			cancel()
			cancel_aim())
	controller.match_ended.connect(func(_w: bool) -> void:
		cancel()
		cancel_aim()
		select(null))
	controller.economy.changed.connect(func(_c: int, _d: int, _r: String) -> void:
		if ghost_visible:
			_refresh_validity())


func is_valid() -> bool:
	return ghost_result == PlacementRules.Result.OK and can_afford


## Palette button pressed (button_down).
func begin_from_palette(tower_def: TowerDef, screen_pos: Vector2) -> void:
	if not controller.can_issue_commands() or not controller.is_tower_available(tower_def):
		return
	if mode == Mode.TAP and def == tower_def:
		cancel() # tapping the same palette button again cancels
		return
	select(null)
	cancel_aim()
	def = tower_def
	mode = Mode.PRESS
	_press_pos = screen_pos
	ghost_visible = false
	session_changed.emit(def)
	_emit_ghost()


## Targeted item: the next tap on the map drops it there. Same item again = cancel.
func begin_aim(item: ConsumableDef) -> void:
	if aim_item == item:
		cancel_aim()
		return
	cancel()
	select(null)
	aim_item = item
	_aim_pos = Vector2.INF
	aim_changed.emit(item)
	message.emit(I18n.f("Tap the map to use %s", I18n.t(item.display_name)))
	queue_redraw()


func cancel_aim() -> void:
	if aim_item == null:
		return
	aim_item = null
	_aim_pos = Vector2.INF
	aim_changed.emit(null)
	queue_redraw()


func cancel() -> void:
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	def = null
	ghost_visible = false
	session_changed.emit(null)
	_emit_ghost()


## Build/confirm button in tap mode.
func confirm() -> void:
	if mode == Mode.TAP and ghost_visible:
		_commit()


func select(t: Tower) -> void:
	if selected == t:
		return
	if selected != null and is_instance_valid(selected):
		selected.selected = false
	selected = t
	if selected != null:
		selected.selected = true
	_link_timer = 0.0
	queue_redraw()
	selection_changed.emit(selected)


func _input(event: InputEvent) -> void:
	if aim_item != null and event is InputEventMouseMotion:
		_aim_pos = _to_world((event as InputEventMouseMotion).position)
		queue_redraw()
	if mode != Mode.PRESS and mode != Mode.DRAG:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mode == Mode.PRESS and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			mode = Mode.DRAG
		if mode == Mode.DRAG:
			_move_ghost(_to_world(mm.position) + DRAG_OFFSET)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
			return
		if mode == Mode.DRAG:
			var over_palette := palette_rect_provider.is_valid() and (palette_rect_provider.call() as Rect2).has_point(mb.position)
			if over_palette or not ghost_visible:
				cancel()
			else:
				_commit()
		else:
			mode = Mode.TAP
			message.emit(I18n.f("Tap the map to place %s", I18n.t(def.display_name)))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	var wp := _to_world(mb.position)
	if aim_item != null:
		var it := aim_item
		cancel_aim()
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		item_target_chosen.emit(it, wp)
		return
	if mode == Mode.TAP:
		_move_ghost(wp)
		if is_inside_tree():
			get_viewport().set_input_as_handled()
	elif mode == Mode.NONE and controller.can_issue_commands():
		select(controller.tower_at(wp))


func _commit() -> void:
	_refresh_validity()
	if not is_valid():
		message.emit(I18n.t("Not enough currency") if ghost_result == PlacementRules.Result.OK else I18n.t(PlacementRules.RESULT_TEXT[ghost_result]))
		if mode == Mode.DRAG:
			cancel()
		return
	var build_def := def
	var pos := ghost_pos
	# End the session before building so a repeated release/confirm cannot place twice.
	cancel()
	var t := controller.try_build(build_def, pos)
	if t == null:
		message.emit(I18n.t("Cannot build here"))


func _move_ghost(world_pos: Vector2) -> void:
	ghost_pos = world_pos
	ghost_visible = true
	_refresh_validity()


func _refresh_validity() -> void:
	if def == null:
		return
	ghost_result = controller.validate_placement(def, ghost_pos)
	can_afford = controller.economy.can_afford(def.cost)
	_emit_ghost()


func _emit_ghost() -> void:
	queue_redraw()
	ghost_changed.emit(ghost_pos, ghost_visible and def != null, is_valid())


## Synergy indicator: lines between the selected tower and the Beacons buffing it (or the towers it buffs).
func _draw_synergy_links() -> void:
	if selected == null or not is_instance_valid(selected) or selected.sold:
		return
	var col := Color("4DE6A1", 0.75)
	if selected.is_beacon():
		for t in controller.towers:
			if t.buff_sources.has(selected):
				_dashed(selected.position, t.position, col)
				draw_arc(t.position, t.def.footprint_radius + 5.0, 0, TAU, 32, col, 2.0)
	else:
		for b in selected.buff_sources:
			if is_instance_valid(b):
				_dashed(b.position, selected.position, col)
				draw_arc(b.position, b.def.footprint_radius + 5.0, 0, TAU, 32, col, 2.0)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 0.001)
	var d := 0.0
	while d < length:
		draw_line(a + dir * d, a + dir * minf(d + 8.0, length), col, 2.0)
		d += 14.0


func _to_world(screen_pos: Vector2) -> Vector2:
	if not is_inside_tree():
		return screen_pos # headless tests: world == screen
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


var _link_timer: float = 0.0


func _process(delta: float) -> void:
	if selected != null:
		_link_timer -= delta
		if _link_timer <= 0.0:
			_link_timer = 0.25
			queue_redraw()


func _draw() -> void:
	_draw_synergy_links()
	if aim_item != null and _aim_pos != Vector2.INF:
		var col := Color("ff9f43") if aim_item.kind == ConsumableDef.Kind.AIRSTRIKE else Color("bfe9ff")
		draw_circle(_aim_pos, aim_item.radius, Color(col, 0.16))
		draw_arc(_aim_pos, aim_item.radius, 0.0, TAU, 64, Color(col, 0.9), 2.0)
	if not ghost_visible or def == null:
		return
	var ok := is_valid()
	var col := Color("4DE6A1") if ok else Color("FF5368")
	draw_set_transform(ghost_pos)
	draw_circle(Vector2.ZERO, def.attack_range, Color(col, 0.08))
	if ok:
		draw_arc(Vector2.ZERO, def.attack_range, 0, TAU, 64, Color(col, 0.6), 2.0)
		TowerArt.glow(self, Vector2.ZERO, def.footprint_radius * 1.8, Color(col, 0.35))
	draw_set_transform(Vector2.ZERO)
	# the real tower art, translucent (Reforged)
	var look := TowerArt.Look.new()
	look.def = def
	look.tint = Color(1, 1, 1, 0.75) if ok else Color(1.0, 0.55, 0.6, 0.55)
	TowerArt.draw(self, ghost_pos, look)
	draw_set_transform(ghost_pos)
	if not ok:
		# Invalid: dashed ring + X so validity does not rely on colour alone.
		var segs := 16
		for i in range(segs):
			if i % 2 == 0:
				draw_arc(Vector2.ZERO, def.footprint_radius + 3.0, TAU * i / segs, TAU * (i + 1) / segs, 4, col, 2.5)
		var k := def.footprint_radius * 0.6
		draw_line(Vector2(-k, -k), Vector2(k, k), col, 4.0)
		draw_line(Vector2(-k, k), Vector2(k, -k), col, 4.0)
	draw_set_transform(Vector2.ZERO)
