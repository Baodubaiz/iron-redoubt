extends Control
## Campaign select (Reforged): region tabs (Circuit / Delta / Prism / Rift) with illustrated previews and
## progress, level cards (real map thumbnail, number, name, cleared / flawless / best HP, lock state,
## boss marker) — one row for 3-level regions, a compact 5-column grid for the 10-level Rift — and a
## detail bar with a prominent PLAY. Unlock logic only reads ProgressionModel.is_level_unlocked() and
## Profile.level_record().

const P = preload("res://ui/style/visual_palette.gd")

var _selected: LevelDef
var _region: StringName
var _regions: Array[StringName] = []
var _by_map := {} ## region id -> Array[LevelDef]
var _tabs := {}
var _cards_box: GridContainer
var _detail: PanelContainer
var _play: Button
var _play_pulse: Tween
var _card_group := ButtonGroup.new()
var _tab_group := ButtonGroup.new()


func _ready() -> void:
	var v := UiKit.screen(self)
	UiKit.header(v, I18n.t("Campaign"), func() -> void: SceneRouter.to_menu())
	var model: ProgressionModel = Progression.model
	for l in model.campaign.levels:
		var rg := l.map.region_id()
		if not _by_map.has(rg):
			_by_map[rg] = []
			_regions.append(rg)
		_by_map[rg].append(l)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	v.add_child(tabs)
	for rg in _regions:
		var t := _region_tab(rg)
		tabs.add_child(t)
		_tabs[rg] = t
	var cards_area := VBoxContainer.new() # keeps cards at a sensible height on tall (4:3) screens
	cards_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_area.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cards_area)
	_cards_box = GridContainer.new()
	_cards_box.add_theme_constant_override("h_separation", 14)
	_cards_box.add_theme_constant_override("v_separation", 12)
	cards_area.add_child(_cards_box)
	_detail = PanelContainer.new()
	_detail.theme_type_variation = "CardAccent"
	_detail.custom_minimum_size = Vector2(0, 118)
	v.add_child(_detail)
	var start := _recommended()
	_show_region(start.map.region_id() if start != null else _regions[0], start)
	UiKit.slide_in(tabs.get_children(), Vector2(0, -24), 0.05)


func _recommended() -> LevelDef:
	var model: ProgressionModel = Progression.model
	var last: LevelDef = null
	for l in model.campaign.levels:
		if not model.is_level_unlocked(l):
			break
		last = l
		if not model.profile.level_record(l.id)["cleared"]:
			return l
	return last


func _region_progress(rg: StringName) -> Vector2i:
	var done := 0
	for l: LevelDef in _by_map[rg]:
		if Progression.model.profile.level_record(l.id)["cleared"]:
			done += 1
	return Vector2i(done, _by_map[rg].size())


func _map_tags(rg: StringName) -> String:
	var nodes := false
	var night := false
	var gates := false
	var two := false
	for l: LevelDef in _by_map[rg]:
		var map := l.map
		nodes = nodes or map.range_bonus_zones.size() > 0
		night = night or map.day_night
		gates = gates or map.dynamic_routes
		two = two or (map.routes.size() > 1 and not map.dynamic_routes)
	var tags: Array[String] = []
	if nodes: tags.append(I18n.t("Overload nodes"))
	if night: tags.append(I18n.t("Day/Night"))
	if gates: tags.append(I18n.t("Shifting gates"))
	if two: tags.append(I18n.t("2 entrances"))
	return " · ".join(tags)


static func boss_of(l: LevelDef) -> EnemyDef:
	for w in l.waves:
		if w.is_boss:
			for g in w.groups:
				if g.enemy != null and g.enemy.is_boss:
					return g.enemy
	return null


func _region_tab(rg: StringName) -> Button:
	var look := P.map_look(rg)
	var accent: Color = look["accent"]
	var first: LevelDef = _by_map[rg][0]
	var map := first.map
	var locked := not Progression.model.is_level_unlocked(first)
	var b := Button.new()
	b.name = "Region_%s" % rg
	b.theme_type_variation = "CardButton"
	b.toggle_mode = true
	b.button_group = _tab_group
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(UiKit.click)
	b.pressed.connect(func() -> void: _show_region(rg, null))
	UiKit.juice(b)
	var thumb := MapThumbnail.new()
	thumb.map = map
	thumb.show_badges = false
	thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb.anchor_left = 0.45
	thumb.offset_top = 3
	thumb.offset_right = -3
	thumb.offset_bottom = -3
	thumb.modulate = Color(1, 1, 1, 0.22)
	b.add_child(thumb)
	var shade := _shade_rect()
	b.add_child(shade)
	var m := _margin(b, 16, 10)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	tv.add_child(UiKit.title(I18n.t(look["name"]).to_upper(), 26, accent, 4))
	var desc := UiKit.label(I18n.t(look["desc"]), 13, P.TEXT_DIM)
	desc.max_lines_visible = 2
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.custom_minimum_size = Vector2(120, 0)
	desc.tooltip_text = _map_tags(rg)
	tv.add_child(desc)
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pv)
	if locked:
		pv.add_child(UiKit.tex(UiKit.icon("lock"), 30, P.TEXT_FAINT))
	else:
		var prog := _region_progress(rg)
		var pl := UiKit.title("%d/%d" % [prog.x, prog.y], 22, P.GREEN if prog.x == prog.y else P.TEXT, 1)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pv.add_child(pl)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(64, 6)
		bar.max_value = prog.y
		bar.value = prog.x
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = accent
		bar.add_theme_stylebox_override("fill", fill)
		pv.add_child(bar)
	return b


func _show_region(rg: StringName, select: LevelDef) -> void:
	_region = rg
	(_tabs[rg] as Button).set_pressed_no_signal(true)
	for c in _cards_box.get_children():
		_cards_box.remove_child(c)
		c.queue_free()
	var levels: Array = _by_map[rg]
	var compact := levels.size() > 3
	_cards_box.columns = mini(levels.size(), 5)
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_CENTER
	var cards: Array = []
	var pick: LevelDef = select
	for l: LevelDef in levels:
		var card := _level_card(l, compact)
		_cards_box.add_child(card)
		cards.append(card)
		if pick == null and Progression.model.is_level_unlocked(l) and not Progression.model.profile.level_record(l.id)["cleared"]:
			pick = l
	if pick == null:
		for l: LevelDef in levels:
			if Progression.model.is_level_unlocked(l):
				pick = l
	if pick != null:
		for c in cards:
			if c.get_meta("level") == pick:
				(c as Button).set_pressed_no_signal(true)
				_lift(c, true)
	_select(pick)
	UiKit.slide_in(cards, Vector2(40, 0), 0.035 if compact else 0.07)


func _level_card(l: LevelDef, compact: bool = false) -> Button:
	var model: ProgressionModel = Progression.model
	var look := P.map_look(l.map.region_id())
	var accent: Color = look["accent"]
	var unlocked := model.is_level_unlocked(l)
	var rec := model.profile.level_record(l.id)
	var b := Button.new()
	b.name = "Level_%s" % l.id
	b.set_meta("level", l)
	b.theme_type_variation = "CardButton"
	b.toggle_mode = true
	b.button_group = _card_group
	b.disabled = not unlocked
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 150 if compact else 340)
	b.pressed.connect(UiKit.click)
	b.toggled.connect(func(on: bool) -> void:
		_lift(b, on)
		if on:
			_select(l))
	UiKit.juice(b)
	var m := _margin(b, 8 if compact else 10, 6 if compact else 10)
	var boss := boss_of(l)
	if boss != null: # boss levels get a red frame
		var frame := Panel.new()
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", UiKit.chamfer(Color(0, 0, 0, 0), Color(P.RED, 0.7 if unlocked else 0.3), 10, 2))
		b.add_child(frame)
		b.move_child(frame, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4 if compact else 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var thumb := MapThumbnail.new()
	thumb.map = l.map
	thumb.level = l
	thumb.dim = not unlocked
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.custom_minimum_size = Vector2(0, 60 if compact else 120)
	v.add_child(thumb)
	if not unlocked:
		var ls := 30 if compact else 44
		var lock := UiKit.tex(UiKit.icon("lock"), ls, P.TEXT_DIM)
		lock.set_anchors_preset(Control.PRESET_CENTER)
		lock.offset_left = -ls * 0.5
		lock.offset_top = -ls * 0.5
		lock.offset_right = ls * 0.5
		lock.offset_bottom = ls * 0.5
		thumb.add_child(lock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	row.add_theme_constant_override("separation", 6 if compact else 10)
	row.add_child(UiKit.title("%02d" % l.level_number, 26 if compact else 40, accent if unlocked else P.TEXT_FAINT, 1))
	var name_l := UiKit.label(UiKit.level_title(l).to_upper(), 14 if compact else 19, P.TEXT if unlocked else P.TEXT_FAINT)
	if compact:
		name_l.max_lines_visible = 2
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.add_theme_font_override("font", UiKit.font("head", 1))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.custom_minimum_size = Vector2(60, 0)
	row.add_child(name_l)
	if boss != null:
		var bi := UiKit.tex(UiKit.icon("boss"), 20 if compact else 26, P.RED if unlocked else Color(P.RED, 0.4))
		bi.tooltip_text = I18n.f("BOSS: %s", I18n.t(boss.display_name))
		bi.mouse_filter = Control.MOUSE_FILTER_PASS
		bi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bi)
	v.add_child(_status_row(l, unlocked, rec, compact))
	return b


func _status_row(l: LevelDef, unlocked: bool, rec: Dictionary, compact: bool = false) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5 if compact else 8)
	h.custom_minimum_size = Vector2(0, 20 if compact else 28)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked and compact:
		return h # the lock on the thumbnail says it all
	if not unlocked:
		var t := UiKit.label(I18n.f("Clear level %d to unlock", l.level_number - 1), 15, P.TEXT_FAINT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(100, 0)
		h.add_child(t)
		return h
	if not rec["cleared"]:
		var badge := PanelContainer.new()
		badge.theme_type_variation = "Chip"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(UiKit.title(I18n.t("NEW"), 12 if compact else 15, P.CYAN, 2))
		h.add_child(badge)
		return h
	var ic := 16 if compact else 22
	h.add_child(UiKit.tex(UiKit.icon("check"), ic, P.GREEN))
	var star := UiKit.tex(UiKit.icon("star"), ic, P.ORANGE if rec["flawless"] else Color(P.TEXT_FAINT, 0.5))
	star.tooltip_text = I18n.t("flawless")
	h.add_child(star)
	h.add_child(UiKit.tex(UiKit.icon("heart"), 14 if compact else 18, P.GREEN))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = l.base_hp
	bar.value = int(rec["best_hp"])
	bar.custom_minimum_size = Vector2(50, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(bar)
	h.add_child(UiKit.title("%d/%d" % [rec["best_hp"], l.base_hp], 13 if compact else 16, P.TEXT_DIM, 0))
	return h


func _select(l: LevelDef) -> void:
	_selected = l
	for c in _detail.get_children():
		c.queue_free()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	_detail.add_child(h)
	if l == null:
		var t := UiKit.label(I18n.t("Select a level."), 18, P.TEXT_DIM)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(t)
	else:
		var look := P.map_look(l.map.region_id())
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		h.add_child(info)
		info.add_child(UiKit.title("%02d · %s" % [l.level_number, UiKit.level_title(l).to_upper()], 22, look["accent"], 2))
		var obj := UiKit.label(I18n.t(l.objective), 15, P.TEXT_DIM)
		obj.custom_minimum_size = Vector2(200, 0)
		info.add_child(obj)
		var stats := VBoxContainer.new()
		stats.add_theme_constant_override("separation", 6)
		stats.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(stats)
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 6)
		stats.add_child(chips)
		var wc := UiKit.chip("wave", str(l.waves.size()), P.BLUE, 17)
		wc.tooltip_text = I18n.t("Waves")
		chips.add_child(wc)
		var seed_creds := l.economy.seed_money(l.starting_currency) if l.economy != null else int(round(l.starting_currency * 1.10))
		chips.add_child(UiKit.chip("credits", str(seed_creds), P.ORANGE, 17))
		chips.add_child(UiKit.chip("heart", str(l.base_hp), P.GREEN, 17))
		var bdef := boss_of(l)
		if bdef != null:
			var bc := UiKit.chip("boss", I18n.t(bdef.display_name), P.RED, 17)
			bc.tooltip_text = I18n.t("BOSS")
			chips.add_child(bc)
		var towers := HBoxContainer.new()
		towers.add_theme_constant_override("separation", 4)
		stats.add_child(towers)
		for t: TowerDef in l.available_towers:
			var owned := Progression.model.profile.owns_tower(t.id)
			var ic := UiKit.tex(UiKit.tower_icon(t.id), 38, Color(1, 1, 1, 1.0 if owned else 0.25))
			ic.tooltip_text = I18n.t(t.display_name)
			ic.mouse_filter = Control.MOUSE_FILTER_PASS
			towers.add_child(ic)
		var rew := VBoxContainer.new()
		rew.alignment = BoxContainer.ALIGNMENT_CENTER
		rew.add_theme_constant_override("separation", 4)
		h.add_child(rew)
		var cleared: bool = Progression.model.profile.level_record(l.id)["cleared"]
		var fc := UiKit.label(I18n.t("First clear"), 13, P.TEXT_FAINT if cleared else P.TEXT_DIM)
		fc.autowrap_mode = TextServer.AUTOWRAP_OFF
		rew.add_child(fc)
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 6)
		rew.add_child(rr)
		var cc := UiKit.chip("cores", "+%d" % l.cores_first_clear, P.ORANGE, 17)
		cc.modulate.a = 0.45 if cleared else 1.0
		rr.add_child(cc)
		if l.unlock_tower_on_clear != null:
			var ut := UiKit.tex(UiKit.tower_icon(l.unlock_tower_on_clear.id), 36)
			ut.tooltip_text = I18n.f("unlocks %s", I18n.t(l.unlock_tower_on_clear.display_name))
			ut.mouse_filter = Control.MOUSE_FILTER_PASS
			ut.modulate.a = 0.45 if cleared else 1.0
			rr.add_child(ut)
	_play = UiKit.button(I18n.t("Play").to_upper(), func() -> void:
		if _selected != null:
			SceneRouter.play_level(_selected), Vector2(210, 86), "PrimaryButton", "play")
	_play.name = "Play"
	_play.add_theme_font_size_override("font_size", 30)
	_play.disabled = l == null
	_play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_play)
	if _play_pulse != null:
		_play_pulse.kill()
	if l != null:
		_play_pulse = create_tween().set_loops()
		_play_pulse.tween_property(_play, "self_modulate", Color(1.15, 1.15, 1.15), 0.7).set_trans(Tween.TRANS_SINE)
		_play_pulse.tween_property(_play, "self_modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)


func _lift(c: Control, on: bool) -> void:
	c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(c, "scale",
		Vector2(1.03, 1.03) if on else Vector2.ONE, 0.2)


func _margin(parent: Control, mx: int, my: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", mx)
	m.add_theme_constant_override("margin_right", mx)
	m.add_theme_constant_override("margin_top", my)
	m.add_theme_constant_override("margin_bottom", my)
	parent.add_child(m)
	return m


func _shade_rect() -> Control:
	var c := ColorRect.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.color = Color(P.BG_DEEP, 0.0)
	return c


func on_back() -> void:
	SceneRouter.to_menu()
