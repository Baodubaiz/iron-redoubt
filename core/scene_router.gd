extends Node
## Autoload "SceneRouter": scene transitions and the match request handed to the match scene.

const MAIN_MENU := "res://ui/menus/main_menu.tscn"
const CAMPAIGN := "res://ui/menus/campaign_select.tscn"
const RESEARCH := "res://ui/menus/research_screen.tscn"
const META := "res://ui/menus/meta_screen.tscn"
const SETTINGS := "res://ui/menus/settings_screen.tscn"
const CODEX := "res://ui/menus/codex_screen.tscn"
const SHOP := "res://ui/menus/shop_screen.tscn"
const LOADOUT := "res://ui/menus/loadout_screen.tscn"
const MATCH_SCENE := "res://gameplay/match/match_scene.tscn"
const LAB_LEVEL := "res://data/levels/combat_lab.tres"

var pending_level: LevelDef
var pending_challenge: ChallengeDef
var pending_period: String = ""
## Dev sandbox: no meta restrictions, results are not submitted to progression.
var pending_is_lab: bool = false
## Towers picked on the loadout screen for pending_level. Empty = no restriction (every owned
## tower available), which is what challenges and the Combat Lab use.
var pending_loadout: Array[StringName] = []
## Set by play_level(), before the loadout screen builds its tower list, so a level that introduces
## a new tower (LevelDef.unlock_tower_on_start) shows it there (with a "New" badge) instead of
## granting it silently once the match starts. Null = this level doesn't unlock one / already owned.
var pending_new_tower: TowerDef = null

## Screen transition (presentation only): the scene still changes immediately (deferred, as before);
## a dark cover with a cyan scan line then reveals the new screen.
var _fx_layer: CanvasLayer
var _cover: ColorRect
var _scan: ColorRect
var _fx_tween: Tween


func _ready() -> void:
	CrazyGamesSdk.init() # no-op outside the CrazyGames web build
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 100
	_fx_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fx_layer)
	_cover = ColorRect.new()
	_cover.color = Color("070B16")
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.modulate.a = 0.0
	_fx_layer.add_child(_cover)
	_scan = ColorRect.new()
	_scan.color = Color(0.22, 0.85, 0.96, 0.55)
	_scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scan.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_scan.custom_minimum_size = Vector2(0, 3)
	_scan.modulate.a = 0.0
	_fx_layer.add_child(_scan)


func _reveal() -> void:
	if _cover == null:
		return
	if _fx_tween != null:
		_fx_tween.kill()
	_cover.modulate.a = 1.0 # covers the swap (and any first-load hitch) immediately
	_scan.modulate.a = 0.0
	# start revealing only once the new scene has been built and drawn, so a slow first load
	# does not eat the animation
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var h := get_viewport().get_visible_rect().size.y
	_scan.modulate.a = 1.0
	_scan.position.y = 0.0
	if _fx_tween != null:
		_fx_tween.kill()
	_fx_tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fx_tween.tween_property(_cover, "modulate:a", 0.0, 0.34).set_delay(0.03).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(_scan, "position:y", h, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(_scan, "modulate:a", 0.0, 0.36)


## Mid-match checkpoint (MatchSnapshot) to rebuild on the next match scene; consumed there.
var pending_resume: Dictionary = {}


## Continues the saved campaign match (main menu "Continue").
func resume_match(d: Dictionary) -> void:
	var lvl := MatchSnapshot.level_of(Progression.model.campaign, d)
	if lvl == null:
		MatchSnapshot.clear()
		return
	pending_level = lvl
	pending_challenge = null
	pending_period = ""
	pending_is_lab = false
	pending_new_tower = null
	var ids: Array[StringName] = []
	for id in d.get("loadout", []):
		ids.append(StringName(id))
	pending_loadout = ids
	pending_resume = d
	_change(MATCH_SCENE)


## Campaign level: stop at the loadout screen first (pick which owned towers to bring).
func play_level(level: LevelDef) -> void:
	pending_level = level
	pending_challenge = null
	pending_period = ""
	pending_is_lab = false
	pending_new_tower = Progression.model.grant_level_start(level) # so the loadout screen can show it
	_change(LOADOUT)


## CrazyGames full launch asks that a new player lands straight in gameplay (2026-11-19): the very first
## start of a fresh profile skips the menu and the loadout screen and opens level 1 with the owned towers.
var first_run_done := false


func quick_start(level: LevelDef) -> void:
	first_run_done = true
	pending_level = level
	pending_challenge = null
	pending_period = ""
	pending_is_lab = false
	pending_new_tower = Progression.model.grant_level_start(level)
	var ids: Array[StringName] = []
	for d in level.available_towers:
		if Progression.model.profile.owns_tower(d.id) and ids.size() < 6:
			ids.append(d.id)
	pending_loadout = ids
	_change(MATCH_SCENE)


## Called by the loadout screen's confirm button.
func start_match_with_loadout(ids: Array[StringName]) -> void:
	pending_loadout = ids
	_change(MATCH_SCENE)


func play_challenge(c: ChallengeDef, period_key: String) -> void:
	pending_level = c.level
	pending_challenge = c
	pending_period = period_key
	pending_is_lab = false
	pending_loadout = [] # challenges keep every owned tower available (their own banned_towers rule)
	_change(MATCH_SCENE)


func play_lab() -> void:
	pending_level = load(LAB_LEVEL)
	pending_challenge = null
	pending_is_lab = true
	pending_loadout = []
	_change(MATCH_SCENE)


func restart_level() -> void:
	_change(MATCH_SCENE)


func to_menu() -> void:
	_change(MAIN_MENU)


func to_campaign() -> void:
	_change(CAMPAIGN)


func to_research() -> void:
	_change(RESEARCH)


func to_meta() -> void:
	_change(META)


func to_settings() -> void:
	_change(SETTINGS)


func to_codex() -> void:
	_change(CODEX)


func to_shop() -> void:
	_change(SHOP)


func to_loadout() -> void:
	_change(LOADOUT)


## Android back button / gesture (quit_on_go_back is off): the current screen decides.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func handle_back() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("on_back"):
		scene.on_back()
	else:
		to_menu()


## Fade the cover in (0.16 s), swap the scene under it, then reveal (2026-11-19: no more hard cut to black).
var _changing := false


func _change(path: String) -> void:
	if _changing:
		return
	_changing = true
	get_tree().paused = false
	if _cover != null:
		if _fx_tween != null:
			_fx_tween.kill()
		_cover.mouse_filter = Control.MOUSE_FILTER_STOP # no double taps while fading
		_fx_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_fx_tween.tween_property(_cover, "modulate:a", 1.0, 0.16)
		await _fx_tween.finished
	get_tree().change_scene_to_file.call_deferred(path)
	_changing = false
	if _cover != null:
		_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal()
