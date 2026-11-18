class_name SettingsPanel
extends PanelContainer
## Settings: music/SFX on-off + independent volumes, and the UI language. Saved immediately.
## Used by the Settings screen (with language) and the in-match pause menu (audio only).

signal closed
signal language_changed

var show_close: bool = true
var show_language: bool = true


func _ready() -> void:
	theme = UiKit.theme()
	add_theme_stylebox_override("panel", UiKit.chamfer(VisualPalette.SURFACE, VisualPalette.SURFACE_LINE, 14))
	custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	if show_close: # the Settings screen already has the title in its header
		v.add_child(UiKit.title(I18n.t("Settings").to_upper(), 26, UiKit.ACCENT, 3))
	var s: GameSettings = Settings.data
	_row(v, I18n.t("Music"), s.music_on, s.music_volume,
		func(on: bool) -> void: Settings.data.music_on = on; Settings.save(),
		func(val: float) -> void: Settings.data.music_volume = val; Settings.save())
	_row(v, I18n.t("Sound effects"), s.sfx_on, s.sfx_volume,
		func(on: bool) -> void: Settings.data.sfx_on = on; Settings.save(),
		func(val: float) -> void:
			Settings.data.sfx_volume = val
			Settings.save()
			UiKit.click())
	var fx := CheckButton.new()
	fx.text = I18n.t("Reduce effects")
	fx.tooltip_text = I18n.t("Fewer particles, no screen shake or flashes.")
	fx.button_pressed = s.reduce_effects
	fx.custom_minimum_size = Vector2(230, 56)
	fx.add_theme_font_size_override("font_size", 20)
	fx.toggled.connect(func(on: bool) -> void:
		Settings.data.reduce_effects = on
		Settings.save())
	v.add_child(fx)
	if show_language:
		_language_row(v)
	v.add_child(UiKit.label(I18n.t("Use the x1/x2 button in a match to change speed. Targeting is automatic."), 14, UiKit.MUTED))
	if show_close:
		v.add_child(UiKit.button(I18n.t("Close"), func() -> void: closed.emit(), Vector2(0, 56)))


func _language_row(v: VBoxContainer) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var l := UiKit.label(I18n.t("Language"), 20)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(300, 56)
	opt.add_theme_font_size_override("font_size", 20)
	var codes := ["auto", "en", "vi"]
	opt.add_item(I18n.t("Device language"))
	opt.add_item("English")
	opt.add_item("Tiếng Việt")
	opt.selected = maxi(codes.find(Settings.data.language), 0)
	opt.item_selected.connect(func(i: int) -> void:
		Settings.data.language = codes[i]
		Settings.save()
		language_changed.emit())
	h.add_child(opt)


func _row(v: VBoxContainer, title: String, on: bool, vol: float, on_toggle: Callable, on_volume: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var cb := CheckButton.new()
	cb.text = title
	cb.button_pressed = on
	cb.custom_minimum_size = Vector2(230, 56)
	cb.add_theme_font_size_override("font_size", 20)
	cb.toggled.connect(on_toggle)
	h.add_child(cb)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = vol
	slider.custom_minimum_size = Vector2(260, 56)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.drag_ended.connect(func(_changed: bool) -> void: on_volume.call(slider.value))
	h.add_child(slider)
	var pct := UiKit.label("%d%%" % int(round(vol * 100)), 18, UiKit.MUTED)
	pct.autowrap_mode = TextServer.AUTOWRAP_OFF
	pct.custom_minimum_size = Vector2(60, 0)
	slider.value_changed.connect(func(x: float) -> void: pct.text = "%d%%" % int(round(x * 100)))
	h.add_child(pct)
