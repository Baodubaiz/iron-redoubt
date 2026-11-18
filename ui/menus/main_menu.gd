extends Control
## Main menu (Reforged): animated battlefield backdrop, Iron Redoubt logo, a prominent PLAY that
## continues the campaign, and Campaign / Research / Challenges / Settings navigation.
## Dev Combat Lab: debug builds only, by long-pressing the version label for 2 s.

const SHINE := preload("res://ui/style/shine.gdshader")

var _shine_labels: Array[Label] = []
var _press_id := 0


func _ready() -> void:
	theme = UiKit.theme()
	var bg := MenuBackdrop.new()
	bg.mode = MenuBackdrop.Mode.FULL
	bg.left_shade = true
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ins := ScreenLayout.insets(get_viewport())
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, (48 if side == "left" else 24) + int(ins[side]))
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	# top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	top.add_child(UiKit.cores_chip())
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var lang := UiKit.button(I18n.resolve(Settings.data.language).to_upper(), _toggle_language, Vector2(104, 52), "GhostButton", "globe")
	lang.name = "Language"
	lang.add_theme_font_size_override("font_size", 18)
	top.add_child(lang)
	var gear := UiKit.icon_button("gear", func() -> void: SceneRouter.to_settings(), Vector2(64, 52))
	gear.name = "Settings"
	gear.tooltip_text = I18n.t("Settings")
	top.add_child(gear)

	root.add_child(_spacer())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(col)

	# logo
	var logo_row := HBoxContainer.new()
	logo_row.add_theme_constant_override("separation", 18)
	col.add_child(logo_row)
	var emblem := HexLogo.new()
	emblem.custom_minimum_size = Vector2(104, 104)
	logo_row.add_child(emblem)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -6)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_row.add_child(tv)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 0)
	tv.add_child(name_row)
	for part in [["IRON", UiKit.TEXT], ["REDOUBT", UiKit.ACCENT]]:
		var l := UiKit.title(part[0], 62, part[1], 5)
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_color_override("font_outline_color", Color(VisualPalette.CYAN, 0.12))
		var m := ShaderMaterial.new()
		m.shader = SHINE
		l.material = m
		_shine_labels.append(l)
		name_row.add_child(l)
	tv.add_child(UiKit.title(I18n.t("DEFENSE PROTOCOL"), 18, VisualPalette.TEXT_DIM, 7))
	if Progression.model.recovered:
		var warn := UiKit.label(I18n.f("Profile data was repaired on load (%s).", Progression.model.last_load_error), 16, UiKit.BAD)
		warn.custom_minimum_size = Vector2(470, 0)
		col.add_child(warn)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)
	var play := _play_button()
	col.add_child(play)
	if not _resume.is_empty(): # a campaign match left mid-way: offer to drop it
		var drop := UiKit.button(I18n.t("Abandon saved match"), func() -> void:
			MatchSnapshot.clear()
			SceneRouter.to_menu(), Vector2(480, 40))
		drop.name = "AbandonSaved"
		drop.add_theme_font_size_override("font_size", 14)
		col.add_child(drop)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	col.add_child(nav)
	var nav_items := [
		["Campaign", "campaign", func() -> void: SceneRouter.to_campaign()],
		["Research", "research", func() -> void: SceneRouter.to_research()],
		["Challenges", "trophy", func() -> void: SceneRouter.to_meta()],
		["Codex", "codex", func() -> void: SceneRouter.to_codex()],
		["Armory", "shop", func() -> void: SceneRouter.to_shop()],
	]
	var nav_buttons: Array = []
	for it in nav_items:
		var b := UiKit.button(I18n.t(it[0]).to_upper(), it[2], Vector2(152, 88), "", it[1])
		b.name = it[0]
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 16)
		nav.add_child(b)
		nav_buttons.append(b)

	root.add_child(_spacer())
	var ver := UiKit.label("v%s%s · %s" % [ProjectSettings.get_setting("application/config/version", "?"),
		"-playtest" if OS.has_feature("playtest") else "", I18n.t("offline build")], 14, VisualPalette.TEXT_FAINT)
	ver.name = "Version"
	ver.autowrap_mode = TextServer.AUTOWRAP_OFF
	ver.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if OS.is_debug_build():
		ver.mouse_filter = Control.MOUSE_FILTER_STOP
		ver.gui_input.connect(_on_version_input)
	root.add_child(ver)

	UiKit.slide_in([logo_row, play] + nav_buttons)
	_run_shine()


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## The level PLAY continues: the first unlocked level not yet cleared, else the last unlocked one.
func continue_level() -> LevelDef:
	var model: ProgressionModel = Progression.model
	var last: LevelDef = null
	for l in model.campaign.levels:
		if not model.is_level_unlocked(l):
			break
		last = l
		if not model.profile.level_record(l.id)["cleared"]:
			return l
	return last


var _resume := {}


func _play_button() -> Button:
	var level := continue_level()
	_resume = MatchSnapshot.pending(Progression.model.campaign)
	var b := UiKit.button("", func() -> void:
		if not _resume.is_empty():
			SceneRouter.resume_match(_resume)
			return
		var l := continue_level()
		if l != null:
			SceneRouter.play_level(l), Vector2(480, 108), "PrimaryButton")
	b.name = "Play"
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(12, 0)
	h.add_child(pad)
	h.add_child(UiKit.tex(UiKit.icon("play"), 46, VisualPalette.BG))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var resumed := MatchSnapshot.level_of(Progression.model.campaign, _resume) if not _resume.is_empty() else null
	v.add_child(UiKit.title(I18n.t("Continue" if resumed != null else "Play").to_upper(), 40, VisualPalette.BG, 6))
	var all_clear: bool = level != null and bool(Progression.model.profile.level_record(level.id)["cleared"])
	var sub := I18n.f("Level %d · %s", [level.level_number, UiKit.level_title(level)]) if level != null else ""
	if all_clear:
		sub = I18n.t("Campaign complete") + " · " + sub
	if resumed != null:
		level = resumed
		sub = I18n.f("Level %d · Wave %d/%d", [resumed.level_number, int(_resume["wave_index"]) + 2, resumed.waves.size()])
	var sl := UiKit.label(sub, 16, Color(VisualPalette.BG, 0.8))
	sl.add_theme_font_override("font", UiKit.font("body_bold"))
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.name = "Next"
	v.add_child(sl)
	for c in [h, v, sl]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.disabled = level == null
	return b


func _run_shine() -> void:
	await get_tree().process_frame
	while is_inside_tree():
		var total := 0.0
		for l in _shine_labels:
			total = maxf(total, l.position.x + l.size.x)
		for l in _shine_labels:
			var m := l.material as ShaderMaterial
			m.set_shader_parameter("width_px", total)
			m.set_shader_parameter("offset_px", l.position.x)
		var tw := create_tween()
		tw.tween_method(func(x: float) -> void:
			for l in _shine_labels:
				(l.material as ShaderMaterial).set_shader_parameter("sweep", x), -0.2, 1.4, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(5.0)
		await tw.finished


func _toggle_language() -> void:
	Settings.data.language = "en" if I18n.resolve(Settings.data.language) == "vi" else "vi"
	Settings.save()
	SceneRouter.to_menu()


func _on_version_input(e: InputEvent) -> void:
	var pressed := (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or e is InputEventScreenTouch
	if not pressed:
		return
	_press_id += 1
	if not e.is_pressed():
		return
	var id := _press_id
	await get_tree().create_timer(2.0).timeout
	if id == _press_id and is_inside_tree():
		SceneRouter.play_lab()


func on_back() -> void:
	get_tree().quit()
