class_name I18n
extends RefCounted
## Translation helpers usable from static code. Keys are the English source strings; the
## Vietnamese table lives in res://i18n/translations.csv (imported by Godot).

const LANGUAGES := {"en": "English", "vi": "Tiếng Việt"}


static func t(s: String) -> String:
	return String(TranslationServer.translate(s))


## Translates a format string, then fills it: I18n.f("Wave %d/%d", [3, 8]).
static func f(fmt: String, args: Variant) -> String:
	return t(fmt) % args


## "auto" follows the device language (Vietnamese if the OS locale is vi*, else English).
static func resolve(setting: String) -> String:
	if setting == "en" or setting == "vi":
		return setting
	return "vi" if OS.get_locale_language() == "vi" else "en"


static func apply(setting: String) -> void:
	TranslationServer.set_locale(resolve(setting))
