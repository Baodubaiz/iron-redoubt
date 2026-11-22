extends Node
## Autoload "Settings": owns GameSettings, persists it and applies it to the audio buses.

signal changed

const PATH := "user://settings.cfg"

var data := GameSettings.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # FPS readout keeps updating on the pause menu
	data.load_from(PATH)
	if CrazyGamesSdk.on_crazygames_host(): # browser language right away, the SDK's locale once it is up
		I18n.platform_locale = I18n.from_locale(CrazyGamesSdk.locale())
		CrazyGamesSdk.when_ready(_on_sdk_locale)
	apply()


func _on_sdk_locale() -> void:
	if not CrazyGamesSdk.is_active():
		return
	var lang := I18n.from_locale(CrazyGamesSdk.locale())
	if lang == I18n.platform_locale:
		return
	I18n.platform_locale = lang
	if data.language == "auto": # only when the player never picked a language themself
		apply()


func apply() -> void:
	data.clamp_values()
	I18n.apply(data.language)
	VisualPalette.reduce_effects = data.reduce_effects
	_apply_render_scale()
	_apply_fps_counter()
	_set_bus("Music", GameSettings.to_db(data.music_volume, data.music_on))
	_set_bus("SFX", GameSettings.to_db(data.sfx_volume, data.sfx_on))
	changed.emit()


## Web: draw the 2D scene at the 1280x720 base size (expanded to the screen's shape) and let the GPU scale it
## up, instead of drawing every physical pixel of a large / high-DPI screen. Same layout and input either way.
func _apply_render_scale() -> void:
	if not OS.has_feature("web") or not is_inside_tree():
		return
	var w := get_tree().root
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if data.sharp_graphics \
			else Window.CONTENT_SCALE_MODE_VIEWPORT


# ---------------------------------------------------------------- FPS readout (2026-11-22 perf)
var _fps_layer: CanvasLayer
var _fps_label: Label
var _fps_t := 0.0
var _fps_frames := 0
var _fps_worst := 0.0


func _apply_fps_counter() -> void:
	if not is_inside_tree():
		return
	if data.show_fps and _fps_layer == null:
		_fps_layer = CanvasLayer.new()
		_fps_layer.layer = 128
		_fps_label = Label.new()
		_fps_label.add_theme_font_size_override("font_size", 13)
		_fps_label.add_theme_color_override("font_color", Color("9FFFB0"))
		_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_fps_label.add_theme_constant_override("outline_size", 4)
		_fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_fps_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_fps_label.offset_right = -6
		_fps_label.offset_bottom = -4
		_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_layer.add_child(_fps_label)
		add_child(_fps_layer)
	if _fps_layer != null:
		_fps_layer.visible = data.show_fps
	set_process(data.show_fps)


## Average FPS over the last half second + the slowest frame in it (stutters show up there).
func _process(delta: float) -> void:
	if _fps_label == null:
		return
	_fps_t += delta
	_fps_frames += 1
	_fps_worst = maxf(_fps_worst, delta)
	if _fps_t >= 0.5:
		_fps_label.text = "%d FPS · %.1f ms · max %.0f ms" % [roundi(_fps_frames / _fps_t), 1000.0 * _fps_t / _fps_frames,
			1000.0 * _fps_worst]
		_fps_t = 0.0
		_fps_frames = 0
		_fps_worst = 0.0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo 			and (e as InputEventKey).keycode == KEY_F3:
		data.show_fps = not data.show_fps
		save()


func save() -> void:
	apply()
	data.save(PATH)


static func ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")
	return idx


func _set_bus(bus_name: String, db: float) -> void:
	var idx := ensure_bus(bus_name)
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, db <= -79.0)
