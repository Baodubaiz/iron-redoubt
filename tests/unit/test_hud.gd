extends TestCase
## Reforged Stage E: HUD / tower panel presentation helpers and the Reduce-effects setting.


func test_reduce_effects_setting_round_trips_and_defaults_off() -> void:
	var path := "user://test_settings_reduce.cfg"
	var s := GameSettings.new()
	check(not s.reduce_effects, "default off")
	s.reduce_effects = true
	s.save(path)
	var r := GameSettings.new()
	r.load_from(path)
	check(r.reduce_effects, "saved and loaded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# an old 0.7.0 settings file (no key) keeps the default
	var cf := ConfigFile.new()
	cf.set_value("audio", "music_on", true)
	cf.save(path)
	var old := GameSettings.new()
	old.load_from(path)
	check(not old.reduce_effects, "old file -> default")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Regression: Air Priority is only meaningful once a tower can actually hit air (e.g. Nova only
## after Cluster III / Flak), so the button must stay hidden until then.
func test_air_priority_button_only_shows_once_tower_can_hit_air() -> void:
	var m := make_lab(100000)
	var t := m.try_build(real_tower("nova"), Vector2(300, 400))
	var panel := TowerPanel.new()
	panel.controller = m
	panel.placement = PlacementController.new()
	tree.root.add_child(panel)
	_nodes.append(panel)
	panel.show_tower(t)
	var buttons: Array = panel.get("_target_buttons")
	var air_idx := -1
	for i in range(TowerPanel.TARGET_MODES.size()):
		if TowerPanel.TARGET_MODES[i][0] == TowerDef.TargetRule.AIR_FIRST:
			air_idx = i
	check(air_idx >= 0, "Air mode exists")
	check(not (buttons[air_idx] as Button).visible, "hidden before Flak upgrade")
	for i in range(3):
		check(m.try_upgrade(t, 0), "Cluster tier %d" % (i + 1)) # III unlocks can_target_air (Flak)
	panel.show_tower(t)
	check((buttons[air_idx] as Button).visible, "shown once Cluster III unlocks air")


func test_upgrade_preview_shows_changes_without_touching_the_tower() -> void:
	var m := make_lab()
	var def := real_tower("pulse")
	var t: Tower = null
	for y in range(100, 700, 40):
		for x in range(60, 1100, 40):
			if t == null and m.validate_placement(def, Vector2(x, y)) == PlacementRules.Result.OK:
				t = m.try_build(def, Vector2(x, y))
	check(t != null, "built")
	if t == null:
		return
	var before_tiers := t.tiers.duplicate()
	var before_dmg := t.damage
	var txt := TowerPanel.preview_text(t, 1) # Penetrator: damage + armor pen
	check(txt.contains("→"), "preview shows a change: %s" % txt)
	eq(t.tiers, before_tiers, "tiers untouched")
	eq(t.damage, before_dmg, "stats untouched")


## Regression: TowerPanel.refresh() crashed for any evolved tower (Array vs Array[String] type
## mismatch building the subtitle), only visible once a tower reached evolution in a real match.
func test_tower_panel_shows_evolved_tower_without_crashing() -> void:
	var u := UpgradeRules.Unlocks.new()
	u.evolutions[&"pulse"] = true
	var m := make_lab(100000, u)
	var t := m.try_build(real_tower("pulse"), Vector2(300, 400))
	for i in range(3):
		m.try_upgrade(t, 0)
	m._on_wave_cleared(0, 0)
	m._on_wave_cleared(1, 0)
	check(m.try_evolve(t), "evolved")
	var panel := TowerPanel.new()
	panel.controller = m
	panel.placement = PlacementController.new()
	tree.root.add_child(panel)
	_nodes.append(panel)
	panel.show_tower(t)
	check(panel.get("_subtitle").text.contains("Storm Array"), "subtitle includes the evolution name")


func test_match_hud_has_tower_cards_and_controls() -> void:
	var campaign: CampaignDef = load("res://data/campaign.tres")
	SceneRouter.pending_level = campaign.levels[3]
	SceneRouter.pending_challenge = null
	SceneRouter.pending_is_lab = false
	var scene: Node = load("res://gameplay/match/match_scene.tscn").instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	var c: MatchController = scene.get("controller")
	c.auto_process = false
	var hud: Hud = scene.get("hud")
	for d in c.available_towers():
		check(hud.find_child("Card_%s" % d.id, true, false) != null, "card for %s" % d.id)
	check(hud.get("_start_btn").visible, "start button visible before wave 1")
	scene.on_back()
	check(hud.get("_pause_overlay").visible, "pause menu shown")
	scene.on_back()
	var fade: Tween = hud.get("_pause_fade")
	check(fade != null and fade.is_valid(), "pause menu fades out (2026-11-19 smooth UI)")
	fade.custom_step(1.0) # finish the fade now
	check(not hud.get("_pause_overlay").visible, "pause menu hidden")
