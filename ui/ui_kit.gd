class_name UiKit
extends RefCounted
## Iron Redoubt Reforged UI kit: theme (chamfered sci-fi panels/buttons, OFL fonts), icon loading and
## small builders shared by the menu screens. Presentation only.
## Older call sites keep working: screen(), header(), label(), button(), scroll(), click() and the
## colour constants (now mapped to the Reforged palette).

const BG := VisualPalette.BG
const TEXT := VisualPalette.TEXT
const MUTED := VisualPalette.TEXT_DIM
const ACCENT := VisualPalette.CYAN
const GOOD := VisualPalette.GREEN
const BAD := VisualPalette.RED
const GOLD := VisualPalette.ORANGE

const P = preload("res://ui/style/visual_palette.gd")
const FONT_BODY := "res://assets/fonts/BeVietnamPro-Regular.ttf"
const FONT_BODY_BOLD := "res://assets/fonts/BeVietnamPro-SemiBold.ttf"
const FONT_HEAD := "res://assets/fonts/ChakraPetch-Bold.ttf"
const FONT_UI := "res://assets/fonts/ChakraPetch-SemiBold.ttf"

static var _theme: Theme
static var _fonts := {}
static var _icons := {}


# ---------------------------------------------------------------- fonts & icons

## kind: "body", "body_bold", "head", "ui". spacing = extra pixels between glyphs.
static func font(kind: String = "body", spacing: int = 0) -> Font:
	var key := "%s:%d" % [kind, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var path: String = {"body": FONT_BODY, "body_bold": FONT_BODY_BOLD, "head": FONT_HEAD, "ui": FONT_UI}.get(kind, FONT_BODY)
	var base: Font = load(path)
	var f: Font = base
	if spacing != 0:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.spacing_glyph = spacing
		f = fv
	_fonts[key] = f
	return f


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := "res://assets/ui/icons/%s.svg" % name
		if not ResourceLoader.exists(path):
			path = "res://assets/art/towers/%s.svg" % name
		_icons[name] = load(path)
	return _icons[name]


static func tower_icon(id: StringName) -> Texture2D:
	return icon("icon_%s" % id)


# ---------------------------------------------------------------- theme

static func chamfer(bg: Color, border: Color = Color.TRANSPARENT, cut: int = 12, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw if border.a > 0.0 else 0)
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_detail = 1 # straight diagonal cut
	s.anti_aliasing = true
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme

	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 20
	t.set_color("font_color", "Label", P.TEXT)
	# panels / cards
	t.set_stylebox("panel", "PanelContainer", chamfer(Color(P.SURFACE, 0.90), P.SURFACE_LINE, 14))
	t.set_type_variation("CardGood", "PanelContainer")
	t.set_stylebox("panel", "CardGood", chamfer(Color(P.SURFACE, 0.92), Color(P.GREEN, 0.55), 14, 2))
	t.set_type_variation("CardAccent", "PanelContainer")
	t.set_stylebox("panel", "CardAccent", chamfer(Color(P.SURFACE, 0.94), Color(P.CYAN, 0.55), 14, 2))
	t.set_type_variation("Chip", "PanelContainer")
	var chip := chamfer(Color(P.BG_DEEP, 0.75), P.SURFACE_LINE, 8)
	chip.content_margin_top = 4
	chip.content_margin_bottom = 4
	chip.content_margin_left = 10
	chip.content_margin_right = 12
	t.set_stylebox("panel", "Chip", chip)
	# buttons
	_button_styles(t, "Button", {
		"normal": chamfer(Color(P.SURFACE, 0.92), P.SURFACE_LINE, 12, 2),
		"hover": chamfer(P.SURFACE_HI, Color(P.CYAN, 0.75), 12, 2),
		"pressed": chamfer(Color("2A3D63"), P.CYAN, 12, 2),
		"disabled": chamfer(Color(P.SURFACE, 0.45), Color(P.SURFACE_LINE, 0.5), 12, 2),
		"focus": chamfer(Color.TRANSPARENT, Color(P.CYAN, 0.5), 12, 2),
	})
	t.set_font("font", "Button", font("ui", 1))
	t.set_color("font_color", "Button", P.TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", P.TEXT)
	t.set_color("font_disabled_color", "Button", P.TEXT_FAINT)
	t.set_color("icon_normal_color", "Button", P.CYAN)
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", Color.WHITE)
	t.set_color("icon_focus_color", "Button", P.CYAN)
	t.set_color("icon_disabled_color", "Button", P.TEXT_FAINT)
	t.set_constant("h_separation", "Button", 12)
	t.set_constant("icon_max_width", "Button", 30)
	# primary (cyan, dark text)
	t.set_type_variation("PrimaryButton", "Button")
	var prim := chamfer(P.CYAN, Color("9FF0FF"), 16, 2)
	prim.shadow_color = Color(P.CYAN, 0.35)
	prim.shadow_size = 10
	var prim_h := prim.duplicate() as StyleBoxFlat
	prim_h.bg_color = Color("6BE6FA")
	prim_h.shadow_color = Color(P.CYAN, 0.55)
	prim_h.shadow_size = 16
	var prim_p := prim.duplicate() as StyleBoxFlat
	prim_p.bg_color = Color("22B6D6")
	_button_styles(t, "PrimaryButton", {"normal": prim, "hover": prim_h, "pressed": prim_p,
		"disabled": chamfer(Color(P.SURFACE, 0.6), Color(P.SURFACE_LINE, 0.6), 16, 2),
		"focus": chamfer(Color.TRANSPARENT, Color.WHITE, 16, 2)})
	t.set_font("font", "PrimaryButton", font("head", 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "PrimaryButton", P.BG)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		t.set_color(c, "PrimaryButton", P.BG)
	t.set_color("font_disabled_color", "PrimaryButton", P.TEXT_FAINT)
	t.set_color("icon_disabled_color", "PrimaryButton", P.TEXT_FAINT)
	# selectable cards (level cards, region tabs): toggle buttons
	t.set_type_variation("CardButton", "Button")
	var card_sel := chamfer(Color("1B2A48"), P.CYAN, 14, 3)
	card_sel.shadow_color = Color(P.CYAN, 0.30)
	card_sel.shadow_size = 12
	_button_styles(t, "CardButton", {
		"normal": chamfer(Color(P.SURFACE, 0.92), P.SURFACE_LINE, 14, 2),
		"hover": chamfer(P.SURFACE_HI, Color(P.CYAN, 0.6), 14, 2),
		"pressed": card_sel, "hover_pressed": card_sel,
		"disabled": chamfer(Color(P.BG_DEEP, 0.8), Color(P.SURFACE_LINE, 0.6), 14, 2),
		"focus": chamfer(Color.TRANSPARENT, Color.TRANSPARENT, 14, 0)})
	# icon-only ghost buttons
	t.set_type_variation("GhostButton", "Button")
	_button_styles(t, "GhostButton", {
		"normal": chamfer(Color(P.BG_DEEP, 0.55), P.SURFACE_LINE, 10, 2),
		"hover": chamfer(P.SURFACE_HI, Color(P.CYAN, 0.75), 10, 2),
		"pressed": chamfer(Color("2A3D63"), P.CYAN, 10, 2),
		"disabled": chamfer(Color(P.BG_DEEP, 0.3), Color(P.SURFACE_LINE, 0.4), 10, 2),
		"focus": chamfer(Color.TRANSPARENT, Color(P.CYAN, 0.5), 10, 2)})
	# check / option / slider / scroll / popup
	t.set_font("font", "CheckButton", font("ui"))
	t.set_color("font_color", "CheckButton", P.TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", P.TEXT)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	t.set_font("font", "OptionButton", font("ui"))
	var track := StyleBoxFlat.new()
	track.bg_color = P.BG_DEEP
	track.border_color = P.SURFACE_LINE
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = P.CYAN
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	var fill_h := fill.duplicate() as StyleBoxFlat
	fill_h.bg_color = Color("6BE6FA")
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(P.SURFACE_LINE, 0.4)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", sb)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(P.CYAN, 0.55)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var popup := chamfer(P.SURFACE, P.SURFACE_LINE, 10)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_font("font", "PopupMenu", font("ui"))
	t.set_font_size("font_size", "PopupMenu", 20)
	var hov := StyleBoxFlat.new()
	hov.bg_color = P.SURFACE_HI
	t.set_stylebox("hover", "PopupMenu", hov)
	# progress bars (best HP etc.)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(P.BG_DEEP, 0.9)
	pb_bg.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = P.GREEN
	pb_fill.set_corner_radius_all(2)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_constant("separation", "HBoxContainer", 10)
	_theme = t
	return t


static func _button_styles(t: Theme, type: String, styles: Dictionary) -> void:
	for st in styles:
		t.set_stylebox(st, type, styles[st])


# ---------------------------------------------------------------- builders

## Full-screen animated backdrop + safe-area margin; returns the content VBox.
static func screen(root: Control, backdrop_mode: int = MenuBackdrop.Mode.AMBIENT) -> VBoxContainer:
	root.theme = theme()
	var bg := MenuBackdrop.new()
	bg.mode = backdrop_mode
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ins := ScreenLayout.insets(root.get_viewport())
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24 + int(ins[side]))
	root.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	return v


## Off while a match is on screen (its HUD is scaled as a whole instead).
static var grow_small_text := true


## Font size adjusted for small screens: body text (<= 18) grows with ScreenLayout.ui_scale().
static func fs(size: int) -> int:
	if not grow_small_text or size > 18:
		return size
	return int(round(size * ScreenLayout.ui_scale()))


static func label(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Headline label in the display font (no wrapping).
static func title(text: String, size: int = 32, color: Color = TEXT, spacing: int = 2) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font("head", spacing))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func button(text: String, cb: Callable, min_size: Vector2 = Vector2(200, 56), variation: String = "",
		icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if variation != "":
		b.theme_type_variation = variation
	if icon_name != "":
		b.icon = icon(icon_name)
		b.expand_icon = false
	b.pressed.connect(click)
	b.pressed.connect(cb)
	juice(b)
	return b


static func icon_button(icon_name: String, cb: Callable, size: Vector2 = Vector2(60, 52)) -> Button:
	var b := button("", cb, size, "GhostButton", icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


## Motion style (2026-11-19, user: "everything smooth"): ease-out quart, no bounce / overshoot.
const MOTION_TRANS := Tween.TRANS_QUART
const MOTION_IN := 0.22 ## appear
const MOTION_OUT := 0.14 ## disappear


static func ease_tween(n: Node, parallel: bool = true) -> Tween:
	var tw := n.create_tween().set_trans(MOTION_TRANS).set_ease(Tween.EASE_OUT)
	if parallel:
		tw.set_parallel(true)
	return tw


## Fade + gentle grow in (alpha 0 -> 1, scale from `from` -> 1) around the centre.
static func pop_in(c: Control, from: float = 0.96, dur: float = MOTION_IN) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(from, from)
	var tw := ease_tween(c)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.8)
	tw.tween_property(c, "scale", Vector2.ONE, dur)


## Fade out, then hide (or run `done`). Kill the returned tween to cancel (e.g. shown again meanwhile).
static func fade_out(c: CanvasItem, dur: float = MOTION_OUT, done: Callable = Callable()) -> Tween:
	var tw := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 0.0, dur)
	tw.tween_callback(func() -> void:
		if done.is_valid():
			done.call()
		else:
			c.visible = false
		c.modulate.a = 1.0)
	return tw


## Press feedback: soft scale-down on press, smooth settle on release, light up on hover (mouse / web).
static func juice(c: Control) -> void:
	var fit := func() -> void: c.pivot_offset = c.size * 0.5
	c.resized.connect(fit)
	if c is BaseButton:
		var b := c as BaseButton
		b.button_down.connect(func() -> void:
			if b.disabled: return
			ease_tween(c).tween_property(c, "scale", Vector2(0.96, 0.96), 0.08))
		b.button_up.connect(func() -> void:
			ease_tween(c).tween_property(c, "scale", Vector2.ONE, 0.2))
		b.mouse_entered.connect(func() -> void:
			if b.disabled: return
			ease_tween(c).tween_property(c, "self_modulate", Color(1.12, 1.12, 1.12), 0.12))
		b.mouse_exited.connect(func() -> void:
			ease_tween(c).tween_property(c, "self_modulate", Color.WHITE, 0.18))


static func tex(t: Texture2D, size: float, color: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## icon + value, e.g. Cores / credits / waves. Returns the chip; its Label is child "Value".
## Tower rank badge (C / B / A / S / SS), colours from data/stats/rarity.tres.
static func rank_badge(id: StringName, size: int = 14) -> PanelContainer:
	var r := RarityCatalog.get_default().find(id)
	var col: Color = r.color if r != null else TEXT
	var acc: Color = r.accent if r != null else TEXT
	var p := PanelContainer.new()
	p.name = "Rank"
	var sb := chamfer(Color(col, 0.2), acc if id == &"SS" or id == &"S" else col, 5, 2)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := title(String(id), size, col, 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


static func chip(icon_name: String, text: String, color: Color, size: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Chip"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(tex(icon(icon_name), size + 4, color))
	var l := title(text, size, color, 1)
	l.name = "Value"
	h.add_child(l)
	return p


static func cores_chip() -> PanelContainer:
	# autoload looked up at runtime: UiKit is also compiled by gameplay scripts that load before
	# autoloads exist (headless test runner), so it must not name the autoload directly
	var prog := (Engine.get_main_loop() as SceneTree).root.get_node("/root/Progression")
	var c := chip("cores", str(prog.model.profile.cores()), GOLD, 22)
	c.name = "Cores"
	c.tooltip_text = I18n.t("Cores")
	return c


static func click() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("Audio"):
		tree.root.get_node("Audio").play(&"ui_click", 0.0)


static func header(v: VBoxContainer, title_text: String, back: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var b := icon_button("back", back, Vector2(64, 54))
	b.name = "Back"
	b.tooltip_text = I18n.t("Back")
	h.add_child(b)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(4, 34)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	var t := title(title_text.to_upper(), 30, TEXT, 3)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(cores_chip())
	v.add_child(h)
	return h


static func scroll(v: VBoxContainer) -> VBoxContainer:
	var s := DragScroll.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(s)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	s.add_child(inner)
	return inner


## Staggered entrance: fade + grow in. Uses scale/modulate only, never position, because
## containers own their children's positions (a position tween would fight the layout).
static func slide_in(nodes: Array, from: Vector2 = Vector2(-48, 0), step: float = 0.06, dur: float = 0.3) -> void:
	var i := 0
	for n in nodes:
		var c := n as Control
		if c == null or not is_instance_valid(c):
			continue
		c.modulate.a = 0.0
		c.scale = Vector2(0.94, 0.94)
		var origin := Vector2(0.0, 0.5) if from.x < 0.0 else (Vector2(1.0, 0.5) if from.x > 0.0 else Vector2(0.5, 0.0 if from.y < 0.0 else 1.0))
		var set_pivot := func() -> void: c.pivot_offset = c.size * origin
		set_pivot.call()
		var tw := ease_tween(c)
		tw.tween_callback(set_pivot).set_delay(i * step)
		tw.tween_property(c, "scale", Vector2.ONE, dur).set_delay(i * step)
		tw.tween_property(c, "modulate:a", 1.0, dur * 0.8).set_delay(i * step)
		i += 1


## Level title without the "N — " number prefix (cards show the number separately).
static func level_title(l: LevelDef) -> String:
	var s := I18n.t(l.display_name)
	var rx := RegEx.create_from_string("^[0-9]+ *[—:.-] *")
	return rx.sub(s, "")
