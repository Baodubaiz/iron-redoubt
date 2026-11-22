class_name Tutorial
extends Control
## First-match onboarding (2026-11-21, CrazyGames quality feedback; 2026-11-22 reworked with the user): shown in
## level 1 until it is finished or skipped once (lifetime counter "tutorial_done"). Each step = a pointer, a short
## instruction and a one-line description of why. Never blocks play:
##   1. drag 3 towers onto the map            4. after wave 1: build a Coil
##   2. start the first wave                  5. call the next wave early for bonus money
##   3. fast-forward x2                       6. max out one tower's branch (level 3/3)
##   7. pick a targeting priority (First / Strongest / Cluster / Air) in the tower panel
##   then: counted as done, and until the match ends a "spare money? build more" pointer whenever a tower is
##   affordable (following the old one-tower tutorial lost level 1; a level-1 follower sim of this flow wins 20/20).
## A "Skip tutorial" button ends it at any time. Lives inside the HUD root, so it scales with the HUD.

const P = preload("res://ui/style/visual_palette.gd")
const COUNTER := "tutorial_done"
enum Step { BUILD, START, SPEED, COIL, EARLY, UPGRADE, TARGET, MORE, DONE }
const FIRST_TOWERS := 3 ## towers asked for before wave 1
const NUMBERED := 7 ## steps shown as n/7 (MORE is "+")
const TEXT := {
	Step.START: ["Start the first wave", "Enemies walk the path to your base. Each one that gets through costs 1 HP."],
	Step.SPEED: ["Speed up the game: x2", "Fast-forward to skip the waiting. Tap again to go back to x1."],
	Step.COIL: ["Coil zaps every enemy around it. Build one!",
		"Its discharge hits every enemy in the ring, ground and air. Great against packs."],
	Step.EARLY: ["Call the next wave early", "Calling early pays bonus money: the sooner you call, the bigger the bonus."],
	Step.TARGET: ["Choose who a tower shoots first",
		"First: the leader. Strongest: the toughest (bosses). Cluster: the biggest group. Air: fliers."],
	Step.MORE: ["Spare money? Build more towers for the big waves",
		"Every kill pays. Money in the bank does not stop enemies: spend it."],
}

var hud: Hud
var controller: MatchController
var placement: PlacementController
var step: Step = Step.BUILD
var _t := 0.0
var _caption: PanelContainer
var _caption_label: Label
var _desc_label: Label
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	_step_label = UiKit.title("1/%d" % NUMBERED, 15, P.CYAN, 1)
	_step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_step_label)
	_caption_label = UiKit.label("", 17, P.TEXT)
	_caption_label.add_theme_font_override("font", UiKit.font("body_bold"))
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_caption_label)
	_desc_label = UiKit.label("", 14, P.TEXT_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_desc_label)
	add_child(_caption)
	_skip = UiKit.button(I18n.t("Skip tutorial"), func() -> void: finish(), Vector2(0, 36), "GhostButton", "forward")
	_skip.name = "SkipTutorial"
	_skip.add_theme_font_size_override("font_size", 14)
	add_child(_skip)
	controller.tower_built.connect(_on_built)
	controller.tower_upgraded.connect(func(_tw: Tower) -> void:
		if step == Step.UPGRADE:
			if _best_tier() >= UpgradeRules.MAX_TIER:
				_mark_done()
				_go(Step.TARGET if _aimed_tower() != null else Step.MORE)
			else:
				_go(Step.UPGRADE)) # refresh the level count
	controller.speed_changed.connect(func(sp: int) -> void:
		if step == Step.SPEED and sp > 1:
			_go(Step.COIL, controller.waves.index == 0 and not _wave1_cleared))
	controller.waves.wave_started.connect(func(i: int, _b: int) -> void:
		if step == Step.START:
			_go(Step.SPEED)
		elif step == Step.EARLY:
			_go(Step.UPGRADE)
		elif (step == Step.SPEED or step == Step.COIL) and i >= 1: # missed the Coil / early call: move on
			_go(Step.UPGRADE))
	controller.waves.wave_cleared.connect(func(i: int, _r: int) -> void:
		if i == 0:
			_wave1_cleared = true
		if step == Step.COIL:
			_waiting = false
			_pick_spot())
	controller.match_ended.connect(func(_w: bool) -> void: finish())
	if controller.towers.size() >= FIRST_TOWERS: # resumed / already built: skip ahead
		_go(Step.START)
	else:
		_go(Step.BUILD)


var _wave1_cleared := false


func _go(s: Step, wait: bool = false) -> void:
	step = s
	_waiting = wait
	_t = 0.0
	if s == Step.BUILD or s == Step.COIL or s == Step.MORE:
		_pick_spot()
	match s:
		Step.BUILD:
			_caption_label.text = I18n.f("Drag 3 towers onto the map, next to the path (%d/3)",
				mini(controller.towers.size(), FIRST_TOWERS))
			_desc_label.text = I18n.t("Towers shoot enemies in range on their own. Place them close to the path.")
		Step.UPGRADE:
			_caption_label.text = I18n.f("Max out one tower (level %d/3)", _best_tier())
			_desc_label.text = I18n.t("Tap a tower and keep upgrading the same branch. Level 3 makes it far stronger.")
		_:
			if TEXT.has(s):
				_caption_label.text = I18n.t(TEXT[s][0])
				_desc_label.text = I18n.t(TEXT[s][1])
	_step_label.text = "%d/%d" % [int(s) + 1, NUMBERED] if s < Step.MORE else "+"
	queue_redraw()


func _on_built(t: Tower) -> void:
	if step == Step.BUILD:
		_go(Step.START if controller.towers.size() >= FIRST_TOWERS else Step.BUILD)
	elif step == Step.COIL and t.def.id == &"coil":
		_go(Step.EARLY)
	elif step == Step.MORE:
		_pick_spot()


## Ends the tutorial (skipped, or the match is over): marked done so it never shows again, then fades out.
func finish() -> void:
	if step == Step.DONE:
		return
	step = Step.DONE
	_mark_done()
	UiKit.fade_out(self, 0.25, func() -> void: queue_free())


func _mark_done() -> void:
	var tree := get_tree()
	if tree != null and tree.root.has_node("Progression"):
		var pm: ProgressionModel = tree.root.get_node("Progression").get("model")
		if pm != null and pm.profile.counter(COUNTER) == 0:
			pm.profile.add_counter(COUNTER, 1)
			pm.save()


## Cheapest tower the player can build here (the "spare money" hint shows once it is affordable).
func _cheapest() -> TowerDef:
	var best: TowerDef = null
	for d in controller.available_towers():
		if best == null or d.cost < best.cost:
			best = d
	return best


## Highest branch level on any tower, and the tower / branch holding it (the one to keep upgrading).
func _best_tier() -> int:
	var best := 0
	for tw in controller.towers:
		for b in range(tw.tiers.size()):
			best = maxi(best, tw.tiers[b])
	return best


## A tower with a targeting choice (Coil and auras hit everything in range): the maxed one if it aims.
func _aimed_tower() -> Tower:
	var f: Tower = _focus()[0]
	if f != null and not f.is_aura() and not f.is_pulse():
		return f
	for tw in controller.towers:
		if not tw.is_aura() and not tw.is_pulse():
			return tw
	return null


func _focus() -> Array: # [tower, branch]
	var ft: Tower = null
	var fb := 0
	var best := -1
	for tw in controller.towers:
		for b in range(tw.tiers.size()):
			if tw.tiers[b] > best:
				best = tw.tiers[b]
				ft = tw
				fb = b
	return [ft, fb]


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
	if step == Step.UPGRADE and controller.towers.is_empty():
		_mark_done()
		_go(Step.MORE)
	if step == Step.EARLY:
		_waiting = not (hud.get("_start_btn") as Control).is_visible_in_tree()
	if step == Step.TARGET:
		for tw in controller.towers:
			if tw.targeting_override >= 0:
				_go(Step.MORE)
				break
		if step == Step.TARGET and _aimed_tower() == null:
			_go(Step.MORE)
	if step == Step.MORE:
		var cheap := _cheapest()
		_waiting = cheap == null or controller.economy.currency < cheap.cost or _spot == Vector2.INF
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
		Step.START, Step.EARLY:
			_tap_hint(_center_of(hud.get("_start_btn") as Control))
		Step.SPEED:
			_tap_hint(_center_of(hud.get("_speed_btn") as Control))
		Step.COIL:
			_drag_hint(_center_of(hud.find_child("Card_coil", true, false) as Control))
		Step.MORE: # alternate Pulse / Coil suggestions
			var id := "coil" if controller.towers.size() % 2 == 1 else "pulse"
			var cost: int = (load("res://data/towers/%s.tres" % id) as TowerDef).cost
			if controller.economy.currency < cost:
				id = "pulse"
			_drag_hint(_center_of(hud.find_child("Card_%s" % id, true, false) as Control))
		Step.TARGET: # open an aiming tower, then point at "Strongest"
			var panel := hud.get("_panel") as Control
			var btns: Array = panel.get("_target_buttons") if panel != null else []
			if panel != null and panel.visible and btns.size() > 1 and (btns[1] as Control).is_visible_in_tree():
				_tap_hint(_center_of(btns[1] as Control))
			elif _aimed_tower() != null:
				_tap_hint(_to_layer(_aimed_tower().position))
		Step.UPGRADE: # the tower with the highest branch: open it, then the same branch again
			var f := _focus()
			var panel := hud.get("_panel") as Control
			if panel != null and panel.visible and panel.get("tower") != null:
				var sel: Tower = panel.get("tower")
				var b: int = f[1] if sel == f[0] else 0
				if f[0] != null and sel != f[0] and sel.tiers.max() > 0:
					b = sel.tiers.find(sel.tiers.max())
				var btns: Array = panel.get("_branch_buttons")
				_tap_hint(_center_of(btns[b] as Control) if b < btns.size() else Vector2.INF)
			elif f[0] != null:
				_tap_hint(_to_layer((f[0] as Tower).position))


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
