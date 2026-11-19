class_name LoadoutScreen
extends Control
## Shown after "Play" on a campaign level, before the match: pick which owned towers to bring
## (at most LOADOUT_SIZE). Challenges and the Combat Lab skip this screen entirely (every owned
## tower stays available there). SceneRouter.start_match_with_loadout() carries the pick onward.

const LOADOUT_SIZE := 6
const P = preload("res://ui/style/visual_palette.gd")

var _level: LevelDef
var _selected: Array[StringName] = []
var _buttons: Dictionary = {} # TowerDef -> Button
var _count_label: Label
var _confirm: Button


func _ready() -> void:
	_level = SceneRouter.pending_level
	_build()


func _owned_towers() -> Array[TowerDef]:
	var model: ProgressionModel = Progression.model
	var out: Array[TowerDef] = []
	for t in _level.available_towers:
		if model.profile.owns_tower(t.id):
			out.append(t)
	return out


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var v := UiKit.screen(self)
	UiKit.header(v, I18n.t("Loadout"), func() -> void: SceneRouter.to_campaign())
	v.add_child(UiKit.label(I18n.f("%s — pick up to %d towers to bring", [I18n.t(_level.display_name), LOADOUT_SIZE]), 16, UiKit.MUTED))
	var owned := _owned_towers()
	if _selected.is_empty():
		for t in owned:
			if _selected.size() >= LOADOUT_SIZE:
				break
			_selected.append(t.id)
	var list := UiKit.scroll(v)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	_buttons.clear()
	for def in owned:
		var b := Button.new()
		b.name = "Card_%s" % def.id
		b.theme_type_variation = "CardButton"
		b.toggle_mode = true
		b.button_pressed = _selected.has(def.id)
		b.custom_minimum_size = Vector2(98, 124)
		b.toggled.connect(func(on: bool) -> void: _on_toggled(def, on))
		UiKit.juice(b)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(vb)
		vb.add_child(UiKit.tex(UiKit.tower_icon(def.id), 56))
		var n := UiKit.label(I18n.t(def.display_name), 14, P.tower_color(def.id))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(n)
		var rank := UiKit.rank_badge(def.rarity, 12)
		rank.position = Vector2(5, 4)
		b.add_child(rank)
		if SceneRouter.pending_new_tower != null and def.id == SceneRouter.pending_new_tower.id:
			var new_chip := UiKit.chip("star", I18n.t("New"), VisualPalette.ORANGE, 11)
			new_chip.position = Vector2(26, 4)
			b.add_child(new_chip)
		grid.add_child(b)
		_buttons[def] = b
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	v.add_child(footer)
	_count_label = UiKit.label("", 16, VisualPalette.CYAN)
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_count_label)
	# A new campaign match replaces the saved mid-match checkpoint: ask first (2026-11-19).
	var saved := {} if SceneRouter.pending_challenge != null else MatchSnapshot.pending(Progression.model.campaign)
	var armed := [saved.is_empty()]
	_confirm = UiKit.button(I18n.t("Enter level"), func() -> void:
		if not armed[0]:
			armed[0] = true
			var lvl := MatchSnapshot.level_of(Progression.model.campaign, saved)
			_confirm.text = I18n.f("Replace saved match (level %d)? Tap again", lvl.level_number if lvl != null else 0)
			return
		SceneRouter.start_match_with_loadout(_selected.duplicate()), Vector2(220, 56), "PrimaryButton", "play")
	footer.add_child(_confirm)
	_refresh()


func _on_toggled(def: TowerDef, on: bool) -> void:
	if on:
		if _selected.size() >= LOADOUT_SIZE:
			(_buttons[def] as Button).set_pressed_no_signal(false)
			return
		if not _selected.has(def.id):
			_selected.append(def.id)
	else:
		_selected.erase(def.id)
	_refresh()


func _refresh() -> void:
	_count_label.text = I18n.f("%d / %d selected", [_selected.size(), LOADOUT_SIZE])
	_confirm.disabled = _selected.is_empty()


func on_back() -> void:
	SceneRouter.to_campaign()
