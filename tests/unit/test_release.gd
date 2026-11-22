extends TestCase
## Phase 6 standalone release: Android export configuration, offline-only code, app lifecycle
## (background → pause + save flush, back button, reopen with persisted progress).


func test_android_export_preset() -> void:
	var cf := ConfigFile.new()
	eq(cf.load("res://export_presets.cfg"), OK, "preset file present")
	eq(cf.get_value("preset.0", "platform"), "Android")
	eq(cf.get_value("preset.0.options", "package/unique_name"), "com.ironredoubt.game")
	eq(cf.get_value("preset.0.options", "package/name"), "Iron Redoubt")
	eq(cf.get_value("preset.0.options", "version/name"), "0.10.0-playtest")
	check(int(cf.get_value("preset.0.options", "version/code")) >= 9, "version code above 0.8.0 (8) so it installs over it")
	check(cf.get_value("preset.0.options", "architectures/arm64-v8a"), "arm64")
	eq(cf.get_value("preset.0.options", "permissions/internet"), false, "no INTERNET permission: offline game")
	check(String(cf.get_value("preset.0", "exclude_filter")).contains("tests/*"), "tests not shipped")
	for key in ["launcher_icons/main_192x192", "launcher_icons/adaptive_foreground_432x432", "launcher_icons/adaptive_background_432x432"]:
		var path := String(cf.get_value("preset.0.options", key))
		check(FileAccess.file_exists(path), "icon exists: %s" % key)


func test_project_settings_for_mobile() -> void:
	eq(ProjectSettings.get_setting("application/config/name"), "Iron Redoubt")
	eq(ProjectSettings.get_setting("application/config/version"), "1.0.0")
	eq(int(ProjectSettings.get_setting("display/window/handheld/orientation")), DisplayServer.SCREEN_SENSOR_LANDSCAPE, "landscape")
	eq(ProjectSettings.get_setting("application/config/quit_on_go_back"), false, "back button handled by the game")
	eq(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"), true, "mobile texture format")
	eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility")


func test_runtime_code_has_no_network_or_login() -> void:
	var offenders: Array[String] = []
	for dir in ["res://core", "res://gameplay", "res://campaign", "res://ui", "res://integration", "res://data/defs"]:
		_scan(dir, offenders)
	eq(offenders.size(), 0, "network APIs used in: %s" % str(offenders))


func _scan(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(dir + "/" + f)
			for api in ["HTTPRequest", "HTTPClient", "StreamPeerTCP", "WebSocketPeer", "PacketPeerUDP"]:
				if text.contains(api):
					out.append("%s/%s (%s)" % [dir, f, api])
	for sub in d.get_directories():
		_scan(dir + "/" + sub, out)


func _start_match_scene() -> Node:
	var campaign: CampaignDef = load("res://data/campaign.tres")
	SceneRouter.pending_level = campaign.levels[0]
	SceneRouter.pending_challenge = null
	SceneRouter.pending_is_lab = false
	var scene: Node = load("res://gameplay/match/match_scene.tscn").instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	return scene


func test_back_button_toggles_pause_in_match() -> void:
	var scene := _start_match_scene()
	var c: MatchController = scene.get("controller")
	check(c != null and scene.is_inside_tree(), "scene running")
	c.auto_process = false
	scene.on_back()
	check(c.paused and tree.paused, "back pauses the match")
	scene.on_back()
	check(not c.paused and not tree.paused, "back again resumes")


func test_backgrounding_pauses_match_and_flushes_save() -> void:
	var original: ProgressionModel = Progression.model
	var store := MemoryStore.new()
	var pm := ProgressionModel.new(original.campaign, store)
	pm.load_profile()
	Progression.model = pm
	var scene := _start_match_scene()
	var c: MatchController = scene.get("controller")
	c.auto_process = false
	# a previous save failed (e.g. storage hiccup) -> pending
	store.fail_next_saves = 1
	pm.profile.credit("test:pending", 5)
	pm.save()
	check(pm.pending_save, "pending before backgrounding")
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	Progression.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(c.paused, "match auto-paused when the app goes to background")
	check(not pm.pending_save, "pending save flushed on background")
	eq(Profile.new(store.stored).cores(), 5, "data persisted")
	c.set_paused(false)
	Progression.model = original


func test_reopen_restores_progress_from_disk() -> void:
	var path := "user://test_reopen_%d.json" % Time.get_ticks_usec()
	var campaign: CampaignDef = load("res://data/campaign.tres")
	var first := ProgressionModel.new(campaign, LocalFileStore.new(path))
	first.load_profile()
	first.submit_match({"level_id": "level_01", "won": true, "base_hp": 20, "damage_taken": 0, "duration": 300.0,
		"tower_types": ["pulse"]}, "reopen-1")
	first.profile.credit("test:grant", 100)
	first.buy_research(&"reserve_1")
	# "kill" the app: drop the model; a new launch builds a fresh one from disk
	first = null
	var second := ProgressionModel.new(campaign, LocalFileStore.new(path))
	second.load_profile()
	check(second.profile.is_cleared(&"level_01"), "campaign progress restored")
	check(second.is_level_unlocked(campaign.levels[1]), "unlock restored")
	check(second.profile.has_research(&"reserve_1"), "research restored")
	check(second.profile.data["achievements"].size() >= 0, "achievements section present")
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_all_runtime_scripts_compile() -> void:
	var broken: Array[String] = []
	for dir in ["res://core", "res://gameplay", "res://campaign", "res://ui", "res://integration", "res://data/defs"]:
		_compile_all(dir, broken)
	eq(broken.size(), 0, "scripts that fail to compile: %s" % str(broken))


func _compile_all(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			var sc: GDScript = load(dir + "/" + f)
			if sc == null or not sc.can_instantiate():
				out.append(dir + "/" + f)
	for sub in d.get_directories():
		_compile_all(dir + "/" + sub, out)
