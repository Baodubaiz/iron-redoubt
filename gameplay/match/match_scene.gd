extends Node2D
## Composes a playable match: MatchController (world + rules), PlacementController, HUD.
## Applies meta progression (research, owned towers, challenge restrictions) and submits the
## result exactly once when the match ends.

var controller: MatchController
var placement: PlacementController
var hud: Hud
var _is_lab := false
var _submitted := false
## Generated once at match start (not only at the end) so consumable items can be tied to "this match"
## (ProgressionModel.use_item_block_reason: at most one use per item per match).
var _match_id := ""
## Presentation: brief world shake (boss arrival / EMP / boss death / base hit). Off with Reduce effects.
var _shake := 0.0
var _shake_amp := 0.0
var _world_offset := Vector2.ZERO
var camera: MatchCamera ## zoom / pan over the map
var _saves := false ## campaign match: checkpoint at every cleared wave (MatchSnapshot)


func _checkpoint() -> void:
	if _saves and not controller.is_over():
		MatchSnapshot.save(MatchSnapshot.capture(controller, _match_id, SceneRouter.pending_loadout))


func _ready() -> void:
	var lvl: LevelDef = SceneRouter.pending_level
	if lvl == null:
		lvl = Progression.model.campaign.levels[0]
		SceneRouter.pending_level = lvl
	_is_lab = SceneRouter.pending_is_lab
	_match_id = "%d-%08x" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]
	var resume: Dictionary = SceneRouter.pending_resume
	SceneRouter.pending_resume = {}
	if not resume.is_empty():
		_match_id = String(resume.get("match_id", _match_id)) # same match: items stay "one use per match"
	var mods: MatchModifiers = null
	# Granted by SceneRouter.play_level(), before the loadout screen, so it's a real pick there
	# (shown with a "New" badge) rather than silently forced into the match here.
	var new_tower: TowerDef = SceneRouter.pending_new_tower if (SceneRouter.pending_challenge == null and not _is_lab) else null
	if not _is_lab:
		mods = Progression.model.build_modifiers(SceneRouter.pending_challenge, SceneRouter.pending_period)
		if SceneRouter.pending_challenge == null and not SceneRouter.pending_loadout.is_empty():
			mods.owned_towers = SceneRouter.pending_loadout.duplicate() # loadout screen's pick
	controller = MatchController.new()
	controller.name = "Match"
	add_child(controller)
	controller.setup(lvl, int(resume.get("seed", -1)) if not resume.is_empty() else -1, null, mods)
	_saves = not _is_lab and SceneRouter.pending_challenge == null # mid-match save: campaign only
	if _saves:
		if resume.is_empty() or not MatchSnapshot.apply(controller, resume):
			MatchSnapshot.clear() # a fresh start (or an unusable save) replaces any old checkpoint
		else:
			MatchSnapshot.refund_items_after(resume) # items spent in the wave being replayed come back
		controller.waves.prep_started.connect(func(_i: int, _s: float) -> void: _checkpoint())
	# CrazyGames SDK (no-op elsewhere): play / break signals and a celebration when a boss falls.
	controller.paused_changed.connect(func(p: bool) -> void:
		if p:
			CrazyGamesSdk.gameplay_stop()
		elif not controller.is_over():
			CrazyGamesSdk.gameplay_start())
	controller.enemy_killed.connect(func(e: Enemy) -> void:
		if e.is_boss():
			CrazyGamesSdk.happytime())
	tree_exiting.connect(func() -> void: CrazyGamesSdk.gameplay_stop())
	CrazyGamesSdk.gameplay_start()
	placement = PlacementController.new()
	placement.name = "Placement"
	placement.controller = controller
	controller.add_child(placement) # drawn above towers/enemies, same world transform
	UiKit.grow_small_text = false # the HUD scales as a whole on small screens (Hud.ui_scale)
	tree_exiting.connect(func() -> void: UiKit.grow_small_text = true)
	hud = Hud.new()
	hud.controller = controller
	hud.placement = placement
	hud.wave_preview = not _is_lab and Progression.model.has_wave_preview()
	hud.challenge = SceneRouter.pending_challenge
	hud.items_enabled = not _is_lab
	hud.match_id = _match_id
	add_child(hud)
	if new_tower != null:
		hud.announce_new_tower.call_deferred(new_tower)
		SceneRouter.pending_new_tower = null # only announce once, not again on a retry
	var audio := MatchAudio.new()
	audio.controller = controller
	add_child(audio)
	controller.match_ended.connect(_on_match_ended)
	controller.boss_spawned.connect(func(_e: Enemy) -> void: shake(4.0, 0.45))
	controller.towers_disrupted.connect(func(_p: Vector2) -> void: shake(3.0, 0.3))
	controller.enemy_killed.connect(func(e: Enemy) -> void:
		if e.is_boss():
			shake(6.0, 0.5))
	controller.enemy_escaped.connect(func(_e: Enemy) -> void: shake(2.0, 0.15))
	camera = MatchCamera.new()
	camera.name = "Camera"
	camera.world = controller
	camera.placement = placement
	add_child(camera)
	get_viewport().size_changed.connect(_relayout)
	_relayout()


## Centres the 1280x720 world in the safe area and insets the HUD (notches, any aspect ratio).
func _relayout() -> void:
	var ins := ScreenLayout.insets(get_viewport())
	var vis := get_viewport().get_visible_rect().size
	# area the map may use: below the top bar, left of the tower palette, inside the safe area
	var k := hud.ui_scale # the HUD is drawn k times larger on small screens
	_world_offset = ScreenLayout.world_offset(vis, ins, (Hud.PALETTE_W + 8.0) * k)
	var area := Rect2(ins["left"], ins["top"] + Hud.TOP_H * k,
		vis.x - ins["left"] - ins["right"] - (Hud.PALETTE_W + 8.0) * k, vis.y - ins["top"] - ins["bottom"] - Hud.TOP_H * k)
	camera.reset(_world_offset, area)
	hud.apply_insets(ins)


func shake(amp: float, duration: float) -> void:
	if VisualPalette.reduce_effects:
		return
	_shake_amp = maxf(_shake_amp if _shake > 0.0 else 0.0, amp)
	_shake = maxf(_shake, duration)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		var k := _shake_amp * minf(1.0, _shake / 0.15)
		camera.shake = Vector2(randf_range(-k, k), randf_range(-k, k)).round() if _shake > 0.0 else Vector2.ZERO
		camera.refresh()


func _on_match_ended(_won: bool) -> void:
	CrazyGamesSdk.gameplay_stop()
	if _submitted:
		return
	_submitted = true
	if _saves:
		MatchSnapshot.clear() # finished: nothing to resume
	if _is_lab:
		hud.show_report({}, null)
		return
	var report := Progression.model.submit_match(controller.build_result(), _match_id)
	var next: LevelDef = null
	if SceneRouter.pending_challenge == null and controller.state == MatchController.State.WON:
		next = Progression.model.next_level(controller.level)
	hud.show_report(report, next)


## Android back: pause, or resume if already paused; after the match ends, leave.
func on_back() -> void:
	if controller.is_over():
		hud.call("_exit")
	else:
		controller.set_paused(not controller.paused)


func _notification(what: int) -> void:
	# Auto-pause when the app is backgrounded (mobile lifecycle) or loses focus.
	var backgrounded := what == NOTIFICATION_APPLICATION_PAUSED \
			or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"))
	if backgrounded:
		if controller != null and not controller.is_over():
			controller.set_paused(true)
