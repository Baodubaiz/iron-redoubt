class_name TowerPanel
extends PanelContainer
## Reforged tower management panel: animated portrait, icon stats, 3 upgrade-branch cards (pips,
## next-tier description, stat-change PREVIEW, cost or block reason), evolution card, Sell with
## the exact refund (tap twice to confirm). Rules are unchanged: main branch up to T3 + one
## secondary up to T2 (UpgradeRules). Docks at the bottom, or at the top when the selected tower
## sits in the lower part of the map. All actions go through MatchController commands.

const HEIGHT := 184.0
const RIGHT_MARGIN := 112.0
const TOP_BAR := 56.0
const P = preload("res://ui/style/visual_palette.gd")
## Player-facing targeting priority (free, instant, same 4 choices for every tower role). Air
## Priority picks a flying enemy first if one's in range, otherwise it's the same as First.
const TARGET_MODES := [[TowerDef.TargetRule.FIRST, "First"], [TowerDef.TargetRule.STRONGEST, "Strongest"],
	[TowerDef.TargetRule.DENSEST, "Cluster"], [TowerDef.TargetRule.AIR_FIRST, "Air"]]

var controller: MatchController
var placement: PlacementController
var tower: Tower

var _portrait: _Portrait
var _title: Label
var _rank_holder: HBoxContainer
var _subtitle: Label
var _stat_dmg: Label
var _stat_rate: Label
var _stat_range: Label
var _stats_extra: Label
var _cards: Array[PanelContainer] = []
var _branch_titles: Array[Label] = []
var _branch_pips: Array[_Pips] = []
var _branch_descs: Array[Label] = []
var _branch_previews: Array[Label] = []
var _branch_buttons: Array[Button] = []
var _evo_card: PanelContainer
var _evo_title: Label
var _evo_desc: Label
var _evo_button: Button
var _target_row: HBoxContainer
var _target_buttons: Array[Button] = []
var _sell_button: Button
var _sell_armed: float = 0.0
var _refresh_timer: float = 0.0

## Press-and-hold reveal for any ellipsized label (touch has no hover, so this replaces tooltip_text).
var _hold_tip: PanelContainer
var _hold_tip_label: Label
var _hold_source: Label = null
var _hold_timer: float = -1.0
var _hold_start_pos := Vector2.ZERO
const HOLD_TIME := 0.35
const HOLD_MOVE_CANCEL := 14.0


## Live tower art for the portrait (shares the tower's TowerVisual look).
class _Portrait extends Node2D:
	var tower: Tower
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if tower == null or not is_instance_valid(tower):
			return
		var v := tower.get_node_or_null("Visual") as TowerVisual
		var look: TowerArt.Look = v.look if v != null else null
		if look == null:
			look = TowerArt.Look.new()
			look.def = tower.def
		TowerArt.draw(self, Vector2.ZERO, look)


## Tier pips: filled = bought, outline = still buyable on this branch, faint = beyond the cap.
class _Pips extends Control:
	var tiers := 0
	var cap := 3
	var col := Color.WHITE
	func _init() -> void:
		custom_minimum_size = Vector2(40, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in range(3):
			var c := Vector2(6 + i * 13, size.y * 0.5)
			var pts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)])
			if i < tiers:
				draw_colored_polygon(pts, col)
			elif i < cap:
				pts.append(pts[0])
				draw_polyline(pts, Color(col, 0.7), 1.5)
			else:
				draw_line(c - Vector2(3, 3), c + Vector2(3, 3), Color(1, 1, 1, 0.2), 1.5)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiKit.chamfer(Color(P.BG_DEEP, 0.94), Color(P.CYAN, 0.45), 16, 2))
	var h := HBoxContainer.new()
	# Trimmed 8->6, and info/card widths below shrunk too (2026-11-15, follow-up fix): the previous
	# widths left only ~20px of slack against the panel's actual available width on a 1280-wide
	# screen -- razor-thin, so any small extra (icon glyphs, border radius, font rounding) tipped it
	# into the same Close/Sell-button overflow bug already fixed twice for individual labels. This
	# cuts total minimum width by ~130px for real margin instead of chasing one label at a time.
	h.add_theme_constant_override("separation", 6)
	add_child(h)

	# portrait + stats
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(225, 0)
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	info.add_child(top)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(78, 66)
	holder.clip_contents = false
	top.add_child(holder)
	_portrait = _Portrait.new()
	_portrait.position = Vector2(38, 34)
	_portrait.scale = Vector2(1.2, 1.2)
	holder.add_child(_portrait)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	tv.add_child(title_row)
	_title = UiKit.title("", 21, P.CYAN, 2)
	title_row.add_child(_title)
	_rank_holder = HBoxContainer.new()
	_rank_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_rank_holder)
	_subtitle = UiKit.label("", 13, P.TEXT_DIM)
	_subtitle.max_lines_visible = 2
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_make_holdable(_subtitle)
	tv.add_child(_subtitle)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	info.add_child(stats)
	_stat_dmg = _stat_chip(stats, "bolt", P.ORANGE)
	_stat_rate = _stat_chip(stats, "clock", P.CYAN)
	_stat_range = _stat_chip(stats, "range", P.GREEN)
	_stats_extra = UiKit.label("", 12, P.TEXT_DIM)
	_stats_extra.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_extra.max_lines_visible = 3
	_stats_extra.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_make_holdable(_stats_extra)
	info.add_child(_stats_extra)
	_target_row = HBoxContainer.new()
	_target_row.add_theme_constant_override("separation", 4)
	info.add_child(_target_row)
	var target_group := ButtonGroup.new()
	for mode in TARGET_MODES:
		var tb := UiKit.button(I18n.t(mode[1]), func() -> void: _on_target(mode[0]), Vector2(0, 28), "CardButton")
		tb.toggle_mode = true
		tb.button_group = target_group
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 11)
		_compact(tb)
		_target_row.add_child(tb)
		_target_buttons.append(tb)

	for i in range(3):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(152, 0)
		h.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)
		var head := HBoxContainer.new()
		box.add_child(head)
		var t := UiKit.label("", 14, P.TEXT) # 14: "Overcharge" fits next to the pips
		t.add_theme_font_override("font", UiKit.font("head", 1))
		# Autowrap (UiKit.label's default) + max_lines_visible keeps the MINIMUM width small so a long
		# translated branch name (e.g. Vietnamese) can't widen the card past its 176px slot; AUTOWRAP_OFF
		# alone reports the full untrimmed text as the minimum size regardless of text_overrun_behavior,
		# which was pushing the whole panel (and its Close/Sell buttons) off the right edge of the screen.
		t.max_lines_visible = 1
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(60, 0)
		head.add_child(t)
		var pips := _Pips.new()
		head.add_child(pips)
		var d := UiKit.label("", 12, P.TEXT_DIM)
		d.size_flags_vertical = Control.SIZE_EXPAND_FILL
		d.max_lines_visible = 2
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_make_holdable(d)
		box.add_child(d)
		var pv := UiKit.label("", 12, P.GREEN)
		pv.add_theme_font_override("font", UiKit.font("ui")) # Chakra Petch has the arrow glyph
		# Same fix as the branch/evo titles: AUTOWRAP_OFF reports the full untrimmed text as the
		# minimum size regardless of text_overrun_behavior, which was widening this card (and the
		# whole panel) again whenever a preview line like "Slow 20% -> 0%  Buff +10%" ran long.
		pv.max_lines_visible = 2 # 2026-11-19: one line cut Vietnamese previews ("Sát thương 54 -> 76…")
		pv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(pv)
		var idx := i
		var b := UiKit.button("", func() -> void: _on_branch(idx), Vector2(0, 44), "", "credits")
		_compact(b)
		box.add_child(b)
		_cards.append(card)
		_branch_titles.append(t)
		_branch_pips.append(pips)
		_branch_descs.append(d)
		_branch_previews.append(pv)
		_branch_buttons.append(b)

	_evo_card = PanelContainer.new()
	_evo_card.custom_minimum_size = Vector2(152, 0)
	h.add_child(_evo_card)
	var evo := VBoxContainer.new()
	evo.add_theme_constant_override("separation", 2)
	_evo_card.add_child(evo)
	_evo_title = UiKit.label("", 15, P.ORANGE)
	_evo_title.add_theme_font_override("font", UiKit.font("head", 1))
	_evo_title.max_lines_visible = 1 # see the branch-title comment above: keeps the minimum width small
	_evo_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	evo.add_child(_evo_title)
	_evo_desc = UiKit.label("", 12, P.TEXT_DIM)
	_evo_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_evo_desc.max_lines_visible = 4
	_evo_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_make_holdable(_evo_desc)
	evo.add_child(_evo_desc)
	_evo_button = UiKit.button("", _on_evolve, Vector2(0, 44), "", "star")
	_compact(_evo_button)
	_evo_button.add_theme_color_override("icon_normal_color", P.ORANGE)
	evo.add_child(_evo_button)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(112, 0)
	h.add_child(side)
	var close := UiKit.icon_button("close", func() -> void: placement.select(null), Vector2(112, 46))
	close.name = "Close"
	close.tooltip_text = I18n.t("Close")
	side.add_child(close)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	_sell_button = UiKit.button("", _on_sell, Vector2(112, 62), "", "sell")
	_compact(_sell_button)
	_sell_button.add_theme_color_override("font_color", P.ORANGE)
	_sell_button.add_theme_color_override("icon_normal_color", P.ORANGE)
	_sell_button.add_theme_font_size_override("font_size", 16)
	side.add_child(_sell_button)

	placement.selection_changed.connect(show_tower)
	controller.economy.changed.connect(func(_c: int, _d: int, _r: String) -> void: refresh())
	controller.tower_upgraded.connect(func(_t: Tower) -> void: refresh())
	controller.paused_changed.connect(func(_p: bool) -> void: refresh())
	controller.match_ended.connect(func(_w: bool) -> void: show_tower(null))

	# Floating "full text" bubble for press-and-hold on any ellipsized label (see _make_holdable).
	_hold_tip = PanelContainer.new()
	_hold_tip.add_theme_stylebox_override("panel", UiKit.chamfer(Color(P.BG_DEEP, 0.97), Color(P.CYAN, 0.6), 10, 2))
	_hold_tip.top_level = true
	_hold_tip.z_index = 100
	_hold_tip.visible = false
	_hold_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_tip_label = UiKit.label("", 13, P.TEXT)
	_hold_tip_label.custom_minimum_size = Vector2(240, 0)
	var tip_margin := MarginContainer.new()
	for side_name in ["left", "right", "top", "bottom"]:
		tip_margin.add_theme_constant_override("margin_%s" % side_name, 8)
	tip_margin.add_child(_hold_tip_label)
	_hold_tip.add_child(tip_margin)
	add_child(_hold_tip)


## Wires a label up to show its untruncated text in `_hold_tip` on press-and-hold, so text that got
## ellipsized to keep the panel's fixed size never truly loses information.
func _make_holdable(label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	if not label.gui_input.is_connected(_on_hold_label_input):
		label.gui_input.connect(_on_hold_label_input.bind(label))


func _on_hold_label_input(event: InputEvent, label: Label) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_hold_source = label
			_hold_start_pos = event.position
			_hold_timer = HOLD_TIME
		elif _hold_source == label:
			_hold_timer = -1.0
			_hold_tip.visible = false
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _hold_source == label:
		if event.position.distance_to(_hold_start_pos) > HOLD_MOVE_CANCEL:
			_hold_timer = -1.0
			_hold_tip.visible = false


func _update_hold_tip(delta: float) -> void:
	if _hold_timer <= 0.0:
		return
	_hold_timer -= delta
	if _hold_timer > 0.0 or not is_instance_valid(_hold_source):
		return
	var label := _hold_source
	_hold_tip_label.text = label.text
	_hold_tip.visible = true
	_hold_tip.reset_size()
	var pos := label.get_global_rect().position + Vector2(0, -_hold_tip.size.y - 8)
	var vp := get_viewport_rect().size
	pos.x = clampf(pos.x, 4.0, vp.x - _hold_tip.size.x - 4.0)
	pos.y = maxf(pos.y, 4.0)
	_hold_tip.global_position = pos


## Buttons keep a fixed width: long texts (block reasons, translations) are clipped with "…"
## instead of widening the panel past the tower cards.
func _compact(b: Button) -> void:
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_constant_override("h_separation", 6)
	b.tooltip_text = ""


func _card_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var st := UiKit.chamfer(bg, border, 12, bw)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	return st


func _stat_chip(parent: Control, icon_name: String, col: Color) -> Label:
	var p := PanelContainer.new()
	p.theme_type_variation = "Chip"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	p.add_child(h)
	h.add_child(UiKit.tex(UiKit.icon(icon_name), 15, col))
	var l := UiKit.title("", 14, P.TEXT, 0)
	h.add_child(l)
	parent.add_child(p)
	return l


func _process(delta: float) -> void:
	if not visible:
		_hold_tip.visible = false
		return
	if _sell_armed > 0.0:
		_sell_armed -= delta
		if _sell_armed <= 0.0:
			refresh()
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		refresh()
	_update_hold_tip(delta)


func show_tower(t: Tower) -> void:
	var was_visible := visible
	tower = t
	_sell_armed = 0.0
	_hold_timer = -1.0
	_hold_tip.visible = false
	visible = t != null
	_portrait.tower = t
	if t == null:
		return
	# dock away from the selected tower so it stays visible
	var dock_top := t.position.y > 420.0
	anchor_left = 0.0
	anchor_right = 1.0
	offset_left = 6
	offset_right = -RIGHT_MARGIN - 6
	if dock_top:
		anchor_top = 0.0
		anchor_bottom = 0.0
		offset_top = TOP_BAR + 4
		offset_bottom = TOP_BAR + 4 + HEIGHT
	else:
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_top = -HEIGHT - 4
		offset_bottom = -4
	refresh()
	if not was_visible: # slide in from the docked edge
		modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.15)


func refresh() -> void:
	if tower == null or not is_instance_valid(tower) or tower.sold:
		visible = false
		return
	var t := tower
	var d := t.def
	var col := P.tower_color(d.id)
	_title.text = I18n.t(d.display_name).to_upper()
	for c in _rank_holder.get_children():
		c.queue_free()
	_rank_holder.add_child(UiKit.rank_badge(d.rarity, 13))
	_title.add_theme_color_override("font_color", col)
	var sub: Array[String] = []
	var main := t.branch
	if main >= 0:
		sub.append("%s %s" % [I18n.t(d.branches[main].display_name), "I".repeat(t.tiers[main])])
		var sec := t.secondary_branch()
		if sec >= 0:
			sub.append("%s %s" % [I18n.t(d.branches[sec].display_name), "I".repeat(t.tiers[sec])])
	if t.evolved:
		sub.insert(0, I18n.t(t.branch_def().evolution.display_name))
	_subtitle.text = " + ".join(sub) if not sub.is_empty() else I18n.t(d.role)
	add_theme_stylebox_override("panel", UiKit.chamfer(Color(P.BG_DEEP, 0.94), Color(col, 0.55), 16, 2))
	_fill_stats(t)
	_target_row.visible = not t.is_aura() # aura towers (Beacon, Bastion, Chronos) have nothing to aim at
	if _target_row.visible:
		var active: int = t.targeting_override if t.targeting_override >= 0 else d.targeting
		for i in range(TARGET_MODES.size()):
			var btn := _target_buttons[i] as Button
			# Air Priority only makes sense (and only shows) once this tower can actually hit air,
			# e.g. Nova only after its Cluster III / Flak upgrade -- not every tower, not always.
			btn.visible = TARGET_MODES[i][0] != TowerDef.TargetRule.AIR_FIRST or t.can_target_air
			btn.button_pressed = TARGET_MODES[i][0] == active

	for i in range(3):
		var card := _cards[i]
		if i >= d.branches.size():
			card.visible = false
			continue
		card.visible = true
		var br := d.branches[i]
		var cap := UpgradeRules.MAX_TIER
		if UpgradeRules.other_is_main(t, i):
			cap = UpgradeRules.SECONDARY_MAX_TIER
		var nt := UpgradeRules.next_tier(t, i)
		var reason := controller.upgrade_block_reason(t, i)
		var locked := nt == null and t.tiers[i] < cap
		_branch_titles[i].text = I18n.t(br.display_name)
		var pips := _branch_pips[i]
		pips.tiers = t.tiers[i]
		pips.cap = 0 if (nt == null and t.tiers[i] == 0) else cap
		pips.col = col
		pips.queue_redraw()
		var is_main := i == main
		var style_col := col if is_main else (P.SURFACE_LINE if nt == null and t.tiers[i] == 0 else Color(col, 0.35))
		card.add_theme_stylebox_override("panel", _card_style(Color(P.SURFACE, 0.85 if nt != null or t.tiers[i] > 0 else 0.45),
			Color(style_col, 0.8 if is_main else 0.6), 2 if is_main else 1))
		_branch_titles[i].add_theme_color_override("font_color", P.TEXT_FAINT if (nt == null and t.tiers[i] == 0) else (col if is_main else P.TEXT))
		var btn := _branch_buttons[i]
		if nt == null:
			_branch_descs[i].text = reason
			_branch_previews[i].text = ""
			btn.text = I18n.t("Locked") if (locked or t.tiers[i] == 0) else I18n.t("Maxed")
			btn.icon = UiKit.icon("lock") if (locked or t.tiers[i] == 0) else UiKit.icon("check")
			btn.disabled = true
		else:
			_branch_descs[i].text = I18n.t(nt.description) if reason == "" else reason
			_branch_previews[i].text = preview_text(t, i)
			btn.icon = UiKit.icon("credits")
			btn.text = str(nt.cost)
			btn.disabled = reason != ""
			var afford := controller.economy.can_afford(nt.cost)
			btn.add_theme_color_override("font_color", P.ORANGE if afford else P.RED)
			btn.add_theme_color_override("icon_normal_color", P.ORANGE)

	var br_def := t.branch_def()
	if br_def != null and br_def.evolution != null and t.tier >= UpgradeRules.MAX_TIER:
		_evo_title.text = I18n.t(br_def.evolution.display_name)
		_evo_desc.text = I18n.t(br_def.evolution.description)
		var r := controller.evolution_block_reason(t)
		if t.evolved:
			_evo_button.text = I18n.t("Evolved")
			_evo_button.disabled = true
		else:
			_evo_button.text = I18n.f("Evolve %d", controller.evolution_cost(t)) if r == "" else r
			_evo_button.disabled = r != ""
			_evo_button.icon = UiKit.icon("star") if r == "" else null # reasons get the full width
		_evo_card.add_theme_stylebox_override("panel", _card_style(Color(P.SURFACE, 0.9), Color(P.ORANGE, 0.7), 2))
	else:
		_evo_title.text = I18n.t("Evolution")
		if UpgradeRules.EVOLUTION_CAP > 0:
			_evo_desc.text = I18n.f("Main branch to tier 3 (+1 secondary branch up to tier 2). Max %d evolved towers per match.", UpgradeRules.EVOLUTION_CAP)
		else:
			_evo_desc.text = I18n.t("Main branch to tier 3 (+1 secondary branch up to tier 2). All towers can evolve.")
		_evo_button.text = I18n.t("Not available")
		_evo_button.disabled = true
		_evo_button.icon = null
		_evo_card.add_theme_stylebox_override("panel", _card_style(Color(P.SURFACE, 0.45), P.SURFACE_LINE, 1))

	var refund := controller.sell_refund(t)
	if _sell_armed > 0.0:
		_sell_button.text = I18n.f("Confirm\n+%d", refund)
		_sell_button.add_theme_color_override("font_color", P.RED)
	else:
		_sell_button.text = I18n.f("Sell +%d", refund).replace(" +", "\n+")
		_sell_button.add_theme_color_override("font_color", P.ORANGE)
	_sell_button.disabled = not controller.can_sell()
	if controller.modifiers.no_selling:
		_sell_button.text = I18n.t("No selling")


func _fill_stats(t: Tower) -> void:
	var extra: Array[String] = []
	if t.is_beacon():
		_stat_dmg.text = I18n.f("Aura %d", int(t.attack_range))
		_stat_rate.text = I18n.f("Slow %d%%", int(round(t.pf("slow") * 100))) if t.pf("slow") > 0.0 else "—"
		_stat_range.text = I18n.t("Reveals stealth")
		if t.pf("amp_damage") > 0.0:
			var buff := I18n.f("Buff: +%d%% dmg", int(round(t.pf("amp_damage") * 100)))
			if t.pf("amp_range") > 0.0:
				buff += "  " + I18n.f("+%d%% range", int(round(t.pf("amp_range") * 100)))
			if t.pf("amp_rate") > 0.0:
				buff += "  " + I18n.f("+%d%% rate", int(round(t.pf("amp_rate") * 100)))
			extra.append(buff + " " + I18n.t("(strongest only)"))
		if t.pf("wave_income") > 0.0:
			extra.append(I18n.f("Income +%d / wave (diminishing per extra Relay)", int(t.pf("wave_income"))))
	else:
		_stat_dmg.text = (I18n.f("Beam %d dps x%.1f", [int(t.beam_dps()), t.beam_ramp()])
			if t.pf("beam_dps") > 0.0 else str(int(round(t.eff_damage()))))
		_stat_rate.text = "%.1f/s" % t.eff_rate()
		_stat_range.text = str(int(t.eff_range()))
		if t.armor_pen > 0.0: extra.append(I18n.f("Pen %d", int(t.armor_pen)))
		if t.splash_radius > 0.0: extra.append(I18n.f("Splash %d", int(t.splash_radius)))
		extra.append(I18n.t("Air: yes") if t.can_target_air else I18n.t("Air: no"))
		if t.buff_sources.size() > 0:
			extra.append(I18n.f("Buffed: +%d%% dmg  +%d%% rate  +%d%% range", [int(round(t.amp_damage * 100)),
				int(round(t.amp_rate * 100)), int(round(t.amp_range * 100))]))
	if t.is_disrupted():
		extra.append(I18n.f("DISRUPTED %.1fs", t.disrupted_timer))
	extra.append(I18n.f("Invested %d", t.total_invested))
	_stats_extra.text = "  ·  ".join(extra)


## Upgrade preview: the stats that change if the next tier of branch `b` is bought.
## Built on a throw-away Tower (recompute() is pure), so nothing in the match is touched.
static func preview_text(t: Tower, b: int) -> String:
	var tmp := Tower.new()
	tmp.setup(t.def, -1, 0)
	tmp.tiers = t.tiers.duplicate()
	tmp.branch_order = t.branch_order.duplicate()
	tmp.evolved = t.evolved
	tmp.add_tier(b)
	tmp.recompute()
	var parts: Array[String] = []
	var keys := [["damage", "Dmg", "%d"], ["fire_rate", "Rate", "%.1f"], ["attack_range", "Range", "%d"],
		["splash_radius", "Splash", "%d"], ["armor_pen", "Pen", "%d"], ["beam_dps", "Beam", "%d"],
		["slow", "Slow", "%d%%"], ["amp_damage", "Buff", "%d%%"], ["chain", "Chain", "%d"]]
	for k in keys:
		var a := float(t.params.get(k[0], 0.0)) if not (t.params.get(k[0], 0.0) is bool) else 0.0
		var z := float(tmp.params.get(k[0], 0.0)) if not (tmp.params.get(k[0], 0.0) is bool) else 0.0
		if absf(a - z) > 0.001:
			var fmt: String = k[2]
			var sa := fmt % (a * 100.0 if fmt.ends_with("%%") else a)
			var sz := fmt % (z * 100.0 if fmt.ends_with("%%") else z)
			parts.append("%s %s → %s" % [I18n.t(k[1]), sa, sz])
		if parts.size() >= 2:
			break
	if parts.size() < 2: # any other changed stat, labelled from the data catalog (new stats need no UI code)
		var known := ["damage", "fire_rate", "attack_range", "splash_radius", "armor_pen", "beam_dps", "slow", "amp_damage", "chain", "can_target_air"]
		var cat := StatCatalog.get_default()
		for k in tmp.params:
			if parts.size() >= 2:
				break
			var sd := cat.find(StringName(k))
			if known.has(k) or sd == null or not sd.shown:
				continue
			var va: Variant = t.params.get(k, 0.0)
			var vz: Variant = tmp.params[k]
			if not (va is float or va is int) or not (vz is float or vz is int) or absf(float(va) - float(vz)) < 0.001:
				continue
			var mul := 100.0 if sd.percent else 1.0
			var f := "%d%%" if sd.percent else ("%.1f" if absf(float(vz) - roundf(float(vz))) > 0.001 else "%d")
			parts.append("%s %s → %s" % [I18n.t(sd.label), f % (float(va) * mul), f % (float(vz) * mul)])
	if not bool(t.params.get("can_target_air", false)) and bool(tmp.params.get("can_target_air", false)):
		parts.append(I18n.t("Air: yes"))
	tmp.free()
	return "  ".join(parts)


func _on_branch(i: int) -> void:
	if tower != null:
		controller.try_upgrade(tower, i)
	refresh()


func _on_evolve() -> void:
	if tower != null:
		controller.try_evolve(tower)
	refresh()


func _on_target(rule: int) -> void:
	if tower != null and controller.set_targeting(tower, rule):
		UiKit.click()
	refresh()


func _on_sell() -> void:
	if tower == null or not controller.can_sell():
		return
	if _sell_armed <= 0.0:
		_sell_armed = 3.0 # second tap within 3 s confirms
		refresh()
		return
	var t := tower
	placement.select(null)
	controller.try_sell(t)
