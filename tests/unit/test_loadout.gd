extends TestCase
## Loadout screen: pick up to LoadoutScreen.LOADOUT_SIZE owned towers before a campaign level starts.
## Challenges and the Combat Lab skip it (SceneRouter.play_challenge / play_lab clear pending_loadout).

var _saved: ProgressionModel
var _saved_level: LevelDef


func before_each() -> void:
	super.before_each()
	_saved = Progression.model
	var pm := ProgressionModel.new(_saved.campaign, MemoryStore.new())
	pm.load_profile()
	Progression.model = pm
	_saved_level = SceneRouter.pending_level


func after_each() -> void:
	super.after_each()
	Progression.model = _saved
	SceneRouter.pending_level = _saved_level
	SceneRouter.pending_loadout = []


func _own(ids: Array) -> void:
	for id in ids:
		Progression.model.profile.unlock_tower(StringName(id))


func _scene() -> Control:
	var s: Control = load("res://ui/menus/loadout_screen.tscn").instantiate()
	tree.root.add_child(s)
	_nodes.append(s)
	return s


func test_default_selection_is_capped_at_loadout_size() -> void:
	SceneRouter.pending_level = Progression.model.campaign.levels[0]
	_own(["nova", "lance", "beacon", "trap", "venom", "sniper", "bastion", "spotter"]) # pulse + coil + 8 = 10 owned
	var s := _scene()
	eq(s._selected.size(), LoadoutScreen.LOADOUT_SIZE)
	eq(s._buttons.size(), 10, "every owned, level-available tower gets a card")
	var pressed := 0
	for b in s._buttons.values():
		if (b as Button).button_pressed:
			pressed += 1
	eq(pressed, LoadoutScreen.LOADOUT_SIZE, "exactly the default pick shows pressed")


func test_fewer_owned_than_the_cap_selects_all_of_them() -> void:
	SceneRouter.pending_level = Progression.model.campaign.levels[0]
	_own(["nova"]) # pulse + coil + nova = 3 owned, well under the cap
	var s := _scene()
	eq(s._selected.size(), 3)


func test_toggling_off_then_on_past_the_cap_is_rejected() -> void:
	SceneRouter.pending_level = Progression.model.campaign.levels[0]
	_own(["nova", "lance", "beacon", "trap", "venom", "sniper", "bastion", "spotter"])
	var s := _scene()
	var defs: Array = s._buttons.keys()
	var off: TowerDef = null
	for d in defs:
		if s._selected.has((d as TowerDef).id):
			off = d
			break
	s._on_toggled(off, false)
	eq(s._selected.size(), LoadoutScreen.LOADOUT_SIZE - 1)
	var extra: Array = []
	for d in defs:
		if not s._selected.has((d as TowerDef).id):
			extra.append(d)
	s._on_toggled(extra[0], true) # back up to the cap: fine
	eq(s._selected.size(), LoadoutScreen.LOADOUT_SIZE)
	s._on_toggled(extra[1], true) # past the cap: rejected, button snaps back unpressed
	eq(s._selected.size(), LoadoutScreen.LOADOUT_SIZE, "cannot exceed the cap")
	check(not (s._buttons[extra[1]] as Button).button_pressed, "rejected card is not shown pressed")


func test_confirm_is_disabled_only_when_nothing_is_selected() -> void:
	SceneRouter.pending_level = Progression.model.campaign.levels[0]
	_own(["nova"])
	var s := _scene()
	check(not s._confirm.disabled, "something is selected by default")
	for d: TowerDef in s._buttons.keys().duplicate():
		s._on_toggled(d, false)
	check(s._confirm.disabled, "nothing selected: cannot enter the level")


func test_play_level_routes_through_loadout_before_the_match() -> void:
	eq(SceneRouter.LOADOUT, "res://ui/menus/loadout_screen.tscn")
	SceneRouter.pending_loadout = [&"whatever"]
	SceneRouter.play_challenge(Progression.model.campaign.daily_pool[0], "D1")
	eq(SceneRouter.pending_loadout, [], "challenges clear any leftover loadout restriction")
