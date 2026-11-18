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


func _ready() -> void:
	var lvl: LevelDef = SceneRouter.pending_level
	if lvl == null:
		lvl = Progression.model.campaign.levels[0]
		SceneRouter.pending_level = lvl
	_is_lab = SceneRouter.pending_is_lab
	_match_id = "%d-%08x" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]
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
	controller.setup(lvl, -1, null, mods)
	placement = PlacementController.new()
	placement.name = "Placement"
	placement.controller = controller
	controller.add_child(placement) # drawn above towers/enemies, same world transform
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
	get_viewport().size_changed.connect(_relayout)
	_relayout()


## Centres the 1280x720 world in the safe area and insets the HUD (notches, any aspect ratio).
func _relayout() -> void:
	var ins := ScreenLayout.insets(get_viewport())
	_world_offset = ScreenLayout.world_offset(get_viewport().get_visible_rect().size, ins)
	controller.position = _world_offset
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
		controller.position = _world_offset + Vector2(randf_range(-k, k), randf_range(-k, k)).round()
		if _shake <= 0.0:
			controller.position = _world_offset


func _on_match_ended(_won: bool) -> void:
	if _submitted:
		return
	_submitted = true
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
