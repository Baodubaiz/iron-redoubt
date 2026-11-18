extends TestCase
## Regression: a level that introduces a new tower (LevelDef.unlock_tower_on_start) must grant it
## before the loadout screen builds its tower list (SceneRouter.play_level), so the player actually
## sees and can pick it there (with a "New" badge) instead of it being silently forced into the
## match, or missing entirely, afterwards.

var _saved: ProgressionModel
var _saved_level: LevelDef
var _saved_loadout: Array[StringName]
var _saved_new_tower: TowerDef
var _scene: Node
var _loadout_scene: Node


func before_each() -> void:
	super.before_each()
	_saved = Progression.model
	var pm := ProgressionModel.new(_saved.campaign, MemoryStore.new())
	pm.load_profile()
	Progression.model = pm
	_saved_level = SceneRouter.pending_level
	_saved_loadout = SceneRouter.pending_loadout
	_saved_new_tower = SceneRouter.pending_new_tower


func after_each() -> void:
	super.after_each()
	Progression.model = _saved
	SceneRouter.pending_level = _saved_level
	SceneRouter.pending_challenge = null
	SceneRouter.pending_is_lab = false
	SceneRouter.pending_loadout = _saved_loadout
	SceneRouter.pending_new_tower = _saved_new_tower
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	if _loadout_scene != null and is_instance_valid(_loadout_scene):
		_loadout_scene.queue_free()


func test_play_level_grants_the_towers_before_the_loadout_screen_builds() -> void:
	var campaign := Progression.model.campaign
	var l2 := campaign.levels[1] # level_02, unlocks nova on start
	var nova := l2.unlock_tower_on_start
	check(nova != null and nova.id == &"nova", "level_02 still unlocks Nova on start")
	check(not Progression.model.profile.owns_tower(&"nova"), "not owned yet")
	SceneRouter.play_level(l2)
	check(Progression.model.profile.owns_tower(&"nova"), "play_level grants it right away")
	check(SceneRouter.pending_new_tower != null and SceneRouter.pending_new_tower.id == &"nova",
		"play_level records it so the loadout screen can show it")
	_loadout_scene = load("res://ui/menus/loadout_screen.tscn").instantiate()
	tree.root.add_child(_loadout_scene)
	check(_loadout_scene.find_child("Card_nova", true, false) != null, "Nova is a pickable loadout card")
	check((_loadout_scene.get("_selected") as Array).has(&"nova"), "Nova is picked by default")
	# The player confirms the loadout (Nova included) and the match actually starts.
	var loadout: Array[StringName] = [&"pulse", &"nova"]
	SceneRouter.start_match_with_loadout(loadout)
	_scene = load("res://gameplay/match/match_scene.tscn").instantiate()
	tree.root.add_child(_scene)
	var controller: MatchController = _scene.get("controller")
	check(controller.modifiers.owned_towers.has(&"nova"), "Nova is in this match's owned_towers")
	check(controller.is_tower_available(nova), "Nova can actually be built this match")
