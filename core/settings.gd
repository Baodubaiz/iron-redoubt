extends Node
## Autoload "Settings": owns GameSettings, persists it and applies it to the audio buses.

signal changed

const PATH := "user://settings.cfg"

var data := GameSettings.new()


func _ready() -> void:
	data.load_from(PATH)
	apply()


func apply() -> void:
	data.clamp_values()
	I18n.apply(data.language)
	VisualPalette.reduce_effects = data.reduce_effects
	_apply_render_scale()
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
