class_name GameSettings
extends RefCounted
## Player settings model (pure, testable). Persisted with ConfigFile.

var music_on: bool = true
var sfx_on: bool = true
var music_volume: float = 0.6 ## 0..1 linear
var sfx_volume: float = 0.8 ## 0..1 linear
var language: String = "auto" ## "auto" (= English, the default), "en" or "vi"
var reduce_effects: bool = false ## fewer particles, no screen shake / flashes


func clamp_values() -> void:
	music_volume = clampf(music_volume, 0.0, 1.0) if is_finite(music_volume) else 0.6
	sfx_volume = clampf(sfx_volume, 0.0, 1.0) if is_finite(sfx_volume) else 0.8
	if not language in ["auto", "en", "vi"]:
		language = "auto"


func save(path: String) -> Error:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music_on", music_on)
	cf.set_value("audio", "sfx_on", sfx_on)
	cf.set_value("audio", "music_volume", music_volume)
	cf.set_value("audio", "sfx_volume", sfx_volume)
	cf.set_value("ui", "language", language)
	cf.set_value("ui", "reduce_effects", reduce_effects)
	return cf.save(path)


## Missing or corrupt files fall back to defaults.
func load_from(path: String) -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	music_on = bool(cf.get_value("audio", "music_on", music_on))
	sfx_on = bool(cf.get_value("audio", "sfx_on", sfx_on))
	music_volume = float(cf.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(cf.get_value("audio", "sfx_volume", sfx_volume))
	language = String(cf.get_value("ui", "language", language))
	reduce_effects = bool(cf.get_value("ui", "reduce_effects", reduce_effects))
	clamp_values()


## Bus volume in dB for a linear value (silence below 0.001).
static func to_db(linear: float, on: bool) -> float:
	if not on or linear <= 0.001:
		return -80.0
	return linear_to_db(linear)
