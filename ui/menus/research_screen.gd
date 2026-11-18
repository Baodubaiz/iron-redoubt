extends Control
## Research: spend persistent Cores on strategic options (branches, evolutions) and modest tech.
## Two steps: a category card ("Tower Upgrades" / "Support") first.
## "Tower Upgrades" then shows one avatar+name card per tower, sorted C -> SS (SS: "coming soon"
## placeholder, no SS tower exists yet); tapping a tower opens a floating popup with its info and
## its research items. "Support" (not tower-specific) goes straight to its flat item list.

const CATEGORIES := [
	{"id": &"tower", "name": "Tower Upgrades", "icon": "upgrade"},
	{"id": &"support", "name": "Support", "icon": "research"},
]
const RANK_ORDER := [&"C", &"B", &"A", &"S", &"SS"]

var _category: StringName = &"" ## "" = showing the category list
var _popup: Control = null
var _rank_filter: StringName = &"" ## "" = every rank; tower grid only
var _only_incomplete: bool = false ## tower grid only: hide towers already fully researched


func _ready() -> void:
	_build()


func _items(cat: StringName) -> Array:
	var out: Array = []
	for r in Progression.model.campaign.research:
		if r.category == cat:
			out.append(r)
	return out


func _tower_def(id: StringName) -> TowerDef:
	for t in Progression.model.campaign.levels[0].available_towers:
		if t.id == id:
			return t
	return null


## Every distinct tower with research under the "tower" category, sorted C -> SS.
func _towers_with_research() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in _items(&"tower"):
		if r.tower_id != &"" and not out.has(r.tower_id):
			out.append(r.tower_id)
	var rc := RarityCatalog.get_default()
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		var da := _tower_def(a)
		var db := _tower_def(b)
		var ra := rc.find(da.rarity) if da != null else null
		var rb := rc.find(db.rarity) if db != null else null
		return (ra.order if ra != null else 99) < (rb.order if rb != null else 99))
	return out


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_popup = null
	var v := UiKit.screen(self)
	if _category == &"":
		_build_categories(v)
	elif _category == &"tower":
		_build_towers(v)
	else:
		_build_items(v, _items(_category), _category_name(_category))


func _category_name(id: StringName) -> String:
	for cat in CATEGORIES:
		if cat["id"] == id:
			return cat["name"]
	return ""


func _build_categories(v: VBoxContainer) -> void:
	UiKit.header(v, I18n.t("Research"), func() -> void: SceneRouter.to_menu())
	v.add_child(UiKit.label(I18n.t("Research unlocks options rather than raw power. Every level can be beaten without it."), 16, UiKit.MUTED))
	var model: ProgressionModel = Progression.model
	var list := UiKit.scroll(v)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	for cat in CATEGORIES:
		var items := _items(cat["id"])
		var owned := 0
		for r in items:
			if model.profile.has_research(r.id):
				owned += 1
		var card := Button.new()
		card.name = "Category_%s" % cat["id"]
		card.theme_type_variation = "CardButton"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 150)
		card.pressed.connect(func() -> void:
			_category = cat["id"]
			_build())
		UiKit.juice(card)
		var cv := _centered_box(card)
		cv.add_child(UiKit.tex(UiKit.icon(cat["icon"]), 44, VisualPalette.CYAN if owned < items.size() else VisualPalette.GREEN))
		_card_title(cv, I18n.t(cat["name"]))
		_card_count(cv, owned, items.size())
		grid.add_child(card)


## Tower avatar+name cards, sorted by rank, with a locked "SS - coming soon" placeholder at the end.
func _build_towers(v: VBoxContainer) -> void:
	UiKit.header(v, I18n.t("Tower Upgrades"), func() -> void:
		_category = &""
		_build())
	_build_tower_filters(v)
	var model: ProgressionModel = Progression.model
	var list := UiKit.scroll(v)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	var shown := 0
	for tid in _towers_with_research():
		var def := _tower_def(tid)
		var rarity := def.rarity if def != null else &"C"
		if _rank_filter != &"" and rarity != _rank_filter:
			continue
		var items := _items(&"tower").filter(func(r: ResearchDef) -> bool: return r.tower_id == tid)
		var owned := 0
		for r in items:
			if model.profile.has_research(r.id):
				owned += 1
		if _only_incomplete and owned == items.size():
			continue
		shown += 1
		var card := Button.new()
		card.name = "Tower_%s" % tid
		card.theme_type_variation = "CardButton"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 150)
		card.pressed.connect(func() -> void: _open_tower_popup(tid))
		UiKit.juice(card)
		var cv := _centered_box(card)
		cv.add_child(UiKit.tex(UiKit.tower_icon(tid), 48))
		_card_title(cv, I18n.t(def.display_name) if def != null else String(tid))
		_card_count(cv, owned, items.size())
		var rank := UiKit.rank_badge(rarity, 12)
		rank.position = Vector2(6, 6)
		card.add_child(rank)
		grid.add_child(card)
	if _rank_filter == &"" or _rank_filter == &"SS":
		var ss := Button.new()
		ss.name = "Tower_ss_placeholder"
		ss.theme_type_variation = "CardButton"
		ss.disabled = true
		ss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ss.custom_minimum_size = Vector2(0, 150)
		var cv := _centered_box(ss)
		cv.add_child(UiKit.tex(UiKit.icon("lock"), 40, UiKit.MUTED))
		_card_title(cv, I18n.t("SS tower"))
		var soon := UiKit.label(I18n.t("Coming soon"), 14, UiKit.MUTED)
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		soon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(soon)
		grid.add_child(ss)
		shown += 1
	if shown == 0:
		list.add_child(UiKit.label(I18n.t("No towers match this filter."), 16, UiKit.MUTED))


## Rank chips (exclusive) + an "only unfinished" toggle. Scales to many towers without a long scroll.
func _build_tower_filters(v: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var tg := ButtonGroup.new()
	var ranks: Array[StringName] = [&""]
	ranks.append_array(RANK_ORDER)
	for rk in ranks:
		var b := UiKit.button(I18n.t("All") if rk == &"" else String(rk), func() -> void:
			_rank_filter = rk
			_build(), Vector2(0, 44), "CardButton")
		b.name = "Filter_%s" % ("all" if rk == &"" else String(rk))
		b.toggle_mode = true
		b.button_group = tg
		b.button_pressed = _rank_filter == rk
		b.add_theme_font_size_override("font_size", 14)
		row.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var inc := UiKit.button(I18n.t("Unfinished only"), func() -> void:
		_only_incomplete = not _only_incomplete
		_build(), Vector2(0, 44), "CardButton", "")
	inc.name = "Filter_incomplete"
	inc.toggle_mode = true
	inc.button_pressed = _only_incomplete
	inc.add_theme_font_size_override("font_size", 14)
	row.add_child(inc)


## The flat item list used by "Support" (not tied to a single tower).
func _build_items(v: VBoxContainer, items: Array, title: String) -> void:
	UiKit.header(v, I18n.t(title), func() -> void:
		_category = &""
		_build())
	var list := UiKit.scroll(v)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	for r in items:
		grid.add_child(_item_card(r, &""))


## Floating popup: tower info + its research items, over whatever the screen currently shows.
func _open_tower_popup(tid: StringName) -> void:
	if _popup != null:
		_popup.queue_free()
	var def := _tower_def(tid)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_popup = bg
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	bg.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CardAccent"
	panel.add_theme_stylebox_override("panel", UiKit.chamfer(VisualPalette.BG_DEEP, Color(VisualPalette.CYAN, 0.55), 18, 2))
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	pv.add_child(top)
	top.add_child(UiKit.tex(UiKit.tower_icon(tid), 56))
	var ttl := VBoxContainer.new()
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ttl.add_theme_constant_override("separation", 2)
	top.add_child(ttl)
	var name_l := UiKit.title((I18n.t(def.display_name) if def != null else String(tid)).to_upper(), 24, UiKit.TEXT, 2)
	ttl.add_child(name_l)
	if def != null:
		ttl.add_child(UiKit.label(I18n.t(def.role), 14, UiKit.MUTED))
	if def != null:
		var rank := UiKit.rank_badge(def.rarity, 16)
		rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(rank)
	top.add_child(UiKit.icon_button("close", func() -> void:
		_popup.queue_free()
		_popup = null, Vector2(44, 44)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	pv.add_child(grid)
	for r in _items(&"tower").filter(func(x: ResearchDef) -> bool: return x.tower_id == tid):
		grid.add_child(_item_card(r, tid))


## One research item's buy card. Reused by both the Support list and the tower popup; when
## `reopen_tower` is set, buying it rebuilds the popup in place instead of the whole screen.
func _item_card(r: ResearchDef, reopen_tower: StringName) -> Control:
	var model: ProgressionModel = Progression.model
	var owned := model.profile.has_research(r.id)
	var reason := model.research_block_reason(r.id)
	var card := PanelContainer.new()
	card.theme_type_variation = "CardGood" if owned else ("CardAccent" if reason == "" else "")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 150)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	var top := HBoxContainer.new()
	cv.add_child(top)
	top.add_child(UiKit.tex(UiKit.tower_icon(r.tower_id) if r.tower_id != &"" else UiKit.icon("research"), 36,
		Color.WHITE if r.tower_id != &"" else VisualPalette.VIOLET))
	var name_l := UiKit.label(I18n.t(r.display_name).to_upper(), 16, VisualPalette.GREEN if owned else UiKit.TEXT)
	name_l.add_theme_font_override("font", UiKit.font("head", 1))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(name_l)
	if owned:
		top.add_child(UiKit.tex(UiKit.icon("check"), 22, VisualPalette.GREEN))
	var desc := UiKit.label(I18n.t(r.description), 14, UiKit.MUTED)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(desc)
	var b := UiKit.button(I18n.t("Owned") if owned else (I18n.f("Buy  %d Cores", r.cost) if reason == "" else reason),
		func() -> void:
			if Progression.model.buy_research(r.id):
				if reopen_tower != &"":
					_build.call_deferred()
					_open_tower_popup.call_deferred(reopen_tower)
				else:
					_build.call_deferred(), Vector2(0, 46), "",
		"check" if owned else ("cores" if reason == "" else "lock"))
	if reason == "" and not owned:
		b.add_theme_color_override("icon_normal_color", VisualPalette.ORANGE)
		b.add_theme_color_override("font_color", VisualPalette.ORANGE)
	elif owned:
		b.add_theme_color_override("icon_disabled_color", VisualPalette.GREEN)
	b.disabled = reason != ""
	b.add_theme_font_size_override("font_size", 15)
	cv.add_child(b)
	return card


func _centered_box(card: Button) -> VBoxContainer:
	var cv := VBoxContainer.new()
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 6)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cv)
	return cv


func _card_title(cv: VBoxContainer, text: String) -> void:
	var n := UiKit.label(text.to_upper(), 16, UiKit.TEXT)
	n.add_theme_font_override("font", UiKit.font("head", 1))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(n)


func _card_count(cv: VBoxContainer, owned: int, total: int) -> void:
	var count := UiKit.label("%d / %d" % [owned, total], 14, VisualPalette.GREEN if owned == total else UiKit.MUTED)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(count)


func on_back() -> void:
	if _popup != null:
		_popup.queue_free()
		_popup = null
	elif _category != &"":
		_category = &""
		_build()
	else:
		SceneRouter.to_menu()
