extends TestCase
## Reforged Stage B: menu screens build, navigation targets and campaign unlock display match the
## progression model (unlock logic itself is unchanged and tested in test_progression).

var _saved: ProgressionModel


func before_each() -> void:
	super.before_each()
	_saved = Progression.model
	var pm := ProgressionModel.new(_saved.campaign, MemoryStore.new())
	pm.load_profile()
	Progression.model = pm


func after_each() -> void:
	super.after_each()
	Progression.model = _saved


func _clear(n: int) -> void:
	var pm: ProgressionModel = Progression.model
	for i in range(n):
		var l := pm.campaign.levels[i]
		pm.submit_match({"level_id": String(l.id), "won": true, "base_hp": l.base_hp, "damage_taken": 0,
			"duration": 300.0, "tower_types": ["pulse"]}, "menu_test_%d" % i)


func _scene(path: String) -> Control:
	var s: Control = load(path).instantiate()
	tree.root.add_child(s)
	_nodes.append(s)
	return s


func _find(root: Node, name: String) -> Node:
	return root.find_child(name, true, false)


func test_ui_assets_load() -> void:
	for k in ["body", "body_bold", "head", "ui"]:
		check(UiKit.font(k) != null, "font %s" % k)
	for i in ["play", "back", "gear", "research", "trophy", "campaign", "lock", "check", "star", "heart",
			"credits", "cores", "wave", "globe", "night", "boss", "air", "gate"]:
		check(UiKit.icon(i) != null, "icon %s" % i)
	for t in ["pulse", "nova", "lance", "beacon"]:
		check(UiKit.tower_icon(StringName(t)) != null, "tower icon %s" % t)


func test_level_title_strips_number_prefix() -> void:
	var l := LevelDef.new()
	l.display_name = "7 — Shifting Gates"
	eq(UiKit.level_title(l), "Shifting Gates")
	l.display_name = "Combat Lab"
	eq(UiKit.level_title(l), "Combat Lab")


func test_main_menu_play_continues_first_uncleared_level() -> void:
	var menu := _scene("res://ui/menus/main_menu.tscn")
	var levels := Progression.model.campaign.levels
	eq(menu.continue_level(), levels[0], "fresh profile -> level 1")
	_clear(4)
	eq(menu.continue_level(), levels[4], "after 4 clears -> level 5")
	_clear(levels.size())
	eq(menu.continue_level(), levels[levels.size() - 1], "all cleared -> last level")


func test_main_menu_has_navigation_and_no_lab_button() -> void:
	var menu := _scene("res://ui/menus/main_menu.tscn")
	for n in ["Play", "Campaign", "Research", "Challenges", "Settings", "Language", "Version", "Cores"]:
		check(_find(menu, n) != null, "menu has %s" % n)
	var texts: Array[String] = []
	for b in menu.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	check(not " ".join(texts).to_lower().contains("lab"), "no Combat Lab button: %s" % str(texts))
	check(not (_find(menu, "Play") as Button).disabled, "PLAY enabled")


func test_campaign_cards_follow_unlock_state() -> void:
	_clear(2)
	var cs := _scene("res://ui/menus/campaign_select.tscn")
	var pm: ProgressionModel = Progression.model
	# region Circuit is shown (it has the recommended level 3)
	for l in pm.campaign.levels.slice(0, 3):
		var card := _find(cs, "Level_%s" % l.id) as Button
		check(card != null, "card for %s" % l.id)
		eq(card.disabled, not pm.is_level_unlocked(l), "card lock matches model for %s" % l.id)
	var rec := _find(cs, "Level_%s" % pm.campaign.levels[2].id) as Button
	check(rec.button_pressed, "recommended level preselected")
	check(not (_find(cs, "Play") as Button).disabled, "PLAY enabled with a selection")
	# switching to a locked region shows locked cards and nothing selected
	(_find(cs, "Region_prism") as Button).pressed.emit()
	for l in pm.campaign.levels.slice(20, 30):
		var card := cs.find_child("Level_%s" % l.id, true, false) as Button
		check(card != null and card.disabled, "Prism card %s locked" % l.id)


func test_research_and_meta_screens_build() -> void:
	var r := _scene("res://ui/menus/research_screen.tscn")
	check(_find(r, "Category_tower") != null and _find(r, "Category_support") != null, "research category cards")
	(_find(r, "Category_tower") as Button).pressed.emit()
	var towers: Array[StringName] = r._towers_with_research()
	check(towers.size() >= 9, "every tower with research gets a card (%d)" % towers.size())
	check(_find(r, "Tower_%s" % towers[0]) != null, "tower card for %s" % towers[0])
	check(_find(r, "Tower_ss_placeholder") != null, "SS placeholder card")
	r._open_tower_popup(towers[0])
	var per_tower: Array = r._items(&"tower").filter(func(x: ResearchDef) -> bool: return x.tower_id == towers[0])
	check(r.find_children("*", "Button", true, false).size() >= per_tower.size(), "tower popup research buttons")
	# A fresh instance: queue_free()'d nodes from a same-named rebuild never actually leave the tree
	# in this synchronous test runner (no frame passes), so a second build on `r` would leave stale
	# "Tower_*" nodes behind and make find_child() non-deterministic. Setting state before the one
	# and only _build() call this instance ever makes avoids that entirely.
	var r2 := _scene("res://ui/menus/research_screen.tscn")
	r2._category = &"tower"
	r2._rank_filter = &"A"
	r2._build()
	for tid in towers:
		var def: TowerDef = r2._tower_def(tid)
		var shown := _find(r2, "Tower_%s" % tid) != null
		eq(shown, def != null and def.rarity == &"A", "rank A filter: %s shown=%s" % [tid, shown])
	var m := _scene("res://ui/menus/meta_screen.tscn")
	check(_find(m, "Back") != null, "meta header back button")


func test_codex_lists_data_and_locks_unmet_enemies() -> void:
	var pm: ProgressionModel = Progression.model
	pm.submit_match({"level_id": "level_01", "won": false, "base_hp": 0, "damage_taken": 20, "duration": 60.0,
		"tower_types": ["pulse"], "seen_enemies": ["drone", "dart", "warden"]}, "codex_test")
	var cx := _scene("res://ui/menus/codex_screen.tscn")
	for t in ["towers", "enemies", "bosses", "effects", "damage", "regions"]:
		check(_find(cx, "Tab_%s" % t) != null, "tab %s" % t)
	eq(_find(cx, "Detail").get_child_count() > 0, true, "first tower shown")
	(_find(cx, "Tab_enemies") as Button).pressed.emit()
	var drone := cx.find_child("Entry_drone", true, false) as Button
	var plated := cx.find_child("Entry_plated", true, false) as Button
	check(drone != null and plated != null, "enemy entries")
	check(not _texts(drone).contains("???"), "met enemy is named")
	check(_texts(plated).contains("???"), "unmet enemy is hidden")
	(_find(cx, "Tab_bosses") as Button).pressed.emit()
	var bosses := 0
	for c in cx.find_children("Entry_*", "Button", true, false):
		if c.is_inside_tree() and not c.is_queued_for_deletion():
			bosses += 1
	eq(bosses, 8, "all 8 bosses listed (from the campaign data)")
	check(not _texts(cx.find_child("Entry_warden", true, false)).contains("???"), "met boss is named")
	(_find(cx, "Tab_effects") as Button).pressed.emit()
	check(cx.find_child("Entry_burn", true, false) != null, "built-in effects listed")
	check(cx.find_child("Entry_poison", true, false) == null, "unused data-only effects stay hidden")
	(_find(cx, "Tab_regions") as Button).pressed.emit()
	check(cx.find_child("Entry_rift", true, false) != null, "regions listed")


func _live(cx: Control, pattern: String) -> Array:
	var out: Array = []
	for c in cx.find_children(pattern, "Button", true, false):
		if c.is_inside_tree() and not c.is_queued_for_deletion():
			out.append(c)
	return out


func test_codex_tower_and_enemy_filters() -> void:
	var cx := _scene("res://ui/menus/codex_screen.tscn")
	(_find(cx, "Filter_A") as Button).pressed.emit()
	var shown := _live(cx, "Entry_*")
	check(shown.size() >= 1, "rank A filter leaves at least one tower")
	for c in shown:
		var id := String(c.name).substr(6)
		eq((load("res://data/towers/%s.tres" % id) as TowerDef).rarity, &"A", "%s is rank A" % id)
	(_find(cx, "Filter_all") as Button).pressed.emit()
	var all_towers: Array = cx.TOWERS
	eq(_live(cx, "Entry_*").size(), all_towers.size(), "clearing the filter shows every tower again")
	(_find(cx, "Tab_enemies") as Button).pressed.emit()
	(_find(cx, "Filter_flying") as Button).pressed.emit()
	var flyers := _live(cx, "Entry_*")
	check(flyers.size() >= 1, "flying filter leaves at least one enemy")
	for c in flyers:
		var id := String(c.name).substr(6)
		check((load("res://data/enemies/%s.tres" % id) as EnemyDef).flying, "%s flies" % id)


func _texts(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		out += (l as Label).text + " "
	return out
