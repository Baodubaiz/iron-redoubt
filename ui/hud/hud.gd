class_name Hud
extends CanvasLayer
## Reforged HUD (Stage E). Top bar: Base HP bar, credits (count-up), wave, map status (day/night,
## gate), wave countdown / enemies left, start-early, speed, pause. Right: tower cards. Feedback:
## toast stack, wave / boss banners, floating credit numbers, EMP flash. Pause menu, animated results.
## Presentation only: every action goes through MatchController / PlacementController commands.

const TOP_H := 56.0
const PALETTE_W := 112.0
const P = preload("res://ui/style/visual_palette.gd")

var controller: MatchController
var placement: PlacementController
var wave_preview: bool = false ## Field Scanner research
var challenge: ChallengeDef
var items_enabled: bool = true ## false in the Combat Lab (no economy there)
var match_id: String = ""

var _root: Control
var _panel: TowerPanel
# top bar
var _hp_bar: ProgressBar
var _hp_label: Label
var _money_chip: PanelContainer
var _money_label: Label
var _money_shown := 0.0
var _wave_label: Label
var _map_chip: PanelContainer
var _map_icon: TextureRect
var _map_label: Label
var _status_chip: PanelContainer
var _status_icon: TextureRect
var _status_label: Label
var _start_btn: Button
var _speed_btn: Button
var _pause_btn: Button
# palette
var _palette: VBoxContainer
var _palette_buttons: Dictionary = {} # TowerDef -> Button
var _palette_costs: Dictionary = {} # TowerDef -> Label
# consumable items
var _items_panel: PanelContainer
var _items_row: HBoxContainer
var _items_toggle: Button
var _items_collapsed: bool = false
var _item_buttons: Dictionary = {} # ConsumableDef -> Button
var _item_counts: Dictionary = {} # ConsumableDef -> Label
# feedback
var _confirm_box: HBoxContainer
var _confirm_ok: Button
var _toasts: VBoxContainer
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _floaters: Control
var _flash: ColorRect
var _preview: Label
var _synergy: PanelContainer
var _synergy_label: Label
var _synergy_time: float = 0.0
var _synergy_last: Dictionary = {}
# overlays
var _pause_overlay: Control
var _results_overlay: Control
var _results_panel: PanelContainer
var _results_title: Label
var _results_sub: Label
var _results_stats: HBoxContainer
var _results_rewards: VBoxContainer
var _next_button: Button
var _next_level: LevelDef
var _rays: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)
	_root = root
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(P.RED, 0.0)
	root.add_child(_flash)
	_build_top_bar(root)
	_build_palette(root)
	_build_items(root)
	_build_confirm(root)
	_build_feedback(root)
	_panel = TowerPanel.new()
	_panel.controller = controller
	_panel.placement = placement
	root.add_child(_panel)
	_pause_overlay = _build_pause(root)
	_results_overlay = _build_results(root)
	_money_shown = controller.economy.currency
	_money_label.text = str(controller.economy.currency)

	controller.economy.changed.connect(func(_c: int, _d: int, _r: String) -> void: _refresh())
	controller.base.changed.connect(func(_h: int, _m: int) -> void:
		_refresh()
		_pulse(_hp_bar.get_parent() as Control, P.RED))
	controller.state_changed.connect(func(_s: int) -> void: _refresh())
	controller.paused_changed.connect(_on_paused)
	controller.match_ended.connect(_on_match_ended)
	controller.waves.wave_started.connect(func(i: int, bonus: int) -> void:
		_show_banner(I18n.f("Wave %d", i + 1).to_upper(), I18n.f("+%d early bonus", bonus) if bonus > 0 else "", P.CYAN))
	controller.waves.wave_cleared.connect(func(i: int, reward: int) -> void:
		_show_banner(I18n.f("Wave %d cleared", i + 1).to_upper(), "+%d" % reward, P.GREEN))
	controller.tower_built.connect(func(t: Tower) -> void: _floater(t.position, "-%d" % t.def.cost, P.ORANGE))
	controller.tower_upgraded.connect(func(t: Tower) -> void:
		var evo_now := t.evolved and not t.has_meta("evo_shown")
		_floater(t.position, I18n.t("Evolved") if evo_now else "T%d" % t.tier, P.tower_color(t.def.id))
		if evo_now:
			t.set_meta("evo_shown", true))
	controller.tower_sold.connect(func(t: Tower, refund: int) -> void:
		_floater(t.position, "+%d" % refund, P.ORANGE)
		_toast(I18n.f("Sold %s +%d", [I18n.t(t.def.display_name), refund]), "sell", P.ORANGE))
	controller.towers_disrupted.connect(func(_p: Vector2) -> void: _screen_flash(P.RED))
	placement.palette_rect_provider = func() -> Rect2: return _palette.get_global_rect()
	placement.message.connect(_on_placement_message)
	placement.item_target_chosen.connect(func(it: ConsumableDef, wp: Vector2) -> void: _consume_item(it, wp))
	placement.aim_changed.connect(func(it: ConsumableDef) -> void:
		for k in _item_buttons:
			(_item_buttons[k] as Button).modulate = Color(1.4, 1.25, 0.8) if k == it else Color.WHITE)
	placement.ghost_changed.connect(_on_ghost_changed)
	placement.session_changed.connect(func(_d: TowerDef) -> void: _refresh())
	controller.boss_spawned.connect(func(e: Enemy) -> void:
		_show_banner(I18n.f("BOSS: %s", I18n.t(e.def.display_name)).to_upper(), "", P.RED)
		_screen_flash(P.RED))
	controller.boss_phase_changed.connect(func(e: Enemy, phase: int) -> void:
		var msg := phase_message(e.def.boss_kit, phase)
		if msg != "":
			_toast(I18n.t(msg), "boss", P.RED))
	controller.interaction_triggered.connect(_on_interaction)
	_refresh()


func _process(delta: float) -> void:
	if controller.state == MatchController.State.PREP or controller.state == MatchController.State.WAVE_ACTIVE:
		_refresh_wave_controls()
	# credits count up / down smoothly
	var target := float(controller.economy.currency)
	if absf(_money_shown - target) > 0.5:
		_money_shown = move_toward(_money_shown, target, maxf(absf(target - _money_shown) * delta * 8.0, delta * 40.0))
		_money_label.text = str(int(round(_money_shown)))
	if _synergy_time > 0.0:
		_synergy_time -= delta
		_synergy.modulate.a = clampf(_synergy_time / 0.4, 0.0, 1.0)


# ================================================================ build

func _build_top_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = TOP_H
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(P.BG_DEEP, 0.9)
	sb.border_color = Color(P.CYAN, 0.35)
	sb.border_width_bottom = 2
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	bar.add_theme_stylebox_override("panel", sb)
	root.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bar.add_child(h)
	# Base HP
	var hp := _chip_box(h)
	hp.get_child(0).add_child(UiKit.tex(UiKit.icon("heart"), 22, P.GREEN))
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(70, 10)
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.get_child(0).add_child(_hp_bar)
	_hp_label = _value(hp.get_child(0), P.TEXT, 18)
	# credits
	_money_chip = _chip_box(h)
	_money_chip.get_child(0).add_child(UiKit.tex(UiKit.icon("credits"), 22, P.ORANGE))
	_money_label = _value(_money_chip.get_child(0), P.ORANGE, 20)
	_money_label.custom_minimum_size = Vector2(52, 0)
	# wave
	var wv := _chip_box(h)
	wv.get_child(0).add_child(UiKit.tex(UiKit.icon("wave"), 22, P.BLUE))
	_wave_label = _value(wv.get_child(0), P.TEXT, 18)
	# map status (day / night, gates)
	_map_chip = _chip_box(h)
	_map_icon = UiKit.tex(UiKit.icon("sun"), 20, P.ORANGE)
	_map_chip.get_child(0).add_child(_map_icon)
	_map_label = _value(_map_chip.get_child(0), P.TEXT_DIM, 15)
	_map_chip.visible = controller.level.map.day_night or controller.level.map.dynamic_routes
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(spacer)
	# countdown / enemies
	_status_chip = _chip_box(h)
	_status_icon = UiKit.tex(UiKit.icon("clock"), 20, P.TEXT_DIM)
	_status_chip.get_child(0).add_child(_status_icon)
	_status_label = _value(_status_chip.get_child(0), P.TEXT, 17)
	_start_btn = UiKit.button("", func() -> void:
		_start_btn.disabled = true # immediate guard against repeated taps
		controller.request_next_wave()
		_refresh(), Vector2(196, 46), "PrimaryButton", "play")
	_start_btn.add_theme_font_size_override("font_size", 17)
	h.add_child(_start_btn)
	_speed_btn = UiKit.button("x1", func() -> void: controller.set_speed(2 if controller.speed == 1 else 1),
		Vector2(78, 46), "GhostButton", "fast")
	_speed_btn.add_theme_font_size_override("font_size", 17)
	controller.speed_changed.connect(func(sp: int) -> void:
		_speed_btn.text = "x%d" % sp
		var c := P.ORANGE if sp > 1 else P.TEXT
		_speed_btn.add_theme_color_override("font_color", c)
		_speed_btn.add_theme_color_override("icon_normal_color", P.ORANGE if sp > 1 else P.CYAN))
	h.add_child(_speed_btn)
	_pause_btn = UiKit.icon_button("pause", func() -> void: controller.set_paused(true), Vector2(56, 46))
	h.add_child(_pause_btn)


func _chip_box(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Chip"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	parent.add_child(p)
	return p


func _value(parent: Control, col: Color, size: int) -> Label:
	var l := UiKit.title("", size, col, 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_palette(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PALETTE_W
	panel.offset_top = TOP_H + 6
	panel.offset_bottom = -6
	var sb := UiKit.chamfer(Color(P.BG_DEEP, 0.82), Color(P.SURFACE_LINE, 0.8), 12)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	# Still scrollable as a safety net (future content with many more towers), but cards shrink
	# first so the whole loadout (up to LoadoutScreen.LOADOUT_SIZE) fits without scrolling.
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	_palette = VBoxContainer.new()
	const SEP := 6
	_palette.add_theme_constant_override("separation", SEP)
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_palette)
	var towers := controller.available_towers()
	const MAX_CARD_H := 124.0
	const MIN_CARD_H := 78.0
	const PANEL_INNER_H := 640.0 # TOP_H + margins already carved out; see _build_palette's panel rect
	var n := maxi(towers.size(), 1)
	var card_h: float = clampf((PANEL_INNER_H - float(n - 1) * SEP) / n, MIN_CARD_H, MAX_CARD_H)
	var s: float = card_h / MAX_CARD_H # shrink icon/text together with the card
	for def in towers:
		var b := Button.new()
		b.name = "Card_%s" % def.id
		b.theme_type_variation = "CardButton"
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(98, card_h)
		b.button_down.connect(func() -> void:
			UiKit.click()
			placement.begin_from_palette(def, b.get_viewport().get_mouse_position()))
		UiKit.juice(b)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.add_theme_constant_override("separation", 0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := UiKit.tex(UiKit.tower_icon(def.id), maxf(28.0, 58.0 * s))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var n_lbl := UiKit.label(I18n.t(def.display_name), maxi(10, roundi(14.0 * s)), P.tower_color(def.id))
		n_lbl.add_theme_font_override("font", UiKit.font("ui"))
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(n_lbl)
		var ch := HBoxContainer.new()
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		ch.add_theme_constant_override("separation", 4)
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ch)
		ch.add_child(UiKit.tex(UiKit.icon("credits"), maxf(10.0, 14.0 * s), P.ORANGE))
		var cost := UiKit.title(str(def.cost), maxi(11, roundi(16.0 * s)), P.ORANGE, 1)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.add_child(cost)
		var rank := UiKit.rank_badge(def.rarity, maxi(10, roundi(12.0 * s)))
		rank.position = Vector2(5, 4)
		b.add_child(rank)
		_palette.add_child(b)
		_palette_buttons[def] = b
		_palette_costs[def] = cost


## Bottom-left row: owned consumable items (Armory). One tap = one use, no targeting, no cooldown.
func _build_items(root: Control) -> void:
	if not items_enabled or Progression.model.campaign.consumables.is_empty():
		return
	_items_panel = PanelContainer.new()
	_items_panel.anchor_left = 0.0
	_items_panel.anchor_top = 1.0
	_items_panel.anchor_bottom = 1.0
	_items_panel.offset_left = 6
	_items_panel.offset_bottom = -6
	_items_panel.offset_top = -82
	var sb := UiKit.chamfer(Color(P.BG_DEEP, 0.82), Color(P.SURFACE_LINE, 0.8), 12)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_items_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_items_panel)
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_items_panel.add_child(outer)
	_items_toggle = UiKit.icon_button("back", func() -> void: _toggle_items(), Vector2(28, 58))
	_items_toggle.name = "ItemsToggle"
	_items_toggle.tooltip_text = I18n.t("Hide items")
	outer.add_child(_items_toggle)
	_items_row = HBoxContainer.new()
	_items_row.add_theme_constant_override("separation", 8)
	outer.add_child(_items_row)
	for item in Progression.model.campaign.consumables:
		var b := Button.new()
		b.name = "Item_%s" % item.id
		b.theme_type_variation = "CardButton"
		b.custom_minimum_size = Vector2(60, 64)
		b.tooltip_text = I18n.t(item.display_name) + "\n" + I18n.t(item.description)
		b.pressed.connect(func() -> void: _use_item(item))
		UiKit.juice(b)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.add_theme_constant_override("separation", 0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		v.add_child(UiKit.tex(UiKit.icon(item.icon), 28, P.VIOLET))
		var count := UiKit.title("0", 15, P.VIOLET, 1)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(count)
		_items_row.add_child(b)
		_item_buttons[item] = b
		_item_counts[item] = count
	_refresh_items()


func _toggle_items() -> void:
	_items_collapsed = not _items_collapsed
	_items_row.visible = not _items_collapsed
	_items_toggle.icon = UiKit.icon("forward" if _items_collapsed else "back")
	_items_toggle.tooltip_text = I18n.t("Show items") if _items_collapsed else I18n.t("Hide items")
	UiKit.click()


func _use_item(item: ConsumableDef) -> void:
	if Progression.model.use_item_block_reason(item, match_id) != "" or not controller.can_issue_commands():
		return
	if item.targeted and placement != null:
		placement.begin_aim(item) # tap the map next; tapping the item again cancels (nothing consumed)
		UiKit.click()
		return
	_consume_item(item, Vector2.INF)


## Spends one item and fires it. It always goes off, even if nothing is in range (2026-11-19, user).
func _consume_item(item: ConsumableDef, at: Vector2) -> void:
	if Progression.model.use_item_block_reason(item, match_id) != "" or not controller.can_issue_commands():
		return
	if not Progression.model.use_item(item, match_id):
		return
	controller.apply_consumable(item, at)
	UiKit.click()
	_refresh_items()


func _refresh_items() -> void:
	for item in _item_buttons:
		var owned: int = Progression.model.profile.item_count(item.id)
		var blocked: bool = Progression.model.use_item_block_reason(item, match_id) != ""
		(_item_buttons[item] as Button).disabled = blocked
		(_item_counts[item] as Label).text = str(owned)


func _build_confirm(root: Control) -> void:
	_confirm_box = HBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", 10)
	_confirm_box.visible = false
	root.add_child(_confirm_box)
	_confirm_ok = UiKit.button(I18n.t("Build"), func() -> void: placement.confirm(), Vector2(104, 52), "PrimaryButton", "check")
	_confirm_ok.add_theme_font_size_override("font_size", 17)
	_confirm_box.add_child(_confirm_ok)
	var no := UiKit.button(I18n.t("Cancel"), func() -> void: placement.cancel(), Vector2(104, 52), "GhostButton", "close")
	no.add_theme_color_override("icon_normal_color", P.RED)
	no.add_theme_font_size_override("font_size", 17)
	_confirm_box.add_child(no)


func _build_feedback(root: Control) -> void:
	_floaters = Control.new()
	_floaters.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floaters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_floaters)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_top = TOP_H + 10
	_toasts.offset_left = -320
	_toasts.offset_right = 320
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -360
	_banner.offset_right = 360
	_banner.offset_top = -170
	_banner.offset_bottom = -90
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_banner_title = UiKit.title("", 46, P.CYAN, 6)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_constant_override("outline_size", 12)
	_banner_title.add_theme_color_override("font_outline_color", Color(P.BG_DEEP, 0.85))
	_banner.add_child(_banner_title)
	_banner_sub = UiKit.title("", 20, P.ORANGE, 2)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_constant_override("outline_size", 8)
	_banner_sub.add_theme_color_override("font_outline_color", Color(P.BG_DEEP, 0.85))
	_banner.add_child(_banner_sub)
	_preview = UiKit.label("", 14, P.TEXT_DIM)
	_preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_preview.offset_left = 12
	_preview.offset_top = TOP_H + 8
	_preview.offset_right = 520
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_theme_constant_override("outline_size", 6)
	_preview.add_theme_color_override("font_outline_color", Color(P.BG_DEEP, 0.9))
	root.add_child(_preview)
	_synergy = PanelContainer.new()
	_synergy.theme_type_variation = "Chip"
	_synergy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_synergy.offset_left = 12
	_synergy.offset_top = -44
	_synergy.offset_bottom = -10
	_synergy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synergy.modulate.a = 0.0
	var sh := HBoxContainer.new()
	_synergy.add_child(sh)
	sh.add_child(UiKit.tex(UiKit.icon("bolt"), 18, P.GREEN))
	_synergy_label = UiKit.title("", 16, P.GREEN, 1)
	sh.add_child(_synergy_label)
	root.add_child(_synergy)


const INTERACTION_NAMES := {"shatter": "Shatter", "grounded": "Grounded", "conductive": "Conductive",
	"meltdown": "Meltdown", "inferno": "Inferno", "cascade": "Cascade", "storm_array": "Storm Array"}


func _on_interaction(n: String) -> void:
	# throttled: at most once per 3 s per interaction name
	var now := controller.match_time
	if now - float(_synergy_last.get(n, -100.0)) < 3.0:
		return
	_synergy_last[n] = now
	_synergy_label.text = I18n.f("Synergy: %s", I18n.t(INTERACTION_NAMES.get(n, n)))
	_synergy_time = 1.5


func _build_pause(root: Control) -> Control:
	var o := _overlay(root)
	var v := _center_box(o, 360)
	_title(v, I18n.t("Paused").to_upper(), P.CYAN)
	_menu_button(v, I18n.t("Resume"), func() -> void: controller.set_paused(false), "PrimaryButton", "play")
	_menu_button(v, I18n.t("Settings"), func() -> void: _open_settings(o), "", "gear")
	_menu_button(v, I18n.t("Restart level"), func() -> void: SceneRouter.restart_level(), "", "restart")
	_menu_button(v, I18n.t("Exit"), func() -> void: _exit(), "", "exit")
	return o


func _build_results(root: Control) -> Control:
	var o := _overlay(root)
	_rays = Control.new()
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	o.add_child(_rays)
	var v := _center_box(o, 480)
	_results_panel = v.get_parent() as PanelContainer
	_results_title = _title(v, "", P.GREEN)
	_results_title.add_theme_font_size_override("font_size", 52)
	_results_sub = UiKit.label("", 16, P.TEXT_DIM)
	_results_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_results_sub)
	_results_stats = HBoxContainer.new()
	_results_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_results_stats.add_theme_constant_override("separation", 8)
	v.add_child(_results_stats)
	_results_rewards = VBoxContainer.new()
	_results_rewards.add_theme_constant_override("separation", 6)
	v.add_child(_results_rewards)
	_next_button = UiKit.button(I18n.t("Next level"), func() -> void:
		if _next_level != null:
			var nl := _next_level
			_after_break_ad(func() -> void: SceneRouter.play_level(nl)), Vector2(0, 58), "PrimaryButton", "play")
	_next_button.visible = false
	v.add_child(_next_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for it in [["Restart level", "restart", func() -> void: _after_break_ad(func() -> void: SceneRouter.restart_level())],
			["Back", "exit", func() -> void: _after_break_ad(func() -> void: _exit())]]:
		var b := UiKit.button(I18n.t(it[0]), it[2], Vector2(0, 52), "", it[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		row.add_child(b)
	return o


func apply_insets(ins: Dictionary) -> void:
	if _root != null:
		ScreenLayout.apply_to_control(_root, ins)


## Between matches only: a CrazyGames break ad (skipped by them while on cooldown), then go on.
var _leaving := false


func _after_break_ad(next: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	AdService.show_midgame(next)


func _exit() -> void:
	if SceneRouter.pending_is_lab:
		SceneRouter.to_menu()
	elif challenge != null:
		SceneRouter.to_meta()
	else:
		SceneRouter.to_campaign()


## Called by MatchScene after the result was submitted to progression.
func show_report(report: Dictionary, next_level: LevelDef) -> void:
	_next_level = next_level
	_next_button.visible = next_level != null
	for c in _results_rewards.get_children():
		c.queue_free()
	var items: Array = [] # [icon or texture, text, colour]
	if report.is_empty():
		items.append(["research", I18n.t("(Combat Lab: no rewards)"), P.TEXT_DIM])
	elif report.get("duplicate", false):
		items.append(["check", I18n.t("Result already recorded"), P.TEXT_DIM])
	else:
		if int(report["cores"]) > 0:
			items.append(["cores", I18n.f("+%d Cores", report["cores"]), P.ORANGE])
		if report.has("defeat_waves"):
			items.append(["check", I18n.f("%d waves survived", int(report["defeat_waves"])), P.TEXT_DIM])
		if report["first_clear"]:
			items.append(["check", I18n.t("First clear!"), P.GREEN])
		if report["flawless"]:
			items.append(["star", I18n.t("Flawless bonus"), P.ORANGE])
		if report["unlocked_tower"] != "":
			var tex: Texture2D = null
			for id in ["pulse", "nova", "lance", "beacon"]:
				var d: TowerDef = load("res://data/towers/%s.tres" % id)
				if d.display_name == report["unlocked_tower"]:
					tex = UiKit.tower_icon(d.id)
			items.append([tex if tex != null else "upgrade", I18n.f("New tower unlocked: %s", I18n.t(report["unlocked_tower"])), P.CYAN])
		var sh: Dictionary = report.get("shards", {})
		if not sh.is_empty():
			var txt := I18n.f("+%d %s shards", [int(sh["amount"]), I18n.t(String(sh["name"]))])
			if sh["jackpot"]:
				txt = I18n.t("JACKPOT!") + "  " + txt
			items.append([UiKit.tower_icon(StringName(String(sh["tower"]))), txt, P.VIOLET])
		if report["unlocked_level"] != "":
			items.append(["campaign", I18n.f("Unlocked: %s", I18n.t(report["unlocked_level"])), P.CYAN])
		if report["challenge_completed"]:
			items.append(["trophy", I18n.t("Challenge complete!"), P.ORANGE])
		for a in report["achievements"]:
			items.append(["trophy", I18n.f("Achievement: %s", I18n.t(a)), P.ORANGE])
		if Progression.model.pending_save:
			items.append(["close", I18n.t("(Saving failed — will retry)"), P.RED])
	var nodes: Array = []
	for it in items:
		var chip := PanelContainer.new()
		chip.theme_type_variation = "Chip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		chip.add_child(h)
		var tex: Texture2D = it[0] if it[0] is Texture2D else UiKit.icon(it[0])
		h.add_child(UiKit.tex(tex, 26, Color.WHITE if it[0] is Texture2D else it[2]))
		var l := UiKit.label(it[1], 17, it[2])
		l.add_theme_font_override("font", UiKit.font("body_bold"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		_results_rewards.add_child(chip)
		nodes.append(chip)
	UiKit.slide_in(nodes, Vector2(-40, 0), 0.12, 0.35)


func _overlay(root: Control) -> Control:
	var o := ColorRect.new()
	o.color = Color(P.BG_DEEP, 0.72)
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	root.add_child(o)
	return o


func _center_box(parent: Control, width: float) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	var p := PanelContainer.new()
	p.theme_type_variation = "CardAccent"
	p.add_theme_stylebox_override("panel", UiKit.chamfer(P.SURFACE, Color(P.CYAN, 0.55), 18, 2))
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(width, 0)
	p.add_child(v)
	return v


func _title(v: VBoxContainer, text: String, col: Color) -> Label:
	var l := UiKit.title(text, 36, col, 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return l


func _menu_button(v: VBoxContainer, text: String, cb: Callable, variation: String = "", icon_name: String = "") -> void:
	var b := UiKit.button(text, cb, Vector2(0, 56), variation, icon_name)
	v.add_child(b)


func _open_settings(overlay: Control) -> void:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(P.BG_DEEP, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	overlay.add_child(c)
	var panel := SettingsPanel.new()
	panel.show_language = false # language is changed from the main menu Settings screen
	panel.closed.connect(func() -> void:
		bg.queue_free()
		c.queue_free())
	c.add_child(panel)


# ================================================================ refresh

func _refresh() -> void:
	var b := controller.base
	_hp_bar.max_value = maxi(b.max_hp, 1)
	_hp_bar.value = b.hp
	var ratio := float(b.hp) / maxf(b.max_hp, 1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = P.GREEN if ratio > 0.6 else (P.ORANGE if ratio > 0.3 else P.RED)
	fill.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_label.text = "%d/%d" % [b.hp, b.max_hp]
	var shown := clampi(controller.waves.index + 1, 0, controller.waves.wave_count())
	_wave_label.text = I18n.f("Wave %d/%d", [shown, controller.waves.wave_count()]).to_upper()
	for def: TowerDef in _palette_buttons:
		var btn: Button = _palette_buttons[def]
		var affordable := controller.economy.can_afford(def.cost)
		btn.modulate = Color(1, 1, 1, 1.0 if affordable else 0.55)
		(_palette_costs[def] as Label).add_theme_color_override("font_color", P.ORANGE if affordable else P.RED)
		btn.set_pressed_no_signal(placement.def == def)
	_pause_btn.disabled = controller.is_over()
	_refresh_wave_controls()


func _refresh_wave_controls() -> void:
	var map := controller.level.map
	if map.day_night or map.dynamic_routes:
		var next := controller.waves.next_wave()
		if map.day_night:
			var night := controller.is_night
			_map_icon.texture = UiKit.icon("night" if night else "sun")
			_map_icon.modulate = P.BLUE if night else P.ORANGE
			var txt := I18n.t("Night") if night else I18n.t("Day")
			if controller.state == MatchController.State.PREP and next != null and next.night != night:
				txt += " → " + (I18n.t("Night") if next.night else I18n.t("Day"))
			_map_label.text = txt
		else:
			_map_icon.texture = UiKit.icon("gate")
			_map_icon.modulate = P.VIOLET
			var route := controller.active_route
			var txt := I18n.t(["North", "South"][clampi(route, 0, 1)])
			if next != null and next.active_route >= 0 and next.active_route != route and controller.state != MatchController.State.WAVE_ACTIVE:
				txt += " → " + I18n.t(["North", "South"][clampi(next.active_route, 0, 1)])
				_map_label.add_theme_color_override("font_color", P.ORANGE)
			else:
				_map_label.add_theme_color_override("font_color", P.TEXT_DIM)
			_map_label.text = txt
	match controller.state:
		MatchController.State.WAITING_FIRST_WAVE:
			_status_chip.visible = true
			_status_icon.texture = UiKit.icon("research") if wave_preview else UiKit.icon("clock")
			_status_label.text = I18n.t("Build, then start")
			_next_wave_note()
			_start_btn.text = I18n.t("Start wave 1").to_upper()
			_start_btn.disabled = false
			_start_btn.visible = true
		MatchController.State.PREP:
			_status_chip.visible = true
			_status_icon.texture = UiKit.icon("clock")
			var secs := ceili(controller.waves.prep_remaining)
			_status_label.text = "%d:%02d" % [secs / 60, secs % 60]
			_next_wave_note()
			var bonus := controller.waves.current_early_bonus()
			_start_btn.text = I18n.f("Start early +%d", bonus).to_upper()
			_start_btn.disabled = false
			_start_btn.visible = true
		MatchController.State.WAVE_ACTIVE:
			_status_chip.visible = true
			_status_icon.texture = UiKit.icon("enemy")
			_status_icon.modulate = P.RED
			_status_label.text = str(controller.alive_enemy_count())
			_preview.text = ""
			_start_btn.visible = false
		_:
			_status_chip.visible = false
			_start_btn.visible = false
	if controller.state != MatchController.State.WAVE_ACTIVE:
		_status_icon.modulate = P.TEXT_DIM


## Boss phase announcement per boss kit (English key; translated by the caller).
static func phase_message(kit: StringName, phase: int) -> String:
	var table := {
		&"monolith": ["", "", "Monolith: EMP phase — spread out!", "Monolith fractures — faster!"],
		&"warden": ["", "", "Warden overclocks — it sprints between shells!"],
		&"carrier": ["", "", "Carrier cloak field online — keep Beacons close!"],
		&"chimera": ["", "", "Chimera jammer online — towers nearby recharge slower!", "Chimera unstable — plating shifts twice as fast!"],
		&"colossus": ["", "", "Colossus tears the Rift — it jumps ahead!", "Colossus overdrive — its escort speeds up!"],
		&"dynamo": ["", "", "Dynamo capacitor online — big hits are capped!", "Dynamo overload — it speeds up!"],
		&"leviathan": ["", "", "Leviathan calls the fallen back — finish them twice!", "Leviathan dives twice as often!"],
		&"refractor": ["", "", "Refractor prismatic shield — it resists one damage type at a time!"],
	}
	var row: Array = table.get(kit, [])
	return row[phase] if phase >= 0 and phase < row.size() else ""


## A level just granted a new tower (the counter to the enemy it introduces).
func announce_new_tower(def: TowerDef) -> void:
	var col := P.tower_color(def.id)
	_show_banner(I18n.f("New tower: %s", I18n.t(def.display_name)).to_upper(), I18n.t(def.role), col)
	_toast(I18n.f("New tower: %s", I18n.t(def.display_name)), "upgrade", col)


## Field Scanner: composition of the next wave (+ boss warning).
func _next_wave_note() -> void:
	var w := controller.waves.next_wave()
	if w == null:
		_preview.text = ""
		return
	var parts: Array[String] = []
	if w.is_boss:
		parts.append(I18n.t("BOSS"))
	if wave_preview:
		var groups: Array[String] = []
		for g in w.groups:
			groups.append("%d %s" % [g.count, I18n.t(g.enemy.display_name)])
		parts.append(I18n.t("Scanner — next: ") + ", ".join(groups))
	_preview.text = "  ·  ".join(parts)


func _on_ghost_changed(world_pos: Vector2, visible_now: bool, valid: bool) -> void:
	var show := visible_now and placement.mode == PlacementController.Mode.TAP
	_confirm_box.visible = show
	_confirm_ok.disabled = not valid
	if show:
		var screen := controller.get_global_transform_with_canvas() * world_pos
		var size := Vector2(218, 52)
		var pos := screen + Vector2(-size.x * 0.5, 34)
		var area := _root.get_global_rect()
		if pos.y + size.y > area.end.y - 8:
			pos.y = screen.y - 34 - size.y
		pos.x = clampf(pos.x, area.position.x + 8, area.end.x - PALETTE_W - size.x - 8)
		_confirm_box.global_position = pos


func _on_paused(p: bool) -> void:
	_pause_overlay.visible = p
	if p:
		var panel := _pause_overlay.get_child(0).get_child(0) as Control
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.92, 0.92)
		panel.modulate.a = 0.0
		var tw := panel.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.22)
		tw.tween_property(panel, "modulate:a", 1.0, 0.15)


func _on_match_ended(won: bool) -> void:
	_refresh()
	_results_title.text = (I18n.t("Victory") if won else I18n.t("Defeat")).to_upper()
	var col := P.GREEN if won else P.RED
	_results_title.add_theme_color_override("font_color", col)
	_results_title.add_theme_constant_override("outline_size", 14)
	_results_title.add_theme_color_override("font_outline_color", Color(col, 0.18))
	_results_panel.add_theme_stylebox_override("panel", UiKit.chamfer(P.SURFACE, Color(col, 0.6), 18, 2))
	_results_sub.text = UiKit.level_title(controller.level)
	for c in _results_stats.get_children():
		c.queue_free()
	var waves_done := controller.waves.index + 1 if won else controller.waves.index
	var t := int(controller.match_time)
	var stats := [["heart", controller.base.hp, "/%d" % controller.base.max_hp, P.GREEN],
		["wave", waves_done, "/%d" % controller.waves.wave_count(), P.BLUE],
		["enemy", controller.kills(), "", P.RED], ["clock", t, "", P.TEXT]]
	for s in stats:
		var chip := UiKit.chip(s[0], "0" + s[2], s[3], 18)
		_results_stats.add_child(chip)
		var val := chip.find_child("Value", true, false) as Label
		var target: int = s[1]
		var suffix: String = s[2]
		var is_time: bool = s[0] == "clock"
		chip.create_tween().tween_method(func(x: float) -> void:
			var n := int(round(x))
			val.text = ("%d:%02d" % [n / 60, n % 60]) if is_time else (str(n) + suffix), 0.0, float(target), 0.9).set_delay(0.25)
	_results_overlay.visible = true
	_rays.set_meta("won", won)
	var panel := _results_panel
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.4)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	var tt := _results_title
	tt.pivot_offset = tt.size * 0.5
	tt.scale = Vector2(1.6, 1.6)
	tt.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).tween_property(tt, "scale", Vector2.ONE, 0.8).set_delay(0.1)
	_rays.create_tween().set_loops().tween_method(func(_x: float) -> void: _rays.queue_redraw(), 0.0, 1.0, 1.0)


## Victory: slow rotating light rays; defeat: a red vignette.
func _draw_rays() -> void:
	var s := _rays.size
	var c := s * 0.5 + Vector2(0, -150)
	var won: bool = _rays.get_meta("won", true)
	var t := Time.get_ticks_msec() / 1000.0
	if won:
		for i in range(12):
			var a := t * 0.15 + TAU * i / 12.0
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a - 0.08) * 900.0, c + Vector2.from_angle(a + 0.08) * 900.0])
			_rays.draw_colored_polygon(pts, Color(P.GREEN, 0.05))
	else:
		for k in range(6):
			var w := 40.0 * (k + 1)
			_rays.draw_rect(Rect2(0, 0, s.x, s.y), Color(P.RED, 0.03), false, w)


# ================================================================ feedback

func _on_placement_message(text: String) -> void:
	var money := text == I18n.t("Not enough currency")
	if money:
		_shake(_money_chip)
		_pulse(_money_chip, P.RED)
		_audio(&"ui_error")
		_toast(text, "credits", P.RED)
	elif placement.def != null and text == I18n.f("Tap the map to place %s", I18n.t(placement.def.display_name)):
		_toast(text, "campaign", P.CYAN)
	else:
		_audio(&"ui_error")
		_toast(text, "close", P.ORANGE)


func _toast(text: String, icon_name: String, col: Color) -> void:
	while _toasts.get_child_count() >= 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", UiKit.chamfer(Color(P.BG_DEEP, 0.9), Color(col, 0.7), 10, 2))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	chip.add_child(h)
	h.add_child(UiKit.tex(UiKit.icon(icon_name), 20, col))
	var l := UiKit.label(text, 17, P.TEXT)
	l.add_theme_font_override("font", UiKit.font("body_bold"))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	_toasts.add_child(chip)
	chip.modulate.a = 0.0
	var tw := chip.create_tween()
	tw.tween_property(chip, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.0)
	tw.tween_property(chip, "modulate:a", 0.0, 0.35)
	tw.tween_callback(chip.queue_free)


## Kept for callers of the Phase 2 API.
func _show_toast(text: String) -> void:
	_toast(text, "campaign", P.CYAN)


func _show_banner(title: String, sub: String, col: Color) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", col)
	_banner_sub.text = sub
	_banner_sub.visible = sub != ""
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.25, 1.25)
	_banner.modulate.a = 0.0
	_banner_tween = _banner.create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.chain().tween_interval(1.1)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.4)


func _floater(world_pos: Vector2, text: String, col: Color) -> void:
	var l := UiKit.title(text, 20, col, 1)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(P.BG_DEEP, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floaters.add_child(l)
	var screen := controller.get_global_transform_with_canvas() * world_pos
	l.global_position = screen + Vector2(-20, -40)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 36.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


func _pulse(c: Control, col: Color) -> void:
	if c == null:
		return
	c.modulate = Color(col.r * 1.6, col.g * 1.6, col.b * 1.6)
	c.create_tween().tween_property(c, "modulate", Color.WHITE, 0.4)


func _shake(c: Control) -> void:
	if c == null or P.reduce_effects:
		return
	var tw := c.create_tween()
	for i in range(4):
		tw.tween_property(c, "position:x", c.position.x + (6.0 if i % 2 == 0 else -6.0), 0.04)
	tw.tween_property(c, "position:x", c.position.x, 0.04)


func _screen_flash(col: Color) -> void:
	if P.reduce_effects:
		return
	_flash.color = Color(col, 0.14)
	_flash.create_tween().tween_property(_flash, "color", Color(col, 0.0), 0.35)


func _audio(id: StringName) -> void:
	if is_inside_tree() and get_tree().root.has_node("Audio"):
		get_tree().root.get_node("Audio").play(id)
