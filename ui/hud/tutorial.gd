class_name Tutorial
extends Control
## First-match onboarding (2026-11-21, CrazyGames quality feedback): shown in level 1 until it is finished or
## skipped once (lifetime counter "tutorial_done"). Visual first, one short line per step, never blocks play:
##   1. drag a tower from the palette onto the map (animated pointer from the card to a good spot)
##   2. start the first wave (pointer on the Start button)
##   3. after wave 1: build a Coil (it hits every enemy around it)
##   4. once a later wave is cleared: tap a tower, then pick an upgrade
## A "Skip tutorial" button ends it at any time. Lives inside the HUD root, so it scales with the HUD.

const P = preload("res://ui/style/visual_palette.gd")
const COUNTER := "tutorial_done"
enum Step { BUILD, START, COIL, UPGRADE, DONE }

var hud: Hud
var controller: MatchController
var placement: PlacementController
var step: Step = Step.BUILD
var _t := 0.0
var _caption: PanelContainer
var _caption_label: Label
var _step_label: Label
var _skip: Button
var _spot := Vector2.INF ## world position suggested for the next build
var _waiting := false ## between steps (e.g. COIL waits for wave 1 to be cleared)


## Level 1, never finished / skipped before, not a challenge, not the lab.
static func should_run(level: LevelDef, is_lab: bool, is_challenge: bool) -> bool:
	if is_lab or is_challenge or level == null or String(level.id) != "level_01":
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("Progression"):
		return false
	var pm: ProgressionModel = tree.root.get_node("Progression").get("model")
	return pm != null and pm.profile.counter(COUNTER) == 0


func _ready() -> void:
	name = "Tutorial"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # offsets too, or the node stays 0x0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = PanelContainer.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_stylebox_override("panel", UiKit.chamfer(Color(P.BG_DEEP, 0.94), Color(P.CYAN, 0.8), 10, 2))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(h)
	_step_label = UiKit.title("1/4", 15, P.CYAN, 1)
	_step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_step_label)
	_caption_label = UiKit.label("", 17, P.TEXT)
	_caption_label.add_theme_font_override("font", UiKit.font("body_bold"))
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_caption_label)
	add_child(_caption)
	_skip = UiKit.button(I18n.t("Skip tutorial"), func() -> void: finish(), Vector2(0, 36), "GhostButton", "forward")
	_skip.name = "SkipTutorial"
	_skip.add_theme_font_size_override("font_size", 14)
	add_child(_skip)
	controller.tower_built.connect(_on_built)
	controller.tower_upgraded.connect(func(_tw: Tower) -> void:
		if step == Step.UPGRADE:
			finish())
	controller.waves.wave_started.connect(func(_i: int, _b: int) -> void:
		if step == Step.START:
			_go(Step.COIL, true) # shown again once wave 1 is cleared
		elif step == Step.COIL and controller.waves.index >= 2:
			_go(Step.UPGRADE, true)) # player did not build a Coil: move on
	controller.waves.wave_cleared.connect(func(i: int, _r: int) -> void:
		if step == Step.COIL and i >= 0:
			_waiting = false
			_pick_spot()
		elif step == Step.UPGRADE and i >= 1:
			_waiting = false)
	controller.match_ended.connect(func(_w: bool) -> void: finish())
	if not controller.towers.is_empty(): # resumed / already built: skip ahead
		_go(Step.START)
	else:
		_go(Step.BUILD)


func _go(s: Step, wait: bool = false) -> void:
	step = s
	_waiting = wait
	_t = 0.0
	if s == Step.BUILD or s == Step.COIL:
		_pick_spot()
	var texts := {
		Step.BUILD: "Drag a tower onto the map, next to the path",
		Step.START: "Start the first wave",
		Step.COIL: "Coil zaps every enemy around it. Build one!",
		Step.UPGRADE: "Tap a tower, then pick an upgrade",
	}
	if texts.has(s):
		_caption_label.text = I18n.t(texts[s])
		_step_label.text = "%d/4" % (int(s) + 1)
	queue_redraw()


func _on_built(t: Tower) -> void:
	if step == Step.BUILD:
		_go(Step.START)
	elif step == Step.COIL and t.def.id == &"coil":
		_go(Step.UPGRADE, true)


## Marks the tutorial as done (finished or skipped) so it never shows again, then fades out.
func finish() -> void:
	if step == Step.DONE:
		return
	step = Step.DONE
	var tree := get_tree()
	if tree != null and tree.root.has_node("Progression"):
		var pm: ProgressionModel = tree.root.get_node("Progression").get("model")
		if pm != null and pm.profile.counter(COUNTER) == 0:
			pm.profile.add_counter(COUNTER, 1)
			pm.save()
	UiKit.fade_out(self, 0.25, func() -> void: queue_free())


## A free spot 50-65 px beside the route, a little way in from the entrance (so it is on screen).
func _pick_spot() -> void:
	_spot = Vector2.INF
	if controller.routes.is_empty():
		return
	var probe: TowerDef = load("res://data/towers/pulse.tres")
	var r: RoutePath = controller.routes[0]
	var d := 220.0 + (90.0 * controller.towers.size())
	while d < r.total_length - 100.0:
		var seg := r.segment_for(d, 0)
		var p := r.position_at(d, seg)
		var ahead := r.position_at(minf(d + 10.0, r.total_length), r.segment_for(minf(d + 10.0, r.total_length), seg))
		var normal := (ahead - p).normalized().orthogonal()
		for side: float in [1.0, -1.0]:
			var c := p + normal * 58.0 * side
			if c.x > 40.0 and c.x < 1100.0 and c.y > Hud.TOP_H + 100.0 and c.y < 680.0 \
					and controller.validate_placement(probe, c) == PlacementRules.Result.OK:
				_spot = c
				return
		d += 40.0


func _process(delta: float) -> void:
	_t += delta
	if step == Step.DONE:
		return
	if step == Step.UPGRADE and not _waiting and controller.towers.is_empty():
		finish()
		return
	_place_caption()
	queue_redraw()


func _place_caption() -> void:
	var area := get_rect()
	_caption.visible = not _waiting
	_skip.reset_size()
	_skip.position = Vector2(12.0, Hud.TOP_H + 12.0)
	_caption.reset_size()
	# centred over the map, but never under the Skip button; too narrow (small screens) -> the row below it
	var left := _skip.position.x + _skip.size.x + 10.0
	var right := area.size.x - Hud.PALETTE_W - 10.0
	var x := maxf((area.size.x - Hud.PALETTE_W - _caption.size.x) * 0.5, left)
	if x + _caption.size.x <= right:
		_caption.position = Vector2(x, Hud.TOP_H + 12.0)
	else:
		_caption.position = Vector2(12.0, _skip.position.y + _skip.size.y + 8.0)


# ---------------------------------------------------------------- pointer drawing

## World position -> this node's local drawing space (HUD layer is scaled by ui_scale, root inset by the
## safe area).
func _to_layer(world: Vector2) -> Vector2:
	return controller.get_global_transform_with_canvas() * world / maxf(hud.ui_scale, 0.01) - global_position


func _center_of(c: Control) -> Vector2:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Vector2.INF
	return c.get_global_rect().get_center() - global_position


func _draw() -> void:
	if step == Step.DONE or _waiting:
		return
	match step:
		Step.BUILD:
			_drag_hint(_center_of(hud.find_child("Card_pulse", true, false) as Control))
		Step.START:
			_tap_hint(_center_of(hud.get("_start_btn") as Control))
		Step.COIL:
			_drag_hint(_center_of(hud.find_child("Card_coil", true, false) as Control))
		Step.UPGRADE:
			var panel := hud.get("_panel") as Control
			if panel != null and panel.visible:
				var btns: Array = panel.get("_branch_buttons")
				_tap_hint(_center_of(btns[0] as Control) if not btns.is_empty() else Vector2.INF)
			elif not controller.towers.is_empty():
				_tap_hint(_to_layer(controller.towers[0].position))


## Card -> map spot: a dot travels along a dashed line and lands in a pulsing ring.
func _drag_hint(from: Vector2) -> void:
	if from == Vector2.INF or _spot == Vector2.INF:
		return
	var to := _to_layer(_spot)
	var col := P.CYAN
	var steps := 18
	for i in range(steps):
		if i % 2 == 0:
			draw_line(from.lerp(to, float(i) / steps), from.lerp(to, float(i + 1) / steps), Color(col, 0.45), 2.0)
	var k := fmod(_t, 1.6) / 1.2
	var pos := from.lerp(to, ease(clampf(k, 0.0, 1.0), -2.0))
	_ring(to, 26.0 + 6.0 * sin(_t * 5.0), col)
	draw_circle(pos, 9.0, Color(col, 0.9))
	draw_circle(pos, 4.0, Color.WHITE)
	_ring(from, 30.0, Color(col, 0.6))


## Pulsing ring + bouncing arrow at the target: from above, or from below for targets near the top edge
## (the Start button), so the arrow stays on screen.
func _tap_hint(at: Vector2) -> void:
	if at == Vector2.INF:
		return
	var col := P.ORANGE
	_ring(at, 30.0 + 6.0 * sin(_t * 5.0), col)
	var dir := 1.0 if at.y > 90.0 else -1.0 # 1: arrow above, pointing down
	var tip := at + Vector2(0, -dir * (38.0 + 8.0 * absf(sin(_t * 4.0))))
	var pts := PackedVector2Array()
	for v: Vector2 in [Vector2.ZERO, Vector2(-12, -16), Vector2(-4, -16), Vector2(-4, -30), Vector2(4, -30),
			Vector2(4, -16), Vector2(12, -16)]:
		pts.append(tip + Vector2(v.x, v.y * dir))
	draw_colored_polygon(pts, col)


func _ring(at: Vector2, r: float, col: Color) -> void:
	draw_arc(at, r, 0.0, TAU, 40, Color(col, 0.9), 3.0)
	draw_arc(at, r + 8.0, 0.0, TAU, 40, Color(col, 0.3), 2.0)
